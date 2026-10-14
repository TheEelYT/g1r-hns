-- Scoped ability identity bridge; pending effects are never assigned by this API.
return function(mod,w,game)
  local old=game._hnsAbilities or {};local H=game._hnsRules.rules;local A={spec=w.abilities,byId={}}
  local P=require('src.core.game3.pokemon');local Ab=require('src.core.game3.battle.abilities');local Adapter=require('src.core.game3.battle.adapter')
  for name,r in pairs(A.spec.records)do A.byId[r.id]={name=name,row=r}end
  function A.id(name)local r=A.spec.records[name];return r and r.support~='pending'and r.id or nil end
  function A.assign(mon,name)
    local id=A.id(name);if not id then return false end
    mon.ability=id;mon.abilityId=id;return true
  end
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
  game._hnsAbilities={abilities=A,name=name,id=abId,make=make}
end
