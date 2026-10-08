-- Source machine numbers and species lists over the native bag/learn workflow.
return function(mod,w,game)
  local P=require('src.core.game3.pokemon');local Items=require('src.core.game3.items_data')
  local Use=require('src.core.game3.item_use');local Learn=require('src.core.game3.move_learn')
  local H=game._hnsRules.rules;local X=game._hnsExpandedMoves.moves;local old=game._hnsTeaching or {}
  local T={byId={},byName={},byIndex={},hmMoves={},tutorNames={}}
  for i,r in ipairs(w.teaching.machines)do
    T.byId[r.itemId]=r;T.byIndex[i-1]=r
    for _,n in ipairs({r.label,r.kind..'_'..r.move,r.key,'ITEM_'..r.label,'ITEM_'..r.kind..'_'..r.move})do T.byName[n]=r end
    if r.kind=='HM'then T.hmMoves[X.id(r.move)]=true end
  end
  for _,n in ipairs(w.teaching.tutors)do T.tutorNames[n]=true end
  function T.machine(id)return T.byId[tonumber(id)]or T.byName[tostring(id):upper()]end
  function T.compatible(species,name)
    local row=X.species[tonumber(species)or P.speciesFromName(species)]
    if not row then return false end
    for _,n in ipairs(w.pokedex.teachables[row.teachableRef]or {})do if n==name then return true end end
    return false
  end
  local function wrap(table,key,fn)
    local base=old[key]or table[key];old[key]=base;table[key]=function(...)return fn(base,...)end
  end
  wrap(Items,'toNumericId',function(base,id)local r=H.battle()and T.machine(id);if r then return r.itemId end;return base(id)end)
  wrap(Items,'info',function(base,id)
    local r=H.battle()and T.machine(id);if not r then return base(id)end
    return {id=r.itemId,name=r.name,pocket='TM_CASE',fieldUse='tm',price=r.price,importance=r.importance,description=r.description,battleUsage=0,registrability=0}
  end)
  wrap(Items,'isTm',function(base,id)local r=H.battle()and T.machine(id);if r then return true end;return base(id)end)
  wrap(Items,'isHm',function(base,id)local r=H.battle()and T.machine(id);if r then return r.kind=='HM'end;return base(id)end)
  wrap(Items,'tmNumber',function(base,id)local r=H.battle()and T.machine(id);if r then return r.number end;return base(id)end)
  wrap(P,'moveFromTmItem',function(base,id)local r=H.battle()and T.machine(id);if r then return X.id(r.move)end;return base(id)end)
  wrap(P,'canLearnTmItem',function(base,species,id)local r=H.battle()and T.machine(id);if r then return X.id(r.move)~=nil and T.compatible(species,r.move)end;return base(species,id)end)
  wrap(P,'canLearnTmIndex',function(base,species,index)
    if H.battle()then local r=T.byIndex[tonumber(index)];return r~=nil and X.id(r.move)~=nil and T.compatible(species,r.move)end;return base(species,index)
  end)
  wrap(P,'isHmMove',function(base,id)if H.battle()then return T.hmMoves[tonumber(id)]==true end;return base(id)end)
  wrap(Use,'checkTmPreflight',function(base,mon,id)
    local r=H.battle()and T.machine(id)
    if r and not X.id(r.move)then return 'unsupported','This move effect is not available in this mod yet.'end
    if r and mon and P.isEgg(mon)then return 'incompatible','An Egg cannot learn a move.'end
    return base(mon,id)
  end)
  wrap(Learn,'relearnableMoves',function(base,mon)
    if not H.battle()then return base(mon)end
    if not mon or P.isEgg(mon)then return {}end
    local moves,seen={},{}
    for _,r in ipairs(P.learnset(P.speciesOf(mon)))do
      if r[1]<=mon.level and not seen[r[2]]and not P.knowsMove(mon,r[2])then moves[#moves+1]=r[2];seen[r[2]]=true end
    end;return moves
  end)
  -- Event bridges can use source move names directly. Do not reinterpret the
  -- native tutor indices or introduce free services before their source gates.
  function T.tutorMoves(mon)
    local result={};if not H.battle()or not mon or P.isEgg(mon)then return result end
    for _,name in ipairs(w.teaching.tutors)do
      local id=X.id(name)
      if id and T.compatible(P.speciesOf(mon),name)and not P.knowsMove(mon,id)then result[#result+1]={name=name,id=id}end
    end;return result
  end
  function T.canTutor(mon,name)
    return H.battle()and mon~=nil and not P.isEgg(mon)and T.tutorNames[name]==true and X.id(name)~=nil and T.compatible(P.speciesOf(mon),name)and not P.knowsMove(mon,X.id(name))
  end
  old.teaching=T;game._hnsTeaching=old
end
