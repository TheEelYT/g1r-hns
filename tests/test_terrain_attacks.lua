-- Installed rows through native damage, hit, move-end and turn-order paths.
return function(T,game,w,s,mon,keep)
  local X=game._hnsExpandedMoves.moves;local F=game._hnsFields.fields
  local State=require('src.core.game3.battle.state');local Adapter=require('src.core.game3.battle.adapter')
  local Engine=require('src.core.game3.battle.engine');local Moves=require('src.core.game3.battle.moves')
  local Damage=require('src.core.game3.battle.damage');local Text=require('src.core.game3.rom_text')
  local IR=require('src.core.game3.scripting.text_ir');local B=require('src.core.game3.battle')
  local fixtures={STRINGID_PKMNPREVENTSUSAGE='Damp prevents the move!',STRINGID_PKMNPROTECTEDITSELF='Protected!',
    STRINGID_PKMNHURTBY='Contact damage!',STRINGID_PKMNSXHURTIT='Contact damage!',STRINGID_PKMNTOOKFOE='Destiny Bond!',
    STRINGID_PKMNREGAINEDHEALTH='Recovered!',STRINGID_PKMNSABSORBEDATTACK='Absorbed!',
    STRINGID_PKMNRESTOREDHPUSING='Absorbed!',STRINGID_PKMNHURTSWITH='Contact damage!'}
  for k,v in pairs(fixtures)do keep(Text.overrides,{k});Text.overrides[k]=IR.fromAscii(v)end
  local function battle(name,terrain,double)
    local id=assert(X.id(name),name);local p,e=mon(),mon(19)
    p.moves={id};p.pp={40};p.hp=100;e.hp=100;p.ability=0;e.ability=0
    local st=State.new({session=s,wild=true,double=double,playerParty={p,mon()},foeParty={e,mon(19)}});st.session=s
    st.rng=function(lo,hi)if hi==100 then return 1 end;return hi end
    for _,b in ipairs(State.present(st))do b.type1,b.type2=0,0;b.ability=0;b.mon.ability=0 end
    st.hnsTerrain=terrain;st.hnsTerrainTurns=terrain and 5 or 0
    return st,Adapter.new(st),id
  end
  local function power(name,terrain,userAir,targetAir)
    local st,ad,id=battle(name,terrain);st.player.type1=userAir and 2 or 0;st.enemy.type1=targetAir and 2 or 0
    local _,info=Damage.calc(st.player,st.enemy,id,{adapter=ad,noCrit=true,noRandom=true})
    return info.power,info.moveType
  end
  for _,r in ipairs({{'ELECTRIC',13,130},{'GRASSY',12,130},{'MISTY',18,100},{'PSYCHIC',14,130}})do
    local p,t=power('TERRAIN_PULSE',r[1]);T.eq(p,r[3],r[1]..' Terrain Pulse doubles then applies type boost');T.eq(t,r[2],r[1]..' Terrain Pulse type')
    p,t=power('TERRAIN_PULSE',r[1],true);T.eq(p,50,'airborne Pulse stays at base power');T.eq(t,0,'airborne Pulse stays Normal')
  end
  local p,t=power('TERRAIN_PULSE');T.eq(p,50,'Pulse without terrain stays at base power');T.eq(t,0,'Pulse without terrain stays Normal')
  T.eq(power('RISING_VOLTAGE','ELECTRIC'),182,'Voltage doubles for grounded defender then receives grounded attacker bonus')
  T.eq(power('RISING_VOLTAGE','ELECTRIC',false,true),91,'Voltage does not double for airborne defender')
  T.eq(power('RISING_VOLTAGE','ELECTRIC',true,false),140,'airborne Voltage still doubles for grounded defender')
  T.eq(power('EXPANDING_FORCE','PSYCHIC'),156,'grounded Force applies both separate source boosts')
  T.eq(power('EXPANDING_FORCE','PSYCHIC',true),80,'airborne Force receives neither boost')
  T.eq(power('PSYBLADE','ELECTRIC',true,true),120,'Psyblade does not require either battler to be grounded')
  T.eq(power('MISTY_EXPLOSION','MISTY'),150,'grounded Misty Explosion receives its source boost')
  T.eq(power('MISTY_EXPLOSION','MISTY',true),100,'airborne Misty Explosion stays unboosted')
  local st,ad,id=battle('TERRAIN_PULSE','ELECTRIC');st.enemy.ability=10;st.enemy.mon.hp=50
  Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(st.enemy.mon.hp,75,'Pulse changes type before native Volt Absorb handling');T.eq(st.player.mon.pp[1],39,'absorbed Pulse consumes one PP')
  st,ad,id=battle('MISTY_EXPLOSION','MISTY');Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(st.player.mon.hp,0,'Misty Explosion faints the user');T.check(st.enemy.mon.hp<100,'Misty Explosion damages the target')
  st,ad,id=battle('MISTY_EXPLOSION','MISTY');st.enemy.ability=6
  Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(st.player.mon.hp,100,'native Damp prevents Misty Explosion self-faint');T.eq(st.enemy.mon.hp,100,'Damp prevents damage');T.eq(st.player.mon.pp[1],39,'Damp-blocked explosion consumes PP')
  for _,air in ipairs({false,true})do
    st,ad,id=battle('EXPANDING_FORCE','PSYCHIC',true);st.player.type1=air and 2 or 0
    Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.check(st.enemy.mon.hp<100,'Force hits selected foe')
    T.eq(State.battler(st,3).mon.hp<100,not air,'Force hits both foes only when grounded in Psychic terrain')
    T.eq(State.battler(st,2).mon.hp,100,'Force leaves ally unharmed');T.eq(st.player.mon.pp[1],39,'spread Force consumes PP only once')
  end
  st,ad,id=battle('MISTY_EXPLOSION','MISTY',true)
  Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  for _,b in ipairs(State.present(st))do T.check(b.mon.hp<100,'Misty Explosion damages both foes and ally, then user faints')end
  T.eq(st.player.mon.pp[1],39,'spread explosion consumes PP only once')
  for _,name in ipairs({'STEEL_ROLLER','ICE_SPINNER'})do
    st,ad,id=battle(name,'ELECTRIC');Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrain,nil,name..' removes terrain after damage');T.eq(st.hnsTerrainTurns,0,name..' clears the terrain timer')
    st,ad,id=battle(name,'ELECTRIC');st.enemy.expProtected=true;Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrain,'ELECTRIC',name..' cannot remove terrain through Protect');T.eq(st.enemy.mon.hp,100,'Protect prevents terrain-removing damage')
    st,ad,id=battle(name,'ELECTRIC');st.player.stages.accuracy=-6;st.enemy.stages.evasion=6;st.rng=function(lo,hi)return hi end
    Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrain,'ELECTRIC',name..' miss cannot remove terrain')
    st,ad,id=battle(name,'ELECTRIC');st.enemy.substituteHP=1;Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.hnsTerrain,nil,name..' removes terrain through substitute damage');T.eq(st.enemy.mon.hp,100,'substitute protects body HP')
    st,ad,id=battle(name,'ELECTRIC');st.player.mon.hp=1;st.enemy.ability=24
    Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
    T.eq(st.player.mon.hp,0,name..' native Rough Skin can faint the user')
    T.eq(st.hnsTerrain,name=='ICE_SPINNER'and'ELECTRIC'or nil,name..' source removal depends on surviving contact only for Spinner')
  end
  st,ad,id=battle('STEEL_ROLLER');Engine.resolveMove(st.player,st.enemy,id,1,ad,st,{})
  T.eq(st.enemy.mon.hp,100,'Steel Roller fails without terrain');T.eq(st.player.mon.pp[1],39,'failed Steel Roller consumes PP')
  local V=game._hnsBattleVisuals.visuals;keep(B,{'_st'})
  st,ad,id=battle('GRASSY_GLIDE','GRASSY');B._st=st
  local field=V.fieldBackground();T.eq(field.full.file,'battle/field_GRASSY.rgba','active terrain selects actual source field backdrop')
  F.remove(ad);T.eq(V.fieldBackground(),nil,'terrain removal restores ordinary arena backdrop')
  st.hnsTerrain='GRASSY';st.hnsTerrainTurns=1;Engine.collectResidualEvents(st,ad);T.eq(V.fieldBackground(),nil,'terrain expiry restores arena backdrop')
  for _,r in ipairs({{'GRASSY',false,33,0},{nil,false,33,1},{'GRASSY',true,33,1},{'GRASSY',false,98,1}})do
    st,ad,id=battle('GRASSY_GLIDE',r[1]);st.player.type1=r[2]and 2 or 0
    st.player.mon.speed=10;st.enemy.mon.speed=100;st.enemy.mon.moves={r[3]};st.enemy.mon.pp={40}
    local actions=Engine.planTurnFromActions(st,ad,{kind='move',move=id,slot=1},{kind='move',move=r[3],slot=1})
    T.eq(actions[1].battler,r[4],'Glide source priority and speed ties affect actual native turn order')
  end
  st,ad,id=battle('GRASSY_GLIDE','GRASSY',true)
  local chosen={}
  for _,b in ipairs(State.present(st))do
    b.mon.speed=b.id==0 and 10 or 100;b.mon.moves={b.id==0 and id or 33};b.mon.pp={40}
    chosen[b.id]={kind='move',move=b.mon.moves[1],slot=1}
  end
  local actions=Engine.planTurnActions(st,ad,chosen)
  T.eq(actions[1].battler,0,'grounded Glide priority affects actual double-battle action sorting')
  T.eq(X.id('SPLINTERED_STORMSHARDS'),nil,'unported Z move is not exposed as an ordinary learnable attack')
  print('Terrain attacks: actual dynamic damage/type, absorption, spread, Damp/self-faint, successful-hit removal, contact survival and native priority')
end
