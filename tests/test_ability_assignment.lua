return function(T,game,w,s,setting)
  local A=game._hnsAbilities.abilities;local P=require('src.core.game3.pokemon');local Party=require('src.core.game3.party')
  local State=require('src.core.game3.battle.state');local C=require('src.core.game3.constants').of('emerald');local Writer=require('src.import.LuaWriter');local count=0
  for name,row in pairs(w.abilities.species)do
    local sp=C:require('species','SPECIES_'..name)
    for _,mode in ipairs({0,1})do
      setting('ITEM_MODE_LEGENDARY_ABILITIES',mode)
      for _,slot in ipairs({0,1,2,3,255})do
        local key=slot==0 and mode==1 and w.abilities.legendary[name]or row.slots[slot+1]
        if not key or key=='NONE'then
          if slot>=2 then for i=3,#row.slots do if row.slots[i]~='NONE'then key=row.slots[i];break end end end
          if not key or key=='NONE'then for _,n in ipairs(row.slots)do if n~='NONE'then key=n;break end end end
        end
        local id,n=A.resolve(sp,slot,s);T.eq(id,w.abilities.records[key or'NONE'].id,'source ability slot '..name..slot..mode);T.eq(n,key or'NONE','source slot name '..name..slot..mode);count=count+1
      end
    end
  end
  T.eq(count,3860,'all source species and fallback slots exercised');setting('ITEM_MODE_LEGENDARY_ABILITIES',1)
  local ok,code,mon=Party.giveMon(s,C:require('species','SPECIES_BULBASAUR'),5,'',{})
  T.check(ok,'native gift succeeds');T.eq(mon.ability,A.spec.records.OVERGROW.id,'native gift gets source normal ability')
  A.sync(mon,s,2);T.eq(mon.ability,A.spec.records.CHLOROPHYLL.id,'source hidden slot applies to native mon')
  local copied=assert(load(Writer.encode(mon)))();T.eq(copied.abilityNum,2,'hidden slot survives serialization')
  local captured={species=mon.species,ability=mon.ability};A.sync(captured,s);T.eq(captured.abilityNum,2,'captured hidden identity recovers its source slot')
  local storage=s.storage;s.storage={boxes={{mons={[5]=copied}}}};copied.ability=0;A.migrate(s);T.eq(copied.ability,A.spec.records.CHLOROPHYLL.id,'sparse PC slots migrate correctly');s.storage=storage
  local b=State.makeBattler(copied,'player');T.eq(b.ability,A.spec.records.CHLOROPHYLL.id,'hidden slot survives native battle construction')
  local pending={species=C:require('species','SPECIES_TOTODILE'),personality=1,abilityNum=2,ability=0}
  A.sync(pending,s);T.eq(pending.ability,A.spec.records.SHEER_FORCE.id,'pending effect retains true source identity');T.eq(P.abilityName(pending.ability),A.spec.records.SHEER_FORCE.name,'pending source name displays without ROM lookup')
  local legacy={species=C:require('species','SPECIES_RATTATA'),personality=0,ability=62};A.sync(legacy,s)
  T.eq(legacy.abilityNum,1,'old secondary ability migrates to source slot');T.eq(legacy.ability,A.spec.records.GUTS.id,'migration keeps secondary identity')
  local art={species=C:require('species','SPECIES_ARTICUNO'),personality=0,abilityNum=0,ability=0};s.party[#s.party+1]=art
  setting('ITEM_MODE_LEGENDARY_ABILITIES',0);A.migrate(s);T.eq(art.ability,A.spec.records.PRESSURE.id,'legendary OFF restores original slot')
  setting('ITEM_MODE_LEGENDARY_ABILITIES',1);A.migrate(s);T.eq(art.ability,A.spec.records.WATER_VEIL.id,'legendary ON applies source override')
  table.remove(s.party,#s.party);table.remove(s.party,#s.party)
end
