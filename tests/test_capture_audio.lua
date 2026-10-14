-- Use the actual native capture callback and capture-success sequencer step.
-- Skip unrelated ball-flight graphics and ROM strings, retaining profile cue
-- selection, HnS translation, native SE baking, wait gate and GB/M4A routing.
return function(T,game,w,s,keep)
  local Catch=require('src.core.game3.battle.catch_seq');local Audio=require('src.core.game3.audio')
  local Player=require('src.core.game3.m4a_player');local Profile=require('src.core.game3.battle.profile')
  local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
  local G=game._hnsGbSounds.sounds;local C=require('src.core.game3.constants').of('emerald')
  local CB
  for i=1,20 do local key,value=debug.getupvalue(Catch.startBall,i);if not key then break end;if key=='CB'then CB=value end end
  T.check(CB and CB.doClick,'actual native ball capture callback is reachable')
  local caughtIntro=Audio.resolveSong(Profile.get(nil).sounds.caughtIntro)
  T.eq(caughtIntro,C.songs.byName.MUS_RG_CAUGHT_INTRO,'current Emerald capture profile uses RG cue')
  keep(Player,{'start'});local start=Player.start;local records={}
  Player.start=function(pack,cache,slot,id,opts)
    local ok=start(pack,cache,slot,id,opts);records[#records+1]={id=id,gb=slot.hnsGB and true or false};return ok
  end
  for _,gb in ipairs({false,true})do
    Flags.setFlag(Space.store,nil,G.spec.flag,gb);Audio.stopAll();Audio._seRawClear();records={}
    local ball={data={[4]=94}};CB.doClick(ball)
    T.eq(ball.released,true,'native frame 95 releases capture message')
    local intro
    for _,r in ipairs(records)do if r.id==w.audio.roles.evolved then intro=r end end
    T.check(intro,'actual capture callback bakes HnS HG_EVOLVED');T.eq(intro and intro.gb,gb,'capture intro follows GB flag')
    Catch.reset();Catch._st={oldManTutorial=true};Catch._steps={{kind='capture_success',data={ballId=4}}}
    Catch.update();T.eq(Audio._waitSe[#Audio._waitSe].id,w.audio.roles.evolved,'actual success step waits for translated HnS cue')
    for i=1,400 do Audio.update(1/60)end
    T.eq(Audio.currentMapMusic(),w.audio.roles.caught,'native success wait starts HnS HG_CAUGHT')
    local caught
    for _,r in ipairs(records)do if r.id==w.audio.roles.caught then caught=r end end
    T.check(caught,'actual caught song reaches native sequencer');T.eq(caught and caught.gb,gb,'caught body follows GB flag')
    Catch.reset()
  end
  local map=s.map;s.map='EM_ROUTE101';Audio.waitSe(caughtIntro,function()end)
  T.eq(Audio._waitSe[#Audio._waitSe].id,caughtIntro,'vanilla capture wait retains native cue');s.map=map;Audio._waitSe={}
  Flags.setFlag(Space.store,nil,G.spec.flag,false);Audio.stopAll();Player.start=start
end
