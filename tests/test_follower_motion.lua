return function(T,game,w,s,lead,keep)
  local F=game._hnsFollower.follower;local P=require('src.core.game3.player');local O=require('src.core.game3.objects')
  local Map=require('src.core.game3.map');local Coll=require('src.core.game3.collision');local Warp=require('src.core.game3.warp')
  local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space')
  local before=s.map;local az='EM_HNS_AZALEA_TOWN_HNS';s.map=az;O.loadMap(game,az,game.data.maps[az]);Coll.bindMap(game,az,game.data.maps[az]);Warp.clear()
  local spots={}
  for y=0,w.maps[az].height-7 do for x=0,w.maps[az].width-1 do
    local _,a=Coll.ledgeLanding(game,x,y,'down');local _,b=Coll.ledgeLanding(game,x,y+2,'down');local _,c=Coll.ledgeLanding(game,x,y+4,'down')
    if a==y+2 and b==y+4 and c==y+6 then spots[#spots+1]={x,y}end
  end end
  T.check(#spots>0,'real Azalea layout contains three consecutive ledges')
  local x,y=spots[1][1],spots[1][2];P.reset(x,y,'down');F.actor=nil;F.refresh();local a=F.actor
  a.visible=true;a.cellY=y-1;a.py=(y-1)*16
  for hop=1,3 do
    P.turnArmed=false;P.turnTimer=0
    T.eq(P.tryMove('down',game,false),'ledge','actual native ledge hop '..hop)
    T.check(a.moving,'follower starts moving on hop '..hop)
    for i=1,32 do P.tick(game);F.tick()end
    T.eq(P.cellY,y+hop*2,'player lands after hop '..hop)
    T.eq(a.cellY,y+(hop-1)*2,'follower reaches preceding ledge without another input '..hop)
    T.eq(a.jumping,false,'follower jump completes '..hop)
  end
  T.eq(F.transition,nil,'visible follower never releases a ball on ledges')
  -- Idle frames are independently exercised through actual sprite draw dispatch.
  local Ow=require('src.core.game3.ow_sprites');local lg=love.graphics;keep(lg,{'draw'})
  local quads={};lg.draw=function(_,quad)quads[#quads+1]=quad end
  a.facing='down';a.animClock=0;a.moving=false;a.raiseY=0
  for i=1,24 do F.tick();Ow.draw(a.graphicsId,a.px,a.py+(a.raiseY or 0),0,0,a.facing,O.walkPhase(a),a.stepFlip,{})end
  local distinct={};local bob={};for _,q in ipairs(quads)do distinct[q]=true end
  for i=1,16 do F.tick();bob[a.raiseY]=true end
  local count=0;for _ in pairs(distinct)do count=count+1 end
  T.eq(count,2,'idle draw uses both source follower poses');T.check(bob[-1]and bob[0],'idle bob alternates source one-pixel offsets')
  -- Hidden followers shadow a hop and emerge on the next walking step only.
  a.visible=false;F.step(P.cellX,P.cellY,32,true);T.eq(F.transition,nil,'hidden follower does not emerge while player jumps')
  F.step(P.cellX,P.cellY,16);T.eq(F.transition.kind,'exit','ordinary step can release hidden follower');for i=1,16 do F.tick()end
  s.flags=Space.store.flags;s.vars=Space.store.vars
  -- Real seamless native map loads retain actor identity in all four directions.
  for _,dir in ipairs({'up','down','left','right'})do
    local src='EM_HNS_NEW_BARK_TOWN_HNS';local dest='EM_HNS_ROUTE29_HNS'
    s.map=src;P.reset(2,8,dir);F.actor=nil;F.refresh();local held=F.actor;held.visible=true;held.cellX=3;held.cellY=8;held.px=48;held.py=128
    local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[dir]
    Map.load(nil,game,dest,{x=50,y=8,facing=dir,seamless=true,depth1Connections=true})
    T.eq(F.refresh(),held,'seamless '..dir..' preserves follower actor');T.eq(held.visible,true,'seamless '..dir..' stays visible');T.eq(F.transition,nil,'seamless '..dir..' has no ball animation')
    T.eq(held.cellX,51-d[1],'seamless '..dir..' rebases follower X');T.eq(held.cellY,8-d[2],'seamless '..dir..' rebases follower Y')
  end
  s.map=before;P.reset(9,8,'left');F.actor=nil;F.refresh();O.loadMap(game,before,game.data.maps[before]);Coll.bindMap(game,before,game.data.maps[before])
end
