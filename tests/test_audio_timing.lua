-- Note lengths and instrument coverage through the actual native allocator,
-- sequencer, sample resolver and mixer. Keep the old allocator as a control.
return function(T,game,world)
  local Audio=require('src.core.game3.audio')
  local Player=require('src.core.game3.m4a_player')
  local Mix=require('src.core.game3.m4a_mix')
  local mode=world.audio.soundMode
  T.eq(mode.maxDsChannels,15,'HnS source config has fifteen sampled voices')
  T.eq(mode.samplesPerVBlank,304,'HnS source mixer clock has 304 samples per VBlank')
  local original=game._hnsAudio.start
  local report={}
  local function trace(id,legacy)
    local slot={};assert((legacy and original or Player.start)(Audio._pack,Audio._cache,slot,id))
    local resolve=slot.seq.voiceResolver
    local created,events={},{};local frame=0
    slot.seq.voiceResolver=function(voice,key,vel,tr,...)
      local v=resolve(voice,key,vel,tr,...)
      if v then
        created[#created+1]={voice=v,started=frame}
        events[#events+1]=table.concat({frame,tr.index,voice,key,vel},':')
      end
      return v
    end
    local peak,cuts=0,0
    for f=1,360 do
      frame=f;Player.updateSlot(slot,1)
      local n=0
      for _,v in ipairs(slot.seq.voices) do if v.kind=='ds' and v.alive then n=n+1 end end
      peak=math.max(peak,n)
      for _,event in ipairs(created) do
        local v=event.voice
        if not event.cut and v.loop and v.alive==false and not v.released and v.gateTicks and v.gateTicks>0 then
          event.cut=true;cuts=cuts+1
        end
      end
      Player.renderSlot(slot,math.floor(Mix.samplesPerVBlank()),{raw=true})
      slot.seq.voices=slot.voices
    end
    return {peak=peak,prematureLoopedCuts=cuts,noteOnsets=table.concat(events,','),notes=#events}
  end
  for _,name in ipairs({'MUS_HG_NEW_BARK','MUS_HG_ROUTE29','MUS_HG_VIOLET','MUS_HG_VS_TRAINER'}) do
    local id
    for key,value in pairs(world.audio.songs) do if value==name then id=tonumber(key) end end
    local before,after=trace(assert(id),true),trace(id,false)
    T.eq(before.peak,5,'old player saturates five voices: '..name)
    T.check(before.prematureLoopedCuts>0,'old player reproduces truncated sustain: '..name)
    T.check(after.peak>5 and after.peak<=15,'source player retains overlapping instruments: '..name)
    T.eq(after.prematureLoopedCuts,0,'source player avoids premature note stealing: '..name)
    T.eq(after.noteOnsets,before.noteOnsets,'all note start times/pitches/velocities unchanged: '..name)
    report[#report+1]={name=name,before={peak=before.peak,cuts=before.prematureLoopedCuts},after={peak=after.peak,cuts=after.prematureLoopedCuts},notes=after.notes}
    print(('Audio sustain: %s, old peak=%d/cuts=%d; source peak=%d/cuts=%d; %d identical note onsets'):format(name,before.peak,before.prematureLoopedCuts,after.peak,after.prematureLoopedCuts,after.notes))
  end
  -- Reuse an imported looped sample, with a known test envelope to isolate
  -- note-gate/release semantics from the sample's natural decay.
  local sampleId
  for id,sample in pairs(Audio._pack.samples) do
    if math.floor((sample.status or 0)/16384)%4~=0 and sample.loopStart<sample.size then sampleId=id;break end
  end
  assert(sampleId,'an imported looped sample is required')
  local function u32(n)return string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,math.floor(n/16777216)%256) end
  local function fixture(track,source,fixed)
    local blob=string.char(1,0,0,0)..u32(0)..u32(16)..u32(#track)..track
    local info={voicegroupId=1,hnsSoundMode=source and mode or nil}
    local tone={type=fixed and 8 or 0,sampleId=sampleId,key=60,attack=255,decay=0,sustain=255,release=192}
    local pack={root='timing',index={songs={[1]=info}},samples=Audio._pack.samples,samplesBin=Audio._pack.samplesBin,
      voicegroups={[1]={[0]=tone}},songCache={}}
    local cache={read=function(_,path)assert(path=='timing/songs/1.bin');return blob end}
    local slot={};assert(Player.start(pack,cache,slot,1));return slot
  end
  local header=string.char(0xBB,75,0xBD,0)
  local chord=header
  for key=60,66 do chord=chord..string.char(0xFF,key,100) end -- N96
  chord=chord..string.char(0xB0,0xB1) -- W96, FINE
  local source,vanilla=fixture(chord,true),fixture(chord,false)
  Player.updateSlot(source,1);Player.updateSlot(vanilla,1)
  T.eq(#source.voices,7,'seven-note chord keeps every source instrument')
  T.eq(#vanilla.voices,5,'vanilla allocator remains unchanged')
  T.eq(vanilla.seq.hnsMaxDsChannels,nil,'vanilla slot never receives source policy')
  for _,case in ipairs({{name='N24',note=string.char(0xE7,60,100),gate=24},
      {name='N24 with gate extension',note=string.char(0xE7,60,100,3),gate=27},
      {name='TIE/EOT',note=string.char(0xCF,60,100),gate=24,tied=true}}) do
    local tail=case.tied and string.char(0x98,0xCE,60,0x98,0xB1) or string.char(0x98,0x98,0xB1)
    local slot=fixture(header..case.note..tail,true)
    Player.updateSlot(slot,1);local voice=assert(slot.voices[1])
    T.eq(voice.envVol,255,'native instrument attacks at note start: '..case.name)
    local expectedGate=case.gate;if case.tied then expectedGate=nil end
    T.eq(voice.gateTicks,expectedGate,'source gate is decoded exactly: '..case.name)
    for _=2,case.gate do Player.updateSlot(slot,1) end
    T.eq(voice.released,nil,'note sustains through its full gate: '..case.name)
    T.eq(voice.envVol,255,'looped sample maintains sustain: '..case.name)
    Player.updateSlot(slot,1)
    T.eq(voice.released,true,'note release starts at exact gate/end-tie tick: '..case.name)
    local expected=255
    for i=1,5 do
      expected=math.floor(expected*192/256)
      T.eq(voice.envVol,expected,'native release envelope tick '..i..': '..case.name)
      if i<5 then Player.updateSlot(slot,1) end
    end
  end
  local fixed=fixture(header..string.char(0xFF,60,100,0xB0,0xB1),true,true)
  local fixedVanilla=fixture(header..string.char(0xFF,60,100,0xB0,0xB1),false,true)
  Player.updateSlot(fixed,1);Player.updateSlot(fixedVanilla,1)
  T.eq(fixed.voices[1].step,mode.samplesPerVBlank*Mix.GBA_VBLANK_HZ/Mix.SAMPLE_RATE,'fixed-rate source instrument uses HnS mixer rate')
  T.eq(fixedVanilla.voices[1].step,Mix.GBA_MIX_RATE/Mix.SAMPLE_RATE,'vanilla fixed-rate instrument retains native rate')
  return report
end
