-- Explicit source move rows; compatible native effect dispatch, no generic HIT fallback.
return function(mod,w,game)
  local old=game._hnsExpandedMoves or {};local H=game._hnsRules.rules
  local Rt=require('src.core.game3.runtime');local Pokemon=require('src.core.game3.pokemon')
  local Moves=require('src.core.game3.battle.moves');local E=require('src.core.game3.battle.effect_ids')
  local Types=require('src.core.game3.battle.types');local Hit=require('src.core.game3.battle.effects.hit')
  local Secondary=require('src.core.game3.battle.effects.secondary')
  local C=require('src.core.game3.constants').of('emerald');local X={byId={},byName={},species={}}
  for name,row in pairs(w.expandedMoves.moves)do X.byId[row.id]=row;X.byName[name]=row.id end
  for _,row in ipairs(w.pokedex.registrationEntries)do
    local id=C.species.byName['SPECIES_'..row.speciesName];if id then X.species[id]=row end
  end
  local aliases={VISE_GRIP='VICE_GRIP',HIGH_JUMP_KICK='HI_JUMP_KICK',FEINT_ATTACK='FAINT_ATTACK',SMELLING_SALTS='SMELLING_SALT'}
  function X.id(name)
    name=aliases[name]or name
    if name=='ROOST'then return w.campaign.roostMove end
    return C.moves.byName['MOVE_'..name]or X.byName[name]
  end
  local get=old.get or Moves.get;local name=old.name or Moves.constName;local number=old.number or Moves.numForName
  Moves.constName=function(id)
    if H.battle()and X.byId[tonumber(id)]then for n,row in pairs(w.expandedMoves.moves)do if row.id==tonumber(id)then return n end end end
    return name(id)
  end
  Moves.numForName=function(n)
    local key=type(n)=='string'and n:upper():gsub(' ','_'):gsub('-','_')
    if H.battle()and X.byName[key]then return X.byName[key]end;return number(n)
  end
  Moves.get=function(id)
    local key=tonumber(id)or(type(id)=='string'and X.byName[id:upper():gsub(' ','_'):gsub('-','_')])
    local row=H.battle()and X.byId[key];if not row then return get(id)end
    local m={};for k,v in pairs(row)do m[k]=v end
    m.id=Moves.constName(key);m.numId=key;m.effectId=E.STATUS_SETUP[m.effect]
    if m.legacyType and H.value('ITEM_MODE_FAIRY_TYPES')==0 then m.type=m.legacyType end
    if H.value('ITEM_MODE_SPLIT')~=1 and m.power>0 then m.category=Types.isPhysical(m.type)and 'physical'or 'special'end
    return m
  end
  local battleMove=old.battleMove or Pokemon.battleMove;local moveName=old.moveName or Pokemon.moveName
  local pp=old.pp or Pokemon.movePp;local maxpp=old.maxpp or Pokemon.moveMaxPp
  Pokemon.battleMove=function(id)if H.battle()and X.byId[tonumber(id)]then return X.byId[tonumber(id)]end;return battleMove(id)end
  Pokemon.moveName=function(id)if H.battle()and X.byId[tonumber(id)]then return X.byId[tonumber(id)].name end;return moveName(id)end
  Pokemon.movePp=function(id)if H.battle()and X.byId[tonumber(id)]then return X.byId[tonumber(id)].pp end;return pp(id)end
  Pokemon.moveMaxPp=function(id)if H.battle()and X.byId[tonumber(id)]then return X.byId[tonumber(id)].pp end;return maxpp(id)end
  local hit=old.hit or Hit.run
  Hit.run=function(M)
    if H.battle(M.st)and M.move.additionalEffects and #M.move.additionalEffects>0 then M.extraEffect={eff='HNS_ADDITIONAL_LIST'}end
    return hit(M)
  end
  local chance=old.chance or Secondary.withChance
  Secondary.withChance=function(M,effect,certain,user)
    if effect~='HNS_ADDITIONAL_LIST'then return chance(M,effect,certain,user)end
    if M.noEffect then return false end
    local ad=M.adapter;local result=false
    for _,row in ipairs(M.move.additionalEffects)do
      local n=row.chance;if ad:abilityOf(M.user)=='SERENE_GRACE'then n=n*2 end
      if n>=100 or ad:roll(0,99)<n then
        result=Secondary.set(M,row.effect,false,n>=100,row.user)or result
      end
    end
    return result
  end
  local learn=old.learn or Pokemon.learnset;local eggs=old.eggs or Pokemon.eggMoves
  local function speciesId(sp)if type(sp)=='table'then return Pokemon.speciesOf(sp)elseif type(sp)=='string'then return Pokemon.speciesFromName(sp)or tonumber(sp)end;return tonumber(sp)end
  function X.learnset(sp)
    local r=X.species[speciesId(sp)];if not r then return end
    local modern=H.value('ITEM_MODE_MODERN_MOVES')==1;local gen=tostring(modern and w.pokedex.modernGeneration or 3)
    local ref=modern and r.learnsetRef or r.legacyLearnsetRef
    local pool=w.pokedex.learnsets[gen]and w.pokedex.learnsets[gen][ref];if not pool then return end
    local list={};for _,row in ipairs(pool)do local id=X.id(row.move);if id then list[#list+1]={row.level,id}else X.pending[row.move]=true end end;return list
  end
  X.pending={}
  Pokemon.learnset=function(sp)if H.battle()then local l=X.learnset(sp);if l then return l end end;return learn(sp)end
  Pokemon.eggMoves=function(sp)
    local r=H.battle()and X.species[speciesId(sp)];if not r then return eggs(sp)end
    local modern=H.value('ITEM_MODE_MODERN_MOVES')==1;local gen=tostring(modern and w.pokedex.modernGeneration or 3)
    local ref=modern and r.eggRef or r.legacyEggRef;local pool=w.pokedex.eggsets[gen]and w.pokedex.eggsets[gen][ref]
    if not pool then return eggs(sp)end
    local result={};for _,n in ipairs(pool)do local id=X.id(n);if id then result[#result+1]=id end end;return result
  end
  game._hnsExpandedMoves={get=get,name=name,number=number,battleMove=battleMove,moveName=moveName,pp=pp,maxpp=maxpp,hit=hit,chance=chance,learn=learn,eggs=eggs,moves=X}
end
