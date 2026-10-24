return function(T,game,w,s,mon,setting)
  local S=game._hnsLeadEncounters.encounters;local A=game._hnsAbilities.abilities
  local P=require('src.core.game3.pokemon');local Rng=require('src.core.game3.rng')
  local B=require('src.core.game3.battle');local C=require('src.core.game3.battle.catching')
  local Writer=require('src.import.LuaWriter')
  local party,dex=s.party,s.dex;local oldRng=Rng.getState();local originalRandom=Rng.Random
  local Moves=require('src.core.game3.battle.moves');local savedMoves={};for k,v in pairs(Moves)do savedMoves[k]=v end
  local savedNames={};for k,v in pairs(Moves.BY_NUM)do savedNames[k]=v end
  local cache={read=function(_,path)if path:match('/pokemon/battle_moves%.lua$')then return Writer.encode({moves=Moves._rom})end end}
  local prior={};for k,v in pairs(B)do prior[k]=v end
  B._active=false
  local lead=mon(63);lead.personality=137;lead.abilityNum=0;lead.hp=0;A.sync(lead,s,0)
  s.party={lead,mon(158)}
  local got,ab=S.lead(s);T.eq(got,lead,'field abilities use fainted first slot rather than healthy follower lead');T.eq(ab,'SYNCHRONIZE','field ability resolves source slot')
  for _,mode in ipairs({0,1})do
    setting('ITEM_MODE_SYNCHRONIZE',mode);local hits=0
    for roll=0,5 do Rng.Random=function()return roll end
      if S.nature('wild',s)==12 then hits=hits+1 end
      T.eq(S.nature('static',s),(mode==1 or roll%2==1)and 12 or nil,'classic/static Synchronize source gate')
      T.eq(S.nature('gift',s),nil,'gifts do not Synchronize');T.eq(S.nature('roamer',s),nil,'roamers do not Synchronize')
    end
    T.eq(hits,mode==1 and 6 or 3,'Synchronize classic half-chance and modern guarantee')
  end
  Rng.Random=originalRandom;setting('ITEM_MODE_SYNCHRONIZE',1)
  lead.isEgg=true;T.eq(S.nature('wild',s),nil,'egg in first slot cannot Synchronize');lead.isEgg=nil
  s.party={mon(158),lead};T.eq(S.nature('wild',s),nil,'bench Synchronize cannot affect encounters');s.party={lead,mon(158)}
  local opts={session=s,wild=true,headless=true,autoFight=false,cache=cache,playerParty=s.party,foe={species=19,level=8,moves={33},ivs={hp=9,atk=8,def=7,spe=6,spa=5,spd=4}}}
  Rng.SeedRng(1234);local prepared=S.prepare(opts)
  T.check(prepared~=opts and prepared.foe~=opts.foe,'owned encounter preparation copies caller tables')
  T.eq(opts.foe.personality,nil,'caller encounter is not mutated');T.eq(prepared.foe.personality%25,12,'prepared PID has source lead nature')
  T.eq(B.start(opts),true,'actual native wild battle starts with Synchronize')
  local st=B.getState();local enemy=st.enemy.mon
  T.eq(enemy.personality%25,12,'actual native enemy receives synchronized PID')
  T.eq(enemy.nature,12,'native nature agrees with synchronized personality')
  T.eq(enemy.gender,P.gender(19,enemy.personality),'native gender derives from final personality')
  T.eq(enemy.ivs.hp,9,'prescribed IVs survive source nature selection')
  local stats=P.calcStats(19,8,enemy.ivs,enemy.evs,enemy.personality)
  T.eq(enemy.spAtk,stats.spAtk,'native stats are calculated after final personality selection')
  local pid=enemy.personality;local before=#s.party;local result=C.storeCaught(s,st.enemy,4)
  T.check(result~=nil,'native capture storage accepts synchronized wild mon')
  local caught=s.party[#s.party];T.eq(#s.party,before+1,'capture is stored in actual party')
  T.eq(caught.personality,pid,'capture retains generated PID');local reload=assert(load(Writer.encode(caught)))()
  T.eq(reload.personality,pid,'captured synchronized PID survives serialization')
  B.reset();s.party={lead,mon(158)}
  -- Rejected paths must preserve both objects and RNG, including fixed PIDs.
  local function delegated(extra,foe)
    local o={session=s,wild=true,headless=true,autoFight=false,cache=cache,playerParty=s.party,foe=foe or{species=19,level=8}}
    for k,v in pairs(extra or{})do o[k]=v end
    Rng.SeedRng(21);local state=Rng.getState();T.eq(S.prepare(o),o,'excluded encounter delegates unchanged')
    T.eq(Rng.getState().value,state.value,'excluded encounter consumes no lead RNG')
  end
  delegated({wild=false});delegated({link=true});delegated({roamer=true});delegated({safari=true});delegated({pyramid=true});delegated({pike=true});delegated({oldManTutorial=true});delegated({firstBattleKind='test'})
  delegated({}, {species=19,personality=123});delegated({}, {species=19,nature=8});delegated({}, {species=19,gender='F'})
  local map=s.map;s.map='EM_ROUTE101';delegated({});s.map=map
  local lead=mon(35);lead.personality=255;A.assign(lead,'CUTE_CHARM');s.party={lead,mon(158)}
  local hits=0
  for roll=0,5 do Rng.Random=function()return roll end
    if S.gender('wild',19,s)=='F'then hits=hits+1 end
    for _,species in ipairs({81,32,29})do T.eq(S.gender('wild',species,s),nil,'Cute Charm guards fixed-gender species '..species)end
  end
  T.eq(hits,4,'Cute Charm source gate succeeds in two of three residues')
  Rng.Random=originalRandom;lead.personality=0;Rng.SeedRng(43)
  local gender=S.gender('wild',19,s);T.check(gender==nil or gender=='M','female Cute Charm lead requests opposite gender')
  lead.isEgg=true;T.eq(S.gender('wild',19,s),nil,'egg cannot activate Cute Charm');lead.isEgg=nil
  local cute=lead;local genderless=mon(81);A.assign(genderless,'CUTE_CHARM');s.party={genderless,cute}
  Rng.Random=function()return 1 end;T.eq(S.gender('wild',19,s),nil,'genderless Cute Charm lead cannot request impossible gender')
  s.party={cute,mon(158)};Rng.Random=originalRandom
  for _,seed in ipairs({1,7,23,56,120})do
    Rng.SeedRng(seed);local opts={session=s,wild=true,headless=true,autoFight=false,cache=cache,playerParty=s.party,foe={species=19,level=8,moves={33}}}
    T.eq(B.start(opts),true,'native Cute Charm encounter starts')
    local e=B.getState().enemy.mon;T.eq(e.gender,P.gender(19,e.personality),'Cute Charm native gender/PID remain consistent');B.reset()
  end
  setting('ITEM_MODE_SYNCHRONIZE',1);s.party=party;s.dex=dex;Rng.Random=originalRandom;Rng.setState(oldRng)
  for k in pairs(Moves)do Moves[k]=nil end;for k,v in pairs(savedMoves)do Moves[k]=v end
  for k in pairs(Moves.BY_NUM)do Moves.BY_NUM[k]=nil end;for k,v in pairs(savedNames)do Moves.BY_NUM[k]=v end
  for k in pairs(B)do B[k]=nil end;for k,v in pairs(prior)do B[k]=v end
end
