-- Exercise FieldView.draw and NativeTileset.get with converted source bytes.
-- Only the GPU boundary is recorded; atlas readiness, decoding, baking,
-- viewport sampling and batch construction are the actual engine modules.
return function(T,game,maps,world)
  local Native=require("src.core.game3.tileset_native")
  local FieldView=require("src.core.game3.field_view")
  local Rt=require("src.core.game3.runtime")
  local Map=require("src.core.game3.map")
  local Ow=require("src.core.game3.ow_sprites")
  local Objects=require("src.core.game3.objects")
  local Collision=require("src.core.game3.collision")
  local Space=require("src.core.game3.scripting.space")
  local Player=require("src.core.game3.player")
  local saved={}
  local function preserve(t,keys)
    for _,k in ipairs(keys) do saved[#saved+1]={t=t,k=k,v=t[k]} end
  end
  preserve(Rt,{"session","active"})
  preserve(Map,{"world","_worldRoot","_worldReachW","_worldReachH","_warmPairs","_warmQueue","_warmEntries"})
  preserve(Objects,{"_byId","_order","_tracks","_mapId","_defs","_bounds","_perm","_templateMt"})
  preserve(Space,{"store"});preserve(Player,{"isVisible"})
  preserve(love.image,{"newImageData"})
  preserve(love.graphics,{"newImage","newSpriteBatch","draw","print","rectangle"})
  local oldImageData,oldImage,oldRectangle=love.image.newImageData,love.graphics.newImage,love.graphics.rectangle
  love.image.newImageData=function(w,h,format,rgba)
    if type(w)=="number" and format=="rgba8" then
      assert(type(rgba)=="string" and #rgba==w*h*4,"atlas RGBA dimensions")
      return {w=w,h=h,rgba=rgba,getDimensions=function(self) return self.w,self.h end}
    end
    return oldImageData(w,h)
  end
  love.graphics.newImage=function(data)
    if type(data)=="table" and data.rgba then
      return {w=data.w,h=data.h,rgba=data.rgba,
        getDimensions=function(self) return self.w,self.h end,
        setFilter=function() end}
    end
    return oldImage(data)
  end
  love.graphics.newSpriteBatch=function(texture)
    local batch={texture=texture,sprites={}}
    function batch:add(q,x,y)
      self.sprites[#self.sprites+1]={q=q,x=x,y=y}
      return #self.sprites
    end
    function batch:set(i,q,x,y)
      assert(i>=1 and i<=#self.sprites,"valid batch index")
      self.sprites[i]={q=q,x=x,y=y}
    end
    function batch:clear() self.sprites={} end
    function batch:getCount() return #self.sprites end
    function batch:getTexture() return self.texture end
    function batch:release() end
    return batch
  end
  local drawn,printed,npcDraws,blueBoxes
  love.graphics.draw=function(thing)
    if type(thing)=="table" and thing.sprites and thing.texture and thing.texture.rgba then
      drawn=drawn+#thing.sprites
    elseif type(thing)=="table" and thing.rgba then
      npcDraws=npcDraws+1
    end
  end
  love.graphics.rectangle=function(...)
    local r,g,b=love.graphics.getColor()
    if r==0.3 and g==0.55 and b==0.95 then blueBoxes=blueBoxes+1 end
    return oldRectangle(...)
  end
  love.graphics.print=function(message) printed[#printed+1]=tostring(message) end
  -- Session coordinates also cover the inactive-runtime startup frame.
  Rt.active=false
  Player.isVisible=function() return false end -- Only NPC placeholders matter here.
  Space.store=require("src.core.game3.scripting.flags").newStore()
  for _,sample in ipairs({
    {"EM_HNS_NEW_BARK_TOWN_HNS",20,12},
    {"EM_HNS_NEW_BARK_TOWN_LAB_HNS",4,7},
    {"EM_HNS_CHERRYGROVE_CITY_HNS",56,11},
    {"EM_HNS_CHERRYGROVE_CITY_POKEMON_CENTER_HNS",7,8},
    {"EM_HNS_CHERRYGROVE_CITY_MART_HNS",7,8},
  }) do
    local def=assert(maps[sample[1]],"render sample map")
    Rt.session={version="emerald",map=def.id,x=sample[2],y=sample[3],facing="down"}
    FieldView.invalidate()
    Space.attachEventsToMaps({[def.id]=def},Space.bundle)
    Collision.bindMap(game,def.id,def)
    Objects.loadMap(game,def.id,def)
    drawn,printed,npcDraws,blueBoxes=0,{},0,0
    T.check(Ow.ready(),"NPC renderer remains ready after full field invalidation: "..def.id)
    local expected=#Objects.forDraw()
    local ok,err=pcall(FieldView.draw,game,240,160)
    T.check(ok,"actual field draw completes: "..def.id.." "..tostring(err or ""))
    T.check(drawn>0,"field submits source atlas tiles: "..def.id)
    T.check(npcDraws>0 and npcDraws>=expected,"field submits real NPC sprite images: "..def.id)
    T.eq(blueBoxes,0,"field avoids blue NPC placeholders: "..def.id)
    local fallback=false
    for _,message in ipairs(printed) do
      if message:match("game3: no") then fallback=true end
    end
    T.check(not fallback,"field avoids missing-layout/atlas screen: "..def.id)
    local atlas=Native._pairs[def.pair]
    T.check(atlas and atlas.image and atlas.image.rgba,"real native atlas loaded: "..def.id)
    if atlas and atlas.image then
      T.eq(atlas.image.w,atlas.cols*16,"atlas width: "..def.id)
      T.eq(atlas.image.h,atlas.rows*16,"atlas height: "..def.id)
      T.check(atlas.layered and atlas.overImage and atlas.midImage,"source layers loaded: "..def.id)
    end
  end
  -- Readiness must survive repeated independent sprite-cache resets, rather
  -- than relying on an in-memory manifest assigned once during game.ready.
  for cycle=1,2 do
    Ow.invalidate()
    T.check(Ow.ready(),"all HnS sheets remain drawable after sprite reset "..cycle)
    for id,info in pairs(world.opening.sprites) do
      local spr=Ow.get(tonumber(id))
      T.check(spr and spr.image and spr.image.rgba,"actual sprite loader opens sheet "..id)
      if spr then
        T.eq(spr.width,info.width,"sprite width "..id)
        T.eq(spr.height,info.height,"sprite height "..id)
        T.eq(spr.frameCount,info.frameCount,"sprite frames "..id)
        T.check(Ow.draw(tonumber(id),0,0,0,0,"down",0,false),"actual standing sprite draw "..id)
        if info.frameCount>=9 then
          T.check(Ow.draw(tonumber(id),0,0,0,0,"right",1,true),"actual walking sprite draw "..id)
        end
      end
    end
  end
  FieldView.invalidate()
  for i=#saved,1,-1 do local s=saved[i];s.t[s.k]=s.v end
  print("Startup render regressions: New Bark, Elm lab, Cherrygrove, Center and mart; real terrain and NPC draws; all source sheets across two sprite resets")
end
