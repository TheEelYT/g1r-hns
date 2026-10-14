return function(mod,w,game)
  local old=game._hnsFieldShadows or {}
  -- Existing collectors/listeners retain this table across game.ready.
  local S=old.shadows or{grass={},short={}};S.spec=w.fieldShadows
  local Fx=require('src.core.game3.field_effects');local P=require('src.core.game3.player');local Rt=require('src.core.game3.runtime')
  local Coll=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui)
  local function own()local s=Rt.getSession();return s and w.maps[s.map]end
  -- The native player controller uses its own ROM effect sheets. Supply the
  -- same source sheet/palette used by followers, while keeping native timing,
  -- restart and cleanup. Both draw in the common outdoor tint pass.
  local loadSheet=old.loadSheet or Fx.loadSheet
  local manifestObject=old.manifestObject or Fx.manifestObject
  local shortSheet,shortObject
  Fx.loadSheet=function(name,...)
    if own()and name=='short_grass'then
      if not shortSheet then
        local art=S.spec.grass.short_grass;local quads={}
        for i=0,art.height/16-1 do quads[i]=love.graphics.newQuad(0,i*16,16,16,art.width,art.height)end
        shortSheet={image=U.image(art.file,art.width,art.height),quads=quads,fw=16,fh=16,frames=art.height/16}
      end
      return shortSheet
    end
    return loadSheet(name,...)
  end
  Fx.manifestObject=function(name,...)
    if own()and name=='short_grass'then
      if not shortObject then
        local seq={};for _,p in ipairs(S.spec.grass.short_grass.sequence)do seq[#seq+1]={'frame',p[1],p[2]}end;seq[#seq+1]={'end'}
        shortObject={anims={seq},fw=16,fh=16,frames=S.spec.grass.short_grass.height/16,paletteTag=S.spec.paletteTag}
      end
      return shortObject
    end
    return manifestObject(name,...)
  end
  local function grassName(beh)return beh==MB.id('LONG_GRASS')and'long_grass'or beh==MB.id('TALL_GRASS')and'tall_grass'end
  function S.leaveShort(a)S.short[a]=nil end
  function S.finish(a,x,y)
    if Coll.behavior(x,y)==MB.id('SHORT_GRASS')and a.visible then
      S.short[a]=S.short[a]or{actor=a,timer=0,x=a.px,y=a.py}
    else S.short[a]=nil end
  end
  function S.step(a,x,y,jump)
    if not own()or not a.visible then return end
    local beh=Coll.behavior(x,y);local name=grassName(beh)
    if beh==MB.id('SHORT_GRASS')and Coll.behavior(a.cellX,a.cellY)==beh and not jump then S.finish(a,x,y)else S.short[a]=nil end
    if name then S.grass[#S.grass+1]={x=x,y=y,name=name,timer=0,actor=a}
    elseif jump then Fx.startDust(x,y)
    elseif beh==MB.id('PUDDLE')then Fx.startRipple(x,y)end
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
  function S.hidden(actor,eo)
    if eo and(eo.noShadow or eo.hidden or eo.inHotSprings or eo.inSandPile)then return true end
    if actor.kind=='player'and(P.surfing or P.underwater)then return true end
    local x,y=math.floor(actor.x/16),math.floor((eo and eo.py or actor.y)/16);local beh=Coll.behavior(x,y)
    if grassName(beh)or beh==MB.id('PUDDLE')or beh==MB.id('SHALLOW_WATER')then return true end
    return Coll.isWater(x,y)
  end
  function S.collect(actors)
    if not own()then return end
    for i=#actors,1,-1 do
      local a=actors[i];local remove=a.kind=='field_effect_shadow'
      if a.kind=='field_effect_npc_grass'then for _,g in ipairs(S.grass)do if a.x==g.x*16 and a.y==g.y*16+8 then remove=true;break end end end
      if remove then table.remove(actors,i)end
    end
    local count=#actors
    for i=1,count do
      local a=actors[i];local eo=a.eventObject;local row=w.opening.sprites[tostring(a.graphicsId)]
      if (a.kind=='npc'or a.kind=='player')and row and row.shadowSize~=nil and row.shadowSize~=S.spec.none and not S.hidden(a,eo)then
        local art=S.spec.shadows[tostring(row.shadowSize)];local sy=(eo and eo.py or a.kind=='player'and P.py or a.y)+16-art.offset-art.height/2
        local sx=a.x+8-art.width/2;local alpha=(a.alpha or 1)*S.spec.intensity/16
        actors[#actors+1]={kind='hns_shadow',x=sx,y=sy,sortY=(a.sortY or a.y)-0.5,elevation=a.elevation,oamPriority=a.oamPriority,i=94000+i,
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
  Fx.collectActors=function(actors,...)collect(actors,...);S.collect(actors)end
  if not old.hook then
    mod.hooks:wrap('input.step',function(next,g,dt)if g==game then S.tick()end;return next(g,dt)end)
    mod.events:on('map.entered',function()S.grass={};S.short={}end)
  end
  game._hnsFieldShadows={shadows=S,collect=collect,loadSheet=loadSheet,manifestObject=manifestObject,hook=true}
end
