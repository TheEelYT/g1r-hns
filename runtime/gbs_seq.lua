-- HnS src/gbs.c command engine. Pointer operands address the source-only pack.
-- Timing retains the source's fractional note carry; loops execute indefinitely.
local Q={}
local bit=require('bit');local band,bor=bit.band,bit.bor
local floor=math.floor
function Q.new(data,header,tables)
  local s={data=data,tables=tables,regs={},tracks={},tempo=256,done=false,stereo=true}
  for i=0,63 do s.regs[i]=0 end
  function s:byte(p)return assert(self.data:byte(p+1),'GB instruction outside source pack')end
  function s:ptr(p)return self:byte(p)+self:byte(p+1)*256+self:byte(p+2)*65536+self:byte(p+3)*16777216 end
  for i=0,s:byte(header)-1 do
    local p=s:ptr(header+8+i*4);assert(s:byte(p)==0xBC and s:byte(p+1)==0);p=p+2
    if s:byte(p)==0xBB then p=p+2 end;assert(s:byte(p)==0xB6)
    local ch=s:byte(p+1);local t=setmetatable({channel=ch%4,pc=p+2,active=true,ret=false,volX=64,pan=255,noteUnitLength=1,sfx=ch>=4,raw=ch>=4},{__index=function()return 0 end})
    s.tracks[#s.tracks+1]=t
  end
  return s
end
local function pitch(s,n,key,oct)
  local shift=oct+floor(key/16);local value=s.tables.frequency[n+key%16+1]
  return band(bit.arshift(value,7-shift),2047)
end
local function note(s,t,cmd)
  local length=t.noteUnitLength*(cmd%16+1)*s.tempo+t.noteLength2
  t.noteLength1=floor(length/256)%256;t.noteLength2=length%256
  if t.noiseActive==true and t.channel==3 then
    if cmd>=16 then t.noise=s.tables.groups[t.dutyCycle+1][floor(cmd/16)+1];t.noisePos=1;t.noiseSampleCountdown=0 end
  elseif cmd>=16 then
    t.pitch=pitch(s,floor(cmd/16),t.keyShift,t.currentOctave);t.noteNoiseSampling=true
    if t.pitchBendActivation==true then
      t.pitchBendDuration=t.noteLength1<=t.pitchBendDuration and 1 or t.noteLength1-t.pitchBendDuration
      local distance=0
      if t.pitch<t.pitchBendTarget then
        if t.pitchBendTarget%256-t.pitch%256<0 then distance=512 end
        distance=distance+t.pitchBendTarget-t.pitch;t.pitchBendDir=true
      else
        if t.pitch%256-t.pitchBendTarget%256<0 then distance=512 end
        distance=distance+t.pitch-t.pitchBendTarget;t.pitchBendDir=false
      end
      t.pitchBendAmount=(floor(distance/t.pitchBendDuration)+1)%256;t.pitchBendFraction=(distance%t.pitchBendDuration)%256;t.pitchBendFractionAccumulator=0
    end
  else t.noteRest=true end
end
local function commands(s,t)
  local function read()local v=s:byte(t.pc);t.pc=t.pc+1;return v end
  local function word()local v=read();return v+read()*256 end
  local cmd=read();local active=true;local count=0
  while cmd>=0xD0 do
    count=count+1;assert(count<10000,'GB command loop has no note')
    if cmd<=0xD7 then t.currentOctave=cmd%8
    elseif cmd==0xD8 then t.noteUnitLength=read();if t.channel~=3 then local e=read();t.velocity=floor(e/16);t.envelope=e%16 end
    elseif cmd==0xD9 then t.keyShift=read()
    elseif cmd==0xDA then s.tempo=word()
    elseif cmd==0xDB then t.dutyCycle=read()
    elseif cmd==0xDC then local e=read();t.velocity=floor(e/16);t.envelope=e%16
    elseif cmd==0xDD then t.pitchSweep=read();t.notePitchSweep=true
    elseif cmd==0xDE then t.dutyCycleLoop=true;t.dutyCyclePattern=read();t.dutyCycle=t.dutyCyclePattern%4
    elseif cmd==0xDF then t.raw=not t.raw
    elseif cmd==0xE0 then t.pitchBendDuration=read();local n=read();t.pitchBendTarget=pitch(s,n%16,t.keyShift,floor(n/16));t.pitchBendActivation=true
    elseif cmd==0xE1 then
      local delay=read();local b=read()
      if b~=0 then t.modulationActivation=true;t.modulationDir=false;t.modulationDelay=delay;t.modulationDelayCountdown=delay;t.modulationMode=0;t.modulationDepth=floor(b/16);t.modulationSpeed=b%16;t.modulationCountdown=t.modulationSpeed
      else t.modulationActivation=false end
    elseif cmd==0xE3 or cmd==0xF0 then
      if t.noiseActive==true then t.noiseActive=false else t.noiseActive=true;t.dutyCycle=read()end
    elseif cmd==0xE5 then t.channelVolume=read();t.volumeChange=true
    elseif cmd==0xE6 then local n=word();t.tone=n>=32768 and n-65536 or n;t.pitchOffset=true
    elseif cmd==0xEF then t.pan=read()
    elseif cmd==0xFB then t.pc=t.pc+5
    elseif cmd==0xFC then t.pc=s:ptr(t.pc)
    elseif cmd==0xFD then
      local n=read();local key=t.ret and 'loopCounter2'or 'loopCounter'
      if n==0 or n-1>t[key]then if n~=0 then t[key]=(t[key]+1)%256 end;t.pc=s:ptr(t.pc)
      elseif n~=0 and t[key]~=0 then t[key]=0;t.pc=t.pc+4 end
    elseif cmd==0xFE then if not t.ret then t.ret=t.pc+4;t.pc=s:ptr(t.pc)end
    elseif cmd==0xFF then if not t.ret then active=false;t.noteRest=true else t.pc=t.ret;t.ret=false end
    -- Remaining commands are no-ops in the pinned HnS engine too.
    end
    cmd=read()
  end
  if active then
    if t.raw then
      local e=read();t.noteNoiseSampling=true;t.noteLength1=(cmd+1)%256;t.noteLength2=0;t.velocity=floor(e/16);t.envelope=e%16
      if t.channel==3 then t.pitch=band(t.pitch,0xFF00)+read()else t.pitch=word()end
    else note(s,t,cmd)end
  end
  t.modulationDelayCountdown=t.modulationDelay;return active
end
local function clear(s,t)
  local pos=t.channel*8;local r=s.regs
  r[pos]=0;r[pos+1]=0;r[pos+2]=0;r[pos+3]=8;r[pos+4]=0;r[pos+5]=128
  r[33]=band(r[33],255-(2^t.channel+2^(t.channel+4)))
end
local function update(s,t)
  t.noteDutyOverride=false;t.noteFreqOverride=false;t.notePitchSweep=false;t.noteNoiseSampling=false;t.noteRest=false;t.noteVibratoOverride=false
  if t.noteLength1<2 then t.active=commands(s,t)else t.noteLength1=t.noteLength1-1 end
  if t.channel==0 and t.pitchBendActivation==true then
    local p=t.pitch
    if t.pitchBendDir==true then
      local f=t.pitchBendFractionAccumulator+t.pitchBendFraction;p=(p+t.pitchBendAmount+(f>=256 and 1 or 0))%65536;t.pitchBendFractionAccumulator=f%256
      if p<t.pitchBendTarget then t.pitch=p;t.noteFreqOverride=true else t.pitchBendActivation=false;t.pitchBendDir=false end
    else
      local f=t.pitchBendFraction*2;p=(p-t.pitchBendAmount-(f>=256 and 1 or 0))%65536;t.pitchBendFraction=f%256
      if p>t.pitchBendTarget then t.pitch=p;t.noteFreqOverride=true else t.pitchBendActivation=false;t.pitchBendDir=false end
    end
  end
  if t.dutyCycleLoop==true then t.dutyCycle=floor(t.dutyCyclePattern/64);t.dutyCyclePattern=(t.dutyCyclePattern*4+t.dutyCycle)%256;t.noteDutyOverride=true end
  local p=t.pitch;if t.pitchOffset==true then p=(p+t.tone)%65536 end
  if t.modulationActivation==true then
    if t.modulationDelayCountdown>0 then t.modulationDelayCountdown=t.modulationDelayCountdown-1
    elseif t.modulationDepth~=0 then
      if t.modulationCountdown>0 then t.modulationCountdown=t.modulationCountdown-1
      elseif t.pitch~=0 then
        t.modulationDir=not(t.modulationDir==true);t.modulationCountdown=t.modulationSpeed
        local half=floor(t.modulationDepth/2);p=(p+(t.modulationDir and t.modulationDepth-half or -half))%65536;t.noteVibratoOverride=true
      end
    end
  end
  if t.channel==3 and t.noiseActive==true then
    if t.noiseSampleCountdown>0 then t.noiseSampleCountdown=t.noiseSampleCountdown-1
    elseif type(t.noise)=='table'and t.noise[t.noisePos]~=255 then
      local n=t.noise[t.noisePos];t.noisePos=t.noisePos+1;t.noiseSampleCountdown=n%16+1
      t.envelope=t.noise[t.noisePos];t.noisePos=t.noisePos+1;t.pitch=t.noise[t.noisePos];t.noisePos=t.noisePos+1;t.noteNoiseSampling=true
    end
  end
  local r=s.regs;local ch=t.channel;local pos=ch*8
  local function frequency(v)r[pos+4]=v%256;r[pos+5]=floor(v/256)%256 end
  local function pan()local mask=2^ch+2^(ch+4);r[33]=bor(band(r[33],255-mask),s.stereo~=false and band(mask,t.pan)or mask)end
  if ch==0 and t.notePitchSweep then r[0]=t.pitchSweep end
  if t.noteRest then clear(s,t)
  elseif t.noteNoiseSampling then
    pan()
    if ch<2 then r[ch==0 and 2 or 8]=bor(63,t.dutyCycle*64);r[ch==0 and 3 or 9]=bor(t.envelope,t.velocity*16);frequency(bor(p,32768))
    elseif ch==2 then
      r[18]=63;r[16]=64
      if t.envelope<#s.tables.waves and s.wave~=t.envelope then
        for i,n in ipairs(s.tables.waves[t.envelope+1])do r[47+i]=n end;s.wave=t.envelope
      end
      r[19]=(t.velocity*32)%256;r[16]=128;frequency(bor(p,32768))
    else r[24]=63;r[25]=bor(t.envelope,t.velocity*16);r[28]=t.pitch%256;r[29]=128 end
  else
    if ch==0 and t.noteFreqOverride or ch<3 and t.noteVibratoOverride then frequency(p);if ch<2 then t.noteDutyOverride=true end end
    if ch<2 and t.noteDutyOverride then local n=ch==0 and 2 or 8;r[n]=bor(band(r[n],63),t.dutyCycle*64)end
  end
  local master=floor(t.volX/8);master=math.min(7,master);master=master*17
  if master==119 and t.volumeChange==true then master=t.channelVolume;t.volumeChange=false end
  local l,rvol=floor(master/16)%8,master%8;l=l>1 and l-2 or 0;rvol=rvol>1 and rvol-2 or 0;s.regs[32]=l*16+rvol
end
function Q.frame(s)
  local active=false
  for _,t in ipairs(s.tracks)do if t.active then update(s,t);active=active or t.active end end
  s.done=not active;return s.regs
end
function Q.clearTriggers(s)
  for _,n in ipairs({5,13,21,29})do s.regs[n]=band(s.regs[n],127)end
end
return Q
