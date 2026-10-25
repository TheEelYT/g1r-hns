return function(T,game,w,s,F,keep)
  local P=require('src.core.game3.player');local Map=require('src.core.game3.map')
  local Coll=require('src.core.game3.collision');local Forced=require('src.core.game3.forced_movement')
  local ModRt=require('src.mods.Runtime');local Rt=require('src.core.game3.runtime')
  local Enc=require('src.core.game3.encounters');local MB=require('src.core.game3.mb')
  keep(Enc,{'onStep'});Enc.onStep=function()return false end -- Wild battle/ROM boundary only.
  local point;for _,d in ipairs(w.practice.destinations)do if d.id=='ice'then point=d end end
  T.check(point~=nil,'practice catalogue supplies actual Ice Path strip')
  local before=s.map
  Map.load(nil,game,point.map,{x=point.x-1,y=point.y,facing='right',depth1Connections=true})
  Rt._game=game;Forced.reset();P.reset(point.x-1,point.y,'right');F.actor=nil;F.transition=nil;F.refresh()
  local a=F.actor;a.visible=true;a.cellX=P.cellX-1;a.cellY=P.cellY;a.px=a.cellX*16;a.py=a.cellY*16
  T.eq(Coll.behavior(P.cellX,P.cellY),MB.id('ICE'),'test starts on native Ice Path collision')
  -- The headless loader leaves the ordinary map-entry input lock in place;
  -- finish that entry boundary before asking the genuine controller to move.
  local Field=require('src.core.game3.field');Field.unlock()
  T.eq(Field.locked,false,'headless map entry releases input before ice movement')
  T.eq(Forced.onStepFinished(game),true,'native ice controller starts actual forced step')
  local start=P.cellX;local sliding=0;local lastIndex,lastProgress
  for frame=1,80 do
    ModRt.call('input.step',function()end,game,1/60);P.tick(game)
    T.eq(F.actor,a,'ice movement retains original follower actor')
    T.eq(a.visible,true,'ice movement keeps follower visible')
    T.eq(F.transition,nil,'ice movement never recalls follower into a ball')
    if a.sliding and a.moving then
      sliding=sliding+1
      T.eq(a.raiseY or 0,0,'source ice sliding has no walking bob')
      if lastProgress and a.progress>lastProgress then T.eq(a.poseIndex,lastIndex,'source sliding holds animation pose within the step')end
      lastIndex,lastProgress=a.poseIndex,a.progress
    else lastIndex,lastProgress=nil,nil end
  end
  T.check(P.cellX>start,'actual native player slides across source ice cells')
  T.check(sliding>0,'follower executes source ice sliding state')
  T.eq(a.cellX,P.cellX-1,'follower completes last queued slide one cell behind player')
  T.eq(P.moving,false,'real Ice Path wall ends native slide')
  T.eq(Forced.isForced(),false,'native forced state releases at ice wall')
  -- Unsupported conveyor/spin movement retains its previous recall policy.
  Forced.forced=true;F.iceStep=nil
  T.eq(F.allowed(s,F.lead(s)),false,'other forced movement remains excluded')
  Forced.reset()
  Map.load(nil,game,before,{x=9,y=8,facing='left',depth1Connections=true});F.actor=nil;F.refresh()
  print('Ice follower: actual Ice Path forced controller, same visible actor, held sliding pose, final trail and wall stop')
end
