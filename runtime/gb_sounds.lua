-- Source GBS register streams share native BGM/fanfare queues and CGB synthesis.
return function(mod,w,game)
  local old=game._hnsGbSounds or {};local G={spec=w.audio.gbSounds,cache={}}
  local Audio=require('src.core.game3.audio');local Player=require('src.core.game3.m4a_player');local Mix=require('src.core.game3.m4a_mix')
  local Rt=require('src.core.game3.runtime');local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
  local function own(s)return s and w.maps[s.map]~=nil end
  function G.enabled(s)return own(s or Rt.getSession())and Space.store and Flags.getFlag(Space.store,nil,G.spec.flag)end
  local Seq=assert(load(mod:read('gbs_seq.lua')))()
  local data=assert(mod:read(G.spec.file));local tables=assert(load(mod:read(G.spec.tables)))()
  local start=old.start or Player.start;local update=old.update or Player.updateSlot
  Player.start=function(pack,cache,slot,id,opts)
    slot.hnsGB=nil
    local row=G.enabled()and G.spec.songs[tostring(id)]
    if not row then return start(pack,cache,slot,id,opts)end
    slot.songId=id;slot.info=Player.songInfo(pack,id);slot.seq=nil;slot.voices={};slot.done=false;slot.sampleOnly=false
    slot.frameSamplesLeft=0;slot.frameSampleCarry=0;slot.hpfState={l=0,r=0};slot.reverbState=nil
    slot.hnsGB={source=Seq.new(data,row.header,tables),frame=0,channels={}};return true
  end
  function G.frame(slot)
    local st=slot.hnsGB;local source=st.source
    if source.done then slot.done=true;slot.voices={};return end
    source.stereo=not Audio._mono
    local regs=Seq.frame(source);local function byte(n)return regs[n]end
    local function word(n)return byte(n)+byte(n+1)*256 end
    local pan=byte(33);local master=byte(32);local voices={}
    for ch=1,4 do
      local pos=(ch-1)*8;local freq=ch<4 and word(pos+4)or 0
      local trigger=ch<4 and freq>=32768 or ch==4 and byte(29)>=128
      local v=st.channels[ch];local period=freq%2048
      local enabled=math.floor(pan/2^(ch-1))%2==1 or math.floor(pan/2^(ch+3))%2==1
      if not enabled then if v then v.alive=false end;st.channels[ch]=nil
      else
        if trigger or not v then
          if ch<=2 then
            v=Mix.newCgbPulse({periodReg=period,cgbChan=ch,duty=math.floor(byte(ch==1 and 2 or 8)/64),tone={pan=ch==1 and byte(0)or 0}})
            -- Native ADSR is M4A-specific; GBS uses hardware envelopes below.
            v.adsr=nil
          elseif ch==3 then v=Mix.newCgbWave({freq=Mix.periodToPulseHz(period)*.5})
          else v=Mix.newCgbNoise()end
          v.hnsGB=true;v.gbClock=0;v.gbLastPeriod=period
          local env=byte(ch==1 and 3 or ch==2 and 9 or 25)
          v.gbVolume=math.floor(env/16);v.gbEnvelope=env%8;v.gbDirection=math.floor(env/8)%2==1 and 1 or -1
          st.channels[ch]=v
        end
        if ch<=2 then
          v.duty=math.floor(byte(ch==1 and 2 or 8)/64)
          if period~=v.gbLastPeriod then v.periodReg=period;v.freq=Mix.periodToPulseHz(period);v.gbLastPeriod=period end
        elseif ch==3 then
          v.freq=Mix.periodToPulseHz(period)*.5;v.wave={}
          for i=0,15 do local n=byte(48+i);v.wave[i*2+1]=math.floor(n/16);v.wave[i*2+2]=n%16 end
          -- GBA NR32 bit 7 overrides the ordinary GB level with 75% output.
          v.gbVolume=byte(19)>=128 and 11 or (({[0]=0,15,7,3})[math.floor(byte(19)/32)%4]or 0)
        else
          local nr=byte(28);local div=({[0]=8,16,32,48,64,80,96,112})[nr%8]
          v.period=Mix.SAMPLE_RATE*div*2^math.floor(nr/16)/4194304;v.shortNoise=math.floor(nr/8)%2==1
        end
        if ch~=3 and not trigger and v.gbEnvelope>0 then
          v.gbClock=v.gbClock+64/Mix.GBA_VBLANK_HZ
          while v.gbClock>=v.gbEnvelope do v.gbClock=v.gbClock-v.gbEnvelope;v.gbVolume=math.max(0,math.min(15,v.gbVolume+v.gbDirection))end
        end
        v.envVol=v.gbVolume;v.routeL=math.floor(pan/2^(ch+3))%2==1;v.routeR=math.floor(pan/2^(ch-1))%2==1
        v.gbGainL=(math.floor(master/16)%8+1)/8;v.gbGainR=(master%8+1)/8
        voices[#voices+1]=v
      end
    end
    slot.voices=voices;st.frame=st.frame+1;Seq.clearTriggers(source);slot.done=source.done
  end
  Player.updateSlot=function(slot,frames)
    if not(slot and slot.hnsGB)then return update(slot,frames)end
    slot.hnsGB.carry=(slot.hnsGB.carry or 0)+math.max(0,tonumber(frames)or 1)
    while slot.hnsGB.carry>=1 do slot.hnsGB.carry=slot.hnsGB.carry-1;G.frame(slot)end
  end
  -- Native PSG buses ignore per-voice M4A gains. Apply source NR50 after the
  -- native oscillator/DC filter, without affecting ordinary M4A voices.
  local render=old.render or Mix.render
  Mix.render=function(voices,n,opts)
    local v=voices and voices[1]
    if not(v and v.hnsGB)then return render(voices,n,opts)end
    local ownOpts={};for k,val in pairs(opts or {})do ownOpts[k]=val end;ownOpts.raw=true
    local l,r,alive=render(voices,n,ownOpts)
    for i=1,#l do l[i]=l[i]*v.gbGainL;r[i]=r[i]*v.gbGainR end
    if opts and opts.raw then return l,r,alive end
    if not(love and love.sound and love.sound.newSoundData)then return l,alive end
    local sd=love.sound.newSoundData(n,(opts and opts.sampleRate)or Mix.SAMPLE_RATE,16,2)
    for i=1,n do sd:setSample(i-1,1,math.max(-1,math.min(1,l[i])));sd:setSample(i-1,2,math.max(-1,math.min(1,r[i])))end
    return sd,alive
  end
  function G.toggle(s)
    if not own(s)then return false end
    local on=not G.enabled(s);Flags.setFlag(Space.store,nil,G.spec.flag,on)
    Audio._fanfareSd={};Audio._fanfareSrc={};Audio._seRawClear()
    Audio.playSong(0);Audio.mapLoadMusic({mapId=s.map,music=w.audio.mapSongs[s.map],restart=true})
    return true,'gb_sounds',on and G.spec.onText or G.spec.offText
  end
  if not old.hook then
    mod.hooks:wrap('item.use',function(next,g,ctx,id,...)
      if g==game and own(Rt.getSession())and (id==w.startup.gbItem or id=='HNS_GB_PLAYER')then return G.toggle(Rt.getSession())end
      return next(g,ctx,id,...)
    end)
  end
  game._hnsGbSounds={sounds=G,start=start,update=update,render=render,hook=true}
end
