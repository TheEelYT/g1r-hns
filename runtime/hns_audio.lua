-- Add source M4A sequences/instruments to the imported native pack. Vanilla
-- SE/cries remain available; map/battle/jingle selection is scoped to HnS.
return function(mod,world,game)
  local Audio=require('src.core.game3.audio')
  local Player=require('src.core.game3.m4a_player')
  local Seq=require('src.core.game3.m4a_seq')
  local Mix=require('src.core.game3.m4a_mix')
  local Writer=require('src.import.LuaWriter')
  local old=game._hnsAudio or {}
  local base=game._hnsAudio and old.pack or Audio._pack
  if game._hnsAudio and old.pack==nil then base=nil end
  local baseCache=game._hnsAudio and old.cache or Audio._cache
  if game._hnsAudio and old.cache==nil then baseCache=nil end
  local customCache={read=function(_,rel)return mod:read(rel) end}
  local source=assert(Player.loadPack(customCache,'audio'))
  local function copy(t)local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
  local index=copy(base and base.index)
  for _,key in ipairs({'songs','fanfares','samples','voicegroups','roles','mapSongs'}) do index[key]=copy(index[key]) end
  local sampleBase=0x4000
  local vanilla=base and base.samplesBin or ''
  for id,row in pairs(source.samples) do
    id=tonumber(id);assert(not index.samples[id+sampleBase],'HnS sample namespace collision')
    local entry=copy(row);entry.id=id+sampleBase;entry.offset=entry.offset+#vanilla
    index.samples[id+sampleBase]=entry
  end
  for id,tones in pairs(source.voicegroups) do
    id=tonumber(id);assert(not index.voicegroups[id+sampleBase],'HnS voice namespace collision')
    local out={}
    for voice,tone in pairs(tones) do
      local entry=copy(tone)
      if entry.sampleId then entry.sampleId=entry.sampleId+sampleBase end
      if entry.subVgId then entry.subVgId=entry.subVgId+sampleBase end
      out[voice]=entry
    end
    index.voicegroups[id+sampleBase]=out
  end
  for id,row in pairs(source.index.songs) do
    id=tonumber(id);assert(not index.songs[id],'HnS song namespace collision')
    local entry=copy(row);entry.voicegroupId=entry.voicegroupId+sampleBase
    entry.hnsSoundMode=world.audio.soundMode
    index.songs[id]=entry
  end
  for id,row in pairs(world.audio.fanfares) do index.fanfares[tonumber(id)]=row end
  for id,song in pairs(world.audio.mapSongs) do index.mapSongs[id]=song end
  local root=Audio._root
  local mergedSamples=vanilla..source.samplesBin
  local overlay={}
  function overlay:read(rel)
    if rel==root..'/index.lua' then return Writer.encode(index) end
    if rel==root..'/samples.bin' then return mergedSamples end
    local id=type(rel)=='string' and rel:match('/songs/(%d+)%.bin$')
    if id and world.audio.songs[id] then return mod:read('audio/songs/'..id..'.bin') end
    return baseCache and baseCache:read(rel)
  end
  -- The worker reads filesystem paths directly and cannot see a mod overlay.
  -- Use native synchronous mixing for this pack, with the engine's buffered
  -- queue, so owned samples stay portable and independent of mounted roots.
  if Audio._cmdCh then Audio._cmdCh:push({cmd='stop'}) end
  if Audio._outCh then Audio._outCh:clear() end
  Audio._worker=false
  Audio._pack={root=root,index=index,samplesBin=mergedSamples,samples=index.samples,
    voicegroups=index.voicegroups,songCache={}}
  Audio._cache=overlay;Audio._meta=index;Audio._ready=true
  Audio._seRawClear();Audio._fanfareSd={};Audio._fanfareSrc={}
  local sourceSeq=assert(load(mod:read('hns_m4a_seq.lua'),'@hns/hns_m4a_seq.lua'))()
  local start=old.start or Player.start
  local update=old.seqUpdate or Seq.update
  Player.start=function(pack,cache,slot,id,opts)
    local ok=start(pack,cache,slot,id,opts)
    local mode=ok and slot.info and slot.info.hnsSoundMode
    if mode and slot.seq then
      slot.seq.hnsMaxDsChannels=mode.maxDsChannels
      local resolve=slot.seq.voiceResolver
      slot.seq.voiceResolver=function(...)
        local voice=resolve(...)
        -- Fixed-rate DS instruments use HnS's mixer clock (304 samples per
        -- VBlank), not FireRed's 224. Pitched samples retain their source tuning.
        if voice and voice.kind=='ds' and voice.fixedFreq then
          voice.step=mode.samplesPerVBlank*Mix.GBA_VBLANK_HZ/Mix.SAMPLE_RATE
        end
        return voice
      end
    end
    return ok
  end
  Seq.update=function(player,vblanks)
    if player and player.hnsMaxDsChannels then return sourceSeq.update(player,vblanks) end
    return update(player,vblanks)
  end
  local function own()
    local session=require('src.core.game3.runtime').getSession()
    return session and world.maps[session.map]~=nil
  end
  local constants=require('src.core.game3.constants').of('emerald')
  local aliases={}
  for name,id in pairs(world.audio.aliases) do
    local native=constants.songs.byName[name]
    if native then aliases[native]=id end
  end
  local playSong=old.playSong or Audio.playSong
  local playFanfare=old.playFanfare or Audio.playFanfare
  local role=old.role or Audio.role
  local function translate(id)
    if own() then return aliases[Audio.resolveSong(id)] or id end
    return id
  end
  Audio.playSong=function(id,opts)return playSong(translate(id),opts) end
  Audio.playFanfare=function(id)return playFanfare(translate(id)) end
  -- HnS battle_anim_throw.c uses HG_EVOLVED as the SE at capture frame 95;
  -- battle_message.c then starts HG_CAUGHT after that SE finishes.
  local intro=Audio.resolveSong('MUS_CAUGHT_INTRO')
  local playSe=old.playSe or Audio.playSe
  local waitSe=old.waitSe or Audio.waitSe
  local function captureCue(id)
    if own() and intro and Audio.resolveSong(id)==intro then return world.audio.roles.evolved end
    return id
  end
  Audio.playSe=function(id,opts)return playSe(captureCue(id),opts)end
  Audio.waitSe=function(id,cb)return waitSe(captureCue(id),cb)end
  Audio.role=function(name)if own() and world.audio.roles[name] then return world.audio.roles[name] end;return role(name) end
  local Profile=require('src.core.game3.battle.profile')
  local battleSong=old.battleSong or Profile.battleSong
  local victorySong=old.victorySong or Profile.victorySong
  local function leader(info)
    local cls=world.trainers.classes[tostring(info and info.trainerClass)]
    return cls and cls.source=='TRAINER_CLASS_LEADER_HNS'
  end
  local function rival(info)
    local cls=world.trainers.classes[tostring(info and info.trainerClass)]
    return cls and cls.source=='TRAINER_CLASS_RIVAL_HNS'
  end
  Profile.battleSong=function(p,info)
    if own() and not (info and info.link) then
      if leader(info) then return world.audio.roles.battleGymLeader end
      if rival(info) then return world.audio.roles.battleRival end
    end
    return battleSong(p,info)
  end
  Profile.victorySong=function(p,info)if own() and leader(info) then return world.audio.roles.victoryGymLeader end;return victorySong(p,info) end
  game._hnsAudio={pack=base,cache=baseCache,playSong=playSong,playFanfare=playFanfare,playSe=playSe,waitSe=waitSe,role=role,overlay=overlay,battleSong=battleSong,victorySong=victorySong,start=start,seqUpdate=update}
end
