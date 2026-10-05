-- Real VM/Objects/Player/entry-table/store/bag; controlled text/name input.
return function(T,game,world,maps)
  local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags')
  local Vm=require('src.core.game3.scripting.vm')
  local Adapters=require('src.core.game3.scripting.adapters')
  local Objects=require('src.core.game3.objects')
  local Player=require('src.core.game3.player')
  local Field=require('src.core.game3.field')
  local Rt=require('src.core.game3.runtime')
  local Bag=require('src.core.game3.bag')
  local Party=require('src.core.game3.party')
  local Collision=require('src.core.game3.collision')
  local Q=world.quest;local saved={}
  local function preserve(t,keys) for _,k in ipairs(keys) do saved[#saved+1]={t=t,k=k,v=t[k]} end end
  preserve(Rt,{'session','active'});preserve(Space,{'store','vm','mapId','active','_inTransition'})
  preserve(Field,{'running','locked','_session','_game','metatileOverrides','_overrideLayouts'});preserve(game,{'currentMap'})
  preserve(Player,{'cellX','cellY','px','py','targetX','targetY','facing','moving','currentElevation','elevation'})
  preserve(Objects,{'_byId','_order','_tracks','_mapId','_defs','_bounds','_perm','_templateMt'})
  local session,store,names,trace
  local function flag(n) return Flags.getFlag(store,nil,Q.flags[n]) end
  local function reset(mid,x,y)
    session={version='emerald',map=mid,playerName='GENE',name='GENE',party={},bag=Bag.new(),flags={},vars={},money=0}
    store=Flags.newStore();Space.store=store;Rt.session=session;Rt.active=true
    game.currentMap=mid;Field.running=true;Field.locked=true;Field._session=session;Field._game=game
    Collision.bindMap(game,mid,maps[mid]);Objects.reset();Objects.loadMap(game,mid,maps[mid])
    Player.cellX,Player.cellY=x,y;Player.px,Player.py=x*16,y*16;Player.targetX,Player.targetY=x,y;Player.moving=false;Player.facing='up';Player.currentElevation=3
    Field.metatileOverrides={};Field._overrideLayouts={};names=0;trace={}
  end
  local function run(key,opts)
    opts=opts or {};local pending
    local a=Adapters.stub({playerName='GENE',onMessage=function(msg)
      local e,o=Objects.find(2),Objects.find(3)
      trace[#trace+1]={message=msg,elm=e and {e.cellX,e.cellY},oak=o and {o.cellX,o.cellY}}
    end,nurseHeal=function(done) Party.healAll(session.party);done() end})
    a.applyMovement=Objects.applyMovement;a.pollMovement=Objects.pollMovement
    a.setObjectState=function(op,row) if op=='setobjectxyperm' then Objects.setObjectXY(row.localId or row[1],row[2],row[3]) end end
    a.onFlagChanged=function(id,hidden) Objects.syncFlagVisibility(id,hidden,true) end
    a.addObject=Objects.addObject;a.removeObject=Objects.removeObject;a.turnObject=Objects.turnObject
    a.modifyItem=function(op,id,qty) if opts.rejectItems then return false end;if op=='removeitem' then return Bag.remove(session.bag,id,qty) end;return Bag.add(session.bag,id,qty) end
    a.setMetatile=function(x,y,mid,blocked) Field.setMetatile(x,y,mid,blocked) end
    a.checkItem=function(id,qty) return Bag.has(session.bag,id,qty) end
    a.openNaming=function(nopts,done) names=names+1;T.eq(nopts.title,"RIVAL'S NAME",'officer opens rival naming');T.eq(nopts.maxLen,7,'source rival name length');pending=done end
    local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,store=store,adapters=a})
    Space.vm=vm;Space.mapId=session.map;Space.active=true
    if key=='ONFRAME' then Space.runOnFrame() else T.check(vm:start(key),'scene starts '..key) end
    for tick=1,2400 do
      require('src.core.game3.audio').update(1/60)
      Player.tick(game);Objects.update(game)
      if pending then T.check(vm:isRunning(),'police waits for naming');local done=pending;pending=nil;done(opts.name or 'SILVER') end
      if vm:isRunning() then vm:resume() else break end
    end
    T.eq(vm:isRunning(),false,'scene finishes '..key);T.eq(vm.ctx.frozen,false,'scene releases control '..key)
    T.eq(#a.logs,0,'scene has no skipped opcode '..key)
  end
  local lab='EM_HNS_NEW_BARK_TOWN_LAB_HNS';local mr='EM_HNS_ROUTE30_MR_POKEMONS_HOUSE_HNS'
  for _,x in ipairs({5,6,7}) do
    reset(lab,x,7);run('HNS_SCENE_LAB_INIT');T.eq(Flags.getVar(store,nil,Q.vars.labStage),0,'starter visit arms entrance')
    run('HNS_SCENE_'..(x==5 and 'ELM_LEFT' or x==7 and 'ELM_RIGHT' or 'ELM_ENTRY'))
    T.eq(Player.cellX,6,'Elm aligns player x');T.eq(Player.cellY,4,'player walks to Elm')
    T.eq(Objects.find(2).cellX,6,'Elm returns from computer x');T.eq(Objects.find(2).cellY,3,'Elm returns y')
    T.eq(Flags.getFlag(store,nil,world.opening.flags.elmReady),true,'email unlocks starters')
    local visited=false;for _,p in ipairs(trace) do if p.elm and p.elm[1]==3 and p.elm[2]==2 then visited=true end end
    T.check(visited,'email is spoken at computer')
  end
  reset(mr,5,8);Flags.setFlag(store,nil,world.opening.flags.received,true);Party.giveMonToPlayer(session,152,5)
  run('HNS_SCENE_MR_INIT');T.eq(Flags.getVar(store,nil,Q.vars.mrPending),1,'entry arms automatic meeting');run('ONFRAME')
  T.eq(Player.cellX,7,'Mr walks player to source x');T.eq(Player.cellY,6,'Mr walks player to source y')
  T.eq(flag('eggReceived'),true,'automatic meeting advances quest');T.eq(Bag.get(session.bag,Q.eggItem),1,'automatic meeting gives one egg')
  T.eq(Objects.find(3).cellX,5,'Oak walks to door x');T.eq(Objects.find(3).cellY,8,'Oak walks to door y');T.eq(Objects.find(3).visible,false,'Oak removed after leaving')
  T.eq(Objects.find(2).visible,false,'before-scene Mr removed');T.eq(Objects.find(1).visible,true,'Mr remains after scene')
  T.eq(Objects.find(1).cellX,5,'Mr final source x');T.eq(Objects.find(1).cellY,4,'Mr final source y')
  local approached=false;for _,p in ipairs(trace) do if p.oak and p.oak[1]==8 and p.oak[2]==6 then approached=true end end
  T.check(approached,'Oak talks after approaching')
  run('HNS_SCENE_MR_INIT');T.eq(Flags.getVar(store,nil,Q.vars.mrPending),0,'repeat entry does not replay meeting')
  reset(mr,5,8);Flags.setFlag(store,nil,world.opening.flags.received,true);run('HNS_SCENE_MR_INIT');run('ONFRAME',{rejectItems=true})
  T.eq(flag('eggReceived'),false,'full bag preserves retry');T.eq(Flags.getVar(store,nil,Q.vars.mrPending),0,'full bag does not loop each frame')
  for _,delivered in ipairs({false,true}) do
  for _,chosenName in ipairs({'SILVER','ASH','REX'}) do
    reset(lab,6,12);Party.giveMonToPlayer(session,152,5)
    Flags.setFlag(store,nil,world.opening.flags.received,true);Flags.setFlag(store,nil,Q.flags.rivalDone,true)
    Flags.setFlag(store,nil,Q.flags.eggReceived,true);Flags.setFlag(store,nil,Q.flags.eggDelivered,delivered)
    if not delivered then Bag.add(session.bag,Q.eggItem,1) end
    Flags.setVar(store,nil,world.opening.vars.starter,delivered and 1 or 0)
    run('HNS_SCENE_LAB_INIT');T.eq(maps[lab].midLayout:midAt(7,1),0x32B,'theft window uses source metatile');T.eq(Objects.find(7).visible,true,'officer present on return');run('ONFRAME',{name=chosenName})
    local found=false
    for _,p in ipairs(trace) do if p.message:find('So '..chosenName,1,true) then found=true end end
    if world.startup then T.check(found,'officer repeats saved name instead of MAY/BRENDAN') end
    T.eq(names,1,'investigation asks for name once');T.eq(Objects.find(delivered and 6 or 5).visible,false,'source stolen starter ball removed');T.eq(session.rivalName,chosenName,'native rival name updated')
    T.eq(flag('policeDone'),true,'police completion persists');T.eq(flag('eggDelivered'),true,'delivery completed or preserved')
    T.eq(Bag.get(session.bag,Q.eggItem),0,'no duplicate egg');T.eq(Objects.find(7).cellY,9,'officer walks away');T.eq(Objects.find(7).visible,false,'officer removed after departure')
    T.eq(Player.cellX,6,'player steps to Elm x');T.eq(Player.cellY,4,'player steps to Elm y')
    run('HNS_SCENE_LAB_INIT');T.eq(Flags.getVar(store,nil,Q.vars.policePending),0,'completed investigation disarmed')
    Space.persistSession(nil,game)
    local Schema=require('src.core.game3.save_schema_firered')
    local save=Schema.toSaveTable(session);local restored=Schema.fromSaveTable(save)
    T.eq(restored.rivalName,chosenName,'native save/reload keeps rival name')
    T.eq(restored.flags[Q.flags.policeDone],session.flags[Q.flags.policeDone],'native save keeps police completion')
  end
  end
  reset(lab,6,12);run('HNS_SCENE_LAB_INIT');T.eq(Objects.find(7).visible,false,'fresh game hides officer');T.eq(maps[lab].midLayout:midAt(7,1),0xA0,'fresh visit restores intact source window')
  local cherry=maps.EM_HNS_CHERRYGROVE_CITY_HNS
  local pool=Objects.spawnFromDefs(cherry.objects,cherry,cherry.id)
  T.eq(pool.byId[14].invisible,false,'connected-map Silver remains drawable');T.check(pool.byId[14].graphicsId>=0xE000,'regression uses high sprite ID')
  reset('EM_HNS_ROUTE30_HOUSE_HNS',5,6);run('HNS_RESIDENT_ROUTE30_BERRY',{rejectItems=true})
  T.eq(flag('berryGift'),false,'full bag berry retry');run('HNS_RESIDENT_ROUTE30_BERRY');run('HNS_RESIDENT_ROUTE30_BERRY')
  T.eq(flag('berryGift'),true,'accepted berry persists');local id=require('src.core.game3.constants').of('emerald'):require('items','ITEM_CHERI_BERRY')
  T.eq(Bag.get(session.bag,id),1,'resident gives exactly one berry')
  for i=#saved,1,-1 do local s=saved[i];s.t[s.k]=s.v end
  print('Scene regressions: Elm lanes/email, automatic Mr/Oak, bag retry, officer/name on fresh and old errands, connected Silver, resident gift')
end
