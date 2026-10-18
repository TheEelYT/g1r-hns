return function(T,game,w,s,F,keep)
  local G=game._hnsFollowerGround;local S=game._hnsFieldShadows.shadows
  local R=require('src.core.game3.field_effects_rse');local C=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  local A=require('src.core.game3.audio');local P=require('src.core.game3.player');local O=require('src.core.game3.objects')
  local before=R._list;R._list={};local behavior,water,se=C.behavior,C.isSurfable,A.playSe
  local n=MB.id('NORMAL');local old=MB.id('SAND');local cur=n;local sounds=0
  C.behavior=function(x,y)return x==2 and old or cur end;C.isSurfable=function(b)return b==MB.id('POND_WATER')end
  A.playSe=function(id)T.eq(id,G.spec.puddleSe,'follower uses source puddle sound ID');sounds=sounds+1 end
  local function reset()G.clear();R._list={};sounds=0 end
  local ids={};for id,row in pairs(w.opening.sprites)do if row.trackType then ids[row.trackType]=tonumber(id)end end
  for _,track in ipairs({'TRACKS_NONE','TRACKS_FOOT','TRACKS_BUG','TRACKS_SPOT','TRACKS_SLITHER'})do T.check(ids[track],'source species metadata contains '..track)end
  local a={px=32,py=64,cellX=2,cellY=4,targetX=3,targetY=4,visible=true,facing='right',currentElevation=3,elevation=3}
  local names={TRACKS_FOOT='sand_footprints',TRACKS_BUG='spot_tracks',TRACKS_SPOT='bug_tracks',TRACKS_SLITHER='slither_tracks'}
  for track,name in pairs(names)do for _,deep in ipairs({false,true})do
    reset();a.graphicsId=ids[track];old=MB.id(deep and'DEEP_SAND'or'SAND');cur=n;G.begin(a,3,4)
    local e=R._list[1];T.check(e,'visible follower creates source '..track)
    T.eq(e.name,deep and track=='TRACKS_FOOT'and'deep_sand_footprints'or name,'source track dispatch including enum/art wiring')
    T.eq(e.x,40,'tracks stay in previous tile X');T.eq(e.y,72,'tracks stay in previous tile Y');T.eq(e.layer,'behind','tracks draw below actors')
    for f=1,57 do R.step();if f<57 then
      T.eq(#R._list,1,'native source track lifetime frame '..f)
      T.eq(e.hidden==true,f>41 and f%2==0,'source track flicker phase frame '..f)
    else T.eq(#R._list,0,'source track expires on frame 57')end end
  end end
  reset();a.graphicsId=ids.TRACKS_NONE;old=MB.id('SAND');G.begin(a,3,4);T.eq(#R._list,0,'source no-track species leaves no footprints')
  a.graphicsId=ids.TRACKS_FOOT;a.visible=false;G.begin(a,3,4);T.eq(#R._list,0,'hidden follower leaves no ground effects');a.visible=true
  a.directionOverwrite=true;G.begin(a,3,4);T.eq(#R._list,0,'source direction overwrite suppresses tracks');a.directionOverwrite=nil
  for _,facing in ipairs({'down','up','left','right'})do
    reset();a.facing=facing;old=MB.id('SAND');G.begin(a,3,4);local e=R._list[1]
    T.eq(e.a.hflip,facing=='right','source footprint horizontal flip '..facing);T.eq(e.a.vflip,facing=='down','source footprint vertical flip '..facing)
  end
  reset();old=MB.id('DEEP_SAND');cur=old;G.begin(a,3,4)
  T.eq(a.inSandPile,true,'deep sand covers follower feet');local pile
  for _,e in ipairs(R._list)do if e.name=='sand_pile'then pile=e end end
  T.check(pile and pile.follow==a,'sand pile follows actual owner');T.eq(pile.a.frame,2,'sand pile spawns at source held pose')
  R.step();T.eq(pile.y,78,'sand pile is grounded at owner feet');S.leaveShort(a);T.eq(a.inSandPile,false,'recall clears sand state')
  for _,e in ipairs(R._list)do T.check(not e.hnsAttached,'recall removes attached effects while detached trails fade')end
  reset();old=MB.id('PUDDLE');cur=old;G.begin(a,3,4);T.eq(R._list[1].name,'splash','puddle crossing splashes at begin')
  G.finish(a,3,4);T.eq(R.count('splash'),2,'puddle has source begin/end splashes');T.eq(R.count('ripple'),1,'puddle landing creates a ripple');T.eq(sounds,2,'source puddle cues at begin/end')
  reset();old=MB.id('SHALLOW_WATER');cur=old;G.begin(a,3,4);local flow=R._list[1]
  T.check(flow and flow.name=='splash'and flow.follow==a,'shallow water attaches looping source splash');R.step();T.eq(sounds,1,'flow sound starts once for owner tile')
  R.step();T.eq(sounds,1,'stationary owner does not repeat flow sound');a.cellX=3;a.px=48;R.step();T.eq(sounds,2,'next owner tile triggers flow cue')
  old=n;cur=n;G.finish(a,4,4);R.step();T.eq(R.count('splash'),0,'leaving shallow water cleans attached splash')
  reset();a.cellX=2;a.px=32;old=MB.id('HOT_SPRINGS');cur=old;G.finish(a,3,4)
  T.eq(a.inHotSprings,true,'hot spring state suppresses source shadow');T.eq(R._list[1].name,'hot_springs_water','source hot spring overlay created')
  G.clear();T.eq(a.inHotSprings,false,'map cleanup clears owner spring state');T.eq(#R._list,0,'map cleanup removes all owned effects')
  for _,b in ipairs({'PUDDLE','SHALLOW_WATER','POND_WATER'})do
    reset();cur=MB.id(b);old=n;T.eq(G.land(a,3,4),true,'special landing selected on '..b)
    T.eq(R._list[1].name,b=='POND_WATER'and'jump_big_splash'or'jump_small_splash','source water landing sheet '..b)
  end
  -- Actual follower movement dispatcher must emit a species-owned previous-tile
  -- trail, rather than relying on this helper being called directly.
  reset();old=MB.id('SAND');cur=n;local actor=F.actor;local saved={};for k,v in pairs(actor)do saved[k]=v end
  actor.visible=true;actor.moving=false;actor.jumping=false;actor.cellX=2;actor.cellY=4;actor.px=32;actor.py=64
  T.eq(w.opening.sprites[tostring(actor.graphicsId)].trackType,'TRACKS_FOOT','integration fixture lead uses source footprints')
  local ledge=C.ledgeLanding;C.ledgeLanding=function()end
  F.step(3,4,16);T.eq(R.count('sand_footprints'),1,'real follower step triggers its own source footprint')
  for i=1,16 do F.tick();R.step()end
  T.eq(actor.cellX,3,'ground effects do not change follower movement completion')
  F.beginBall('enter');for _,e in ipairs(R._list)do T.check(not e.hnsAttached,'real recall removes attached ground effects')end
  F.transition=nil;for k in pairs(actor)do actor[k]=nil end;for k,v in pairs(saved)do actor[k]=v end;C.ledgeLanding=ledge
  reset();C.behavior=behavior;C.isSurfable=water;A.playSe=se;R._list=before
end
