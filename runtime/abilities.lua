-- Scoped ability identity bridge; pending effects are never assigned by this API.
return function(mod,w,game)
  local old=game._hnsAbilities or {};local H=game._hnsRules.rules;local A={spec=w.abilities,byId={}}
  local P=require('src.core.game3.pokemon');local Ab=require('src.core.game3.battle.abilities');local Adapter=require('src.core.game3.battle.adapter')
  for name,r in pairs(A.spec.records)do A.byId[r.id]={name=name,row=r}end
  function A.id(name)local r=A.spec.records[name];return r and r.support~='pending'and r.id or nil end
  function A.assign(mon,name)
    local id=A.id(name);if not id then return false end
    mon.ability=id;mon.abilityId=id;mon.hnsAbilityOverride=true;return true
  end
  local C=require('src.core.game3.constants').of('emerald');local State=require('src.core.game3.battle.state');local Party=require('src.core.game3.party')
  local Rt=require('src.core.game3.runtime');A.species={};A.speciesNames={}
  for key,row in pairs(A.spec.species)do local id=C:require('species','SPECIES_'..key);A.species[id]=row;A.speciesNames[id]=key end
  for key,id in pairs(C.species.byName)do if key:match('^SPECIES_UNOWN_')then A.species[id]=A.species[C:require('species','SPECIES_UNOWN')];A.speciesNames[id]='UNOWN'end end
  function A.resolve(species,slot,s)
    local row=A.species[species];if not row then return end
    slot=tonumber(slot)or 0;local key=row.slots[slot+1]
    if slot==0 and H.value('ITEM_MODE_LEGENDARY_ABILITIES',s)==1 then key=A.spec.legendary[A.speciesNames[species]]or key end
    if not key or key=='NONE'then
      if slot>=A.spec.normalSlots then for i=A.spec.normalSlots+1,#row.slots do if row.slots[i]~='NONE'then key=row.slots[i];break end end end
      if not key or key=='NONE'then for _,n in ipairs(row.slots)do if n~='NONE'then key=n;break end end end
    end
    return A.spec.records[key or 'NONE'].id,key or 'NONE'
  end
  local pair=old.pair or P.abilities;local abilityId=old.abilityId or P.abilityId
  P.abilities=function(species)
    local row=H.battle()and A.species[tonumber(species)]
    if row then local ids={};for i,n in ipairs(row.slots)do ids[i]=A.spec.records[n].id end;return ids end
    return pair(species)
  end
  P.abilityId=function(species,personality)
    if H.battle()and A.species[tonumber(species)]then return A.resolve(tonumber(species),(tonumber(personality)or 0)%2)end
    return abilityId(species,personality)
  end
  function A.sync(mon,s,slot)
    if type(mon)~='table'or mon.hnsAbilityOverride then return mon end
    local species=P.speciesOf(mon);if not A.species[species]then return mon end
    slot=tonumber(slot)or tonumber(mon.abilityNum)or tonumber(mon.hnsAbilitySlot)
    if not slot then
      slot=(tonumber(mon.personality)or 0)%2
      local legacy=pair(species);local id=mon.ability or mon.abilityId
      local second=A.spec.records[A.species[species].slots[2]].id
      if id and id~=0 and ((legacy[2]~=0 and id==legacy[2])or(id==second and second~=A.spec.records[A.species[species].slots[1]].id))then slot=1 end
    end
    mon.abilityNum=slot;mon.hnsAbilitySlot=slot;mon.ability=A.resolve(species,slot,s);mon.abilityId=mon.ability;return mon
  end
  local give=old.give or Party.giveMon
  Party.giveMon=function(s,species,level,nickname,opts)
    local ok,code,mon,boxId,slotIdx=give(s,species,level,nickname,opts)
    if mon and H.own(s)then A.sync(mon,s,opts and opts.abilityNum)end
    return ok,code,mon,boxId,slotIdx
  end
  local battler=old.battler or State.makeBattler
  State.makeBattler=function(mon,side,opts)if H.battle()then A.sync(mon)end;return battler(mon,side,opts)end
  local function migrate(s)
    if not H.own(s)then return end
    for _,mon in ipairs(s.party or {})do A.sync(mon,s)end
    for _,box in pairs(s.boxes or {})do for _,mon in ipairs(box.mons or box)do A.sync(mon,s)end end
  end
  if not old.hooks then mod.events:on('map.entered',function()migrate(Rt.getSession())end)end
  migrate(game.session or Rt.getSession())
  local Summary=require('src.core.game3.summary_data');local description=old.description or Summary.abilityDescription
  Summary.abilityDescription=function(id,...)local r=H.battle()and A.byId[tonumber(id)];return r and r.row.description or description(id,...)end
  local name=old.name or P.abilityName
  P.abilityName=function(id)
    local r=H.battle()and A.byId[tonumber(id)]
    return r and r.row.name or name(id)
  end
  local abId=old.id or Ab.id
  Ab.id=function(key)return H.battle()and A.id(key)or abId(key)end
  local make=old.make or Adapter.new
  Adapter.new=function(st,...)
    local ad=make(st,...);local native=ad.abilityOf
    ad.abilityOf=function(self,b)
      if H.battle(st)and b and not b.expTracedAbility and not b.expAbilitySuppressed then
        local id=b.ability or b.mon and(b.mon.ability or b.mon.abilityId);local r=A.byId[tonumber(id)]
        if r then return r.name end
      end
      return native(self,b)
    end
    return ad
  end
  game._hnsAbilities={abilities=A,name=name,id=abId,make=make,description=description,pair=pair,abilityId=abilityId,give=give,battler=battler,hooks=true}
end
