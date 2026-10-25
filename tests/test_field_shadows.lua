return function(T,game,w,s,F,keep)
  local S=game._hnsFieldShadows.shadows;local Coll=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  local Fx=require('src.core.game3.field_effects');local Rse=require('src.core.game3.field_effects_rse');local P=require('src.core.game3.player')
  keep(Rse,{'_list','_state'});Rse._list={};Rse._state={}
  -- The ROM's field-effect family header is unavailable in this fixture.
  local manifest=Fx._manifest;local fixture={}
  for k,v in pairs(type(manifest)=='table'and manifest or {})do fixture[k]=v end
  fixture.family='rse';fixture._byName=fixture._byName or{};Fx._manifest=fixture
  local MB=require('src.core.game3.mb');local grass=MB.id('SHORT_GRASS')
  Rse.onSpawn({cx=P.cellX,cy=P.cellY},grass,grass);local e=Rse._list[1]
  T.check(e and e.name=='short_grass','native player short-grass controller starts source effect')
  T.eq(e.sheet,Fx.loadSheet('short_grass'),'native player selects shared HnS sheet')
  T.eq(e.a.cmds[1][3],4,'player grass uses source first-frame duration');T.eq(e.a.cmds[2][3],4,'player grass uses source second-frame duration')
  T.eq(w.fieldShadows.paletteTag,0x1005,'player/follower grass share source general-1 palette');T.eq(w.fieldShadows.timeBlend,true,'grass palette is not source time-blend immune')
  local lg=love.graphics;local draw=lg.draw;local images={};lg.draw=function(im)images[#images+1]=im end
  local follow=F.actor;follow.visible=true;S.short[follow]={actor=follow,timer=0,x=follow.px,y=follow.py}
  local actors={};Rse.collectActors(actors);S.collect(actors)
  local playerActor,followerActor
  for _,a in ipairs(actors)do if a.fxEntry==e then playerActor=a elseif a.kind=='hns_follower_short_grass'then followerActor=a end end
  T.check(playerActor and followerActor,'both grass effects enter same native actor collection')
  playerActor:draw(0,0);followerActor:draw(0,0);T.eq(images[1],images[2],'player/follower use identical source texture before common tint')
  -- Draw the real field with the shader/upload boundary recorded. The two
  -- textures must share the same day/night canvas and one final time blend.
  local Field=require('src.core.game3.field_view');local Rtc=require('src.core.game3.rtc');local Time=game._hnsTime.time
  local calc=Rtc.calcLocalTime;local shader=lg.newShader;local timeShader,timeCanvas=Time.shader,Time.canvas
  lg.newShader=function()return {send=function()end,hasUniform=function()return true end}end
  Time.shader=nil;Time.canvas=nil
  for _,hour in ipairs({12,21})do
    Rtc.calcLocalTime=function()return {days=0,hours=hour,minutes=0,seconds=0}end
    local canvases={};local blends=0
    lg.draw=function(im,...)
      if im==e.sheet.image then canvases[#canvases+1]=lg.getCanvas()or false end
      if im==Time.canvas and lg.getShader()==Time.shader then blends=blends+1 end
      return draw(im,...)
    end
    Field.draw(game,240,160)
    T.eq(#canvases,2,'actual field renders player and follower short-grass at hour '..hour)
    T.eq(canvases[1],canvases[2],'player/follower grass draw into same lighting canvas at hour '..hour)
    if hour==21 then T.eq(canvases[1],Time.canvas,'both night grass draws enter time-tint canvas');T.eq(blends,1,'both grass effects receive one common outdoor tint')
    else T.eq(blends,0,'day grass receives no night tint')end
  end
  Rtc.calcLocalTime=calc;lg.newShader=shader;Time.shader=timeShader;if Time.canvas then Time.canvas:release()end;Time.canvas=timeCanvas
  local map=s.map;s.map='EM_ROUTE101'
  T.check(Fx.loadSheet('short_grass')~=e.sheet,'vanilla short grass does not receive HnS source sheet');s.map=map
  lg.draw=draw;Rse._list={};Rse._state={};S.short={}
  local behavior,water=Coll.behavior,Coll.isWater;local lg=love.graphics;local draw,color=lg.draw,lg.setColor;local draws,colors={},{}
  -- Locate an adjacent pair in imported Azalea data, with native collision.
  local P=require('src.core.game3.player');local before=s.map;local px,py,pf=P.cellX,P.cellY,P.facing
  local az='EM_HNS_AZALEA_TOWN_HNS';s.map=az;Coll.bindMap(game,az,game.data.maps[az]);local pair
  for y=0,w.maps[az].height-1 do for x=0,w.maps[az].width-2 do
    if Coll.behavior(x,y)==MB.id('SHORT_GRASS')and Coll.behavior(x+1,y)==MB.id('SHORT_GRASS')then pair={x,y};break end
  end;if pair then break end end
  T.check(pair,'real imported Azalea contains adjacent source short-grass tiles')
  P.reset(pair[1],pair[2],'right');F.actor=nil;F.refresh();local actual=F.actor;actual.visible=true
  F.step(pair[1]+1,pair[2],16);T.check(S.short[actual],'Azalea native collision selects follower short-grass effect')
  for i=1,16 do F.tick();S.tick()end
  T.check(S.short[actual]and actual.cellX==pair[1]+1,'actual Azalea walking retains short-grass overlay after landing')
  S.short={};s.map=before;P.reset(px,py,pf);F.actor=nil;F.refresh();Coll.bindMap(game,before,game.data.maps[before])
  Coll.behavior=function()return MB.id('NORMAL')end;Coll.isWater=function()return false end
  local gid;for id,row in pairs(w.opening.sprites)do if row.shadowSize==1 then gid=tonumber(id);break end end
  local eo={px=32,py=64,visible=true};local npc={kind='npc',eventObject=eo,graphicsId=gid,x=32,y=40,sortY=64,elevation=3}
  local actors={npc,{kind='field_effect_shadow'}};S.collect(actors)
  T.eq(#actors,2,'persistent shadow replaces inherited jump-only shadow');T.eq(actors[2].kind,'hns_shadow','persistent NPC shadow is collected')
  T.eq(actors[2].y,72,'shadow stays on ground during raised sprite jump')
  lg.draw=function(_,...)draws[#draws+1]={...}end;lg.setColor=function(...)colors[#colors+1]={...}end
  actors[2]:draw(4,8);T.eq(colors[1][4],w.fieldShadows.intensity/16,'shadow uses source opacity');T.eq(draws[1][1],28,'shadow camera X');T.eq(draws[1][2],64,'shadow camera Y')
  -- Exercise the engine's real row/elevation sorter, including the exact
  -- one-pixel idle bob that used to put the grounded shadow over short grass.
  local sort=require('src.core.game3.field_view').applyDrawOrder
  local Weather=require('src.core.game3.field_weather_rse');local weather=Weather.getCurrentWeather
  Weather.getCurrentWeather=function()return 0 end
  Coll.behavior=function()return MB.id('SHORT_GRASS')end
  local parent={px=32,py=64,cellX=2,cellY=4,visible=true}
  S.short={[parent]={actor=parent,timer=8}}
  for elevation=0,15 do for cy=0,31 do for bob=-1,0 do
    parent.currentElevation=elevation
    local owner={kind='npc',eventObject=parent,graphicsId=gid,x=32,y=64+bob,sortY=64,elevation=elevation}
    local stack={owner};S.collect(stack,0,cy);local under,over=sort(stack,{}, {},cy)
    local group=#over>0 and over or under
    T.eq(group[1].kind,'hns_shadow','shadow precedes idle-bobbing owner at every camera row/elevation')
    T.eq(group[2],owner,'short-grass parent follows its ground shadow')
    T.eq(group[3].kind,'hns_follower_short_grass','short grass remains above shadow and parent')
  end end end
  -- Use the whole installed collector chain. The outer follower wrapper used
  -- to discard camera coordinates even though S.collect alone sorted correctly.
  for _,cy in ipairs({0,17,128,257,1024})do for bob=-1,0 do
    parent.currentElevation=3;parent.py=cy+64;parent.px=32
    local owner={kind='npc',eventObject=parent,graphicsId=gid,x=32,y=parent.py+bob,sortY=parent.py,elevation=3}
    local stack={owner};Fx.collectActors(stack,16,cy)
    local under,over=sort(stack,{}, {},cy);local group=#over>0 and over or under
    local shadowIndex,ownerIndex,shadow
    for i,v in ipairs(group)do if v==owner then ownerIndex=i elseif v.kind=='hns_shadow'and v.x==owner.x+8-w.fieldShadows.shadows['1'].width/2 then shadowIndex=i;shadow=v end end
    T.check(shadowIndex and ownerIndex and shadowIndex<ownerIndex,'installed collectors keep shadow below sprite at world camera '..cy)
    T.eq(shadow.subpriority,owner.subpriority+1,'installed collector uses actual camera for owner-relative shadow priority '..cy)
  end end
  parent.py=64
  -- Composite a source leaf pixel that actually overlaps the shadow mask.
  -- A post-grass 25% shadow would darken this exact pixel in the old ordering.
  local ga=w.fieldShadows.grass.short_grass;local sa=w.fieldShadows.shadows['1']
  local gb,sb=T.readAsset(ga.file),T.readAsset(sa.file);local overlap
  for y=0,15 do for x=0,15 do
    local gi=(16*16+y*16+x)*4+1;local sx=x-(8-sa.width/2);local sy=y-(16-sa.offset-sa.height/2)
    if sx>=0 and sy>=0 and sx<sa.width and sy<sa.height and gb:byte(gi+3)>0 and sb:byte((sy*sa.width+sx)*4+4)>0 then overlap={gi,x,y};break end
  end;if overlap then break end end
  T.check(overlap,'source short-grass leaf really overlaps medium shadow mask')
  local owner={kind='npc',eventObject=parent,graphicsId=gid,x=32,y=63,sortY=64,elevation=3}
  local stack={owner};S.collect(stack,0,0);local group=sort(stack,{}, {},0);local rgb={100,100,100}
  for _,v in ipairs(group)do
    if v.kind=='hns_shadow'then for i=1,3 do rgb[i]=rgb[i]*(1-w.fieldShadows.intensity/16)end
    elseif v.kind=='hns_follower_short_grass'then rgb={gb:byte(overlap[1],overlap[1]+2)}end
  end
  for i=1,3 do T.eq(rgb[i],gb:byte(overlap[1]+i-1),'overlapping grass keeps source ink rather than shadow-darkened ink')end
  for _,v in ipairs(stack)do if v.kind=='hns_shadow'then v.fixedPriority=false end end
  local legacy=sort(stack,{}, {},0)
  T.eq(legacy[3].kind,'hns_shadow','negative control reproduces former shadow-over-grass ordering')
  parent.fixedPriority=true;parent.fixedClass=1;parent.subpriority=42
  stack={owner};S.collect(stack,0,27);local _,over=sort(stack,{}, {},27)
  T.eq(over[1].kind,'hns_shadow','scripted fixed-priority shadow stays in owner layer');T.eq(over[1].subpriority,43,'fixed shadow follows current scripted subpriority')
  parent.fixedPriority=nil;S.short={};S.history={}
  Coll.behavior=function()return MB.id('NORMAL')end
  for id=0,23 do
    Weather.getCurrentWeather=function()return id end
    local hide=S.hidden(npc,eo)and true or false
    T.eq(hide,id==9 or id==14,'source weather shadow suppression '..id)
  end
  Weather.getCurrentWeather=function()return 0 end
  for _,name in ipairs(w.fieldShadows.suppression.grass)do
    local id=MB.id(name);if id then Coll.behavior=function()return id end;T.check(S.hidden(npc,eo),'source PokeGrass suppression '..name)end
  end
  for _,name in ipairs(w.fieldShadows.suppression.water)do
    local id=MB.id(name);if id then Coll.behavior=function()return id end;T.check(S.hidden(npc,eo),'source water behavior suppression '..name)end
  end
  Coll.behavior=function(x)return x==2 and MB.id('POND_WATER')or MB.id('NORMAL')end
  parent.cellX=2;parent.cellY=4;S.history={};T.check(S.hidden(owner,parent),'water step has no shadow')
  parent.moving=true;parent.targetX=3;parent.targetY=4;T.check(S.hidden(owner,parent),'landing from water retains previous-water suppression')
  parent.cellX=3;parent.moving=false;T.check(S.hidden(owner,parent),'shore rest retains previous behavior')
  parent.moving=true;parent.targetX=4;T.check(not S.hidden(owner,parent),'next dry step restores source shadow')
  parent.moving=false;S.history={}
  keep(P,{'cellX','cellY','moving','targetX','targetY','surfing','underwater'})
  P.cellX=2;P.cellY=4;P.moving=false;P.surfing=true;P.underwater=false
  local player={kind='player',x=32,y=64}
  T.check(S.hidden(player),'surfing hides player shadow while retaining tile history')
  P.surfing=false;P.moving=true;P.targetX=3;P.targetY=4
  T.check(S.hidden(player),'actual player shore step retains previous water after Surf ends')
  P.cellX=3;P.targetX=4;T.check(not S.hidden(player),'actual next dry player step restores shadow')
  -- Restore immediately as later tests draw this same real player.
  P.cellX=px;P.cellY=py;P.moving=false;P.targetX=px;P.targetY=py;P.surfing=false
  S.history={};Weather.getCurrentWeather=weather
  Coll.behavior=function()return MB.id('TALL_GRASS')end;actors={npc};S.collect(actors);T.eq(#actors,1,'grass suppresses shadow')
  Coll.behavior=function()return MB.id('NORMAL')end;Coll.isWater=function()return true end;actors={npc};S.collect(actors);T.eq(#actors,1,'water suppresses shadow')
  Coll.isWater=function()return false end
  local a=F.actor;a.visible=true;S.grass={};Coll.behavior=function()return MB.id('TALL_GRASS')end
  a.moving=false;F.step(a.cellX+1,a.cellY,16);T.eq(#S.grass,1,'real follower movement dispatch triggers grass');a.moving=false;S.grass={}
  S.step(a,3,4,false);T.eq(#S.grass,1,'follower step starts its own grass rustle')
  actors={};S.collect(actors);T.eq(#actors,2,'grass has independent back and feet-cover actors')
  T.eq(actors[1].kind,'hns_follower_grass_back','rustle is behind follower');T.eq(actors[2].kind,'hns_follower_grass_front','feet cover is in front')
  for i=1,10 do S.tick()end;T.eq(S.grass[1].timer,10,'rustle source timer advances independently of player')
  Coll.behavior=function()return MB.id('LONG_GRASS')end;S.step(a,4,4,false);T.eq(S.grass[2].name,'long_grass','source long-grass sequence is selected')
  a.visible=false;S.step(a,5,4,false);T.eq(#S.grass,2,'hidden follower cannot trigger grass')
  a.visible=true;S.grass={};S.short={};Coll.behavior=function()return MB.id('SHORT_GRASS')end
  a.moving=false;a.jumping=false;F.step(a.cellX+1,a.cellY,16)
  T.check(S.short[a],'actual follower step enters source short grass')
  actors={};S.collect(actors);T.eq(#actors,1,'short grass creates one attached overlay')
  T.eq(actors[1].kind,'hns_follower_short_grass','source short-grass effect is selected');T.eq(actors[1].disguiseObject,a,'overlay links native parent subpriority')
  actors[1]:draw(0,0);T.check(#draws>=2,'short-grass source sheet uploads through actual mod asset loader');T.eq(actors[1].x,a.px,'short-grass X follows actor');T.eq(actors[1].y,a.py,'short-grass Y follows ground anchor rather than follower bob')
  for i=1,8 do a.px=a.px+1;S.tick()end
  T.eq(S.short[a].timer,8,'two four-frame short-grass poses finish')
  for i=1,16 do S.tick()end;T.eq(S.short[a].timer,8,'stationary short-grass effect holds end pose')
  a.px=a.px+1;S.tick();T.eq(S.short[a].timer,0,'moving parent restarts completed short-grass animation')
  Coll.behavior=function()return MB.id('NORMAL')end;S.finish(a,2,3);T.eq(S.short[a],nil,'leaving short grass clears overlay')
  Coll.behavior=function()return MB.id('SHORT_GRASS')end;S.finish(a,2,3);a.visible=false;S.tick();T.eq(S.short[a],nil,'hidden follower cannot leave stale short-grass overlay')
  a.moving=false;S.short={}
  S.grass={};a.visible=true;lg.draw=draw;lg.setColor=color;Coll.behavior=behavior;Coll.isWater=water;Fx._manifest=manifest
end
