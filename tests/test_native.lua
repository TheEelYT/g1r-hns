-- Run from the pinned gen1recomp checkout with LuaJIT, no ROM required.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
-- Match LÖVE's raw ImageData size check; the upstream headless stub skips it.
local imageData=love.image.newImageData
love.image.newImageData=function(w,h,format,bytes,...)
  if type(w)=='number' and format=='rgba8' and bytes~=nil then
    assert(type(bytes)=='string' and #bytes==w*h*4,'raw ImageData byte count must match dimensions')
  end
  return imageData(w,h,format,bytes,...)
end
local GameVersion = require("src.core.GameVersion")
GameVersion.set("emerald")
-- Match the desktop importer too: GameVersion and Versions are separate
-- selectors, and the SDK does not perform a real Emerald ROM import.
require("src.import.gba.versions").select("emerald")
local data = T.sdk.gen3Data()
data.generation = 3
-- Named species fixture, sufficient for opening registry references and real
-- party construction. Production reads the user's complete Emerald tables.
local C=require("src.core.game3.constants").of("emerald")
local path = arg[1] or "../build/hns_exploration"
-- Independent pixel/oracle fixtures also read installed files, rather than
-- assuming that bytes on disk are raw. Production uses its own mod API.
function T.readAsset(file)
  local f=assert(io.open(path..'/'..file,'rb'));local bytes=f:read('*a');f:close()
  local ok,Blob=pcall(require,'src.import.CacheBlob')
  if ok then local decoded,raw=pcall(Blob.decode,file,bytes);if decoded then bytes=raw end end
  return bytes
end
local world=dofile(path.."/world.lua")
for _,name in ipairs({"CHIKORITA","CYNDAQUIL","TOTODILE","SENTRET","HOPPIP","RATTATA","HOOTHOOT"}) do
  local id=C.species.byName["SPECIES_"..name]
  data.gen3Pokemon._names[id]=name
  data.gen3Pokemon._stats[id]={hp=50,atk=50,def=50,spe=50,spa=50,spd=50}
  data.gen3Pokemon._types[id]={0,0}
  data.gen3Pokemon._speciesMeta[id]=data.gen3Pokemon._speciesMeta[4]
  data.gen3Pokemon._abilities[id]={0,0}
  data.gen3Pokemon._learnsets[id]={{1,33}}
end
-- Extend the ROM-free fixture with names needed by this release. Production
-- uses the user's complete Emerald tables; fixture stats/moves are deliberately
-- small and generic and do not validate original ROM balance.
if world.trainers then
  local speciesNeeded,movesNeeded,itemsNeeded={},{},{}
  for _,table in pairs(world.encounters.tables) do
    for _,area in pairs(table) do for _,slot in ipairs(area.slots) do speciesNeeded[slot.species]=true end end
  end
  for _,trainer in pairs(world.trainers.records) do
    for _,item in ipairs(trainer.items) do itemsNeeded[item]=true end
    for _,mon in ipairs(trainer.party) do
      speciesNeeded[mon.species]=true
      if mon.heldItem then itemsNeeded[mon.heldItem]=true end
      for _,move in ipairs(mon.moves or {}) do movesNeeded[move]=true end
    end
  end
  for _,rows in pairs(world.scripts) do for _,row in ipairs(rows) do if row.speciesName then speciesNeeded[row.speciesName]=true end end end
  for name in pairs(speciesNeeded) do
    local id=C:require("species","SPECIES_"..name)
    if not data.gen3Pokemon._names[id] then
      data.gen3Pokemon._names[id]=name
      data.gen3Pokemon._stats[id]={hp=50,atk=50,def=50,spe=50,spa=50,spd=50}
      data.gen3Pokemon._types[id]={0,0}
      data.gen3Pokemon._speciesMeta[id]=data.gen3Pokemon._speciesMeta[4]
      data.gen3Pokemon._abilities[id]={0,0}
      data.gen3Pokemon._learnsets[id]={{1,33}}
    end
  end
  for name in pairs(movesNeeded) do
    local id=C:require("moves","MOVE_"..name)
    data.gen3Pokemon._moveNames[id]=name
    data.gen3Moves._rom[id]=data.gen3Moves._rom[id] or data.gen3Moves._rom[33]
  end
  for name in pairs(itemsNeeded) do
    local id=C:require("items","ITEM_"..name)
    data.gen3Items._byId[id]=data.gen3Items._byId[id] or {name=name,pocket="ITEMS",price=100}
  end
  data.gen3Trainers.money={[81]=4};data.gen3Trainers.moneyDefault=5
end
-- Live Game3 exposes the imported module as gen3Pokemon. The SDK instead
-- gives isolated content tables; bind those fixture fields for real Party API
-- calls without mocking Pokemon creation or modifying production data.
local Pokemon=require("src.core.game3.pokemon")
for key,value in pairs(data.gen3Pokemon) do Pokemon[key]=value end
Pokemon._national={}
for id in pairs(Pokemon._names) do Pokemon._national[id]=id end
Pokemon._battleMoves=data.gen3Moves._rom
-- Engine contexts require the imported ROM-name table. The SDK only supplies
-- display names, so provide the authoritative native constant names here.
Pokemon._romMoveNames={}
for name,id in pairs(C.moves.byName) do
  if name:sub(1,5)=='MOVE_' and id>0 and id<355 then Pokemon._romMoveNames[id]=name:sub(6):gsub('_',' ') end
end
local BattleMoves=require('src.core.game3.battle.moves')
BattleMoves._rom=data.gen3Moves._rom;BattleMoves._romLoaded=true
Pokemon._tmhm={}
Pokemon._byName={}
for id,name in pairs(Pokemon._names) do Pokemon._byName[name]=id end
local Runtime = require("src.mods.Runtime")
local Native = require("src.core.game3.tileset_native")
local Palette = require("src.core.game3.palette")
local Space = require("src.core.game3.scripting.space")
local Collision = require("src.core.game3.collision")
local Interactions = require("src.core.game3.scripting.interaction_scripts")
local Pack = require("src.import.gba.native_pack")
local Save = require("src.core.SaveData")
-- Dataset normally installs these surfability flags from the user's imported
-- Emerald pack before loading mods. The ROM-free SDK fixture has no such pack.
-- Both Emerald and HnS mark pond/ocean water and waterfalls as surfable.
local MB=require("src.core.game3.mb")
require("src.core.game3.scripting.collision_rse").setTileBits({
  [MB.require("POND_WATER")]=3,
  [MB.require("OCEAN_WATER")]=3,
  [MB.require("WATERFALL")]=2,
  [MB.require("TALL_GRASS")]=1,
  [MB.require("LONG_GRASS")]=1,
})
local fs = require("tests.fs_io").new(".")
-- The renderer was required against the original root above. Simulate the
-- cache being mounted later, as in a desktop process changing cache scope.
-- Older HnS overlays follow only this new spelling, so Native.ready() fails
-- even though direct reads through the new prefix decode correctly.
local CachePaths=require("src.core.game3.cache_paths")
if arg[2]~="default" then CachePaths.setRoot("emerald/data/generated/gba") end
-- The upstream SDK aliases paths beneath its root; split absolute paths so
-- both Windows rebuild instructions and repository-relative runs load files.
local loaderPath,sdkRoot=path,"."
if path:match("^/") or path:match("^%a:[/\\]") then
  sdkRoot,loaderPath=path:match("^(.*)[/\\]([^/\\]+)$")
end
local run = T.sdk.loadMod(loaderPath, {data=data, generation=3, dev=true,root=sdkRoot})
T.eq(run.mod and run.mod.state, "loaded", "mod actually executes on Emerald")
T.eq(#run.errors, 0, "real loader errors")
for _, e in ipairs(run.errors) do print(tostring(e)) end
local maps, n = {}, 0
for id, def in pairs(data.maps) do
  if id:sub(1,7) == "EM_HNS_" then maps[id]=def; n=n+1 end
end
T.eq(n,world.scope=="all" and 564 or world.scope=="opening" and 36 or 16,"complete selected world merged")
T.eq(data.maps.FR_OAKS_LAB.name,"OAKS LAB","vanilla fixture map unaffected")
local nativeBase = {
  read=function(_,rel) if rel=="vanilla" then return "unchanged" end end,
  exists=function(_,rel) return rel=="vanilla" end,
  write=function() return true end,
}
Native._cache=nativeBase
Space.bundle={events={},text=data.gen3Text,scripts=data.gen3Scripts}
local activeMap="EM_INSIDE_OF_TRUCK"
local activeSave
local savedOriginals={}
for _,key in ipairs({"load","createSlot","setActiveSlot","renameSlot"}) do savedOriginals[key]=Save[key] end
local created, selected, named, handled = 0,nil,nil,nil
Save.load=function() return activeSave or {engine="game3",map=activeMap,version="emerald"} end
Save.createSlot=function(version) T.eq(version,"emerald","slot version");created=created+1;return "slot99" end
Save.setActiveSlot=function(version,id) selected=id;return id end
Save.renameSlot=function(version,id,name) named=name;return true end
local game={data=data,boot={},_handleBootAction=function(self,action) handled=action end}
-- Rows.build constructs its cartridge descriptors before we exclude those
-- six rows. Supply their imported-ROM labels in the otherwise ROM-free SDK.
local optionText=require('src.core.game3.rom_text');local optionIR=require('src.core.game3.scripting.text_ir')
for i,label in ipairs({'TEXT SPEED','BATTLE SCENE','BATTLE STYLE','SOUND','BUTTON MODE','FRAME'})do
  optionText.overrides['sOptionMenuItemsNames['..(i-1)..']']=optionIR.fromAscii(label)
end
run.loader.game=game
Runtime.emit("game.ready",{game=game})
T.eq(#run.errors,0,"game.ready installs without errors")
T.check(game._hnsExploration~=nil,"native integration installed")
if world.bootPresentation then
  T.eq(game._hnsBoot.versionText,'v2.0.6 · Port v'..run.mod.manifest.version,'title uses the installed mod manifest version')
end
if arg[3]=='expansion' then
  require('src.core.game3.items_data').installPack({items=data.gen3Items._byId})
  dofile((arg[0]:match('^(.*)[/\\]')or'.')..'/test_expansion.lua')(T,game,world,maps)
  run:release();T.finish('HnS expansion');return
end
T.eq(game.boot.hasContinue,false,"vanilla save is not offered as HnS Continue")
T.eq(Native._cache:read("vanilla"),"unchanged","vanilla cache read preserved")
local Extract=require("src.import.gba.extract_island1")
local root=(Extract.NATIVE_ROOT or "native").."/"
local pairsSeen={}
for id,def in pairs(maps) do
  local layout=def.midLayout
  T.check(layout~=nil,id.." bound native layout")
  if layout then
    T.eq(#layout.cells,def.width*def.height,id.." layout cell count")
    T.eq(layout:collAt(-1,-1),255,id.." border stays blocked")
    T.check(type(layout.midAt)=="function",id.." real native layout methods")
    for _,warp in ipairs(def.warps) do
      if warp.mapNum==127 then
        T.eq(warp.destMap,nil,id.." dynamic exits use the engine's session return")
      else
        T.check(maps[warp.destMap]~=nil,id.." warp destination exists")
        T.check(warp.destX~=nil and warp.destY~=nil,id.." explicit warp arrival")
        local destination=maps[warp.destMap]
        T.check(destination and warp.destX>=0 and warp.destY>=0 and warp.destX<destination.width and warp.destY<destination.height,id.." arrival inside destination")
      end
      T.eq(warp.destWarp,0,id.." sliced warp does not accidentally target first warp")
    end
    for _,conn in ipairs(def.connections) do
      T.check(maps[conn.map]~=nil,id.." connection destination exists")
    end
    for _,sign in ipairs(def.bgEvents) do
      T.check(Space.bundle.scripts[sign.scriptKey]~=nil,id.." sign code registered")
    end
  end
  if not pairsSeen[def.pair] then
    pairsSeen[def.pair]=true
    T.check(Native.ready(def.pair),"actual renderer readiness survives mounted-root change")
    T.check(Native._cache:exists(root..def.pair.."/mids.idx"),"native overlay exists")
    local idx=Pack.decodeIdx(Native._cache:read(root..def.pair.."/mids.idx"))
    local over=Pack.decodeIdx(Native._cache:read(root..def.pair.."/mids_over.idx"))
    local middle=Pack.decodeIdx(Native._cache:read(root..def.pair.."/mids_mid.idx"))
    local palBlob=Native._cache:read(root..def.pair.."/palettes.bin")
    local pals=Pack.decodePalettes(palBlob)
    T.check(idx and over and middle and pals,"engine decodes source-converted layered atlas and palette")
    -- Reproduce the real draw-path assertion from Elm's lab. The binary
    -- decoder accepts nonblack backdrop colors; the renderer loader does not.
    local ok,rgb,bgr=pcall(Palette.load,palBlob)
    T.check(ok and rgb and bgr,"renderer palette loader accepts "..def.pair)
    if ok and rgb and bgr then
      T.eq(bgr[0][0],0,"native backdrop is black for "..def.pair)
      for index,layer in ipairs({idx,over,middle}) do
        local rgba,w,h=Pack.bakeRgba(layer,rgb,{transparentZero=index>1})
        T.eq(#rgba,w*h*4,"renderer bakes native RGBA layer "..index.." for "..def.pair)
      end
    end
    if idx then
      T.eq(idx.midCount,#idx.midIds,"native metatile ID count")
      T.eq(#idx.pixels,idx.midCount*256,"native pixel table length")
      for _,mid in ipairs(idx.midIds) do T.check(Interactions.behaviors[def.pair][mid]~=nil,"behavior mapped") end
    end
  end
end
-- Reproduce the reported tree-border regressions with the same native sampler
-- the renderer uses. Merely registering an adjacent map does not prove it is
-- connected or sampled with the source offset.
local Map=require("src.core.game3.map")
if world.quest then
  local cherry=maps.EM_HNS_CHERRYGROVE_CITY_HNS
  local mr=maps.EM_HNS_ROUTE30_MR_POKEMONS_HOUSE_HNS
  Space.attachEventsToMaps({[cherry.id]=cherry,[mr.id]=mr},Space.bundle)
  T.eq(#cherry.coordEvents,world.startup.guideStateVar and 6 or 3,"map-entry reattachment preserves Silver and guide triggers")
  T.eq(cherry.mapScripts.onTransition,world.startup.guideStateVar and 'HNS_POLISH_CITY_INIT' or 'HNS_QUEST_RIVAL_INIT',"map-entry reattachment preserves city visibility setup")
  T.eq(mr.mapScripts.onTransition,world.quest.nameNative and "HNS_SCENE_MR_INIT" or "HNS_QUEST_MR_INIT","map-entry reattachment preserves Mr Pokemon's visibility setup")
  local testDir=arg[0]:match("^(.*)[/\\]") or "."
  dofile(testDir.."/test_startup_render.lua")(T,game,maps,world)
end
local function checkSeam(sourceId,destId,dir,offset)
  local source,dest=maps[sourceId],maps[destId]
  T.check(source and dest,"both sides of reported boundary exist")
  if not (source and dest and source.midLayout and dest.midLayout) then return end
  Map.world={}
  local neighbors=Map.loadNeighborsDepth1(game,source)
  local neighbor=neighbors[dir]
  T.eq(neighbor and neighbor.map,destId,"reported boundary connects to its source neighbor")
  T.eq(neighbor and neighbor.offset,offset,"source connection offset preserved")
  local sampled,water,walkable=0,0,0
  local span=dir=="north" and source.width or source.height
  for along=0,span-1 do
    for depth=1,8 do
      local x,y,lx,ly
      if dir=="north" then
        x,y,lx,ly=along,-depth,along-offset,dest.height-depth
      else
        x,y,lx,ly=source.width+depth-1,along,depth-1,along-offset
      end
      if lx>=0 and ly>=0 and lx<dest.width and ly<dest.height then
        local mid,pair,border=Map.worldMidAt(x,y,source)
        T.eq(mid,dest.midLayout:midAt(lx,ly),"edge samples original adjacent terrain")
        T.eq(pair,dest.pair,"edge samples the adjacent tileset")
        T.check(not border,"connected edge does not fall back to repeating tree border")
        sampled=sampled+1
        if Collision.isWaterOn(dest,lx,ly) then water=water+1 end
        if depth==1 and dest.midLayout:collAt(lx,ly)==0 then
          local sx,sy=dir=="north" and along or source.width-1,dir=="north" and 0 or along
          local px,py=Collision.connectionLanding(dest,neighbor,dir=="north" and "up" or "right",sx,sy)
          T.eq(px,lx,"boundary crossing lands at sampled x")
          T.eq(py,ly,"boundary crossing lands at sampled y")
          if source.midLayout:collAt(sx,sy)==0 then walkable=walkable+1 end
        end
      end
    end
  end
  T.check(sampled>0,"reported seam has sampled terrain")
  if dir=="north" then T.check(walkable>0,"Route 31 has walkable arrival cells")
  else T.check(water>0,"New Bark east seam preserves water") end
end
checkSeam("EM_HNS_ROUTE30_HNS","EM_HNS_ROUTE31_HNS","north",-10)
checkSeam("EM_HNS_NEW_BARK_TOWN_HNS","EM_HNS_ROUTE27_HNS","east",-11)
local town=maps.EM_HNS_NEW_BARK_TOWN_HNS
if town and town.midLayout then
  T.eq(town.midLayout:collAt(20,12),0,"New Bark start cell is walkable")
  T.check(town.midLayout:collAt(0,0)~=0,"tree boundary is blocked")
  T.eq(town.width,30,"HnS town width preserved")
  T.eq(town.height,39,"HnS town height preserved")
  Collision.bindMap(game,town.id,town)
  local warped=Collision.warpAt(20,11)
  T.eq(warped and warped.destMap,"EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_1F_HNS","player house doorway")
end
-- Execute every authored sign through the real VM, including text decoding,
-- lock/release and the A/B wait. A registered-but-inert sign must fail here.
local Vm=require("src.core.game3.scripting.vm")
local Adapters=require("src.core.game3.scripting.adapters")
local signs=0
for _,def in pairs(maps) do
  for _,sign in ipairs(def.bgEvents) do
    if sign.scriptKey:sub(1,14)=="HNS_PORT_SIGN_" then
    signs=signs+1
    local adapter=Adapters.stub({playerName="GENE"})
    local vm=Vm.new({scripts=data.gen3Scripts,text=data.gen3Text,adapters=adapter})
    T.check(vm:start(sign.scriptKey),"sign starts in real script VM")
    for _=1,12 do if vm:isRunning() then vm:resume() end end
    T.check(not vm:isRunning(),"sign completes without stalling")
    T.check(type(adapter.lastMessage)=="string" and adapter.lastMessage~="(missing text)","original sign text is displayed")
    T.eq(adapter.boxOpen(),false,"sign closes its message")
    T.eq(vm.ctx.frozen,false,"sign releases player lock")
    T.eq(#adapter.logs,0,"sign has no unimplemented opcode log")
    end
  end
end
T.eq(signs,world.scope=="all" and 505 or world.scope=="opening" and 50 or 33,"all original simple signs executed")
-- Native NPC sheets must retain the source frame order and stay outside the
-- vanilla sprite-ID resolver's clamp. Exercise actual object spawning too.
local Ow=require("src.core.game3.ow_sprites")
local OwExtract=require("src.import.gba.ow_extract")
local owRoot=(Extract.CACHE_ROOT or "data/generated/gba").."/ow/"
local sheets=0
for id,info in pairs(world.opening.sprites) do
  sheets=sheets+1
  local meta=OwExtract.decodeMeta(Ow._cache:read(owRoot..id..".meta"))
  local rgba=Ow._cache:read(owRoot..id..".rgba")
  T.eq(meta and meta.graphicsId,tonumber(id),"own NPC sheet ID decodes")
  T.eq(meta and meta.frameCount,info.frameCount,"source NPC frame order retained")
  T.eq(#rgba,info.width*info.height*info.frameCount*4,"native NPC RGBA dimensions")
end
T.eq(sheets,world.scope=="all" and (world.worldEvents.spriteCount or 55) or sheets,"all source NPC sheets converted")
local Flags=require("src.core.game3.scripting.flags")
local Party=require("src.core.game3.party")
local G3Runtime=require("src.core.game3.runtime")
local oldSession=G3Runtime.session
local encounterSession
local function runScript(scriptKey,session,store,answer,giveCode)
  G3Runtime.session=session
  local messages={}
  local adapter=Adapters.stub({playerName="GENE",askYesNo=function(done) done(answer~=false) end,
    onMessage=function(text) messages[#messages+1]=text end,
    nurseHeal=function(done) Party.healAll(session.party);done() end})
  adapter.doFieldEffect=require('src.core.game3.field_effects').doFieldEffect
  adapter.waitFieldEffect=require('src.core.game3.field_effects').waitFieldEffect
  adapter.giveMonToPlayer=function(species,level)
    if giveCode~=nil then return giveCode end
    return Party.giveMonToPlayer(session,species,level)
  end
  local vm=Vm.new({scripts=data.gen3Scripts,text=data.gen3Text,store=store,adapters=adapter})
  local name=scriptKey
  T.check(vm:start(scriptKey),"script starts: "..name)
  for _=1,1800 do
    require('src.core.game3.audio').update(1/60)
    require('src.core.game3.pokecenter_heal').step()
    if vm:isRunning() then vm:resume() else break end
  end
  T.check(not vm:isRunning(),"opening script finishes: "..name)
  T.eq(vm.ctx.frozen,false,"opening releases the player: "..name)
  T.eq(adapter.boxOpen(),false,"opening closes its message: "..name)
  T.eq(#adapter.logs,0,"opening has no skipped opcode: "..name)
  for _,message in ipairs(messages) do T.check(message~="(missing text)","opening dialogue resolves: "..name) end
  adapter.messages=messages
  G3Runtime.session=oldSession
  return adapter
end
local function openingScript(name,...) return runScript("HNS_OPENING_"..name,...) end
local Objects=require("src.core.game3.objects")
Space.store=Flags.newStore()
local importedObjects=0
for id,def in pairs(maps) do
  if #def.objects>0 then
    Objects.loadMap(game,id,def)
    T.eq(#Objects._order,#def.objects,"every imported object actually spawns on "..id)
    for _,template in ipairs(def.objects) do
      T.eq(Space.resolveObjectGraphicsId(template,false),template.hnsGraphicsId,"world NPC bypasses vanilla graphics clamp")
      if template.hnsMovementType then
        T.eq(template.movementType,C:require("movement",template.hnsMovementAlias or template.hnsMovementType),"source movement resolves to native Emerald ID")
        if template.hnsMovementType:find("_WANDER_") or template.hnsMovementType:find("_WALK_") or template.hnsMovementType:find("_JOG_") or template.hnsMovementType:find("_RUN_") then
          T.check(world.opening.sprites[tostring(template.hnsGraphicsId)].frameCount>=9,"every moving NPC has directional walking frames")
        end
      end
    end
    importedObjects=importedObjects+#Objects._order
  end
end
if world.scope=="all" then T.eq(importedObjects,(world.startup and world.startup.extraObjectCount or 0)+world.opening.npcCount+world.worldEvents.dialogueNpcCount+#world.worldEvents.nurses+(world.worldEvents.specialResidentCount or (world.worldEvents.additionalResidents and 1 or 0))+#(world.worldEvents.marts and world.worldEvents.marts.clerks or {})+#(world.trainers and world.trainers.events or {})+#(world.quest and world.quest.objects or {})+#(world.campaign and world.campaign.objects or {})+#(world.fieldPokemon and world.fieldPokemon.objects or {})+#(world.services and world.services.objects or {}),"all imported NPCs, trainers, clerks, Pokémon and starter objects spawn") end
local lab=maps.EM_HNS_NEW_BARK_TOWN_LAB_HNS
Objects.loadMap(game,lab.id,lab)
T.eq(#Objects._order,world.quest.nameNative and 7 or 6,"Elm lab source objects spawn")
T.eq(Objects.find(2).graphicsId,lab.objects[2].hnsGraphicsId,"Elm uses own HnS sheet, not clamped vanilla NPC")
T.eq(Objects.find(2).def.scriptKey,"HNS_OPENING_ELM","Elm talk script is attached to spawned object")
local house=maps.EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_1F_HNS
Objects.loadMap(game,house.id,house)
T.eq(#Objects._order,2,"Mom and her friend spawn in the source house")
for _,name in ipairs({"AIDE1","AIDE2","FRIEND","HEAL"}) do
  openingScript(name,{version="emerald",party={},playerName="GENE"},Flags.newStore(),true)
end
for index,name in ipairs({"CHIKORITA","CYNDAQUIL","TOTODILE"}) do
  local session={version="emerald",party={},playerName="GENE",flags={},vars={}}
  local store=Flags.newStore()
  openingScript(name,session,store,true)
  T.eq(#session.party,0,"cannot take a starter before Elm's introduction")
  openingScript("MOM",session,store,true)
  openingScript("ELM",session,store,false)
  T.eq(Flags.getFlag(store,nil,world.opening.flags.elmReady),false,"refusing Elm does not unlock the balls")
  openingScript("ELM",session,store,true)
  T.eq(Flags.getFlag(store,nil,world.opening.flags.elmReady),true,"accepting Elm unlocks the balls")
  openingScript(name,session,store,false)
  T.eq(#session.party,0,"declining the ball grants no Pokemon")
  openingScript(name,session,store,true,2)
  T.eq(Flags.getFlag(store,nil,world.opening.flags.received),false,"failed gift does not mark starter received")
  local gift=openingScript(name,session,store,true)
  T.eq(#session.party,1,"starter gift creates exactly one party member")
  T.check(table.concat(gift.messages,"\n"):find("GENE received "..name.."!",1,true)~=nil,"starter name and player expand in received dialogue")
  local mon=session.party[1]
  T.eq(mon and mon.species,C.species.byName["SPECIES_"..name],"starter mapped by name to engine species")
  T.eq(mon and mon.level,5,"starter is level five")
  T.check(mon and mon.hp>0 and #mon.moves>0,"starter has engine-calculated HP and legal moves")
  T.eq(Flags.getFlag(store,nil,C.flags.byName.FLAG_SYS_POKEMON_GET),true,"native party menu is unlocked")
  openingScript("ELM",session,store,true)
  openingScript("MOM",session,store,true)
  Space.store=store
  G3Runtime.session=session
  Space.persistSession(nil,game)
  G3Runtime.session=oldSession
  T.eq(session.flags[tostring(world.opening.flags.received)],true,"real session persistence includes starter flag")
  T.eq(session.vars[tostring(world.opening.vars.species)],mon.species,"real session persistence includes chosen species")
  local snapshot={flags=session.flags,vars=session.vars}
  local restored=Flags.loadInto(Flags.newStore(),snapshot)
  openingScript(name,session,restored,true)
  openingScript(({"CHIKORITA","CYNDAQUIL","TOTODILE"})[index%3+1],session,restored,true)
  T.eq(#session.party,1,"save/continue and other balls cannot duplicate the starter")
  Space.store=restored
  Objects.loadMap(game,lab.id,lab)
  T.eq(Objects.find(index+3).visible,false,"chosen ball remains hidden after restoring save flags")
  mon.hp=1;mon.currentHp=1
  openingScript("HEAL",session,restored,true)
  T.eq(mon.hp,mon.maxHp,"lab healing restores the starter")
  encounterSession=session
end
local Encounters=require("src.core.game3.encounters")
local route29=Encounters.tableFor("EM_HNS_ROUTE29_HNS")
T.eq(route29 and route29.land.rate,20,"source Route 29 encounter rate")
T.eq(route29 and #route29.land.slots,12,"source Route 29 slot weights retained")
for i,slot in ipairs(route29.land.slots) do
  T.check(type(slot.species)=="number" and data.gen3Pokemon._names[slot.species]~=nil,"encounter resolves to an engine species")
  T.check(slot.minLevel>=2 and slot.maxLevel<=3,"opening encounters preserve source levels")
end
-- Follow the actual Emerald step-roll path on source-converted walkable
-- Route 29 grass. Table registration alone would miss terrain/gating errors.
local route=maps.EM_HNS_ROUTE29_HNS
Collision.bindMap(game,route.id,route)
local grass
for y=0,route.height-1 do
  for x=0,route.width-1 do
    if Collision.isWalkable(x,y) and Collision.behavior(x,y)==MB.require("TALL_GRASS") then grass={x=x,y=y};break end
  end
  if grass then break end
end
T.check(grass~=nil,"Route 29 has source walkable encounter grass")
local Rng=require("src.core.game3.rng")
Rng.SeedRng(0x1234);Rng.SeedWildEncounterRng(0x1234)
G3Runtime.session={version="emerald",party={}}
local before=Rng.getState()
local emptyEncounter
for _=1,2000 do
  if grass then emptyEncounter=Encounters.onStep(route.id,nil,grass) end
  if emptyEncounter then break end
end
T.eq(emptyEncounter,nil,"old exploration save cannot roll an empty-party battle")
T.eq(Rng.getState().wild,before.wild,"empty-party gate consumes no encounter RNG")
G3Runtime.session=encounterSession
encounterSession.map=route.id
Encounters.resetRateModifiers()
local encounter
for _=1,2000 do
  if grass then encounter=Encounters.onStep(route.id,nil,grass) end
  if encounter then break end
end
T.check(encounter~=nil,"real Emerald step rolls produce an encounter on Route 29")
if encounter then
  local allowed={}
  for _,slot in ipairs(route29.land.slots) do allowed[slot.species]=true end
  T.check(allowed[encounter.species],"step-roll species belongs to the HnS table")
  T.check(encounter.level>=2 and encounter.level<=3,"step-roll level preserves the HnS table")
end
G3Runtime.session=oldSession
-- Safe dialogue events execute to completion without borrowing source flags
-- or silently skipping unknown commands. Center acceptance actually heals;
-- refusal leaves HP, status and move PP untouched.
local worldEvents=world.worldEvents
if worldEvents then
  local dialogNpcs=0
  for _,key in ipairs(worldEvents.dialogueScripts) do
    local adapter=runScript(key,{version="emerald",party={}},Flags.newStore())
    local expected=0
    for _,row in ipairs(data.gen3Scripts[key]) do if row.op=="message" then expected=expected+1 end end
    T.eq(#adapter.messages,expected,"ordinary NPC displays each source message")
    dialogNpcs=dialogNpcs+1
  end
  if world.scope=="all" then
    T.eq(dialogNpcs,worldEvents.dialogueNpcCount,"all reviewed ordinary NPC scripts execute")
    T.eq(#worldEvents.nurses,28,"all reviewed basic healing nurses installed")
  end
  local mon=encounterSession.party[1]
  mon.hp=1;mon.status="poison";mon.sleep=3;mon.pp[1]=0
  runScript("HNS_WORLD_NURSE",encounterSession,Flags.newStore(),false)
  T.eq(mon.hp,1,"declining Center keeps HP unchanged")
  T.eq(mon.status,"poison","declining Center keeps status unchanged")
  T.eq(mon.pp[1],0,"declining Center keeps PP unchanged")
  runScript("HNS_WORLD_NURSE",encounterSession,Flags.newStore(),true)
  T.eq(mon.hp,mon.maxHp,"accepting Center restores HP")
  T.eq(mon.status,nil,"accepting Center clears status")
  T.eq(mon.sleep,nil,"accepting Center clears sleep")
  T.check(mon.pp[1]>0,"accepting Center restores move PP")
  if worldEvents.marts and world.scope=="all" then
    local testDir=arg[0]:match("^(.*)[/\\]") or "."
    dofile(testDir.."/test_npc_services.lua")(T,game,world,maps,encounterSession,runScript)
    if world.quest then dofile(testDir.."/test_progress.lua")(T,game,world,maps) end
    if world.quest and world.quest.nameNative then dofile(testDir.."/test_scenes.lua")(T,game,world,maps) end
    if world.pokedex then dofile(testDir.."/test_pokedex.lua")(T,game,world,maps) end
    if world.campaign then dofile(testDir.."/test_campaign.lua")(T,game,world,maps) end
    if world.audio then dofile(testDir.."/test_audio.lua")(T,game,world,maps,testDir) end
    if world.startup then dofile(testDir.."/test_startup.lua")(T,game,world,maps) end
    if world.presentation then dofile(testDir.."/test_field_presentation.lua")(T,game,world,maps) end
    if world.startup and world.startup.guideStateVar then dofile(testDir.."/test_polish.lua")(T,game,world,maps) end
  end
  local checkpointCount=0
  for center,target in pairs(worldEvents.healCheckpoints) do
    G3Runtime.session={version="emerald",party={}}
    Runtime.emit("map.entered",{mapId=center})
    T.eq(G3Runtime.session.healMap,target.map,"Center entry stores source whiteout map")
    T.eq(G3Runtime.session.healX,target.x,"Center entry stores source whiteout x")
    T.eq(G3Runtime.session.healY,target.y,"Center entry stores source whiteout y")
    local def=maps[target.map]
    T.check(def and def.midLayout:collAt(target.x,target.y)==0,"source whiteout arrival is walkable")
    checkpointCount=checkpointCount+1
  end
  if world.scope=="all" then T.eq(checkpointCount,19,"all source-backed Center checkpoints installed") end
  G3Runtime.session=oldSession
end
-- Use the engine's actual dynamic-return resolver, intercepting only the
-- final visual transition. Both exit cells must return to the entered door.
local Warp=require("src.core.game3.warp")
local savedRequest=Warp.request
local savedTeleport,savedFall=Warp.startTeleport,Warp.startFall
local dynamicExits=0
local dormantDynamic=0
for id,def in pairs(maps) do
  for _,exit in ipairs(def.warps) do
    if exit.mapNum==127 then
      G3Runtime.session={version="emerald",party={}}
      game.currentMap=town.id;Collision.bindMap(game,town.id,town)
      T.eq(Collision.noteDynamicWarpEntry(game,id,exit.x,exit.y,20,11),true,"dynamic room records entrance")
      T.eq(G3Runtime.session.dynamicWarp.map,town.id,"dynamic room stores source map")
      game.currentMap=id;Collision.bindMap(game,id,def)
      if not Collision.warpAt(exit.x,exit.y) then
        -- Two HnS placeholder-room cells and the shared Union Room's right
        -- exit retain NORMAL source behavior; header rows alone are inert.
        T.eq(Collision.behavior(exit.x,exit.y),MB.require("NORMAL"),"source dormant dynamic cell stays ordinary terrain")
        dormantDynamic=dormantDynamic+1
      else
      local arrival
      local capture=function(_,_,dest,x,y) arrival={map=dest,x=x,y=y};return true end
      Warp.request=capture;Warp.startTeleport=capture;Warp.startFall=capture
      T.eq(Collision.tryWarpAt(game,exit.x,exit.y,"down",{arrow=true}),true,"native dynamic resolver triggers return: "..id)
      T.eq(arrival and arrival.map,town.id,"dynamic exit returns to entered map")
      T.eq(arrival and arrival.x,20,"dynamic exit preserves entrance x")
      T.eq(arrival and arrival.y,11,"dynamic exit preserves entrance y")
      dynamicExits=dynamicExits+1
      end
    end
  end
end
Warp.request=savedRequest;Warp.startTeleport=savedTeleport;Warp.startFall=savedFall;G3Runtime.session=oldSession
if world.scope=="all" then
  T.eq(dynamicExits,8,"all active source dynamic exits round-trip")
  T.eq(dormantDynamic,3,"three source dormant dynamic headers remain inert")
end
local originalBoot=game._hnsExploration.originalBootAction
Runtime.emit("game.ready",{game=game})
T.eq(game._hnsExploration.originalBootAction,originalBoot,"repeated ready preserves the original boot handler")
T.eq(game._hnsExploration.baseCache,nativeBase,"repeated ready avoids stacking atlas overlays")
local input={action="new_game",name="GENE",fieldCallback="truck"}
game:_handleBootAction(input)
T.eq(created,1,"new game allocates a new slot")
T.eq(selected,"slot99","new slot activated")
T.eq(named,"HnS exploration","new slot labelled")
T.eq(handled and handled.start and handled.start.map,world.startup and world.startup.start.map or "EM_HNS_NEW_BARK_TOWN_HNS","new game enters intended starting map")
T.eq(handled and handled.fieldCallback,nil,"truck callback removed")
T.eq(input.fieldCallback,"truck","incoming engine action is not mutated")
handled=nil
game:_handleBootAction({action="continue"})
T.eq(handled,nil,"vanilla Continue prevented")
activeMap="EM_HNS_ROUTE29_HNS"
activeSave={engine='game3',version='emerald',map=activeMap,name='GENE',dex=require('src.core.game3.dex').new(),flags={[C:flag('FLAG_BADGE01_GET')]=true}}
for _,sp in ipairs({158,69,161,16,19})do require('src.core.game3.dex').setCaught(activeSave.dex,sp)end
game.boot.continueInfo={dexCount=1,badges=1}
game:_handleBootAction({action="continue"})
T.eq(handled and handled.action,"continue","HnS Continue allowed")
-- A real imported Emerald manifest supplies player avatar states and vanilla
-- sheets. Extending it must survive install/invalidate without replacing
-- those rows or changing delegated byte reads.
local LuaWriter=require("src.import.LuaWriter")
local vanillaSprites={ow_version=1,count=1,total=1,
  sprites={[0]={width=16,height=32,frameCount=9,atlasW=16,atlasH=288}},
  avatars={player={{state="NORMAL",male=0,female=89},{state="SURFING",male=2,female=92}}}}
local vanillaOw={}
function vanillaOw:read(rel)
  if rel:match("/ow/manifest%.lua$") then return LuaWriter.encode(vanillaSprites) end
  if rel:match("/ow/0%.rgba$") then return "vanilla sprite bytes" end
end
function vanillaOw:exists(rel) return self:read(rel)~=nil end
function vanillaOw:write() return true end
game._hnsOpening.baseCache=vanillaOw
Runtime.emit("game.ready",{game=game})
T.eq(game.boot.continueInfo.dexCount,5,"install refreshes pre-mod boot summary for an older HnS save")
T.eq(game.boot.continueInfo.badges,1,"boot refresh preserves earned badge summary")
for cycle=1,2 do
  Ow.invalidate()
  T.check(Ow.ready(),"merged sprite manifest survives reset with vanilla cache "..cycle)
  local avatars=Ow.avatars()
  T.eq(Ow.avatarGraphicsId("NORMAL",false,avatars),0,"merged manifest preserves Brendan")
  T.eq(Ow.avatarGraphicsId("SURFING",true,avatars),92,"merged manifest preserves May's surf state")
  T.eq(Ow._cache:read(owRoot.."0.rgba"),"vanilla sprite bytes","unowned sprite data delegates unchanged")
  T.check(Ow._manifest.sprites[0]~=nil,"merged manifest preserves vanilla sheet row")
  T.eq(Ow._manifest.count,sheets+1,"merged manifest counts both vanilla and HnS sheets once")
  for id in pairs(world.opening.sprites) do
    T.check(Ow._manifest.sprites[tonumber(id)]~=nil,"reloaded manifest includes HnS sheet "..id)
  end
end
for key,value in pairs(savedOriginals) do Save[key]=value end
dofile((arg[0]:match('^(.*)[/\\]') or '.')..'/test_fidelity.lua')(T,game,world,maps)
dofile((arg[0]:match('^(.*)[/\\]') or '.')..'/test_gameplay.lua')(T,game,world,maps)
dofile((arg[0]:match('^(.*)[/\\]') or '.')..'/test_battle_presentation.lua')(T,game,world)
dofile((arg[0]:match('^(.*)[/\\]') or '.')..'/test_collection_screens.lua')(T,game,world)
dofile((arg[0]:match('^(.*)[/\\]') or '.')..'/test_tile_animation.lua')(T,game,world)
dofile((arg[0]:match('^(.*)[/\\]') or '.')..'/test_field_services.lua')(T,game,world,maps)
dofile((arg[0]:match('^(.*)[/\\]') or '.')..'/test_engine_options.lua')(T,game,world)
if world.battleVisuals then dofile((arg[0]:match('^(.*)[/\\]')or'.')..'/test_expansion.lua')(T,game,world,maps)end
run.release()
T.finish("HnS native exploration integration")
