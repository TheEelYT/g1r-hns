return function(mod,w,game)
  local old=game._hnsFieldShadows or {}
  -- Existing collectors/listeners retain this table across game.ready.
  local S=old.shadows or{grass={},short={}};S.spec=w.fieldShadows;S.history=S.history or{}
  local Fx=require('src.core.game3.field_effects');local P=require('src.core.game3.player');local Rt=require('src.core.game3.runtime')
  local Coll=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  local Weather=require('src.core.game3.field_weather_rse')
  local Warp=require('src.core.game3.warp');local Special=require('src.core.game3.special_field_anim')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui)
  local function own()local s=Rt.getSession();return s and w.maps[s.map]end
  -- The native player controller uses its own ROM effect sheets. Supply the
  -- same source sheet/palette used by followers, while keeping native timing,
  -- restart and cleanup. Both draw in the common outdoor tint pass.
  local loadSheet=old.loadSheet or Fx.loadSheet
  local manifestObject=old.manifestObject or Fx.manifestObject
  local sheets,objects={},{}
  local function sourceArt(name)
    if not own()then return end
    return name=='short_grass'and S.spec.grass.short_grass or S.spec.ground.art[name]
  end
  Fx.loadSheet=function(name,...)
    local art=sourceArt(name)
    if art then
      if not sheets[name]then
        local fw,fh=art.fw or 16,art.fh or 16;local quads={}
        for i=0,art.height/fh-1 do quads[i]=love.graphics.newQuad(0,i*fh,fw,fh,art.width,art.height)end
        sheets[name]={image=U.image(art.file,art.width,art.height),quads=quads,fw=fw,fh=fh,frames=art.height/fh}
      end
      return sheets[name]
    end
    return loadSheet(name,...)
  end
  Fx.manifestObject=function(name,...)
    local art=sourceArt(name)
    if art then
      if not objects[name]then
        local anims=art.anims
        if not anims then
          local seq={};for _,p in ipairs(art.sequence)do seq[#seq+1]={'frame',p[1],p[2]}end;seq[#seq+1]={'end'};anims={seq}
        end
        objects[name]={anims=anims,fw=art.fw or 16,fh=art.fh or 16,frames=art.height/(art.fh or 16),paletteTag=name=='short_grass'and S.spec.paletteTag or nil}
      end
      return objects[name]
    end
    return manifestObject(name,...)
  end
  local Ground=assert(load(mod:read('follower_ground.lua')))()(mod,w,game)
  local function grassName(beh)return beh==MB.id('LONG_GRASS')and'long_grass'or beh==MB.id('TALL_GRASS')and'tall_grass'end
  function S.leaveShort(a)S.short[a]=nil;Ground.leave(a)end
  local function shortCover(a,x,y)
    if Coll.behavior(x,y)==MB.id('SHORT_GRASS')and a.visible then
      S.short[a]=S.short[a]or{actor=a,timer=0,x=a.px,y=a.py}
    else S.short[a]=nil end
  end
  function S.finish(a,x,y,jumped)Ground.finish(a,x,y,jumped);shortCover(a,x,y)end
  function S.appear(a,x,y)Ground.appear(a,x,y);shortCover(a,x,y)end
  function S.step(a,x,y,jump)
    if not own()or not a.visible then return end
    if not jump then Ground.begin(a,x,y)end
    local beh=Coll.behavior(x,y);local name=grassName(beh)
    if beh==MB.id('SHORT_GRASS')and Coll.behavior(a.cellX,a.cellY)==beh and not jump then S.finish(a,x,y)else S.short[a]=nil end
    if name then S.grass[#S.grass+1]={x=x,y=y,name=name,timer=0,actor=a}
    elseif jump and not Ground.land(a,x,y)then Fx.startDust(x,y)end
  end
  function S.tick()
    for a,g in pairs(S.short)do
      if not a.visible or a.jumping then S.short[a]=nil
      else
        local moved=a.px~=g.x or a.py~=g.y;g.x,g.y=a.px,a.py
        if g.timer>=8 and moved then g.timer=0 else g.timer=math.min(8,g.timer+1)end
      end
    end
    for i=#S.grass,1,-1 do
      local g=S.grass[i];g.timer=g.timer+1;local total=0
      for _,p in ipairs(S.spec.grass[g.name].sequence)do total=total+p[2]end
      if g.timer>=total and (not g.actor.visible or g.actor.cellX~=g.x or g.actor.cellY~=g.y)then table.remove(S.grass,i)end
    end
  end
  local noGrass,noWater,noWeather={},{},{}
  for _,name in ipairs(S.spec.suppression.grass)do local id=MB.id(name);if id then noGrass[id]=true end end
  for _,name in ipairs(S.spec.suppression.water)do local id=MB.id(name);if id then noWater[id]=true end end
  for _,id in ipairs(S.spec.suppression.weather)do noWeather[id]=true end
  function S.hidden(actor,eo)
    local parent=eo or(actor.kind=='player'and P)
    local x,y
    if parent and parent.cellX then x,y=parent.cellX,parent.cellY
      if parent.moving and parent.targetX then x,y=parent.targetX,parent.targetY end
    else x,y=math.floor(actor.x/16),math.floor((eo and eo.py or actor.y)/16)end
    local beh=Coll.behavior(x,y)
    local previous
    if parent then
      local h=S.history[parent]
      if not h then h={x=x,y=y,behavior=beh};S.history[parent]=h
      elseif h.x~=x or h.y~=y then h.previous=h.behavior;h.behavior=beh;h.x,h.y=x,y end
      previous=h.previous
    end
    if eo and(eo.active==false or eo.noShadow or eo.hidden or eo.inHotSprings or eo.inSandPile)then return true end
    if noWeather[Weather.getCurrentWeather()]then return true end
    if actor.kind=='player'and(P.surfing or P.underwater)then return true end
    return noGrass[beh]or beh==MB.id('PUDDLE')or noWater[beh]or noWater[previous]or Coll.isWater(x,y)
  end
  -- Native ordering derives subpriority from screen-space sprite Y. A one-pixel
  -- follower bob can cross a row while its grounded shadow does not. Pin the
  -- shadow behind its owner's current priority, never behind its previous frame.
  local function shadowOrder(a,eo,camY)
    local elev=a.elevation or(a.kind=='player'and P.elevation)or 3
    local priority=a.oamPriority
    if not priority and a.kind=='player'then
      if P.jumping or P.surfHopping then priority=1
      elseif P.oamPriority then priority=P.oamPriority
      elseif Warp.isEscalatorActive and Warp.isEscalatorActive()or Special.isActive and Special.isActive()then priority=1 end
    end
    priority=priority or S.spec.elevationPriority[tostring(elev)]or 2
    local fixed=(eo and eo.fixedPriority)or a.fixedPriority
    local sub
    if fixed then sub=(eo and eo.subpriority)or a.subpriority or 83;priority=(eo and eo.fixedClass)or a.priority or priority
    else sub=(S.spec.elevationSubpriority[tostring(elev)]or 115)+(16-math.floor(math.floor((a.y or 0)-(camY or 0))/16))*2+1 end
    return sub+1,priority
  end
  function S.collect(actors,camX,camY)
    if not own()then return end
    for i=#actors,1,-1 do
      local a=actors[i];local e=a.fxEntry
      if e and e.hnsAttached then a.disguiseObject=e.hnsGroundOwner end
      local remove=a.kind=='field_effect_shadow'
      if a.kind=='field_effect_npc_grass'then for _,g in ipairs(S.grass)do if a.x==g.x*16 and a.y==g.y*16+8 then remove=true;break end end end
      if remove then table.remove(actors,i)end
    end
    local count=#actors
    for i=1,count do
      local a=actors[i];local eo=a.eventObject;local row=w.opening.sprites[tostring(a.graphicsId)]
      if (a.kind=='npc'or a.kind=='player')and row and row.shadowSize~=nil and row.shadowSize~=S.spec.none and not S.hidden(a,eo)then
        local art=S.spec.shadows[tostring(row.shadowSize)];local sy=(eo and eo.py or a.kind=='player'and P.py or a.y)+16-art.offset-art.height/2
        local sx=a.x+8-art.width/2;local alpha=(a.alpha or 1)*S.spec.intensity/16
        local sub,priority=shadowOrder(a,eo,camY)
        actors[#actors+1]={fixedPriority=true,subpriority=sub,priority=priority,kind='hns_shadow',x=sx,y=sy,sortY=(a.sortY or a.y)-0.5,elevation=a.elevation,oamPriority=a.oamPriority,i=94000+i,
          draw=function(_,cx,cy)love.graphics.setColor(1,1,1,alpha);love.graphics.draw(U.image(art.file,art.width,art.height),sx-cx,sy-cy);love.graphics.setColor(1,1,1,1)end}
      end
    end
    for a,g in pairs(S.short)do if a.visible then
      local art=S.spec.grass.short_grass;local frame=g.timer<4 and 0 or 1
      local sx,sy=a.px,a.py
      actors[#actors+1]={kind='hns_follower_short_grass',x=sx,y=sy,elevation=a.currentElevation,disguiseObject=a,sortY=sy+.5,i=95500,
        draw=function(_,cx,cy)love.graphics.setColor(1,1,1,1);love.graphics.draw(U.image(art.file,art.width,art.height),love.graphics.newQuad(0,frame*16,16,16,art.width,art.height),sx-cx,sy-cy)end}
    end end
    for i,g in ipairs(S.grass)do if g.actor.visible then
      local art=S.spec.grass[g.name];local time=g.timer;local frame=0
      for _,p in ipairs(art.sequence)do frame=p[1];if time<p[2]then break end;time=time-p[2]end
      local sx,sy=g.x*16,g.y*16
      for _,front in ipairs({false,true})do
        local top,height=front and 8 or 0,8
        actors[#actors+1]={kind=front and'hns_follower_grass_front'or'hns_follower_grass_back',x=sx,y=sy+top,elevation=g.actor.currentElevation,sortY=sy+(front and .5 or -.5),i=95000+i,
          draw=function(_,cx,cy)love.graphics.setColor(1,1,1,1);love.graphics.draw(U.image(art.file,art.width,art.height),love.graphics.newQuad(0,frame*16+top,16,height,art.width,art.height),sx-cx,sy+top-cy)end}
      end
    end end
  end
  local collect=old.collect or Fx.collectActors
  Fx.collectActors=function(actors,...)collect(actors,...);S.collect(actors,...)end
  if not old.hook then
    mod.hooks:wrap('input.step',function(next,g,dt)if g==game then S.tick()end;return next(g,dt)end)
    mod.events:on('map.entered',function()S.grass={};S.short={};S.history={}end)
  end
  game._hnsFieldShadows={shadows=S,collect=collect,loadSheet=loadSheet,manifestObject=manifestObject,hook=true}
end
