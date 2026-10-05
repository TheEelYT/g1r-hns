-- Real script VM, flags, bag, dex, trainer builder, sight and prize APIs.
-- Battle completion is a controlled async boundary here; teams are built by
-- the actual native trainer module. Scripted Silver walking uses Objects.
return function(T,game,world,maps)
  local Rt=require("src.core.game3.runtime")
  local Space=require("src.core.game3.scripting.space")
  local Flags=require("src.core.game3.scripting.flags")
  local Vm=require("src.core.game3.scripting.vm")
  local Adapters=require("src.core.game3.scripting.adapters")
  local Items=require("src.core.game3.items_data")
  local Bag=require("src.core.game3.bag")
  local Party=require("src.core.game3.party")
  local Trainers=require("src.core.game3.scripting.trainers")
  local Objects=require("src.core.game3.objects")
  local Collision=require("src.core.game3.collision")
  local Player=require("src.core.game3.player")
  local Field=require("src.core.game3.field")
  local Marts=require("src.core.game3.marts")
  local Q=world.quest
  local saved={}
  local function preserve(t,keys) for _,k in ipairs(keys) do saved[#saved+1]={t=t,k=k,v=t[k]} end end
  preserve(Rt,{"session"});preserve(Space,{"store","vm","active","startScript"})
  preserve(Field,{"running","locked","_session","_game"});preserve(game,{"currentMap"})
  preserve(Player,{"cellX","cellY","px","py","targetX","targetY","facing","moving","currentElevation","elevation"})
  Items.ensureModel("emerald");Items.installPack({items=game.data.gen3Items._byId})
  T.eq(Items.info(Q.eggItem).pocket,"KEY_ITEMS","mystery egg is a real native key item")
  T.eq(Items.info(Q.eggItem).importance,1,"mystery egg cannot be tossed like an ordinary item")
  local session,store,battleCalls,battleFoe,battleOptions
  local function reset()
    session={version="emerald",playerName="GENE",party={},bag=Bag.new(),flags={},vars={},money=0}
    store=Flags.newStore();Rt.session=session;Space.store=store
    battleCalls=0;battleFoe=nil
  end
  local function run(key,opts)
    opts=opts or {};Rt.session=session;Space.store=store
    local pending,messages=nil,{}
    local a=Adapters.stub({playerName="GENE",onMessage=function(v) messages[#messages+1]=v end,
      nurseHeal=function(done) Party.healAll(session.party);done() end})
    a.modifyItem=function(op,id,qty)
      if opts.rejectItems then return false end
      if op=="removeitem" then return Bag.remove(session.bag,id,qty) end
      return Bag.add(session.bag,id,qty)
    end
    a.checkItem=function(id,qty) return Bag.has(session.bag,id,qty) end
    a.startTrainerBattle=function(foe,done,battleOpts)
      battleCalls=battleCalls+1;battleFoe=foe;battleOptions=battleOpts;pending=done
    end
    if opts.movement then
      a.applyMovement=function(lid,bytes,done) return Objects.applyMovement(lid,bytes,done) end
      a.pollMovement=function(lid) return Objects.pollMovement(lid) end
    end
    local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,store=store,adapters=a})
    T.check(vm:start(key),"progress script starts: "..key)
    for _=1,1200 do
      require('src.core.game3.audio').update(1/60)
      if opts.movement then Player.tick(game);Objects.update(game) end
      if pending then
        T.check(vm:isRunning(),"script waits for async trainer result")
        local done=pending;pending=nil;done(opts.result or "win")
      end
      if vm:isRunning() then vm:resume() end
      if not vm:isRunning() then break end
    end
    T.check(not vm:isRunning(),"progress script finishes: "..key)
    T.eq(vm.ctx.frozen,false,"progress script releases player: "..key)
    T.eq(a.boxOpen(),false,"progress message closes: "..key)
    T.eq(#a.logs,0,"progress has no skipped opcode: "..key)
    for _,v in ipairs(messages) do T.check(v~="(missing text)","progress source text resolves") end
    return messages
  end
  local function q(name,opts) return run("HNS_QUEST_"..name,opts) end
  local function flag(name) return Flags.getFlag(store,nil,Q.flags[name]) end
  local function snapshot()
    Space.store=store;Rt.session=session;Space.persistSession(nil,game)
    store=Flags.loadInto(Flags.newStore(),{flags=session.flags,vars=session.vars});Space.store=store
  end
  reset();q("MR")
  T.eq(Bag.get(session.bag,Q.eggItem),0,"cannot take egg before starter")
  T.eq(flag("eggReceived"),false,"pre-starter visit does not advance quest")
  for choice,name in ipairs({"CHIKORITA","CYNDAQUIL","TOTODILE"}) do
    reset()
    local C=require("src.core.game3.constants").of("emerald")
    local id=C:require("species","SPECIES_"..name)
    Party.giveMonToPlayer(session,id,5)
    Flags.setFlag(store,nil,world.opening.flags.received,true)
    Flags.setVar(store,nil,world.opening.vars.starter,choice-1)
    -- Existing saves carry the starter flag/variable; new quest flags default
    -- false. Full bag must not mark the egg or a one-time gift as received.
    q("MR",{rejectItems=true})
    T.eq(flag("eggReceived"),false,"rejected egg can be retried")
    run("HNS_OPENING_AIDE1",{rejectItems=true})
    T.eq(flag("potionGift"),false,"rejected Potion can be retried")
    run("HNS_OPENING_AIDE1");run("HNS_OPENING_AIDE1")
    T.eq(Bag.get(session.bag,13),1,"aide gives exactly one Potion")
    session.party[1].hp=1;session.party[1].status="poison";session.party[1].pp[1]=0
    q("MR")
    T.eq(Bag.get(session.bag,Q.eggItem),1,"Mr Pokemon gives native mystery egg")
    T.eq(flag("eggReceived"),true,"egg quest advances after bag accepts it")
    T.eq(require("src.core.game3.dex").nationalEnabled(session),true,"Oak unlocks native national dex for Johto species")
    T.eq(session.party[1].hp,session.party[1].maxHp,"Mr Pokemon heals party")
    T.eq(session.party[1].status,nil,"Mr Pokemon clears status")
    T.check(session.party[1].pp[1]>0,"Mr Pokemon restores PP")
    q("MR");T.eq(Bag.get(session.bag,Q.eggItem),1,"repeat visit cannot duplicate egg")
    snapshot();q("MR")
    T.eq(Bag.get(session.bag,Q.eggItem),1,"save reload cannot duplicate egg")
    run("HNS_OPENING_ELM")
    T.eq(flag("eggDelivered"),false,"delivery waits for rival encounter")
    q("RIVAL",{result="lose"})
    T.eq(flag("rivalDone"),false,"losing rival leaves encounter retryable")
    T.eq(battleCalls,1,"first rival attempt launches one battle")
    local stronger=({"CYNDAQUIL","TOTODILE","CHIKORITA"})[choice]
    T.eq(battleFoe.species,C:require("species","SPECIES_"..stronger),"rival takes stronger source starter")
    T.eq(battleFoe.level,5,"rival starter has source level")
    -- Exercise source Silver movement on the middle coordinate trigger.
    local cherry=maps.EM_HNS_CHERRYGROVE_CITY_HNS
    session.map=cherry.id;game.currentMap=cherry.id;Field._session=session
    Collision.bindMap(game,cherry.id,cherry);Objects.loadMap(game,cherry.id,cherry)
    q("RIVAL_INIT")
    local silver=Objects.find(14)
    T.eq(silver.visible,true,"Silver appears only once egg is received")
    Player.cellX,Player.cellY=56,10;Player.px,Player.py=896,160;Player.moving=false;Player.facing="right"
    Field.locked=true
    q("RIVAL_MID",{movement=true})
    Field.locked=false
    T.eq(flag("rivalDone"),true,"winning rival advances quest")
    T.eq(Flags.getVar(store,nil,Q.vars.rivalStage),2,"return trigger disarms after win")
    T.eq(Player.cellX,56,"Silver scene preserves source player x")
    T.eq(Player.cellY,11,"Silver scene moves player out of exit path")
    T.eq(silver.cellX,47,"Silver source departure finishes at correct x")
    T.eq(silver.cellY,10,"Silver source departure preserves y")
    q("RIVAL");T.eq(battleCalls,2,"completed rival cannot battle again")
    local clerkKey
    for key,s in pairs(world.worldEvents.marts.stocks) do if s.postQuestItems then clerkKey=key;break end end
    T.eq(#Marts.itemsFor(clerkKey),2,"mart retains pre-quest stock before egg delivery")
    run("HNS_OPENING_ELM")
    T.eq(flag("eggDelivered"),true,"Elm accepts egg after rival win")
    T.eq(Bag.get(session.bag,Q.eggItem),0,"delivery removes mystery egg from bag")
    T.eq(#Marts.itemsFor(clerkKey),9,"quest completion restores source zero-badge mart stock")
    run("HNS_OPENING_AIDE1",{rejectItems=true})
    T.eq(flag("ballsGift"),false,"rejected ball gift can be retried")
    run("HNS_OPENING_AIDE1");run("HNS_OPENING_AIDE1")
    T.eq(Bag.get(session.bag,4),5,"aide gives exactly five balls")
    snapshot();run("HNS_OPENING_ELM");run("HNS_OPENING_AIDE1");q("MR")
    T.eq(Bag.get(session.bag,4),5,"save reload cannot duplicate ball gift")
    T.eq(Bag.get(session.bag,Q.eggItem),0,"delivered egg cannot be regenerated after reload")
    T.eq(#session.party,1,"quest cannot duplicate starter")
  end
  -- Actual coordinate-event selection and native visibility on older saves.
  reset();local cherry=maps.EM_HNS_CHERRYGROVE_CITY_HNS
  session.map=cherry.id;game.currentMap=cherry.id;Field.running=true;Field.locked=false;Field._session=session
  Space.active=true;Space.vm=nil;Space.store=store
  Objects.loadMap(game,cherry.id,cherry);Collision.bindMap(game,cherry.id,cherry)
  q("RIVAL_INIT");Objects.loadMap(game,cherry.id,cherry)
  T.eq(Objects.find(14).visible,false,"pre-quest save hides Silver")
  local captured
  Space.startScript=function(key) captured=key;return true end
  T.eq(Field.tryCoordEvents(game,56,10),false,"return trigger inactive before quest")
  Flags.setFlag(store,nil,Q.flags.eggReceived,true);q("RIVAL_INIT")
  T.eq(Field.tryCoordEvents(game,56,10),true,"actual step event selects return scene")
  T.eq(captured,"HNS_QUEST_RIVAL_MID","coordinate selects correct scene")
  q("RIVAL_MID")
  T.eq(battleCalls,0,"empty-party return scene cannot launch a broken battle")
  for _,entry in ipairs({{9,"RIVAL_TOP"},{11,"RIVAL_BOTTOM"}}) do
    reset();Party.giveMonToPlayer(session,152,5)
    Flags.setFlag(store,nil,world.opening.flags.received,true)
    Flags.setFlag(store,nil,Q.flags.eggReceived,true)
    Flags.setVar(store,nil,world.opening.vars.starter,0)
    session.map=cherry.id;game.currentMap=cherry.id;Field._session=session
    Collision.bindMap(game,cherry.id,cherry);Objects.loadMap(game,cherry.id,cherry);q("RIVAL_INIT")
    Player.cellX,Player.cellY=56,entry[1];Player.px,Player.py=896,entry[1]*16;Player.moving=false
    Field.locked=true;q(entry[2],{movement=true});Field.locked=false
    T.eq(Player.cellX,56,"outer rival trigger aligns source player x")
    T.eq(Player.cellY,11,"outer rival trigger aligns source player y")
    T.eq(flag("rivalDone"),true,"outer rival trigger completes battle and movement")
  end

  -- Every imported land/water/rock/fishing pool generates a native monster,
  -- with no species or level outside the preserved source slot windows.
  reset();Party.giveMonToPlayer(session,152,5)
  local Encounters=require("src.core.game3.encounters")
  local Rng=require("src.core.game3.rng")
  Rng.SeedRng(0x401);Rng.SeedWildEncounterRng(0x401)
  local rolled,catchable=0,nil
  for mid,areas in pairs(world.encounters.tables) do
    session.map=mid
    for kind,sourceArea in pairs(areas) do
      local area=Encounters.tableFor(mid)[kind]
      T.eq(area.rate,sourceArea.rate,"native encounter rate preserves source")
      T.eq(#area.slots,#sourceArea.slots,"native encounter pool preserves every slot")
      local rods=kind=="fishing" and {"old","good","super"} or {false}
      for _,rod in ipairs(rods) do
        local enc
        for _=1,2000 do
          if kind=="fishing" then enc=Encounters.rollFishing(mid,rod)
          elseif kind=="land" then enc=Encounters.rollLand(mid)
          elseif kind=="water" then enc=Encounters.rollWater(mid)
          else enc=Encounters.rollRocks(mid) end
          if enc then break end
        end
        T.check(enc~=nil,"native encounter pool generates a monster: "..mid.."/"..kind)
        if enc then
          local inPool=false
          for _,slot in ipairs(area.slots) do
            if enc.species==slot.species and enc.level>=slot.minLevel and enc.level<=slot.maxLevel then inPool=true end
          end
          T.check(inPool,"rolled wild species/level belongs to source pool")
          catchable=enc;rolled=rolled+1
        end
      end
    end
  end
  if catchable then
    local Catching=require("src.core.game3.battle.catching")
    local temporary={party={},version="emerald"}
    Party.giveMonToPlayer(temporary,catchable.species,catchable.level)
    local mon=temporary.party[1]
    local captured=Catching.storeCaught(session,{mon=mon,species=catchable.species},4)
    T.eq(captured.success,true,"native wild capture enters party")
    T.eq(captured.location,"party","capture uses available party slot")
    T.eq(session.party[2].species,catchable.species,"captured wild species persists in party")
    T.eq(captured.firstTimeCaught,true,"capture records native dex ownership")
    local repeated=Catching.storeCaught(session,{mon=mon,species=catchable.species},4)
    T.eq(repeated.firstTimeCaught,false,"repeat capture reads existing dex ownership")
    while #session.party<6 do Party.giveMonToPlayer(session,152,5) end
    local boxed=Catching.storeCaught(session,{mon=mon,species=catchable.species},4)
    T.eq(boxed.success,true,"native capture can use PC storage")
    T.eq(boxed.location,"pc","full party directs caught monster to PC")
  end

  -- Every registered ordinary fight builds the exact source roster through
  -- the native trainer builder, yields, records wins and refuses refights.
  local Prize=require("src.core.game3.battle.prize")
  local Sight=require("src.core.game3.trainer_sight")
  for _,event in ipairs(world.trainers.events) do
    reset();Party.giveMonToPlayer(session,152,5)
    local tid=event.trainerId;local source=world.trainers.records[tostring(tid)]
    local built=Trainers.foeFromId(tid)
    T.eq(#built.party,#source.party,"native trainer team size preserved")
    for i,m in ipairs(source.party) do
      local C=require("src.core.game3.constants").of("emerald")
      T.eq(built.party[i].species,C:require("species","SPECIES_"..m.species),"trainer species maps by name")
      T.eq(built.party[i].level,m.level,"trainer source level preserved")
      T.eq(built.party[i].iv,m.iv,"trainer source uniform IVs preserved")
    end
    run(event.script,{result="lose"})
    T.eq(Flags.isTrainerDefeated(store,nil,tid),false,"loss does not defeat trainer")
    run(event.script)
    T.eq(Flags.isTrainerDefeated(store,nil,tid),true,"native win persists trainer flag")
    T.eq(battleCalls,2,"loss then win launch two battles")
    run(event.script);T.eq(battleCalls,2,"defeated trainer speaks without refighting")
    snapshot();run(event.script);T.eq(battleCalls,2,"trainer stays defeated after save reload")
    local class=world.trainers.classes[tostring(source.class)]
    local expected=4*source.party[#source.party].level*class.money
    T.eq(Prize.calcRse(tid,{}),expected,"native prize uses source class money")
    local amount=Prize.rewardRse(tid,{})
    T.eq(amount,expected,"native trainer prize calculates source amount")
    Prize.apply(session,amount)
    T.eq(session.money,expected,"trainer prize enters persistent native money")
  end
  -- A source Route 30 trainer really sees an unobstructed player, while the
  -- same ID's defeated flag suppresses engagement. Empty-party guard covers
  -- both per-object and whole-map sight checks.
  reset();local route=maps.EM_HNS_ROUTE30_HNS
  session.map=route.id;game.currentMap=route.id;Field._session=session
  Objects.loadMap(game,route.id,route);Collision.bindMap(game,route.id,route)
  local target
  for _,event in ipairs(world.trainers.events) do if event.map==route.id then target=Objects.find(event.localId);break end end
  T.check(target~=nil,"opening Route 30 has trainers")
  T.eq(Sight.check(game,target),false,"empty-party object sight check is gated")
  T.eq(Sight.check(game),false,"empty-party global sight check is gated")
  Party.giveMonToPlayer(session,152,5)
  local found=false
  for _,d in ipairs({{0,1,"down"},{0,-1,"up"},{1,0,"right"},{-1,0,"left"}}) do
    local x,y=target.cellX+d[1],target.cellY+d[2]
    if Collision.isWalkable(x,y) then
      target.facing=d[3];Player.cellX,Player.cellY=x,y;Player.currentElevation=route.midLayout:elevAt(x,y)
      if Sight.checkLineOfSight(target,Player,game) then found=true;break end
    end
  end
  T.check(found,"native raycast sees player beside source Route 30 trainer")
  Flags.setTrainerDefeated(store,nil,target.def.trainerId,true)
  T.eq(Sight.isDefeated(target,store),true,"native sight reads port trainer defeat flag")
  print(string.format("Progress regressions: all three starters, egg/dex/rival/Elm/gifts/reload; %d trainers build, lose/win, persist and pay",#world.trainers.events))
  for _,s in ipairs(saved) do s.t[s.k]=s.v end
end
