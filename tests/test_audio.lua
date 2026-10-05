-- Exercise the real native sequencer/mixer, map policy, jingles and restoration.
return function(T,game,world,maps,testDir)
  local Audio=require('src.core.game3.audio');local Player=require('src.core.game3.m4a_player')
  local Rt=require('src.core.game3.runtime');local Avatar=require('src.core.game3.player')
  local Profile=require('src.core.game3.battle.profile');local C=require('src.core.game3.constants').of('emerald')
  local savedSession,savedGame=Rt.session,Rt._game
  local surfing,biking=Avatar.surfing,Avatar.biking
  Rt._game=game;Avatar.surfing=false;Avatar.biking=false
  local count=0;local silent={}
  for id,name in pairs(world.audio.songs) do
    id=tonumber(id);count=count+1
    T.check(id<0x4000,'source cue is immediate, never a script variable')
    local info=Audio.songInfo(id)
    T.check(info and info.tracks>0,'source song has native tracks '..name)
    local slot={};T.eq(Player.start(Audio._pack,Audio._cache,slot,id),true,'native song starts '..name)
    local energy=0;local finite=true
    for _=1,4 do
      local left,right=Player.renderBuffered(slot,22050,{raw=true})
      for i=1,#left do energy=energy+math.abs(left[i])+math.abs(right[i]);finite=finite and math.abs(left[i])<math.huge and math.abs(right[i])<math.huge end
      if energy>0 then break end
    end
    T.check(energy>0,'source song produces audible PCM '..name)
    T.check(finite,'source PCM contains finite samples '..name)
    if energy==0 then silent[#silent+1]=name end
  end
  T.eq(count,world.audio.songCount,'every packaged song is sequenced and mixed')
  assert(loadfile(testDir..'/test_audio_timing.lua'))()(T,game,world)
  local town='EM_HNS_NEW_BARK_TOWN_HNS';local route='EM_HNS_ROUTE29_HNS'
  Rt.session={version='emerald',map=town,party={},flags={},vars={}}
  Audio.stopAll();Audio._savedSong=nil;Audio._fadeOut=nil
  Audio.mapLoadMusic({mapId=town,music=maps[town].music})
  T.eq(Audio.currentMapMusic(),maps[town].music,'new game plays source New Bark theme')
  Audio.playFanfare('MUS_HEAL')
  T.eq(Audio._fanfareFrames,160,'source healing duration')
  T.eq(Audio._bgmPaused,true,'jingle pauses field BGM')
  T.eq(Audio.isFanfareFinished(),false,'script waits for active jingle')
  Rt.session.map=route;Audio.mapLoadMusic({mapId=route,music=maps[route].music})
  for _=1,161 do Audio.update(1/60) end
  T.eq(Audio.isFanfareFinished(),true,'jingle completes through actual audio clock')
  T.eq(Audio.currentMapMusic(),maps[route].music,'jingle restores newly entered route rather than old town')
  T.eq(Audio._bgmPaused,false,'jingle restores playback')
  Audio.playSong('MUS_VS_WILD');T.eq(Audio.currentMapMusic(),world.audio.roles.battleWild,'wild battle uses HnS theme')
  Audio.playSong('MUS_VICTORY_TRAINER');T.eq(Audio.currentMapMusic(),world.audio.roles.victoryTrainer,'trainer victory uses HnS theme')
  local falkner=world.trainers.records[tostring(world.campaign.battles[2].trainerId)]
  local info={trainerClass=falkner.class,trainerName='FALKNER'}
  T.eq(Profile.battleSong({music={}},info),world.audio.roles.battleGymLeader,'Falkner uses gym battle theme')
  T.eq(Profile.victorySong({music={}},info),world.audio.roles.victoryGymLeader,'Falkner uses gym victory theme')
  Rt.session.map='EM_LITTLEROOT_TOWN';Audio.playSong('MUS_VS_WILD')
  T.eq(Audio.currentMapMusic(),C.songs.byName.MUS_VS_WILD,'vanilla session retains native song identity')
  for mid,def in pairs(maps) do T.eq(def.music,world.audio.mapSongs[mid],'every map retains source-selected music') end
  Audio.stopAll();Rt.session,Rt._game=savedSession,savedGame;Avatar.surfing,Avatar.biking=surfing,biking
  print('Audio regressions: '..count..' source songs mixed to PCM, map themes, native battle/victory, heal duration/pause/restoration, vanilla isolation')
end
