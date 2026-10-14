return function(T,game,w,s,mon,keep)
  local X=game._hnsExpandedMoves.moves;local F=game._hnsFields.fields
  local State=require('src.core.game3.battle.state');local Adapter=require('src.core.game3.battle.adapter')
  local Engine=require('src.core.game3.battle.engine');local Moves=require('src.core.game3.battle.moves')
  local P=require('src.core.game3.pokemon');local Damage=require('src.core.game3.battle.damage')
  local Secondary=require('src.core.game3.battle.effects.secondary');local Items=require('src.core.game3.items_data')
  local Text=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir')
  local fixtures={STRINGID_BUTITFAILED='Failed!',STRINGID_SUNLIGHTGOTBRIGHT='Sunlight!',STRINGID_STARTEDTORAIN='Rain!',STRINGID_STARTEDHAIL='Hail!',STRINGID_SANDSTORMBREWED='Sandstorm!',
    STRINGID_RAINCONTINUES='Rain continues!',STRINGID_RAINSTOPPED='Rain stopped!',STRINGID_PKMNREGAINEDHEALTH='Healed!',STRINGID_ATTACKMISSED='Missed!'}
  for k,v in pairs(fixtures)do keep(Text.overrides,{k});Text.overrides[k]=IR.fromAscii(v)end
  local function battle(name,item)
    local p,e=mon(),mon(19);local id=X.id(name)or tonumber(name)
    p.moves={id};p.pp={40};p.heldItem=item;p.hp=50
    local st=State.new({session=s,wild=true,playerParty={p},foeParty={e}});st.session=s
    st.rng=function(lo,hi)if hi==100 then return 1 end;return hi end
    st.player.type1,st.player.type2=0,0;st.enemy.type1,st.enemy.type2=0,0
    return st,Adapter.new(st),id
  end
  for _,kind in ipairs({'GRASSY','ELECTRIC','MISTY','PSYCHIC'})do
    local st,ad,id=battle(kind..'_TERRAIN')
    T.check(id~=nil,kind..' source move enabled');T.eq(Moves.get(id).sourceEffect,kind..'_TERRAIN',kind..' retains source effect')
    T.eq(w.moveTable.moves[kind..'_TERRAIN'].target,'FIELD',kind..' retains original field target')
    Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrain,kind,kind..' actual move sets terrain');T.eq(st.hnsTerrainTurns,5,kind..' default duration')
    st.hnsTerrainTurns=3;Engine.clearTurnFlags(st.player);Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrainTurns,3,kind..' duplicate terrain fails without refreshing')
    st.hnsTerrainTurns=5
    for turn=1,5 do Engine.collectResidualEvents(st,ad);T.eq(st.hnsTerrainTurns,5-turn,kind..' decrements once per full native turn')end
    T.eq(st.hnsTerrain,nil,kind..' expires on fifth turn')
    if kind=='GRASSY'then T.eq(st.player.mon.hp,80,'Grassy terrain heals five times for maxHP/16')end
    st,ad,id=battle(kind..'_TERRAIN',949);Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrainTurns,8,kind..' Terrain Extender adds three turns')
    st.isSkyBattle=true;st.hnsTerrain=nil;Engine.clearTurnFlags(st.player);Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrain,nil,'terrain fails in source sky battle')
  end
  local st,ad,id=battle('ELECTRIC_TERRAIN');Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(ad:applyStatus(st.enemy,'SLP',st.player),false,'Electric prevents grounded sleep')
  T.eq(ad:applyStatus(st.enemy,'SLP',st.player,{force=true}),false,'Electric prevents forced Yawn-like sleep')
  st.enemy.type1=2;T.eq(ad:applyStatus(st.enemy,'SLP',st.player),true,'airborne target can sleep under Electric');ad:clearStatus(st.enemy)
  st.enemy.type1=0;st.enemy.ability=26;T.eq(ad:applyStatus(st.enemy,'SLP',st.player),true,'Levitate bypasses grounded sleep protection');ad:clearStatus(st.enemy);st.enemy.ability=0
  st.hnsTerrain='MISTY'
  for _,status in ipairs({'BRN','PAR','PSN','TOX','FRZ','SLP'})do T.eq(ad:applyStatus(st.enemy,status,st.player),false,'Misty prevents '..status)end
  local ctx=Engine.newContext(st.player,st.enemy,id,1,ad,st,{},{hits={}},{});ctx.move=Moves.get(id)
  T.eq(Secondary.set(ctx,'CONFUSION',true,false,false),false,'Misty prevents direct and secondary confusion');T.eq(st.enemy.confusionTurns,nil,'Misty does not set confusion counter')
  st.enemy.type1=2;T.eq(ad:applyStatus(st.enemy,'PAR',st.player),true,'Misty does not protect Flying target');ad:clearStatus(st.enemy)
  st.enemy.rooted=true;T.eq(ad:applyStatus(st.enemy,'PAR',st.player),false,'Ingrain grounds Flying target for terrain');st.enemy.rooted=false;st.enemy.type1=0
  local weather=require('src.core.game3.battle.effects.weather')
  for _,r in ipairs({{'rainy',945},{'sunny',946},{'sandstorm',947},{'hail',948}})do
    st,ad,id=battle('GRASSY_TERRAIN',r[2]);weather[r[1]]({adapter=ad,user=st.player,target=st.player})
    T.eq(st.weatherTurns,8,r[1]..' source duration rock extends actual weather')
    st.weatherTurns=2;weather[r[1]]({adapter=ad,user=st.player,target=st.player});T.eq(st.weatherTurns,2,r[1]..' failed repeat cannot reset duration')
    st,ad,id=battle('GRASSY_TERRAIN');weather[r[1]]({adapter=ad,user=st.player,target=st.player});T.eq(st.weatherTurns,5,r[1]..' no rock keeps five turns')
  end
  -- Real native damage formula, with only an absent ROM row supplied.
  keep(Moves._rom,{85,98,89});keep(P._moveNames,{85,98,89})
  for num,r in pairs({[85]={power=90,type=13,pp=15,accuracy=100,priority=0},[98]={power=40,type=0,pp=30,accuracy=100,priority=1},[89]={power=100,type=4,pp=10,accuracy=100,priority=0}})do r.effect=0;r.target=0;r.flags=0;Moves._rom[num]=r;P._moveNames[num]='MOVE'end
  st,ad,id=battle(85);local opts={adapter=ad,noCrit=true,noRandom=true}
  local base=Damage.calc(st.player,st.enemy,85,opts)
  st.hnsTerrain='ELECTRIC';local boosted,info=Damage.calc(st.player,st.enemy,85,opts)
  T.eq(info.power,117,'source fixed-point terrain bonus changes power before damage');T.check(boosted>base,'actual Electric damage boosted')
  st.player.type1=2;local airborne=Damage.calc(st.player,st.enemy,85,opts);T.eq(airborne,base,'airborne attacker receives no type boost');st.player.type1=0
  st.hnsTerrain='GRASSY';local _,quake=Damage.calc(st.player,st.enemy,89,opts);T.eq(quake.power,50,'Grassy halves Earthquake base power')
  st,ad,id=battle(98);st.hnsTerrain='PSYCHIC';Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(st.enemy.mon.hp,100,'actual Psychic terrain blocks grounded Quick Attack');T.eq(st.player.mon.pp[1],39,'blocked priority still consumes PP')
  st.enemy.type1=2;Engine.clearTurnFlags(st.player);Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.check(st.enemy.mon.hp<100,'Psychic allows priority attack against airborne target')
  for name,r in pairs(w.battleFields.items)do T.eq(Items.info(r.index).name,r.record.name,name..' registered bag/held item metadata')end
  local foreign={session={map='EM_LITTLEROOT_TOWN'},hnsTerrain='MISTY'}
  T.eq(F.terrain(foreign),false,'terrain effects are scoped to HnS')
  print('Source terrains: actual setup, grounded status/damage/priority, healing/expiry, and duration items')
end
