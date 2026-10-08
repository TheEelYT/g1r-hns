-- Real native damage/secondary/faint and item teaching paths, with ROM text
-- fixtures and deterministic damage values at the calculation boundary.
return function(T,game,w,s,mon,keep)
  local P=require('src.core.game3.pokemon');local State=require('src.core.game3.battle.state')
  local Engine=require('src.core.game3.battle.engine');local Adapter=require('src.core.game3.battle.adapter')
  local Damage=require('src.core.game3.battle.damage');local Moves=require('src.core.game3.battle.moves')
  local Use=require('src.core.game3.item_use');local Items=require('src.core.game3.items_data')
  local Bag=require('src.core.game3.bag');local Learn=require('src.core.game3.move_learn')
  local Text=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir')
  local X=game._hnsExpandedMoves.moves;local Teaching=game._hnsTeaching.teaching
  local fixtures={STRINGID_PKMNHITWITHRECOIL='Recoil!',STRINGID_ITSUCKEDLIQUIDOOZE='Liquid ooze!',STRINGID_ATTACKMISSED='Missed!',STRINGID_BUTITFAILED='Failed!',
    STRINGID_STATSHARPLY='sharply ',STRINGID_STATROSE='rose!',STRINGID_STATHARSHLY='harshly ',STRINGID_STATFELL='fell!',
    STRINGID_ATTACKERSSTATROSE='{B_ATK_NAME_WITH_PREFIX} {B_BUFF1} {B_BUFF2}',STRINGID_ATTACKERSSTATFELL='{B_ATK_NAME_WITH_PREFIX} {B_BUFF1} {B_BUFF2}',
    STRINGID_STATSWONTINCREASE='Cannot increase!',STRINGID_STATSWONTDECREASE='Cannot decrease!',
    STRINGID_TARGETFAINTED='{B_DEF_NAME_WITH_PREFIX} fainted!',STRINGID_ATTACKERFAINTED='{B_ATK_NAME_WITH_PREFIX} fainted!',
    STRINGID_SUBSTITUTEDAMAGED='Substitute damaged!',STRINGID_PKMNSUBSTITUTEFADED='Substitute faded!',
    gText_PkmnCantLearnMove='Cannot learn.',gText_PkmnAlreadyKnows='Already knows.',gText_PkmnLearnedMove3='Learned!',gText_PkmnNeedsToReplaceMove='Replace a move.',
    gText_WontHaveEffect='No effect.',gText_MoveNotLearned='Did not learn.'}
  for i,n in ipairs({'Attack','Defense','Speed','Sp. Atk','Sp. Def','Accuracy','Evasion'})do fixtures['gStatNamesTable['..i..']']=n end
  for k,v in pairs(fixtures)do keep(Text.overrides,{k});Text.overrides[k]=IR.fromAscii(v)end
  local function battle(name,hp,targetHp,ability,targetAbility,sub)
    local id=assert(X.id(name),name);local p,e=mon(),mon(19)
    p.hp=hp or 50;p.moves={id};p.pp={40};p.ability=ability or 0;e.hp=targetHp or 100;e.ability=targetAbility or 0
    local st=State.new({session=s,wild=true,playerParty={p},foeParty={e}});st.session=s
    st.rng=function(lo,hi)if hi==100 then return 1 end;return hi end
    st.player.type1,st.player.type2=0,0;st.enemy.type1,st.enemy.type2=0,0
    st.enemy.substituteHP=sub
    local ad=Adapter.new(st);return st,ad,id
  end
  keep(Damage,{'calc'});local calc=Damage.calc
  local function hit(name,damage,hp,targetHp,ability,targetAbility,sub)
    local st,ad,id=battle(name,hp,targetHp,ability,targetAbility,sub)
    Damage.calc=function()return damage,{effectiveness=1,physical=true,critical=false}end
    Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    Damage.calc=calc;return st,ad
  end
  for _,case in ipairs({{'DRAINING_KISS',75},{'OBLIVION_WING',75},{'BOUNCY_BUBBLE',100},{'DRAIN_PUNCH',50}})do
    local name,percent=case[1],case[2]
    local st=hit(name,31);T.eq(st.player.mon.hp,50+math.floor(31*percent/100),name..' exact source absorb percentage')
    st=hit(name,100,50,7);T.eq(st.player.mon.hp,50+math.max(1,math.floor(7*percent/100)),name..' caps drain at actual target HP')
    st=hit(name,100,50,100,0,0,9);T.eq(st.enemy.mon.hp,100,name..' leaves body HP behind substitute');T.eq(st.player.mon.hp,50+math.max(1,math.floor(9*percent/100)),name..' drains actual substitute damage')
    st=hit(name,31,50,100,0,64);T.eq(st.player.mon.hp,50-math.floor(31*percent/100),name..' native Liquid Ooze reverses healing')
    st=hit(name,31,99);T.eq(st.player.mon.hp,100,name..' healing cannot exceed max HP')
  end
  for _,name in ipairs({'BRAVE_BIRD','FLARE_BLITZ','WOOD_HAMMER','HEAD_SMASH','WILD_CHARGE','HEAD_CHARGE','LIGHT_OF_RUIN','WAVE_CRASH'})do
    local row=Moves.get(X.id(name));local percent=({HEAD_SMASH=50,LIGHT_OF_RUIN=50,WILD_CHARGE=25,HEAD_CHARGE=25})[name]or 33
    T.eq(row.recoilPercentage,percent,name..' source recoil data')
    local st=hit(name,31);T.eq(st.player.mon.hp,50-math.floor(31*percent/100),name..' exact recoil percentage')
    st=hit(name,100,50,7);T.eq(st.player.mon.hp,50-math.max(1,math.floor(7*percent/100)),name..' capped actual-damage recoil')
    st=hit(name,31,50,100,69);T.eq(st.player.mon.hp,50,name..' native Rock Head prevents recoil')
    st=hit(name,31,50,100,'MAGIC_GUARD');T.eq(st.player.mon.hp,50,name..' named Magic Guard prevents recoil')
    st=hit(name,100,1,7);T.eq(st.player.mon.hp,0,name..' recoil can faint the user after target faint')
  end
  local st,ad,id=battle('DRAINING_KISS');st.rng=function(lo,hi)return hi end
  st.player.stages.accuracy=-6;st.enemy.stages.evasion=6
  Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(st.enemy.mon.hp,100,'miss deals no drain damage');T.eq(st.player.mon.hp,50,'miss does not heal')
  st=hit('DRAINING_KISS',0);T.eq(st.player.mon.hp,50,'zero damage cannot heal')
  for _,case in ipairs({{'ROCK_POLISH','speed'},{'NASTY_PLOT','spAtk'},{'SHELTER','defense'}})do
    st,ad,id=battle(case[1]);Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.player.stages[case[2]],2,case[1]..' dispatches native two-stage boost')
  end
  st,ad,id=battle('HEAL_ORDER',20);Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(st.player.mon.hp,70,'Heal Order uses native half-max healing')
  local stages={QUIVER_DANCE={spAtk=1,spDef=1,speed=1},COIL={attack=1,defense=1,accuracy=1},
    HONE_CLAWS={attack=1,accuracy=1},WORK_UP={attack=1,spAtk=1},COTTON_GUARD={defense=3},
    VICTORY_DANCE={attack=1,defense=1,speed=1},SHELL_SMASH={defense=-1,spDef=-1,attack=2,spAtk=2,speed=2}}
  for name,expected in pairs(stages)do
    st,ad,id=battle(name);st.player.mon.ability=29
    Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    for stat,delta in pairs(expected)do T.eq(st.player.stages[stat],delta,name..' source '..stat..' stages')end
    for stat,delta in pairs(expected)do st.player.stages[stat]=delta<0 and -6 or 6 end
    Engine.clearTurnFlags(st.player);Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    for stat,delta in pairs(expected)do T.eq(st.player.stages[stat],delta<0 and -6 or 6,name..' respects stage limit')end
  end
  for _,r in ipairs(w.teaching.machines)do
    T.eq(Items.toNumericId(r.label),r.itemId,r.label..' stable item mapping')
    T.eq(Items.isTm(r.itemId),true,r.label..' uses native TM workflow')
    T.eq(Items.isHm(r.itemId),r.kind=='HM',r.label..' HM classification')
    T.eq(Items.pocketOf(r.itemId),'TM_CASE',r.label..' source machine pocket')
    T.eq(P.moveFromTmItem(r.itemId),X.id(r.move),r.label..' source move mapping')
  end
  T.eq(P.moveFromTmItem(901),901,'saved Roost item/move IDs remain stable')
  T.eq(P.moveFromTmItem('HM08'),250,'HnS HM08 teaches Whirlpool instead of Dive')
  T.eq(P.isHmMove(250),true,'Whirlpool has native HM forgetting protection');T.eq(P.isHmMove(291),false,'Dive is not an HnS HM')
  T.eq(P.canLearnTmItem(158,'TM60'),false,'Totodile uses source Drain Punch incompatibility')
  T.eq(P.canLearnTmItem(62,'TM60'),true,'Poliwrath uses HnS Drain Punch compatibility')
  T.eq(P.canLearnTmItem(158,'TM85'),false,'Totodile cannot learn Dream Eater')
  local learner=mon(62);learner.moves={};learner.pp={};s.party={learner}
  T.eq(Use.checkTmPreflight(learner,'TM60'),'ok','source expanded machine preflight')
  Bag.add(s.bag,912,2);T.eq(Use.useTm(s,s.bag,912,1),true,'native item-use teaches expanded Drain Punch')
  T.eq(learner.moves[1],X.id('DRAIN_PUNCH'),'native saved move slot has expanded ID')
  T.eq(learner.pp[1],10,'new TM teaching initializes source PP');T.eq(Bag.get(s.bag,912),1,'successful ordinary TM consumes once')
  T.eq(Use.checkTmPreflight(learner,'TM60'),'knows','duplicate TM detected before consumption')
  T.eq(Use.useTm(s,s.bag,912,1),false,'already known TM fails');T.eq(Bag.get(s.bag,912),1,'failed teaching preserves TM')
  learner.moves={901,250,86,150};learner.pp={5,15,20,40}
  Use.useTm(s,s.bag,912,1);T.eq(Bag.get(s.bag,912),1,'declining native full move-list teaching preserves TM')
  T.eq(learner.moves[1],901,'declined teaching preserves existing moves')
  learner.moves={X.id('DRAIN_PUNCH')};learner.pp={10}
  T.eq(Use.checkTmPreflight(learner,'TM56'),'unsupported','unreviewed Fling effect is explicitly unavailable')
  learner.isEgg=true;T.eq(Use.checkTmPreflight(learner,'TM60'),'incompatible','egg cannot use machine');learner.isEgg=false
  -- ROM row fixtures are needed only for native PP; source compatibility and
  -- move replacement still run through the actual native APIs.
  keep(Moves._rom,{250});keep(P._moveNames,{250})
  Moves._rom[250]={effect=0,power=35,type=11,pp=15,accuracy=85,target=0,flags=0};P._moveNames[250]='WHIRLPOOL'
  Bag.add(s.bag,346,1);T.eq(Use.useTm(s,s.bag,346,1),true,'native HM08 teaches Whirlpool');T.eq(Bag.get(s.bag,346),1,'HM is retained after teaching')
  T.eq(Teaching.canTutor(learner,'ICE_PUNCH'),true,'source compatible tutor available to future event bridge')
  T.eq(Teaching.canTutor(learner,'FLING'),false,'unimplemented/non-tutor cannot be taught')
  local Writer=require('src.import.LuaWriter');local reloaded=assert(load(Writer.encode(learner)))()
  T.eq(reloaded.moves[1],X.id('DRAIN_PUNCH'),'expanded taught move persists');T.eq(reloaded.pp[1],10,'expanded source PP persists')
  learner.species=158;learner.level=100;learner.moves={};local list=Learn.relearnableMoves(learner)
  local expected,seen={},{};for _,r in ipairs(P.learnset(158))do if not seen[r[2]]then expected[#expected+1]=r[2];seen[r[2]]=true end end
  T.eq(#list,#expected,'relearner retains complete source level-up list');T.eq(list[#list],expected[#expected],'relearner includes final source row')
  local extended=false
  for species in pairs(X.species)do
    local rows=P.learnset(species)
    if #rows>20 then
      local seen,count={},0
      for _,r in ipairs(rows)do if not seen[r[2]]then seen[r[2]]=true;count=count+1 end end
      if count>20 then
        learner.species=species
        T.eq(#Learn.relearnableMoves(learner),count,'source relearner removes native twenty-row truncation');extended=true;break
      end
    end
  end
  T.eq(extended,true,'native species fixture covers over twenty distinct source level-up moves')
  print('Move expansion: exact absorb/recoil, substitute/faint/ability behavior, ordered setup stages, 100 source machines, native teaching and tutor compatibility')
end
