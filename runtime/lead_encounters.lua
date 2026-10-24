-- Source lead-slot Synchronize/Cute Charm over native wild-mon construction.
return function(mod,w,game)
  local old=game._hnsLeadEncounters or{};local S={spec=w.abilities.fieldLead}
  local H=game._hnsRules.rules;local A=game._hnsAbilities.abilities
  local Rt=require('src.core.game3.runtime');local P=require('src.core.game3.pokemon')
  local Rng=require('src.core.game3.rng');local Battle=require('src.core.game3.battle')
  function S.lead(s)
    local mon=s and s.party and s.party[1]
    -- HnS checks slot zero and egg state, not the first healthy party member.
    if not mon or P.isEgg(mon)then return end
    local ability
    if mon.hnsAbilityOverride then local row=A.byId[tonumber(mon.ability or mon.abilityId)];ability=row and row.name
    else local _,name=A.resolve(P.speciesOf(mon),tonumber(mon.abilityNum)or tonumber(mon.hnsAbilitySlot)or(tonumber(mon.personality)or 0)%2,s);ability=name end
    return mon,ability
  end
  function S.nature(origin,s)
    local mon,ability=S.lead(s)
    if ability~='SYNCHRONIZE'then return end
    if H.value('ITEM_MODE_SYNCHRONIZE',s)==0 then
      if (origin~='wild'and origin~='static')or Rng.Random()%2==0 then return end
    else
      -- The pinned OW_SYNCHRONIZE_NATURE is GEN_9: wild/static always,
      -- roamers and gifts never. Do not silently invent a future config.
      assert(S.spec.synchronizeGeneration>=8,'unreviewed source Synchronize generation')
      if origin~='wild'and origin~='static'then return end
    end
    return P.natureId(mon.personality)
  end
  function S.gender(origin,species,s)
    local mon,ability=S.lead(s)
    if ability~='CUTE_CHARM'or(origin~='wild'and origin~='static')then return end
    -- The source rolls before checking fixed ratios and the lead's gender.
    if Rng.Random()%3==0 then return end
    local meta=P.speciesMeta(species);local ratio=meta and tonumber(meta.genderRatio)
    if ratio==nil or ratio==0 or ratio==254 or ratio==255 then return end
    local g=P.gender(P.speciesOf(mon),mon.personality)
    if g=='F'then return 'M'elseif g=='M'then return 'F'end
  end
  function S.personality(species,nature,gender)
    local pid
    repeat pid=Rng.Random32()%4294967296
    until(nature==nil or P.natureId(pid)==nature)and(gender==nil or P.gender(species,pid)==gender)
    return pid
  end
  function S.origin(opts)
    local foe=opts and opts.foe
    if not(opts and opts.wild and type(foe)=='table')or opts.link or foe.link or opts.roamer or foe.roamer
      or opts.recordedLink or opts.safari or foe.safari or opts.pyramid or opts.pike or opts.battleTower
      or opts.eReader or opts.secretBase or opts.oldManTutorial or opts.pokedude or opts.firstBattle
      or opts.firstBattleKind or opts.tutorialKind or opts.foeParty or foe.party then return end
    return(opts.wildScripted or foe.wildScripted or opts.legendary or foe.legendary)and'static'or'wild'
  end
  function S.prepare(opts)
    if type(opts)~='table'or Battle._active or #(opts.playerParty or{})==0 then return opts end
    local s=opts.session or Rt.getSession();if not H.own(s)then return opts end
    local origin=S.origin(opts);if not origin then return opts end
    local foe=opts.foe;local species=tonumber(foe.species or foe.id)
    if not species or not A.species[species]or foe.personality~=nil or foe.gender~=nil or foe.nature~=nil then return opts end
    local nature=S.nature(origin,s);local gender=S.gender(origin,species,s)
    if nature==nil and gender==nil then return opts end
    local out,copy={},{};for k,v in pairs(opts)do out[k]=v end;for k,v in pairs(foe)do copy[k]=v end
    copy.personality=S.personality(species,nature,gender);out.foe=copy;return out
  end
  local start=old.start or Battle.start
  Battle.start=function(opts)return start(S.prepare(opts))end
  game._hnsLeadEncounters={start=start,encounters=S}
end
