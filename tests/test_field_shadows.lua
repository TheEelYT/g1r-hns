return function(T,game,w,s,F,keep)
  local S=game._hnsFieldShadows.shadows;local Coll=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  local behavior,water=Coll.behavior,Coll.isWater;local lg=love.graphics;local draw,color=lg.draw,lg.setColor;local draws,colors={},{}
  Coll.behavior=function()return MB.id('NORMAL')end;Coll.isWater=function()return false end
  local gid;for id,row in pairs(w.opening.sprites)do if row.shadowSize==1 then gid=tonumber(id);break end end
  local eo={px=32,py=64,visible=true};local npc={kind='npc',eventObject=eo,graphicsId=gid,x=32,y=40,sortY=64,elevation=3}
  local actors={npc,{kind='field_effect_shadow'}};S.collect(actors)
  T.eq(#actors,2,'persistent shadow replaces inherited jump-only shadow');T.eq(actors[2].kind,'hns_shadow','persistent NPC shadow is collected')
  T.eq(actors[2].y,72,'shadow stays on ground during raised sprite jump')
  lg.draw=function(_,...)draws[#draws+1]={...}end;lg.setColor=function(...)colors[#colors+1]={...}end
  actors[2]:draw(4,8);T.eq(colors[1][4],w.fieldShadows.intensity/16,'shadow uses source opacity');T.eq(draws[1][1],28,'shadow camera X');T.eq(draws[1][2],64,'shadow camera Y')
  Coll.behavior=function()return MB.id('TALL_GRASS')end;actors={npc};S.collect(actors);T.eq(#actors,1,'grass suppresses shadow')
  Coll.behavior=function()return MB.id('NORMAL')end;Coll.isWater=function()return true end;actors={npc};S.collect(actors);T.eq(#actors,1,'water suppresses shadow')
  Coll.isWater=function()return false end
  local a=F.actor;a.visible=true;S.grass={};Coll.behavior=function()return MB.id('TALL_GRASS')end
  S.step(a,3,4,false);T.eq(#S.grass,1,'follower step starts its own grass rustle')
  actors={};S.collect(actors);T.eq(#actors,2,'grass has independent back and feet-cover actors')
  T.eq(actors[1].kind,'hns_follower_grass_back','rustle is behind follower');T.eq(actors[2].kind,'hns_follower_grass_front','feet cover is in front')
  for i=1,10 do S.tick()end;T.eq(S.grass[1].timer,10,'rustle source timer advances independently of player')
  Coll.behavior=function()return MB.id('LONG_GRASS')end;S.step(a,4,4,false);T.eq(S.grass[2].name,'long_grass','source long-grass sequence is selected')
  a.visible=false;S.step(a,5,4,false);T.eq(#S.grass,2,'hidden follower cannot trigger grass')
  S.grass={};a.visible=true;lg.draw=draw;lg.setColor=color;Coll.behavior=behavior;Coll.isWater=water
end
