-- Regress the user-visible paths: A across desks, autonomous movement and
-- native shop transactions. Run inside test_native.lua's real engine fixture.
return function(T,game,world,maps,session,runScript)
  local Field=require("src.core.game3.field")
  local Player=require("src.core.game3.player")
  local Objects=require("src.core.game3.objects")
  local Collision=require("src.core.game3.collision")
  local Permissions=require("src.core.CollPermissions")
  local Std=require("src.core.game3.scripting.collision_std")
  local Space=require("src.core.game3.scripting.space")
  local Rt=require("src.core.game3.runtime")
  local Flags=require("src.core.game3.scripting.flags")
  local Marts=require("src.core.game3.marts")
  local saved={}
  local function preserve(t,keys)
    for _,k in ipairs(keys) do saved[#saved+1]={t=t,k=k,v=t[k]} end
  end
  preserve(Field,{"running","locked","_session","_game"})
  preserve(Space,{"active","startScript","vm","store"})
  preserve(Player,{"cellX","cellY","px","py","facing","moving","boulderPush","elevation","currentElevation"})
  preserve(game,{"currentMap"});preserve(Rt,{"session"})
  Field.running=true;Field.locked=false;Field._session=session;Field._game=game
  Space.active=true;Space.vm=nil;Space.store=Flags.newStore()
  Rt.session=session;Player.moving=false;Player.boulderPush=false
  local directions={{0,1,"up"},{0,-1,"down"},{1,0,"left"},{-1,0,"right"}}
  local targetedNurses,targetedClerks=0,0
  local function talkAcross(entry,nurse)
    local def=maps[entry.map]
    game.currentMap=entry.map;session.map=entry.map
    Collision.bindMap(game,entry.map,def);Objects.loadMap(game,entry.map,def)
    local eo=Objects.find(entry.localId)
    T.check(eo~=nil,"service NPC actually spawns")
    for _,d in ipairs(directions) do
      local cx,cy=eo.cellX+d[1],eo.cellY+d[2]
      local px,py=eo.cellX+2*d[1],eo.cellY+2*d[2]
      if Std.isCounter(Collision.cell(cx,cy)) and Collision.isWalkable(px,py) then
        T.check(Permissions.isWall(Collision.cell(cx,cy)),"counter remains a physical wall")
        Player.cellX,Player.cellY=px,py;Player.px,Player.py=px*16,py*16
        Player.facing=d[3];Player.currentElevation=def.midLayout:elevAt(px,py)
        Player.elevation=Player.currentElevation
        T.check(not Collision.canEnter(game,cx,cy,{fromX=px,fromY=py,dir=d[3],elevation=Player.currentElevation}),"player cannot walk through service desk")
        local captured
        Space.startScript=function(key,lid) captured={key=key,lid=lid};return true end
        T.eq(Field.interact(game),true,"actual A interaction reaches NPC across desk: "..entry.map)
        T.eq(captured and captured.key,eo.def.scriptKey,"counter targets the service script")
        T.eq(captured and captured.lid,entry.localId,"counter targets the correct object")
        T.eq(eo.frozen,true,"talk freezes service NPC")
        if nurse and captured then
          local mon=session.party[1];mon.hp=1;mon.status="poison";mon.pp[1]=0
          runScript(captured.key,session,Flags.newStore(),true)
          T.eq(mon.hp,mon.maxHp,"A-selected nurse restores HP")
          T.eq(mon.status,nil,"A-selected nurse clears status")
          T.check(mon.pp[1]>0,"A-selected nurse restores PP")
        end
        Objects.unfreeze(entry.localId)
        return true
      end
    end
    return false
  end
  for _,n in ipairs(world.worldEvents.nurses) do if talkAcross(n,true) then targetedNurses=targetedNurses+1 end end
  T.check(targetedNurses>=20,"healing desks across the world use real counter interactions")
  for _,c in ipairs(world.worldEvents.marts.clerks) do if talkAcross(c,false) then targetedClerks=targetedClerks+1 end end
  T.eq(targetedClerks,#world.worldEvents.marts.clerks,"every imported mart clerk is reachable across a desk")
  if world.scope=="all" then T.eq(targetedClerks,22,"all supported money-mart clerks installed") end

  -- The native VM must wait for the shop and then finish/unlock on close.
  local Vm=require("src.core.game3.scripting.vm")
  local Adapters=require("src.core.game3.scripting.adapters")
  local potion=require("src.core.game3.constants").of("emerald"):require("items","ITEM_POTION")
  local openingStock
  for key,stock in pairs(world.worldEvents.marts.stocks) do
    local items=Marts.itemsFor(key)
    T.eq(#items,#stock.items,"native mart registry retains every source stock item")
    local closed,seen
    local adapter=Adapters.stub()
    adapter.openShop=function(ptr,done) seen=ptr;closed=done end
    local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,adapters=adapter})
    T.check(vm:start(key),"clerk script starts")
    for _=1,30 do if not closed then vm:resume() end end
    T.eq(seen,key,"clerk opens its namespaced inventory")
    T.check(vm:isRunning() and closed~=nil,"clerk waits while native shop is open")
    if closed then closed() end
    for _=1,30 do if vm:isRunning() then vm:resume() end end
    T.check(not vm:isRunning(),"closing shop resumes and ends clerk script")
    T.eq(vm.ctx.frozen,false,"shop close releases player lock")
    T.eq(#adapter.logs,0,"mart has no skipped script commands")
    if stock.sourceScript=="Cherrygrove_Pokemart_EventScript_Clerk" then
      T.eq(#items,2,"Cherrygrove retains its pre-quest stock")
      T.eq(items[1],potion,"early Cherrygrove sells native Potion")
      openingStock=items
    end
  end
  -- Use the actual Emerald shop input handler and bag API. Only the ROM's
  -- item metadata is supplied by the same small fixture as the SDK.
  local Items=require("src.core.game3.items_data")
  Items.ensureModel("emerald")
  Items.installPack({items=game.data.gen3Items._byId})
  local TextIR=require("src.core.game3.scripting.text_ir")
  for key,value in pairs({gText_HowMayIServeYou="Welcome! How may I serve you?",
    gText_Var1CertainlyHowMany="How many?",gText_Var1AndYouWantedVar2="Confirm purchase?",
    gText_HereYouGoThankYou="Here you go! Thank you!",gText_YouDontHaveMoney="You don't have enough money."}) do
    if not Space.bundle.text[key] then
      preserve(Space.bundle.text,{key})
      Space.bundle.text[key]=TextIR.fromAscii(value)
    end
  end
  local Bag=require("src.core.game3.bag")
  local Shop=require("src.ui.game3.rse.shop_menu")
  -- SDK graphics are a loader shim, not an advancing visual fade loop.
  local graphics=love and love.graphics
  if love then love.graphics=nil end
  local shopSession={version="emerald",money=1000,bag=Bag.new()}
  local shop={_items=openingStock,_session=shopSession,close=function() end}
  Shop.show(shop,{})
  local function press(key) Shop.handleInput(shop,{wasPressed=function(_,k) return k==key end}) end
  press("a");press("a");press("b")
  T.eq(shopSession.money,1000,"canceled quantity leaves money unchanged")
  T.eq(Bag.get(shopSession.bag,potion),0,"canceled quantity gives no item")
  press("a");press("a");press("a")
  T.eq(shopSession.money,700,"confirmed native purchase debits Potion price")
  T.eq(Bag.get(shopSession.bag,potion),1,"confirmed native purchase adds Potion to bag")
  press("a");shopSession.money=0;press("a")
  T.eq(shop.state,"msg","native shop rejects purchase with insufficient money")
  T.eq(shopSession.money,0,"failed purchase leaves money unchanged")
  T.eq(Bag.get(shopSession.bag,potion),1,"failed purchase gives no extra item")
  if love then love.graphics=graphics end

  -- Observe real autonomous updates on imported Violet NPCs, with the actual
  -- collision/range/player/object checks; no mocked movement scheduler.
  local violet=maps.EM_HNS_VIOLET_CITY_HNS
  game.currentMap=violet.id;session.map=violet.id
  Collision.bindMap(game,violet.id,violet);Objects.loadMap(game,violet.id,violet)
  Player.cellX,Player.cellY=-100,-100;Player.px,Player.py=-1600,-1600
  require("src.core.game3.rng").SeedRng(0x1234)
  local walker,turner=Objects.find(1),Objects.find(2)
  local moved,turned,walkingPose=false,false,false
  local firstFacing=turner.facing
  local Ow=require("src.core.game3.ow_sprites")
  local info=world.opening.sprites[tostring(walker.graphicsId)]
  T.check(info.frameCount>=9,"walking NPC has source animation frames")
  for _=1,1600 do
    Objects.update(game)
    if walker.cellX~=walker.homeX or walker.cellY~=walker.homeY then moved=true end
    if turner.facing~=firstFacing then turned=true end
    T.check(math.abs(walker.cellX-walker.homeX)<=walker.rangeX and math.abs(walker.cellY-walker.homeY)<=walker.rangeY,"walker respects source movement range")
    T.check(not Permissions.isWall(Collision.cell(walker.cellX,walker.cellY)),"walker stays off blocked terrain")
    if walker.moving then
      local frame=Ow.pose(info,walker.facing,true,walker.stepFlip)
      if frame>=3 and frame<info.frameCount then walkingPose=true end
    end
  end
  T.check(moved,"imported wandering NPC changes cells under native updates")
  T.check(turned,"imported looking NPC turns under native updates")
  T.check(walkingPose,"native renderer selects actual walking frames")
  -- Wait for a step to settle before freezing, just as script interaction does.
  while walker.moving do Objects.update(game) end
  Objects.freeze(1)
  local x,y,facing=walker.cellX,walker.cellY,walker.facing
  for _=1,200 do Objects.update(game) end
  T.eq(walker.cellX,x,"frozen NPC does not wander in dialogue")
  T.eq(walker.cellY,y,"frozen NPC does not wander in dialogue")
  T.eq(walker.facing,facing,"frozen NPC does not turn in dialogue")
  Objects.unfreeze(1)
  local resumed=false
  for _=1,1200 do Objects.update(game);if walker.cellX~=x or walker.cellY~=y then resumed=true end end
  T.check(resumed,"NPC resumes wandering after dialogue releases it")
  print(string.format("NPC service regressions: %d nurse desks, %d mart desks; native movement, healing and shop transactions",targetedNurses,targetedClerks))
  for _,s in ipairs(saved) do s.t[s.k]=s.v end
end
