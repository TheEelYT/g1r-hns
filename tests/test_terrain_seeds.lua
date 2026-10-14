return function(T,game,w,s,mon,keep)
  local F=game._hnsFields.fields;local A=game._hnsAbilities.abilities
  local State=require('src.core.game3.battle.state');local Adapter=require('src.core.game3.battle.adapter')
  local Engine=require('src.core.game3.battle.engine');local Ab=require('src.core.game3.battle.abilities')
  local Held=require('src.core.game3.battle.held_items');local P=require('src.core.game3.pokemon')
  local Text=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir')
  local Schema=require('src.core.game3.save_mon')
  keep(Text.overrides,{'STRINGID_USINGITEMSTATOFPKMNROSE'})
  Text.overrides.STRINGID_USINGITEMSTATOFPKMNROSE=IR.fromAscii('{B_SCR_ACTIVE_NAME_WITH_PREFIX} used {B_LAST_ITEM}!')
  local function battle(seed,ability,double)
    local p,e=mon(),mon(19);p.heldItem=seed;p.hp=100;p.ability=0;e.ability=0
    if ability then T.eq(A.assign(p,ability),true,'reviewed ability can be explicitly assigned')end
    local st=State.new({session=s,wild=true,double=double,playerParty={p,mon()},foeParty={e,mon(19)}});st.session=s
    st.rng=function(lo,hi)if hi==100 then return 1 end;return hi end
    for _,b in ipairs(State.present(st))do b.type1,b.type2=0,0 end
    return st,Adapter.new(st),p
  end
  for name,r in pairs(w.battleFields.items)do
    if r.terrain then
      for _,air in ipairs({false,true})do
        local st,ad,p=battle(r.index);st.hnsTerrain=r.terrain;st.player.type1=air and 2 or 0
        T.eq(Held.normal(ad,st.player,true),true,name..' activates through native item callback')
        T.eq(st.player.stages[r.stat],1,name..' source stat increased even for airborne holder')
        T.eq(st.player.item,0,name..' clears battler held item');T.eq(p.heldItem,nil,name..' consumes persistent party held item')
        T.eq(st.player.expUsedHeldItem,r.index,name..' preserves native consumed-item record')
        T.eq(Held.normal(ad,st.player,true),false,name..' does not activate a second time')
      end
      local st,ad,p=battle(r.index);st.hnsTerrain=r.terrain;st.player.stages[r.stat]=6
      T.eq(Held.normal(ad,st.player,true),false,name..' capped stat keeps seed');T.eq(p.heldItem,r.index,name..' capped seed remains in party')
      st.player.stages[r.stat]=0;st.hnsTerrain='OTHER'
      T.eq(Held.normal(ad,st.player,true),false,name..' nonmatching terrain keeps seed')
      st.hnsTerrain=r.terrain;st.player.mon.hp=0;T.eq(Held.normal(ad,st.player,true),false,name..' fainted holder keeps seed')
      st,ad,p=battle(r.index);st.hnsTerrain=r.terrain
      Engine.switchInEffects(st,ad,st.player)
      T.eq(p.heldItem,nil,name..' native switch-in activates matching seed')
    end
  end
  for name,kind in pairs(w.abilities.surges)do
    local st,ad,p=battle(949,name)
    T.eq(ad:abilityOf(st.player),name,name..' numeric saved identity resolves through native adapter')
    T.eq(Ab.id(name),p.ability,name..' native formatter uses stable custom ability ID')
    T.eq(P.abilityName(p.ability),w.abilities.records[name].name,name..' source display name')
    Schema.normalize(p);T.eq(ad:abilityOf(st.player),name,name..' survives actual native save-mon normalization')
    Engine.battleStartEffects(st,ad)
    T.eq(st.hnsTerrain,kind,name..' real battle-start callback sets terrain');T.eq(st.hnsTerrainTurns,8,name..' Extender grants eight turns')
    st.hnsTerrainTurns=2;Ab.switchIn(ad,st.player);T.eq(st.hnsTerrainTurns,2,name..' matching terrain does not reset timer')
    st.hnsTerrain=nil;st.isSkyBattle=true;T.eq(Ab.switchIn(ad,st.player),false,name..' sky battle blocks terrain')
    st.isSkyBattle=false;st.player.expAbilitySuppressed=true;T.eq(Ab.switchIn(ad,st.player),false,name..' suppressed ability does not activate');st.player.expAbilitySuppressed=nil
    st,ad,p=battle(nil,name);Engine.switchInEffects(st,ad,st.player);T.eq(st.hnsTerrainTurns,5,name..' ordinary switch-in sets five turns')
    local foreign={session={map='EM_LITTLEROOT_TOWN'},player=st.player,enemy=st.enemy}
    T.eq(Ab.switchIn(Adapter.new(foreign),st.player),false,name..' effect is scoped to HnS')
  end
  local st,ad,p=battle(951,'GRASSY_SURGE',true)
  st.enemy.item=951;st.enemy.mon.heldItem=951
  Engine.battleStartEffects(st,ad)
  T.eq(p.heldItem,nil,'Surge immediately consumes own matching seed')
  T.eq(st.enemy.mon.heldItem,nil,'Surge immediately consumes opposing matching seed')
  T.eq(st.enemy.stages.defense,1,'Surge raises opposing seed holder stat')
  T.eq(A.assign(p,'HADRON_ENGINE'),false,'pending ability cannot be assigned as a plain Surge')
  T.eq(A.id('HADRON_ENGINE'),nil,'pending ability is explicitly excluded from assignment API')
  print('Seeds/Surges: native item consumption/persistence, airborne/capped/fainted holders, entry callbacks, numeric identities, suppression, sky and scope checks')
end
