-- Real native damage/context/hit/item/experience/step and script VM regressions.
return function(T,game,world,maps)
  local Q=world.startup;local H=assert(game._hnsRules).rules
  local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space');local Flags=require('src.core.game3.scripting.flags')
  local Pokemon=require('src.core.game3.pokemon');local Moves=require('src.core.game3.battle.moves');local Types=require('src.core.game3.battle.types')
  local Damage=require('src.core.game3.battle.damage');local Engine=require('src.core.game3.battle.engine');local State=require('src.core.game3.battle.state')
  local Adapter=require('src.core.game3.battle.adapter');local Hit=require('src.core.game3.battle.effects.hit');local Held=require('src.core.game3.battle.held_items')
  local Items=require('src.core.game3.battle.items');local ItemUse=require('src.core.game3.item_use');local Bag=require('src.core.game3.bag')
  local Exp=require('src.core.game3.battle.experience');local Runtime=require('src.mods.Runtime');local Steps=require('src.core.game3.step_events')
  local C=require('src.core.game3.constants').of('emerald');local E=require('src.core.game3.battle.effect_ids')
  local Rules=require('src.core.game3.battle.rules');local RomText=require('src.core.game3.rom_text');local TextIR=require('src.core.game3.scripting.text_ir')
  local saved={};local function keep(t,keys)for _,k in ipairs(keys)do saved[#saved+1]={t=t,k=k,v=t[k]}end end
  local itemRows=require('src.core.game3.items_data').ensureLoaded()
  keep(itemRows[13],{'battleUsage'});itemRows[13].battleUsage=1 -- ROM Potion metadata omitted by the SDK fixture.
  keep(Rt,{'session','active'});keep(Space,{'store','vm','mapId','active'});keep(game,{'session','currentMap','boot','phase'})
  keep(Steps,{'_queue','_activeEvent','_poisonFlashTimer','_totalSteps'});keep(Moves,{'_numByName'});keep(Exp,{'expYield'});keep(Pokemon,{'evYield'})
  -- Only absent ROM text data is supplied; native formatter/engine stay live.
  local text={sText_ExclamationMark='!',sText_WildPkmnPrefix='Wild ',sText_FoePkmnPrefix='Foe ',
    sText_AttackerUsedX='{B_ATK_NAME_WITH_PREFIX} used {B_BUFF2}',
    sText_HitXTimes='Hit {B_BUFF1} times!',sText_SuperEffective="It's super effective!",
    sText_NotVeryEffective="It's not very effective…",sText_CriticalHit='A critical hit!',
    sText_PkmnFainted='{B_DEF_NAME_WITH_PREFIX} fainted!',
    sText_PkmnsItemRestoredHealth='{B_SCR_ACTIVE_NAME_WITH_PREFIX} restored health using {B_LAST_ITEM}!'}
  text.STRINGID_HITXTIMES=text.sText_HitXTimes;text.STRINGID_SUPEREFFECTIVE=text.sText_SuperEffective
  text.STRINGID_NOTVERYEFFECTIVE=text.sText_NotVeryEffective;text.STRINGID_CRITICALHIT=text.sText_CriticalHit
  text.STRINGID_PKMNFAINTED=text.sText_PkmnFainted;text.STRINGID_PKMNSITEMRESTOREDHEALTH=text.sText_PkmnsItemRestoredHealth
  text.STRINGID_TARGETFAINTED=text.sText_PkmnFainted;text.STRINGID_ATTACKERFAINTED='{B_ATK_NAME_WITH_PREFIX} fainted!'
  text.STRINGID_ITHURTCONFUSION='It hurt itself in its confusion!'
  for key,value in pairs(text)do keep(RomText.overrides,{key});RomText.overrides[key]=TextIR.fromAscii(value)end
  local s={version='emerald',map='EM_HNS_NEW_BARK_TOWN_HNS',party={},flags={},vars={},playerName='GENE',bag=Bag.new(),gender=0}
  local store=Flags.newStore();Space.store=store;Rt.session=s;game.session=s
  Flags.setFlag(store,nil,Q.settings.initializedFlag,true)
  local settings={};for _,p in ipairs(Q.settings.pages)do for _,r in ipairs(p.rows)do settings[r.id]=r;Flags.setVar(store,nil,r.var,r.default)end end
  local function option(id,value)Flags.setVar(store,nil,settings[id].var,value)end
  local function mode(id,value)option('ITEM_MODE_'..id,value)end
  local function difficulty(id,value)option('ITEM_DIFFICULTY_'..id,value)end
  for _,id in ipairs(Q.rules.implemented)do T.eq(settings[id].implemented,true,'active rule no longer marked pending '..id)end
  T.eq(settings.ITEM_MODE_MODERN_MOVES.implemented,true,'compatible source expanded learnsets are active')
  T.check(#world.expandedMoves.omitted>0,'unsupported expanded move effects remain explicitly tracked')
  local function fixture(id,name,row)
    keep(Moves._rom,{id});keep(Pokemon._moveNames,{id});Moves._rom[id]=row;Pokemon._moveNames[id]=name;Moves._numByName=nil
  end
  fixture(44,'BITE',{effect=0,power=60,type=17,accuracy=100,pp=25,target=0,priority=0,flags=51})
  fixture(247,'SHADOW_BALL',{effect=0,power=80,type=7,accuracy=100,pp=15,target=0,priority=0,flags=18})
  fixture(24,'DOUBLE_KICK',{effect=E.DOUBLE_HIT,power=200,type=1,accuracy=100,pp=30,target=0,priority=0,flags=51})
  fixture(68,'COUNTER',{effect=E.COUNTER,power=1,type=1,accuracy=100,pp=20,target=0,priority=-5,flags=18})
  fixture(204,'CHARM',{effect=E.ATTACK_DOWN_2,power=0,type=0,accuracy=100,pp=20,target=0,priority=0,flags=18})
  fixture(237,'HIDDEN_POWER',{effect=E.HIDDEN_POWER,power=1,type=0,accuracy=100,pp=15,target=0,priority=0,flags=18})
  fixture(153,'EXPLOSION',{effect=E.EXPLOSION,power=250,type=0,accuracy=100,pp=5,target=0,priority=0,flags=18})
  fixture(263,'FACADE',{effect=E.FACADE,power=70,type=0,accuracy=100,pp=20,target=0,priority=0,flags=18})
  fixture(85,'THUNDERBOLT',{effect=0,power=95,type=13,accuracy=100,pp=15,target=0,priority=0,flags=18})
  fixture(22,'VINE_WHIP',{effect=0,power=35,type=12,accuracy=100,pp=10,target=0,priority=0,flags=18})
  local function mon(max)
    return {species=1,level=50,hp=max or 200,maxHp=max or 200,attack=150,defense=60,spAtk=25,spDef=60,speed=50,ability=0,nickname='MON',personality=0,ivs={},evs={},moves={44,24,68,247},pp={25,30,20,15}}
  end
  local function battle(max)
    local p,e=mon(),mon(max);s.party={p}
    local st=State.new({wild=true,session=s,playerParty=s.party,foeParty={e}});st.session=s;st.rng=function(lo,hi)if lo==1 and hi==100 then return 1 end;return hi end
    st.player.type1,st.player.type2=0,0;st.enemy.type1,st.enemy.type2=0,0
    return st,Adapter.new(st)
  end
  local st,ad=battle()
  local opts={noCrit=true,noRandom=true,adapter=ad}
  mode('SPLIT',1);local bite,info=Damage.calc(st.player,st.enemy,44,opts)
  T.eq(info.physical,true,'Bite uses physical Attack after split');T.eq(Moves.get(44).category,'physical','menu/AI move row uses source category')
  mode('SPLIT',0);local oldbite=Damage.calc(st.player,st.enemy,44,opts);T.check(bite>oldbite*3,'split changes actual Bite damage calculation')
  mode('SPLIT',1);st.player.mon.status='BRN';local burned=Damage.calc(st.player,st.enemy,44,opts);T.check(burned<bite,'burn reduces modern physical Bite')
  st.player.mon.status=nil;opts.reflect=true;local reflected=Damage.calc(st.player,st.enemy,44,opts);T.check(reflected<bite,'Reflect reduces physical Bite');opts.reflect=nil
  st.enemy.type1,st.enemy.type2=11,11
  mode('SPLIT',1);local shadow,si=Damage.calc(st.player,st.enemy,247,opts);T.eq(si.physical,false,'Shadow Ball uses Special Attack after split')
  mode('SPLIT',0);local oldshadow=Damage.calc(st.player,st.enemy,247,opts);T.check(oldshadow>shadow*3,'classic split restores physical Ghost damage')
  mode('SPLIT',1)
  st.enemy.type1,st.enemy.type2=0,0
  -- Fixed rules apply without enabling the learnset or split settings.
  mode('MODERN_MOVES',0);mode('SPLIT',0);mode('FAIRY_TYPES',0)
  T.eq(Moves.get(85).power,90,'fixed source Thunderbolt power independent of Modern Moves')
  T.eq(Moves.get(22).pp,25,'fixed source Vine Whip PP independent of settings')
  T.eq(Pokemon.movePp(22),25,'newly taught moves use source PP')
  T.eq(Types.effectiveness(7,8,8),1,'source Steel matchups independent of Fairy setting')
  local hpPower,hpType=Damage.hiddenPower(st.player.mon);T.eq(hpPower,60,'fixed Hidden Power power');T.eq(hpType,1,'Hidden Power preserves IV type')
  local _,hpInfo=Damage.calc(st.player,st.enemy,237,opts);T.eq(hpInfo.power,60,'actual Hidden Power calculation uses fixed power')
  local explosion=Moves.get(153);local normalExplosion={};for k,v in pairs(explosion)do normalExplosion[k]=v end;normalExplosion.effect=0
  T.eq(Damage.base(st.player,st.enemy,explosion,opts),Damage.base(st.player,st.enemy,normalExplosion,opts),'Explosion no longer halves defense')
  local facade=Damage.calc(st.player,st.enemy,263,opts);st.player.mon.status='BRN';local burnedFacade=Damage.calc(st.player,st.enemy,263,opts)
  T.check(burnedFacade>facade*1.9,'burned Facade doubles power without Attack penalty');st.player.mon.status=nil
  local ranges={};Rules.crit.roll(st.player,44,false,function(lo,hi)ranges[#ranges+1]=hi;return hi end,st);T.eq(ranges[1],23,'fixed base critical odds 1/24')
  st.player.focusEnergy=true;T.eq(Rules.crit.roll(st.player,44,false,function(lo,hi)T.eq(hi,1,'stage 2 critical odds 1/2');return 0 end,st),true,'stage 2 can crit')
  T.eq(Rules.crit.roll(st.player,44,true,function()error('guaranteed crit must not roll')end,st),true,'stage 3 critical guaranteed');st.player.focusEnergy=nil
  T.eq(Rules.crit.multiplier(),2,'HnS retains Gen 3 critical damage multiplier')
  mode('MODERN_MOVES',1);mode('SPLIT',1);mode('FAIRY_TYPES',1)
  st.player.ability=C:require('abilities','ABILITY_HUSTLE');st.rng=function(lo,hi)if lo==1 and hi==100 then return 90 end;return hi end
  local accuracy=Engine.newContext(st.player,st.enemy,44,1,ad,st,{},{hits={}},{});T.eq(accuracy:accuracyCheck('normal',false),false,'Hustle penalizes physical Bite after split')
  mode('SPLIT',0);accuracy=Engine.newContext(st.player,st.enemy,44,1,ad,st,{},{hits={}},{});T.eq(accuracy:accuracyCheck('normal',false),true,'classic special Bite avoids Hustle penalty')
  mode('SPLIT',1);st.player.ability=0;st.rng=function(lo,hi)if lo==1 and hi==100 then return 1 end;return hi end
  local M=Engine.newContext(st.player,st.enemy,44,1,ad,st,{},{hits={}},{});Hit.dealDamage(M,10,{physical=H.physical(M.move)})
  T.eq(st.enemy.lastPhysicalDamageTaken,10,'Bite damage recorded for Counter');T.eq(st.enemy.lastSpecialDamageTaken,nil,'Bite is not recorded for Mirror Coat')
  st.enemy.lastPhysicalDamageTaken=10;local counter=Damage.calc(st.enemy,st.player,68,opts);T.eq(counter,20,'native Counter consumes new physical damage history')
  for name,row in pairs(Q.rules.species)do
    local id=C:require('species','SPECIES_'..name)
    mode('FAIRY_TYPES',1);local ts=Pokemon.types(id);T.eq(ts[1],row.modern[1],'source modern type 1 '..name);T.eq(ts[2],row.modern[2],'source modern type 2 '..name)
    mode('FAIRY_TYPES',0);ts=Pokemon.types(id);T.eq(ts[1],row.legacy[1],'source pre-Fairy type 1 '..name);T.eq(ts[2],row.legacy[2],'source pre-Fairy type 2 '..name)
  end
  mode('FAIRY_TYPES',1);T.eq(Moves.get(204).type,18,'Charm uses Fairy type');T.eq(Types.name(18),'FAIRY','Fairy has display name')
  T.eq(Types.effectiveness(16,18,18),0,'Fairy immune to Dragon');T.eq(Types.effectiveness(18,16,17),4,'Fairy super effective against Dragon/Dark')
  T.eq(Types.effectiveness(13,8,8),1,'source Electric versus Steel is neutral');T.eq(Types.effectiveness(7,8,8),1,'source Ghost versus Steel is neutral')
  local _,flags,eff=Types.typeCalc(16,18,18,100);T.eq(flags.immune,true,'actual damage flags register Fairy immunity');T.eq(eff,0,'actual type calculation registers immunity')
  local damage=Types.typeCalc(0,7,7,100,true);T.eq(damage,100,'Foresight restores Normal hit against Ghost')
  mode('FAIRY_TYPES',0);T.eq(Moves.get(204).type,0,'disabling Fairy restores Charm type')
  mode('STURDY',1);st,ad=battle(100);st.enemy.ability=5;st.enemy.mon.ability=5
  M=Engine.newContext(st.player,st.enemy,44,1,ad,st,{},{hits={}},{});local adjusted,status=Hit.adjustDamage(M,st.enemy,500)
  T.eq(adjusted,99,'modern Sturdy survives lethal hit from full HP');T.eq(status,nil,'Sturdy does not break native multi-hit continuation')
  Hit.dealDamage(M,adjusted,{});T.eq(ad:hp(st.enemy),1,'Sturdy preserves real battler HP')
  adjusted=Hit.adjustDamage(M,st.enemy,500);T.eq(adjusted,500,'Sturdy cannot protect damaged battler')
  st,ad=battle(100);st.enemy.ability=5;st.enemy.mon.ability=5;st.enemy.substituteHP=20
  M=Engine.newContext(st.player,st.enemy,44,1,ad,st,{},{hits={}},{});T.eq(Hit.adjustDamage(M,st.enemy,500),500,'Sturdy does not protect substitute')
  mode('STURDY',0);st.enemy.substituteHP=0;T.eq(Hit.adjustDamage(M,st.enemy,500),500,'disabled Sturdy keeps Gen III lethal damage')
  mode('STURDY',1);st,ad=battle(100);st.enemy.ability=5;st.enemy.mon.ability=5
  st.player.mon.attack=1000;st.enemy.mon.defense=1
  local out={};Engine.resolveMove(st.player,st.enemy,24,2,ad,st,out)
  T.eq(ad:hp(st.enemy),0,'real native Double Kick breaks Sturdy on second hit')
  st,ad=battle();st.player.ability=5;st.player.mon.ability=5
  M=Engine.newContext(st.player,st.enemy,44,1,ad,st,{},{hits={}},{});Engine.selfHit(M,1000);T.eq(ad:hp(st.player),1,'source Sturdy also protects confusion self-hit')
  local sitrus=C:require('items','ITEM_SITRUS_BERRY');local heldOf=Held.effectOf;keep(Held,{'effectOf'})
  Held.effectOf=function(id)if id==sitrus then return Held.HOLD.RESTORE_HP,30 end;return heldOf(id)end
  mode('NEW_CITRUS',1);st,ad=battle();st.player.item=sitrus;st.player.mon.item=sitrus;st.player.mon.hp=80
  T.eq(Held.normal(ad,st.player),true,'new Sitrus activates at half HP');T.eq(ad:hp(st.player),130,'new Sitrus restores quarter max HP');T.eq(st.player.item,0,'held Sitrus consumed once')
  T.eq(Held.normal(ad,st.player),false,'consumed Sitrus does not heal twice')
  mode('NEW_CITRUS',0);st.player.item=sitrus;st.player.mon.item=sitrus;st.player.mon.hp=80;Held.normal(ad,st.player);T.eq(ad:hp(st.player),110,'classic Sitrus restores 30 HP')
  mode('NEW_CITRUS',1);local target=mon();target.hp=80;local ok,amount=ItemUse.healMon(s,target,sitrus);T.check(ok,'bag Sitrus heals');T.eq(amount,50,'bag Sitrus uses source quarter HP')
  target.hp=0;T.eq(ItemUse.healMon(s,target,sitrus),false,'Sitrus cannot revive');target.hp=200;T.eq(ItemUse.healMon(s,target,sitrus),false,'Sitrus cannot heal full HP')
  difficulty('ITEM_PLAYER',1);Bag.add(s.bag,13,2);local before=Bag.get(s.bag,13)
  local result,msgs,turn,ended=Items.use(st,ad,s.bag,s,13,1)
  T.eq(result,'error','battle item setting rejects Potion');T.eq(turn,false,'rejected Potion does not spend turn');T.eq(ended,false,'rejected Potion does not end battle');T.eq(Bag.get(s.bag,13),before,'rejected Potion stays in bag')
  T.eq(Items.isBattleUsable(13),false,'battle bag filters forbidden medicine');T.eq(Items.canUseOn(st,13,1,st.player.mon),false,'party target validation rejects medicine')
  T.eq(Items.isBattleUsable(4),true,'no-items rule still allows source Poké Balls');difficulty('ITEM_PLAYER',0)
  T.eq(Items.isBattleUsable(13),true,'disabling item rule restores Potion use')
  difficulty('ITEM_TRAINER',1);T.eq(require('src.core.game3.battle.ai_items').shouldUseItem(st,1),nil,'trainer item setting skips AI item choice')
  Pokemon.evYield=function()return {hp=1,atk=1,def=0,spe=0,spa=0,spd=0}end
  difficulty('NO_EVS',1);T.eq(Pokemon.gainEVs(st.player.mon,1),0,'no-EVs blocks actual award');T.eq(st.player.mon.evs.hp,nil,'blocked EV award does not mutate stats')
  difficulty('NO_EVS',0);T.eq(Pokemon.gainEVs(st.player.mon,1),2,'disabling no-EVs restores normal award')
  local Bridge=require('src.core.game3.battle_bridge');keep(Bridge,{'_battleParty'})
  Bridge._battleParty=require('src.core.game3.battle.party_view').fromSession(s.party,nil)
  local clone=Bridge._battleParty[1];T.check(clone~=s.party[1],'real native PartyView creates battle copy')
  local cloneHp=clone.evs.hp;difficulty('NO_EVS',1)
  T.eq(Pokemon.gainEVs(clone,1),0,'no-EVs blocks real battle copy award');T.eq(clone.evs.hp,cloneHp,'battle copy EVs stay unchanged')
  local other=mon();T.eq(Pokemon.gainEVs(other,1),2,'player EV restriction does not affect foreign Pokémon')
  difficulty('NO_EVS',0);T.eq(Pokemon.gainEVs(clone,1),2,'battle copy gains EVs when restriction disabled')
  Bridge._battleParty=nil
  for choice,mult in pairs({[0]=1,[1]=1.5,[2]=2,[3]=0})do
    difficulty('EXP_MULTIPLIER',choice)
    T.eq(Runtime.call('exp.gain',function()return 101 end,{battle=st}),math.floor(101*mult),'source EXP multiplier '..choice)
  end
  difficulty('EXP_MULTIPLIER',2);Exp.expYield=function()return 70 end
  st.player.mon.level=10;st.enemy.mon.level=10;st.enemy.species=1;st.enemy.participants={[1]=true};Flags.setFlag(store,nil,Q.expOffFlag,true)
  local results=Exp.awardFoe(st,st.enemy,{getOpts=function()return {}end});T.eq(results[1].amount,200,'actual native award applies double EXP')
  difficulty('EXP_MULTIPLIER',0);difficulty('NO_EVS',0)
  -- Vanilla execution after selecting HnS settings delegates the original rules.
  s.map='EM_ROUTE101';T.eq(Moves.get(44).category,'special','vanilla Bite retains type-based category');T.eq(Types.effectiveness(7,8,8),.5,'vanilla Steel resistance preserved')
  T.eq(Moves.get(85).power,95,'vanilla Thunderbolt retains Gen 3 power');T.eq(Pokemon.movePp(22),10,'vanilla Vine Whip retains PP')
  T.eq(Damage.hiddenPower(st.player.mon),30,'vanilla Hidden Power retains IV power')
  Rules.crit.roll(st.player,44,false,function(lo,hi)T.eq(hi,15,'vanilla critical odds remain 1/16');return hi end,st)
  difficulty('ITEM_PLAYER',1);T.eq(Items.isBattleUsable(13),true,'HnS item ban does not affect vanilla battle bag')
  difficulty('EXP_MULTIPLIER',3);T.eq(Runtime.call('exp.gain',function()return 101 end,{battle=st}),101,'HnS zero EXP does not affect vanilla awards')
  s.map='EM_HNS_NEW_BARK_TOWN_HNS';difficulty('ITEM_PLAYER',0);difficulty('EXP_MULTIPLIER',0)
  -- Exercise the native shared step queue; no separate poison engine or timer.
  mode('SURVIVE_POISON',1);local poisoned=mon();poisoned.hp=2;poisoned.status='PSN';poisoned.friendship=100;s.party={poisoned};s.poisonSteps=3
  local Sem=require('src.core.game3.field_semantics');s.vars[Sem.var(s,'poisonSteps')]=3;Steps.flush();Steps.onStepTaken(s,game)
  T.eq(poisoned.hp,1,'field poison stops at 1 HP');T.eq(poisoned.status,nil,'surviving field poison is cured');T.eq(poisoned.friendship,100,'surviving poison does not deduct friendship')
  T.eq(#Steps._queue,1,'survival enqueues one native message');T.eq(Steps._queue[1].mon,poisoned,'native queue carries actual surviving Pokémon')
  mode('SURVIVE_POISON',0);poisoned.hp=1;poisoned.status='PSN';s.vars[Sem.var(s,'poisonSteps')]=3;Steps.flush();Steps.onStepTaken(s,game)
  T.eq(poisoned.hp,0,'classic field poison can faint');T.eq(#Steps._queue,2,'classic poison keeps faint and blackout sequence')
  -- Recreating a boot menu after EXIT retains the HnS new-game module.
  local Boot=require('src.ui.game3.boot');local boot=Boot.new(game);T.eq(boot.custom.mods.newGame,'hns.oak_speech','fresh boot after exit retains Oak intro')
  local vanilla=Boot.new({});T.eq(vanilla.custom.mods.newGame,'src.ui.game3.rse.birch_speech','unowned game keeps Birch intro')
  for i=#saved,1,-1 do local v=saved[i];v.t[v.k]=v.v end
  print('HnS gameplay: real move-category damage/Counter/Hustle context; source Fairy chart/types; multi-hit/confusion Sturdy; Sitrus; EXP/EV/items; poison queue; recreated boot')
end
