-- Actual VM, source movement, inventory, native trainer flags and save schema.
return function(T,game,world,maps)
  local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags');local Vm=require('src.core.game3.scripting.vm')
  local Adapters=require('src.core.game3.scripting.adapters');local Bag=require('src.core.game3.bag')
  local Party=require('src.core.game3.party');local Player=require('src.core.game3.player')
  local Objects=require('src.core.game3.objects');local Collision=require('src.core.game3.collision')
  local Audio=require('src.core.game3.audio');local C=require('src.core.game3.constants').of('emerald')
  local Q=world.campaign;local saved={}
  local function preserve(t,keys)for _,k in ipairs(keys) do saved[#saved+1]={t,k,t[k]} end end
  preserve(Rt,{'session','active'});preserve(Space,{'store','vm','mapId','active'})
  preserve(Player,{'cellX','cellY','px','py','targetX','targetY','facing','moving','currentElevation'})
  preserve(Objects,{'_byId','_order','_tracks','_mapId','_defs','_bounds','_perm','_templateMt'})
  local session,store,calls,foe,messages
  local function reset(mid,x,y)
    session={version='emerald',map=mid,name='GENE',party={},bag=Bag.new(),flags={},vars={},money=0,rivalName='SILVER'}
    store=Flags.newStore();Rt.session=session;Rt.active=true;Space.store=store;calls=0;messages={}
    Party.giveMonToPlayer(session,152,5)
    Collision.bindMap(game,mid,maps[mid]);Objects.reset();Objects.loadMap(game,mid,maps[mid])
    Player.cellX,Player.cellY=x,y;Player.px,Player.py=x*16,y*16;Player.targetX,Player.targetY=x,y;Player.moving=false;Player.currentElevation=0
  end
  local function run(name,opts)
    opts=opts or {};local pending
    local a=Adapters.stub({onMessage=function(msg)messages[#messages+1]=msg end})
    a.startTrainerBattle=function(team,done)calls=calls+1;foe=team;pending=done end
    a.applyMovement=Objects.applyMovement;a.pollMovement=Objects.pollMovement
    a.setObjectState=function(_,row)Objects.setObjectXY(row.localId or row[1],row[2],row[3]) end
    a.onFlagChanged=function(id,hidden)Objects.syncFlagVisibility(id,hidden,true) end
    a.removeObject=Objects.removeObject;a.addObject=Objects.addObject
    a.modifyItem=function(op,id,n)if opts.reject then return false end;return Bag.add(session.bag,id,n) end
    local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,store=store,adapters=a})
    T.check(vm:start('HNS_CAMPAIGN_'..name),'campaign script starts '..name)
    for _=1,2400 do
      Audio.update(1/60);Player.tick(game);Objects.update(game)
      if pending then local done=pending;pending=nil;done(opts.result or 'win') end
      if vm:isRunning() then vm:resume() else break end
    end
    T.eq(vm:isRunning(),false,'campaign completes '..name);T.eq(vm.ctx.frozen,false,'campaign releases control '..name)
    T.eq(#a.logs,0,'no skipped campaign opcode '..name)
  end
  local tower='EM_HNS_SPROUT_TOWER_3F_HNS'
  for _,side in ipairs({'LEFT','RIGHT'}) do
    reset(tower,side=='LEFT' and 13 or 14,7);run('TOWER_INIT');run('SILVER_'..side)
    T.eq(Objects.find(5).cellX,side=='LEFT' and 13 or 14,'Silver walks to source lane')
    T.eq(Objects.find(5).cellY,6,'Silver faces player from source y')
    T.eq(Objects.find(5).visible,false,'Silver leaves with Escape Rope')
    T.eq(Flags.getFlag(store,nil,Q.flags.silverHidden),true,'Silver departure persists')
    run('TOWER_INIT');T.eq(Flags.getVar(store,nil,Q.vars.towerStage),1,'scene not replayed on reentry')
  end
  reset(tower,11,4);run('LI',{result='lose'})
  T.eq(Flags.getFlag(store,nil,Q.flags.flashGift),false,'Li loss grants no reward')
  run('LI',{reject=true});T.eq(calls,2,'retry after loss fights Li again')
  T.eq(Flags.getFlag(store,nil,Q.flags.flashGift),false,'full bag leaves FLASH pending')
  run('LI');run('LI');T.eq(calls,2,'pending reward and repeat talk do not refight Li')
  local flash=C:require('items','ITEM_HM05')
  T.eq(Bag.get(session.bag,flash),1,'Li gives exactly one native FLASH HM')
  local gym='EM_HNS_VIOLET_CITY_GYM_HNS';reset(gym,9,5)
  run('FALKNER',{result='lose'});T.eq(Flags.getFlag(store,nil,Q.flags.zephyr),false,'Falkner loss grants no badge')
  run('FALKNER',{reject=true});T.eq(foe.party[1].level,8,'Falkner source Pidgey level');T.eq(foe.party[2].level,11,'Falkner source Noctowl level')
  T.eq(foe.party[2].heldItem,C:require('items','ITEM_SITRUS_BERRY'),'Falkner source held berry')
  T.eq(Flags.getFlag(store,nil,Q.flags.zephyr),true,'badge granted after native win')
  T.eq(Flags.getFlag(store,nil,C.flags.byName.FLAG_BADGE01_GET),true,'badge reaches native save state')
  T.eq(Flags.getFlag(store,nil,C.flags.byName.FLAG_BADGE02_GET),false,'first badge does not create second badge')
  T.eq(Flags.getFlag(store,nil,Q.flags.roostGift),false,'full bag leaves TM pending')
  run('FALKNER');run('FALKNER');T.eq(calls,2,'Falkner reward retry does not refight')
  T.eq(Bag.get(session.bag,Q.roostItem),1,'exactly one ROOST TM')
  local FieldMoves=require('src.core.game3.field_moves')
  T.eq(FieldMoves.hasBadge(store,'FLASH'),true,'Zephyr authorizes native FLASH')
  T.eq(FieldMoves.hasBadge(store,'CUT'),false,'Zephyr does not unlock CUT')
  Space.persistSession(nil,game)
  local Schema=require('src.core.game3.save_schema_firered');local restored=Schema.fromSaveTable(Schema.toSaveTable(session))
  local restoredStore=Flags.loadInto(Flags.newStore(),{flags=restored.flags,vars=restored.vars})
  T.eq(Flags.getFlag(restoredStore,nil,Q.flags.zephyr),true,'Zephyr survives native save/reload')
  T.eq(Bag.get(restored.bag,Q.roostItem),1,'custom TM survives native save/reload')
  for _,pickup in ipairs(Q.pickups) do
    reset(pickup.map,0,0);local name='PICKUP_'..pickup.flag
    run(name,{reject=true});T.eq(Flags.getFlag(store,nil,pickup.flag),false,'full bag preserves source pickup')
    run(name);run(name);T.eq(Bag.get(session.bag,C:require('items',pickup.itemName)),1,'source pickup cannot duplicate')
  end
  reset(gym,9,5)
  local Pokemon=require('src.core.game3.pokemon');local Items=require('src.core.game3.items_data')
  T.eq(Items.isTm(Q.roostItem),true,'ROOST appears as teachable TM');T.eq(Items.tmNumber(Q.roostItem),51,'ROOST uses source TM number')
  T.eq(Pokemon.canLearnTmItem(16,Q.roostItem),true,'source Pidgey can learn ROOST')
  T.eq(Pokemon.canLearnTmItem(19,Q.roostItem),false,'source Rattata cannot learn ROOST')
  Party.giveMonToPlayer(session,16,5);local mon=session.party[2]
  local status=require('src.core.game3.item_use').checkTmPreflight(mon,Q.roostItem)
  T.eq(status,'ok','native teaching preflight accepts source-compatible mon')
  T.eq(Pokemon.teachMove(mon,Q.roostMove),true,'native move storage accepts ROOST')
  T.eq(mon.pp[#mon.moves],5,'ROOST uses pinned source current-generation PP')
  local Moves=require('src.core.game3.battle.moves')
  preserve(Moves._rom,{Q.roostMove});Moves._rom[Q.roostMove]=nil
  local roost=Moves.get(Q.roostMove)
  T.eq(roost.numId,Q.roostMove,'Roost resolves without an Emerald ROM row')
  T.eq(roost.type,2,'Roost has native Flying type for battle selection')
  T.eq(roost.category,'status','Roost is a status move')
  T.eq(roost.pp,5,'Roost selection exposes source PP')
  T.eq(roost.effectId,'EXP_RECOVER_EFFECT','Roost dispatch retains implemented healing effect')
  T.eq(Moves.get('HNS_ROOST').numId,Q.roostMove,'canonical custom move name resolves without ROM data')
  T.eq(Moves.get({move=Q.roostMove}).numId,Q.roostMove,'native wrapped move identifier resolves')
  local Effects=require('src.core.game3.battle.effects');local Adapter=require('src.core.game3.battle.adapter')
  for _,types in ipairs({{0,2},{2,2},{10,2},{0,0}}) do
    local user={id=0,type1=types[1],type2=types[2],mon={hp=25,maxHp=100}}
    local ad=Adapter.new({});ad.sayText=function() end -- ROM-free text boundary; healing/types remain native.
    Effects.runForMove(ad,user,user,Q.roostMove)
    T.eq(user.mon.hp,75,'ROOST heals half maximum HP')
    T.check(user.type1~=2 and user.type2~=2,'ROOST removes Flying until end of turn')
    require('src.mods.Runtime').emit('battle.turn_ended',{battle={},turn=1})
    T.eq(user.type1,types[1],'ROOST restores first type');T.eq(user.type2,types[2],'ROOST restores second type')
    user.mon.hp=100;Effects.runForMove(ad,user,user,Q.roostMove)
    T.eq(user.type1,types[1],'full HP ROOST does not change type')
  end
  reset('EM_HNS_NEW_BARK_TOWN_HNS',20,19)
  T.check(Objects.find(1)~=nil,'New Bark man spawns');T.check(Objects.find(4)~=nil,'New Bark Wooper spawns')
  for i=#saved,1,-1 do local s=saved[i];s[1][s[2]]=s[3] end
  print('Campaign regressions: both Silver lanes, Li/FLASH, Falkner/badge/TM loss and bag retries, native saves, pickups, ROOST teaching/healing/types')
end
