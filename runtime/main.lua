-- HnS native full-world exploration milestone. Generated data is separate from runtime code.
-- Gen 3 has no public native tileset registry yet, so this prototype declares
-- engine_internals and uses a read-only overlay of its own native blobs.
return function(mod)
  local function readTable(file)
    local bytes = mod:read(file)
    if not bytes then return nil, "missing " .. file end
    local chunk, err = load(bytes, "@hns/" .. file, "t", {})
    if not chunk then return nil, err end
    local ok, value = pcall(chunk)
    if not ok or type(value) ~= "table" then return nil, tostring(value) end
    return value
  end
  local world, err = readTable("world.lua")
  if not world or world.format ~= 1 then
    mod.log:error("HnS world data unavailable (%s); rebuild this mod with build_port.py", tostring(err))
    return
  end
  local Pack = require("src.import.gba.native_pack")
  local Layout = require("src.core.game3.layout_native")
  local Native = require("src.core.game3.tileset_native")
  local MB = require("src.core.game3.mb")
  local ScriptCollision = require("src.core.game3.scripting.collision_rse")
  local CollPermissions = require("src.core.CollPermissions")
  local FieldCollision = require("src.core.game3.collision")
  local Interactions = require("src.core.game3.scripting.interaction_scripts")
  local Space = require("src.core.game3.scripting.space")
  local SaveData = require("src.core.SaveData")
  local Boot = require("src.ui.game3.boot")
  local Hud = require("src.ui.game3.hud")
  local PREFIX = "EM_HNS_"
  -- Explicit exploration-only approximations for HnS behaviors absent from the
  -- vanilla engine. Their additional interactions/animations are not ported.
  local BEHAVIOR_ALIAS = {
    MB_BOOKSHELF_GREEN = "BOOKSHELF",
    MB_SHOP_SHELF_DEPARTMENT = "POKEMART_SHELF",
    MB_SHOP_SHELF_DEPARTMENT_FORWARD = "POKEMART_SHELF",
    MB_HEADBUTT_TREE = "NORMAL",
    MB_CAVE_IMPASSABLE_NORTH = "IMPASSABLE_NORTH",
    MB_TALL_GRASS_IMPASSABLE_NORTH = "IMPASSABLE_NORTH",
    MB_WATER_NORTH_ARROW_WARP = "NORTH_ARROW_WARP",
    MB_SIDEWAYS_STAIRS_LEFT_SIDE_TOP = "NORMAL",
    MB_SIDEWAYS_STAIRS_LEFT_SIDE = "NORMAL",
    MB_SIDEWAYS_STAIRS_LEFT_SIDE_BOTTOM = "NORMAL",
    MB_SIDEWAYS_STAIRS_RIGHT_SIDE_TOP = "NORMAL",
    MB_SIDEWAYS_STAIRS_RIGHT_SIDE = "NORMAL",
    MB_SIDEWAYS_STAIRS_RIGHT_SIDE_BOTTOM = "NORMAL",
  }

  local function ownMap(id)
    return type(id) == "string" and id:sub(1, #PREFIX) == PREFIX
  end

  -- Validate every layout before registering any maps, so a corrupt build never
  -- changes new-game behavior and then fails after the player starts a save.
  local decoded, behaviors = {}, {}
  local counterBehavior = MB.require("COUNTER")
  for pair, info in pairs(world.pairs or {}) do
    behaviors[pair] = {}
    for mid, name in pairs(info.behaviors or {}) do
      local canonical = MB.id(BEHAVIOR_ALIAS[name] or name)
      if canonical == nil then
        mod.log:error("unported HnS metatile behavior %s; rebuild after adding its engine mapping", tostring(name))
        return
      end
      behaviors[pair][tonumber(mid)] = canonical
    end
  end
  for id, def in pairs(world.maps or {}) do
    local blob = mod:read(def.hnsLayoutFile)
    if not blob or #blob < 24 then
      mod.log:error("HnS layout %s is missing; rebuild the mod", tostring(id))
      return
    end
    local ok, value = pcall(Pack.decodeMidLayout, blob)
    if not ok or type(value) ~= "table" or value.width ~= def.width or value.height ~= def.height then
      mod.log:error("HnS layout %s is invalid; rebuild the mod", tostring(id))
      return
    end
    local byMid = behaviors[def.pair]
    local warpCells = {}
    for _, w in ipairs(def.warps or {}) do warpCells[w.y * 1024 + w.x] = true end
    for i, cell in ipairs(value.cells) do
      local original = cell.coll
      local behavior = byMid and byMid[cell.mid]
      if behavior == nil then
        mod.log:error("HnS map %s references an unmapped metatile; rebuild the mod", tostring(id))
        return
      end
      -- The imported Emerald tileBits table describes water using named behavior
      -- ids shared by HnS; each HnS raw behavior was canonicalized by name above.
      local collision = ScriptCollision.fromCell(cell.mid, original, behavior, def.kind)
      local sourceBehavior = world.pairs[def.pair].behaviors[tostring(cell.mid)]
      if sourceBehavior == "MB_WATER_NORTH_ARROW_WARP" then
        collision = ScriptCollision.seed("WATER")
      elseif sourceBehavior == "MB_TALL_GRASS_IMPASSABLE_NORTH" then
        collision = ScriptCollision.seed("TALL_GRASS")
      end
      local x, y = (i - 1) % value.width, math.floor((i - 1) / value.width)
      local hasWarp = warpCells[y * 1024 + x] == true
      if original ~= 0 and not CollPermissions.isLedge(collision)
          and behavior ~= counterBehavior
          and not (hasWarp and FieldCollision.isWarpMetatileBehavior(behavior)) then
        collision = ScriptCollision.seed("BLOCKED")
      end
      -- An unresolved or inactive source exit has no registered warp. Its
      -- doorway remains blocked, instead of letting the player walk into void.
      if FieldCollision.isWarpMetatileBehavior(behavior) and not hasWarp then
        collision = ScriptCollision.seed("BLOCKED")
      end
      cell.coll = collision
    end
    decoded[id] = value
  end
  if not (world.start and world.maps[world.start.map]) then
    mod.log:error("HnS start map is missing; rebuild the mod")
    return
  end
  for id, def in pairs(world.maps) do mod.content.maps:register(id, def) end
  for id, text in pairs(world.text or {}) do mod.content.text:register(id, text) end
  for id, rows in pairs(world.scripts or {}) do mod.content.map_scripts:register(id, rows) end
  for id, def in pairs(world.quest and world.quest.items or {}) do mod.content.items:register(id, def) end
  for id, def in pairs(world.campaign and world.campaign.moves or {}) do mod.content.moves:register(id, def) end
  for id, def in pairs(world.trainers and world.trainers.records or {}) do mod.content.trainers:register(id, def) end
  local encounterTables=world.encounters and world.encounters.tables or world.opening and world.opening.encounters or {}
  for id, def in pairs(encounterTables) do mod.content.encounters:register(id, def) end
  local function usablePartner()
    local session = require("src.core.game3.runtime").getSession()
    for _,mon in ipairs(session and session.party or {}) do
      if not (mon.isEgg or mon.egg) and (tonumber(mon.hp or mon.currentHp) or 0)>0 then return true end
    end
    return false
  end
  -- Old exploration saves can walk these routes without a party. Wait for a
  -- usable partner before rolling an opening battle instead of attempting an
  -- empty-party battle on every successful grass roll.
  mod.hooks:wrap("encounter.roll", function(next, tableDef, ctx)
    if encounterTables[ctx.mapId] and not usablePartner() then return nil end
    return next(tableDef, ctx)
  end)
  mod.hooks:wrap("world.talk",function(next,game,object)
    local tid=object and object.def and object.def.trainerId
    if world.trainers and world.trainers.records[tostring(tid)] and not usablePartner() then
      Hud.openMessage(game,"You need a healthy POKéMON to battle. Visit ELM or a POKéMON CENTER.")
      return true
    end
    return next(game,object)
  end)

  local function installOpening(game)
    local opening = world.opening
    if not opening then return true end
    local names = game.data.gen3Pokemon and game.data.gen3Pokemon._names or {}
    local species = {}
    for id, name in pairs(names) do
      if type(name) == "string" then species[name:upper()] = tonumber(id) end
    end
    for _, name in ipairs({"CHIKORITA","CYNDAQUIL","TOTODILE"}) do
      if not species[name] then
        mod.log:error("Opening requires the imported Emerald species table (%s missing)",name)
        return false
      end
    end
    local Constants = require("src.core.game3.constants").of("emerald")
    -- Supplement stable scripts with reviewed audio cues. Rebuild from the
    -- authored originals on every install so repeated game.ready cannot double
    -- jingles or alter any original inventory, movement or progression rows.
    for key,cues in pairs(world.audio and world.audio.cues or {}) do
      local rows={}
      local function append(row)local out={};for k,v in pairs(row) do out[k]=v end;rows[#rows+1]=out end
      for i,row in ipairs(world.scripts[key]) do
        for _,cue in ipairs(cues) do if cue.before==i then for _,sound in ipairs(cue.rows) do append(sound) end end end
        append(row)
        for _,cue in ipairs(cues) do if cue.after==i then for _,sound in ipairs(cue.rows) do append(sound) end end end
      end
      game.data.gen3Scripts[key]=rows
    end
    -- Resolve source movement names through Emerald's own canonicalizer;
    -- HnS numeric movement IDs are not interchangeable with native IDs.
    for id in pairs(world.maps) do
      for _, obj in ipairs(game.data.maps[id].objects or {}) do
        if obj.hnsMovementType then
          obj.movementType = Constants:require("movement",obj.hnsMovementAlias or obj.hnsMovementType)
        end
      end
    end
    for id in pairs(world.scripts) do
      for _, row in ipairs(game.data.gen3Scripts[id] or {}) do
        if row.speciesName then
          if row.op == "givemon" then row.species = species[row.speciesName]
          elseif row.op == "playmoncry" then row[1],row[2] = species[row.speciesName],row.mode or 0
          elseif row.op == "showmonpic" then row[1],row[2],row[3]=species[row.speciesName],row.x or 10,row.y or 3
          elseif row.op == "setvar" then row.value = species[row.speciesName] end
        end
        if row.engineFlagName then
          row.flag = Constants.flags.byName[row.engineFlagName]
          if not row.flag then error("missing engine flag " .. row.engineFlagName) end
        end
        if row.itemName then row.item=Constants:require("items",row.itemName) end
        if row.seName then row[1]=Constants:require('songs',row.seName) end
        if row.songName then
          for song,name in pairs(world.audio.songs) do if name==row.songName then row[1]=tonumber(song) end end
          assert(row[1],"unmapped source cue "..row.songName)
        end
        if (row.op == "setobjectxyperm" or row.op == "setobjectxy") and row.x ~= nil then row[2],row[3]=row.x,row.y end
        if row.movementNames then
          local Movement=require("src.import.gba.movement_emerald")
          row.movement={}
          for _,name in ipairs(row.movementNames) do
            row.movement[#row.movement+1]=assert(Movement.canonOf(name),"unmapped quest movement "..name)
          end
        end
      end
    end
    local Ow = require("src.core.game3.ow_sprites")
    local previous = game._hnsOpening
    local base = previous and previous.baseCache or Ow._cache
    local vanillaManifest = previous and previous.vanillaManifest or Ow._manifest
    local overlay = {}
    local function isManifest(rel)
      return type(rel)=="string" and (rel:match("/ow/manifest%.lua$") or rel=="ow/manifest.lua")
    end
    -- FieldView gates NPC drawing on the manifest, including after sprite
    -- invalidation. Serve a real merged manifest through the same overlay as
    -- the sheets; retain Emerald's avatar rows and unowned sprite entries.
    local function manifestBytes(rel)
      local original=vanillaManifest
      local bytes=base and base:read(rel)
      if type(bytes)=="string" then
        local chunk=load(bytes,"@hns/base-ow-manifest","t",{})
        if chunk then
          local ok,value=pcall(chunk)
          if ok and type(value)=="table" then original=value end
        end
      end
      local merged={sprites={}}
      for key,value in pairs(original or {}) do
        if key~="sprites" then merged[key]=value end
      end
      for id,info in pairs(original and original.sprites or {}) do merged.sprites[id]=info end
      for id,info in pairs(opening.sprites) do
        merged.sprites[tonumber(id)]={width=info.width,height=info.height,frameCount=info.frameCount,
          atlasW=info.width,atlasH=info.height*info.frameCount}
      end
      local count=0
      for _ in pairs(merged.sprites) do count=count+1 end
      local missing=original and math.max(0,(original.total or 0)-(original.count or 0)) or 0
      merged.count=count;merged.total=count+missing
      merged.ow_version=require("src.import.gba.versions").OW_VERSION or 1
      return require("src.import.LuaWriter").encode(merged)
    end
    -- Match our exact sprite IDs across mounted cache root spellings.
    local function path(rel)
      if type(rel) ~= "string" then return nil end
      local suffix = rel:match("/ow/([^/]+)$") or rel:match("^ow/([^/]+)$")
      if not suffix then return nil end
      local gid,ext = suffix:match("^(%d+)%.(%w+)$")
      if gid and opening.sprites[gid] and (ext == "meta" or ext == "rgba") then return "ow/" .. suffix end
    end
    function overlay:read(rel)
      if isManifest(rel) then return manifestBytes(rel) end
      local localPath = path(rel)
      if localPath then return mod:read(localPath) end
      return base and base:read(rel)
    end
    function overlay:exists(rel)
      if isManifest(rel) then return true end
      local localPath = path(rel)
      if localPath then return mod:info(localPath) ~= nil end
      return base and base:exists(rel) or false
    end
    function overlay:write(rel,bytes) return base and base:write(rel,bytes) or false end
    Ow.install(overlay)
    -- Keep source frame sheets in a separate ID range; the vanilla resolver
    -- clamps large IDs, so bypass it only for this mod's tagged NPC templates.
    local original = previous and previous.graphicsResolver or Space.resolveObjectGraphicsId
    Space.resolveObjectGraphicsId = function(obj,neighbor)
      local gid = obj and obj.hnsGraphicsId
      if gid and opening.sprites[tostring(gid)] then return gid end
      return original(obj,neighbor)
    end
    local Natives = require("src.core.game3.scripting.natives")
    Natives.ALLOW["native:" .. opening.healNative] = assert(Natives.handlerFor("HealPlayerParty"))
    if world.quest then
      Natives.ALLOW["native:"..world.quest.dexNative]=function()
        require("src.core.game3.dex").enableNational(require("src.core.game3.runtime").getSession())
        return false
      end
      Natives.ALLOW["native:"..world.quest.partyNative]=function(ctx)
        require("src.core.game3.scripting.flags").setVar(Space.store,ctx,0x800D,usablePartner() and 1 or 0)
        return false
      end
    end
    if world.quest and world.quest.nameNative then
      assert(load(mod:read("scenes.lua"),"@hns/scenes.lua"))()(mod,world,game)
    end
    if world.pokedex then
      assert(load(mod:read("dex_state.lua"),"@hns/dex_state.lua"))()(mod,world,game)
      assert(load(mod:read("pokedex.lua"),"@hns/pokedex.lua"))()(mod,world,game)
    end
    if world.audio then assert(load(mod:read("hns_audio.lua"),"@hns/hns_audio.lua"))()(mod,world,game) end
    if world.campaign then assert(load(mod:read("campaign.lua"),"@hns/campaign.lua"))()(mod,world,game) end
    if world.startup then assert(load(mod:read("startup.lua"),"@hns/startup.lua"))()(mod,world,game) end
    if world.bootPresentation then assert(load(mod:read("boot_presentation.lua")))()(mod,world,game) end
    if world.startup and world.startup.rules then assert(load(mod:read("gameplay.lua"),"@hns/gameplay.lua"))()(mod,world,game) end
    if world.startup and world.pokedex then assert(load(mod:read('battle_mechanics.lua'),'@hns/battle_mechanics.lua'))()(mod,world,game) end
    if world.startup and world.startup.rules then assert(load(mod:read("battle_presentation.lua"),"@hns/battle_presentation.lua"))()(mod,world,game) end
    if world.startup and world.pokedex.registrationEntries then assert(load(mod:read("collection_screens.lua"),"@hns/collection_screens.lua"))()(mod,world,game) end
    if world.services then assert(load(mod:read('bag_services.lua'),'@hns/bag_services.lua'))()(mod,world,game) end
    if world.presentation then assert(load(mod:read("field_presentation.lua"),"@hns/field_presentation.lua"))()(mod,world,game) end
    if world.services then assert(load(mod:read('field_services.lua'),'@hns/field_services.lua'))()(mod,world,game) end
    if world.followers then assert(load(mod:read('followers.lua')))()(mod,world,game) end
    if world.encounters.timed then assert(load(mod:read('time_cycle.lua')))()(mod,world,game) end
    local Marts = require("src.core.game3.marts")
    Marts.ensure()
    local marts = world.worldEvents and world.worldEvents.marts
    local upgraded={}
    for key,stock in pairs(marts and marts.stocks or {}) do
      local items = {}
      for _,name in ipairs(stock.items) do items[#items+1] = Constants:require("items",name) end
      Marts._byKey[key] = {key=key,items=items}
      if stock.postQuestItems then
        local after={}
        for _,name in ipairs(stock.postQuestItems) do after[#after+1]=Constants:require("items",name) end
        upgraded[key]={key=key,items=after}
      end
    end
    if world.quest then
      local baseItems=game._hnsProgress and game._hnsProgress.baseItems or Marts.itemsFor
      Marts.itemsFor=function(key)
        local after=upgraded[key]
        local Flags=require("src.core.game3.scripting.flags")
        if after and Space.store and Flags.getFlag(Space.store,nil,world.quest.flags.eggDelivered) then return after.items,after end
        return baseItems(key)
      end
      game._hnsProgress=game._hnsProgress or {};game._hnsProgress.baseItems=baseItems
    end
    if world.trainers then
      local Trainers=require("src.core.game3.scripting.trainers")
      local source=game.data.gen3Trainers
      source=source._pack or source
      local pack=Trainers.pack() or source
      assert(pack and pack.trainers,"native trainer table unavailable")
      for id in pairs(world.trainers.records) do
        pack.trainers[tonumber(id)]=assert(source.trainers[tonumber(id)],"missing port trainer "..id)
      end
      pack.money=pack.money or {};pack.classNames=pack.classNames or {}
      for id,info in pairs(world.trainers.classes) do
        pack.money[tonumber(id)]=info.money;pack.classNames[tonumber(id)]=info.name
      end
      Trainers._pack=pack
      local Pic=require("src.core.game3.trainer_pic")
      if not Pic._cache then Pic.install(nil) end
      local picBase=game._hnsProgress and game._hnsProgress.picBase or Pic._cache
      local picOverlay={}
      function picOverlay:read(rel)
        local id=type(rel)=="string" and rel:match("trainers/front/(%d+)%.rgba$")
        local info=id and world.trainers.portraits[id]
        if info then return mod:read(info.file) end
        return picBase and picBase:read(rel)
      end
      Pic._cache=picOverlay;Pic._front={}
      local Sight=require("src.core.game3.trainer_sight")
      local baseSight=game._hnsProgress and game._hnsProgress.baseSight or Sight.check
      Sight.check=function(g,eo,...)
        local tid=eo and eo.def and eo.def.trainerId
        local session=require("src.core.game3.runtime").getSession()
        if (world.trainers.records[tostring(tid)] or not eo and ownMap(session and session.map)) and not usablePartner() then return false end
        return baseSight(g,eo,...)
      end
      game._hnsProgress=game._hnsProgress or {}
      game._hnsProgress.picBase=picBase;game._hnsProgress.baseSight=baseSight
    end
    local Encounters = require("src.core.game3.encounters")
    for id in pairs(encounterTables) do Encounters._tables[id] = game.data.gen3Encounters[id] end
    Encounters._loaded = true
    game._hnsOpening = {baseCache=base,vanillaManifest=vanillaManifest,graphicsResolver=original,version=2}
    return true
  end

  local function install(game)
    if not (game and game.data and game.data.maps) then
      mod.log:error("Gen 3 map service is unavailable; use the pinned gen1recomp build")
      return
    end
    if not installOpening(game) then return end
    for id, value in pairs(decoded) do
      local def = game.data.maps[id]
      if not def then
        mod.log:error("HnS map registration did not merge; use the pinned gen1recomp build")
        return
      end
      def.midLayout = Layout.fromDecoded(value, id, def.pair)
    end
    for pair, byMid in pairs(behaviors) do Interactions.behaviors[pair] = byMid end

    -- Read only this mod's namespaced blobs. Cache writes delegate to the
    -- engine for its derived RGBA atlas cache; vanilla files delegate unchanged.
    local previous = game._hnsExploration
    local base = previous and previous.baseCache or Native._cache
    local overlay = {}
    local function localRel(rel)
      if type(rel) ~= "string" then return nil end
      -- NativeTileset captures its root at require time; Dataset can mount a
      -- different root later. Identify only our exact pair + blob names so
      -- both root spellings resolve to the same mod-owned assets.
      local pair, file = rel:match("([^/]+)/([^/]+)$")
      if not (pair and world.pairs[pair]) then return nil end
      if file == "mids.idx" or file == "mids_over.idx" or file == "mids_mid.idx"
          or file == "palettes.bin" then return "native/" .. pair .. "/" .. file end
      for _,owned in ipairs(world.pairs[pair].animationFiles or {})do if file==owned then return 'native/'..pair..'/'..file end end
      return nil
    end
    function overlay:read(rel)
      local path = localRel(rel)
      if path then return mod:read(path) end
      return base and base:read(rel)
    end
    function overlay:exists(rel)
      local path = localRel(rel)
      if path then return mod:info(path) ~= nil end
      return base and base:exists(rel) or false
    end
    function overlay:write(rel, bytes)
      return base and base:write(rel, bytes) or false
    end
    Native._cache = overlay
    Native.invalidate()
    if world.animations then
      require('src.core.game3.tileset_anim').install(overlay)
      assert(load(mod:read('tile_animation.lua'),'@hns/tile_animation.lua'))()(mod,world,game)
    end

    -- Reviewed lab/house object scripts and healing supplement the map signs.
    -- Preserve reviewed entry scripts and coordinate triggers when the real
    -- map loader reattaches Space.bundle events onto map definitions.
    if Space.bundle then
      Space.bundle.events = Space.bundle.events or {}
      for id, def in pairs(world.maps) do
        Space.bundle.events[id] = { objects = def.objects or {}, bgEvents = def.bgEvents,
          coordEvents = def.coordEvents or {}, mapScripts = def.mapScripts or {}, music = def.music }
      end
      Space.bundle.text = game.data.gen3Text or Space.bundle.text
      Space.bundle.scripts = game.data.gen3Scripts or Space.bundle.scripts
    end

    -- Wrap this Game3 instance only. Removing/disabling the mod on the next
    -- boot does not change the engine singleton or any vanilla game instance.
    local original = previous and previous.originalBootAction or game._handleBootAction
    if type(original) ~= "function" then
      mod.log:error("Gen 3 boot API changed; use the pinned engine revision")
      return
    end
    game._handleBootAction = function(self, action)
      if type(action) == "table" and action.action == "new_game" then
        local slot = SaveData.createSlot("emerald")
        if not slot then
          mod.log:error("Could not create a separate HnS save slot; free space and try again")
          return
        end
        SaveData.setActiveSlot("emerald", slot)
        SaveData.renameSlot("emerald", slot, "HnS exploration")
        local copy = {}
        for key, value in pairs(action) do copy[key] = value end
        local start=world.startup and world.startup.start or world.start
        copy.start = {map=start.map,x=start.x,y=start.y,facing=start.facing,
          healMap=world.start.map,healX=world.start.x,healY=world.start.y}
        if action.hnsOptions then
          local Options=require('src.core.game3.options')
          local block=Options.block(self.options)
          for k,v in pairs(action.hnsOptions) do block[k]=v end
          self:applyOptions(self.options);self:writeOptions()
        end
        self._hnsNewChoices=action.hnsChoices
        copy.fieldCallback = nil -- Emerald's moving-truck scene is map-specific.
        return original(self, copy)
      elseif type(action) == "table" and action.action == "continue" then
        local ok, save = pcall(SaveData.load)
        if not ok or not save or not ownMap(save.map) then
          mod.log:warn("This slot is not an HnS exploration save; choose New Game or the HnS slot")
          return
        end
      end
      return original(self, action)
    end
    local ok, save = pcall(SaveData.load)
    if game.boot then
      Boot.setHasContinue(game.boot, ok and save and ownMap(save.map))
      if ok and save and ownMap(save.map) then Boot.setContinueInfo(game.boot,Boot.continueInfoFromSave(save)) end
    end
    game._hnsExploration = { mapCount = 0, atlasOverlay = overlay,
      baseCache = base, originalBootAction = original }
    for _ in pairs(world.maps) do game._hnsExploration.mapCount = game._hnsExploration.mapCount + 1 end
    mod.log:info("HnS world installed: %d maps; source music, opening, Sprout Tower, Violet Gym and compatible world battles; later campaign in progress", game._hnsExploration.mapCount)
  end
  mod.events:on("game.ready", function(ev) install(ev.game) end)
  mod.events:on("save.created", function(ev)
    if ev.save and ownMap(ev.save.map) then
      ev.save.hnsExplorationVersion = 1
      ev.save.money = 0
      if world.startup then
        local Q=world.startup
        ev.save.flags=ev.save.flags or {};ev.save.vars=ev.save.vars or {}
        ev.save.flags[Q.newGameFlag]=true;ev.save.vars[Q.houseState]=0
        local C=require('src.core.game3.constants').of('emerald')
        ev.save.flags[C:flag('FLAG_SYS_B_DASH')]=nil
        local Bag=require('src.core.game3.bag')
        assert(Bag.add(ev.save.bag,Q.gbItem,1),'GB SOUNDS starter item failed')
        assert(Bag.add(ev.save.bag,Q.expItem,1),'EXP. SHARE starter item failed')
        local choices=mod.game._hnsNewChoices or {}
        for _,p in ipairs(Q.settings.pages)do for _,r in ipairs(p.rows)do ev.save.vars[r.var]=choices[r.id] or r.default end end
        ev.save.flags[Q.settings.initializedFlag]=true
        mod.game._hnsNewChoices=nil
      end
    end
  end)
  local announced = false
  mod.events:on("map.entered", function(ev)
    local checkpoint = world.worldEvents and world.worldEvents.healCheckpoints[ev.mapId]
    if checkpoint then
      local session = require("src.core.game3.runtime").getSession()
      if session then
        session.healMap, session.healX, session.healY = checkpoint.map, checkpoint.x, checkpoint.y
        session.healHealerLocalId = nil
      end
    end
    if not world.startup and not announced and ownMap(ev.mapId) then
      announced = true
      local game = mod.game
      if game then
        Hud.openMessage(game, "ELM's errand, SPROUT TOWER and VIOLET GYM are ready.\nThe later HnS story is still being ported.")
      end
    end
  end)
end
