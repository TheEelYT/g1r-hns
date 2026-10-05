-- Source mechanics that extend the native engine, scoped to HnS saves.
return function(mod,w,game)
  local old=game._hnsMechanics or {};local H=game._hnsRules.rules
  local Rt=require('src.core.game3.runtime');local Pokemon=require('src.core.game3.pokemon')
  local State=require('src.core.game3.battle.state');local Adapter=require('src.core.game3.battle.adapter')
  local Secondary=require('src.core.game3.battle.effects.secondary')
  local ItemUse=require('src.core.game3.item_use');local FieldMoves=require('src.core.game3.field_moves')
  local C=require('src.core.game3.constants').of('emerald');local M={}
  local rows={};for _,r in ipairs(w.pokedex.registrationEntries)do
    local id=C.species.byName['SPECIES_'..r.speciesName];if id then rows[id]=r end
  end
  local function row(id)return H.own(Rt.getSession())and rows[tonumber(id)]end
  local stats=old.stats or Pokemon.stats;local meta=old.meta or Pokemon.speciesMeta
  Pokemon.stats=function(id)
    local r=row(id);if not r or not r.stats then return stats(id)end
    local v={};for _,k in ipairs({'hp','atk','def','spe','spa','spd'})do v[k]=r.stats[k]end;return v
  end
  local growth={['Medium Fast']=0,Erratic=1,Fluctuating=2,['Medium Slow']=3,Fast=4,Slow=5}
  Pokemon.speciesMeta=function(id)
    local base=meta(id);local r=row(id);if not r or not r.stats then return base end
    local v={};for k,n in pairs(base or {})do v[k]=n end
    for _,k in ipairs({'catchRate','expYield','friendship','eggCycles'})do v[k]=r.stats[k]end
    v.growthRate=growth[r.growthRate]or v.growthRate
    if r.femalePercent then v.genderRatio=math.min(254,math.floor(r.femalePercent*255/100))
    elseif tonumber(r.genderRatio)then v.genderRatio=tonumber(r.genderRatio)end
    if r.evYield then for _,k in ipairs({'hp','atk','def','spe','spa','spd'})do
      v['ev'..k:sub(1,1):upper()..k:sub(2)]=r.evYield[k]
    end end
    return v
  end
  -- Normalize a GBA status bitfield once. A retained status1 field can
  -- resurrect an old status after a cure, so migrate it to the native string.
  function M.status(v)
    if type(v)~='number'then return Adapter.normStatus(v)end
    local bit=require('bit');if bit.band(v,7)>0 then return 'SLP' end
    for _,r in ipairs({{128,'TOX'},{64,'PAR'},{32,'FRZ'},{16,'BRN'},{8,'PSN'}})do
      if bit.band(v,r[1])~=0 then return r[2]end
    end
  end
  local make=old.make or State.makeBattler
  State.makeBattler=function(mon,side,opts)
    local s=opts and opts.st and opts.st.session or Rt.getSession()
    if mon and H.own(s)then
      local value=mon.status;if value==nil then value=mon.status1 end
      mon.status=M.status(value);mon.status1=nil
      if mon.status=='SLP'and type(value)=='number'then mon.sleep=value%8 end
    end
    return make(mon,side,opts)
  end
  local secondary=old.secondary or Secondary.set
  Secondary.set=function(ctx,effect,...)
    if effect=='RECHARGE'and H.battle(ctx.st or ctx.adapter._st)
      and H.value('ITEM_MODE_GEN_ONE_RECHARGE',ctx.adapter._st.session)==1
      and ctx.target and ctx.adapter:isFainted(ctx.target)then return false end
    return secondary(ctx,effect,...)
  end
  local rope=old.rope or ItemUse.useEscapeRope;local dig=old.dig or FieldMoves.digFromMenu
  ItemUse.useEscapeRope=function(s,bag,id)
    if H.own(s)and H.value('ITEM_DIFFICULTY_ESCAPE_ROPE_DIG',s)==1 then
      return false,'escape',FieldMoves.TEXT.CANT_USE_HERE
    end
    return rope(s,bag,id)
  end
  FieldMoves.digFromMenu=function(ctx)
    local s=ctx.session or Rt.getSession();local map=H.own(s)and w.maps[s.map]
    if not map then return dig(ctx)end
    if H.value('ITEM_DIFFICULTY_ESCAPE_ROPE_DIG',s)==1 or map.allowEscaping~=1 then
      return {ok=false,text=FieldMoves.TEXT.CANT_USE_HERE}
    end
    return {ok=true,action='dig',mon=ctx.mon or FieldMoves.partyMoveUser(ctx.party,'DIG')}
  end
  if not old.hook then mod.hooks:wrap('battle.run',function(next,ctx)
    if H.battle(ctx.battle)and H.value('ITEM_DIFFICULTY_LESS_ESCAPES',ctx.battle.session)==1
      and not ctx.battle.pyramid then
      -- Preserve the pinned source's Random() & 512 two-valued threshold.
      local threshold=require('bit').band(ctx.rng(0,65535),512)
      local speedVar=(math.floor(ctx.pSpd*128/math.max(1,ctx.eSpd))+ctx.attempts*30)%256
      return speedVar>threshold
    end
    return next(ctx)
  end)end
  game._hnsMechanics={stats=stats,meta=meta,make=make,secondary=secondary,rope=rope,dig=dig,hook=true,mechanics=M}
end
