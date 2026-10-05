-- Scoped HnS startup, avatars and source section names.
return function(mod,world,game)
  local Q=world.startup
  local old=game._hnsStartup or {}
  local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags')
  local Natives=require('src.core.game3.scripting.natives')
  local Ow=require('src.core.game3.ow_sprites')
  local Mapsec=require('src.ui.game3.rse.mapsec')
  local BootModules=require('src.ui.game3.boot_modules')
  local function own(g)
    g=g or game
    local s=g.session or g.save
    return s and world.maps[s.map]~=nil
  end
  local baseGfx=old.playerGraphicsId or Ow.playerGraphicsId
  Ow.playerGraphicsId=function(g,p)
    if own(g) then
      local s=g.session or g.save
      local female=s.gender==1 or s.gender=='female' or s.gender=='F'
      return Ow.avatarGraphicsId(Ow.avatarState(p or require('src.core.game3.player')),female,{player=Q.avatars})
    end
    return baseGfx(g,p)
  end
  local baseName=old.name or Mapsec.name;local baseTheme=old.theme or Mapsec.theme
  Mapsec.name=function(sec) return Q.areas[tostring(sec)] or baseName(sec) end
  Mapsec.theme=function(sec) if Q.areaThemes[tostring(sec)] then return Q.areaThemes[tostring(sec)] end;return baseTheme(sec) end
  local clockSet=assert(Natives.handlerFor('StartWallClock'))
  local clockView=assert(Natives.handlerFor('Special_ViewWallClock'))
  Natives.ALLOW['native:'..Q.clockNative]=function(ctx,a)
    local view=Flags.getFlag(Space.store,ctx,Q.clockFlag)
    -- Source clock is gender-dependent; do not confuse view-mode with gender.
    local s=require('src.core.game3.runtime').getSession()
    Flags.setVar(Space.store,ctx,0x8004,s and s.gender or 0)
    return (view and clockView or clockSet)(ctx,a)
  end
  local function image(kind)
    local bytes,w,h
    if kind=='ball' then
      local result=love.graphics.newImage(love.image.newImageData(16,48,'rgba8',assert(mod:read('startup_ball.rgba'))))
      result:setFilter('nearest','nearest');return result
    end
    local info=kind:match('^bg') and Q.backdrops[kind:sub(3)] or Q.portraits[kind];bytes=assert(mod:read(info.file));w,h=info.width,info.height
    local result=love.graphics.newImage(love.image.newImageData(w,h,'rgba8',bytes));result:setFilter('nearest','nearest');return result
  end
  local Speech=assert(load(mod:read('hns_oak_speech.lua'),'@hns/hns_oak_speech.lua'))()
  local oakSong
  for id,name in pairs(world.audio.songs) do if name==Q.oakSong then oakSong=tonumber(id) end end
  local UI=assert(load(mod:read('source_ui.lua'),'@hns/source_ui.lua'))()(mod,Q.ui)
  local Settings=assert(load(mod:read('settings.lua'),'@hns/settings.lua'))()(Q.settings,UI)
  Speech.configure({speech=Q.speech,image=image,oakSong=assert(oakSong),settings=Settings})
  assert(load(mod:read('pokegear.lua'),'@hns/pokegear.lua'))()(mod,world,game,Settings,UI)
  local baseLoad=old.bootLoad or BootModules.load
  BootModules.load=function(name) if name=='hns.oak_speech' then return Speech end;return baseLoad(name) end
  local Boot=require('src.ui.game3.boot')
  local baseNew=old.bootNew or Boot.new
  Boot.new=function(g)
    local state=baseNew(g)
    if g==game and state.custom then state.custom.mods.newGame='hns.oak_speech' end
    return state
  end
  if game.boot and game.boot.custom then
    game.boot.custom.mods.newGame='hns.oak_speech'
  end
  -- Old saves keep their shoes and quest state. New games start in the bedroom.
  game._hnsStartup={playerGraphicsId=baseGfx,name=baseName,theme=baseTheme,bootLoad=baseLoad,bootNew=baseNew}
end
