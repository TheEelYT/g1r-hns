-- HnS rule effects; original native functions stay available to vanilla sessions.
return function(mod,world,game)
  local Q=world.startup;local spec=Q.rules;local old=game._hnsRules or {}
  local Rt=require('src.core.game3.runtime')
  local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags')
  local C=require('src.core.game3.constants').of('emerald')
  local Pokemon=require('src.core.game3.pokemon')
  local Moves=require('src.core.game3.battle.moves')
  local Types=require('src.core.game3.battle.types')
  local Damage=require('src.core.game3.battle.damage')
  local Rules=require('src.core.game3.battle.rules')
  local Engine=require('src.core.game3.battle.engine')
  local Hit=require('src.core.game3.battle.effects.hit')
  local Held=require('src.core.game3.battle.held_items')
  local Items=require('src.core.game3.battle.items')
  local ItemUse=require('src.core.game3.item_use')
  local AiItems=require('src.core.game3.battle.ai_items')
  local Bridge=require('src.core.game3.battle_bridge')
  local Steps=require('src.core.game3.step_events')
  local H={criticalOdds=spec.criticalOdds}
  local function session(st)return st and st.session or Rt.getSession()end
  function H.own(s)return s and world.maps[s.map]~=nil end
  function H.battle(st)return H.own(session(st)) and not (st and (st.link or st.kinds and st.kinds.link)) end
  local rows={}
  for _,p in ipairs(Q.settings.pages)do for _,r in ipairs(p.rows)do rows[r.id]=r end end
  function H.value(id,s)
    s=s or Rt.getSession();local row=assert(rows[id],id)
    local current=s==Rt.getSession() and Space.store
    local initialized=current and Flags.getFlag(Space.store,nil,Q.settings.initializedFlag) or s and s.flags and (s.flags[Q.settings.initializedFlag] or s.flags[tostring(Q.settings.initializedFlag)])
    if not initialized then return row.default end
    if current then return Flags.getVar(Space.store,nil,row.var) end
    local v=s and s.vars and (s.vars[row.var] or s.vars[tostring(row.var)])
    return v~=nil and v or row.default
  end
  local numericMoves,numericSpecies={},{}
  for name,row in pairs(spec.moves)do numericMoves[C:require('moves','MOVE_'..name)]=row end
  for name,row in pairs(spec.species)do numericSpecies[C:require('species','SPECIES_'..name)]=row end
  function H.physical(move,moveType)
    if H.value('ITEM_MODE_SPLIT')==1 then
      local row=numericMoves[tonumber(move.numId)] or spec.moves[move.id]
      local category=row and row.category or move.category
      if category then return category=='physical' end
    end
    return Types.isPhysical(moveType or move.type)
  end
  local baseGet=old.movesGet or Moves.get
  Moves.get=function(id)
    local m=baseGet(id)
    if H.battle() then
      local row=numericMoves[m.numId]
      if row then
        -- Fixed HnS move parameters apply even with Modern Moves disabled.
        for _,key in ipairs({'power','accuracy','pp','priority'})do m[key]=row[key] end
        if row.type~=spec.fairyType then m.type=row.type end
        if row.fairyType and H.value('ITEM_MODE_FAIRY_TYPES')==1 then m.type=row.fairyType end
        if H.value('ITEM_MODE_SPLIT')==1 then m.category=row.category
        elseif row.category~='status' then m.category=Types.isPhysical(m.type) and 'physical' or 'special' end
      end
    end
    return m
  end
  local basePp=old.movePp or Pokemon.movePp
  local baseMaxPp=old.moveMaxPp or Pokemon.moveMaxPp
  local baseBattleMove=old.battleMove or Pokemon.battleMove
  Pokemon.battleMove=function(id)
    local native=baseBattleMove(id);local row=numericMoves[tonumber(id)]
    if native and row and H.battle()then
      local copy={};for k,v in pairs(native)do copy[k]=v end
      for _,key in ipairs({'power','accuracy','pp','priority'})do copy[key]=row[key]end
      if row.type~=spec.fairyType or H.value('ITEM_MODE_FAIRY_TYPES')==1 then copy.type=row.type end
      return copy
    end
    return native
  end
  Pokemon.movePp=function(id)
    local row=numericMoves[tonumber(id)]
    if row and H.battle() then return row.pp end
    return basePp(id)
  end
  Pokemon.moveMaxPp=function(id)
    local row=numericMoves[tonumber(id)]
    if row and H.battle() then return row.pp end
    return baseMaxPp(id)
  end
  local baseTypes=old.pokemonTypes or Pokemon.types
  Pokemon.types=function(sp)
    local row=numericSpecies[tonumber(sp)]
    if row and H.battle() then
      local t=H.value('ITEM_MODE_FAIRY_TYPES')==1 and row.modern or row.legacy
      return {t[1],t[2]}
    end
    return baseTypes(sp)
  end
  local baseTypeName=old.typeName or Types.name
  Types.name=function(id)if tonumber(id)==spec.fairyType and H.battle()then return 'FAIRY'end;return baseTypeName(id)end
  -- Source matchup generation is independent of the optional Fairy retyping.
  local function multiplier(a,d,foresight)
    if d==nil or tonumber(d)==9 then return 10 end
    if foresight and tonumber(d)==7 and (tonumber(a)==0 or tonumber(a)==1)then return 10 end
    local row=spec.chart[tostring(a)]
    return row and row[tostring(d)] or 10
  end
  local baseCalc=old.typeCalc or Types.typeCalc
  Types.typeCalc=function(a,d1,d2,dmg,foresight)
    if not H.battle()then return baseCalc(a,d1,d2,dmg,foresight)end
    local product=1;local flags={super=false,notVery=false,immune=false}
    for i,d in ipairs({d1,d2~=d1 and d2 or nil})do
      local m=multiplier(a,d,foresight);product=product*m/10
      if dmg then dmg=math.floor(dmg*m/10);if dmg==0 and m>0 and not flags.immune then dmg=1 end end
      if m==0 then flags.immune=true end
    end
    flags.super=not flags.immune and product>1;flags.notVery=not flags.immune and product<1
    return dmg,flags,product
  end
  local baseEff=old.effectiveness or Types.effectiveness
  Types.effectiveness=function(a,d1,d2)
    if not H.battle()then return baseEff(a,d1,d2)end
    return multiplier(a,d1)*(d2~=nil and d2~=d1 and multiplier(a,d2)or 10)/100
  end
  local OwnDamage=assert(load(mod:read('hns_damage.lua'),'@hns/hns_damage.lua'))();OwnDamage.configure(H)
  local baseDamage=old.damageBase or Damage.base;local baseDamageCalc=old.damageCalc or Damage.calc
  Damage.base=function(a,d,m,opts)
    if H.battle(opts and opts.adapter and opts.adapter._st) then return OwnDamage.base(a,d,m,opts)end
    return baseDamage(a,d,m,opts)
  end
  Damage.calc=function(a,d,m,opts)
    if H.battle(opts and (opts.st or opts.adapter and opts.adapter._st)) then return OwnDamage.calc(a,d,m,opts)end
    return baseDamageCalc(a,d,m,opts)
  end
  local baseHiddenPower=old.hiddenPower or Damage.hiddenPower
  Damage.hiddenPower=function(mon)if H.battle()then return OwnDamage.hiddenPower(mon)end;return baseHiddenPower(mon)end
  local baseCritRoll=old.critRoll or Rules.crit.roll
  local ownCritRoll=assert(load(mod:read('hns_critical.lua'),'@hns/hns_critical.lua'))()(H)
  Rules.crit.roll=function(a,m,high,rng,st)
    if H.battle(st) then return ownCritRoll(a,m,high,rng,st)end
    return baseCritRoll(a,m,high,rng,st)
  end
  -- Use the real context metatable, shared by the native local new_ctx path.
  local Context=getmetatable(Engine.newContext({}, {},33,1,{displayName=function()return ''end},{},{},{},{}))
  local baseAccuracy=old.accuracy or Context.accuracyCheck
  local ownAccuracy=assert(load(mod:read('hns_accuracy.lua'),'@hns/hns_accuracy.lua'))()(H)
  Context.accuracyCheck=function(M,...)
    if H.battle(M.st)then return ownAccuracy(M,...)end
    return baseAccuracy(M,...)
  end
  function H.sturdy(M,target,dmg)
    local ad=M.adapter
    return H.battle(M.st) and H.value('ITEM_MODE_STURDY',session(M.st))==1
      and ad:abilityOf(target)=='STURDY' and not target.expEnduring and (target.substituteHP or 0)<=0
      and ad:hp(target)>0 and ad:hp(target)==ad:maxHp(target) and dmg>=ad:hp(target)
  end
  function H.sturdyMessage(ad,b)ad:say(ad:displayName(b)..' held on with STURDY!')end
  local baseAdjust=old.adjustDamage or Hit.adjustDamage
  Hit.adjustDamage=function(M,target,dmg)
    if H.sturdy(M,target,dmg)then M.hnsSturdy=target;return M.adapter:hp(target)-1,nil end
    return baseAdjust(M,target,dmg)
  end
  local baseDeal=old.dealDamage or Hit.dealDamage
  Hit.dealDamage=function(M,dmg,info)
    if H.battle(M.st)then
      local copy={};for k,v in pairs(info or {})do copy[k]=v end;info=copy
      if info.physical==nil then info.physical=H.physical(M.move,M.moveType)end
    end
    local dealt=baseDeal(M,dmg,info)
    if M.hnsSturdy==M.target then H.sturdyMessage(M.adapter,M.target);M.hnsSturdy=nil end
    return dealt
  end
  local baseSelfHit=old.selfHit or Engine.selfHit
  local ownSelfHit=assert(load(mod:read('hns_self_hit.lua'),'@hns/hns_self_hit.lua'))()(H)
  Engine.selfHit=function(M,dmg)if H.battle(M.st)then return ownSelfHit(M,dmg)end;return baseSelfHit(M,dmg)end
  local sitrus=C:require('items','ITEM_SITRUS_BERRY')
  local baseHeldNormal=old.heldNormal or Held.normal
  Held.normal=function(ad,b,moveTurn)
    if b and H.battle(ad._st) and H.value('ITEM_MODE_NEW_CITRUS',session(ad._st))==1 and Held.itemOf(b)==sitrus then
      local hp,max=ad:hp(b),ad:maxHp(b)
      if hp>0 and hp<=math.floor(max/2)then
        ad:playAnim('general','HELD_ITEM_EFFECT',b,b)
        ad:sayText('STRINGID_PKMNSITEMRESTOREDHEALTH',{scrActive=b,lastItem=sitrus})
        ad:heal(b,math.floor(max/4));Held.consume(ad,b);return true
      end
      return false
    end
    return baseHeldNormal(ad,b,moveTurn)
  end
  local baseHeal=old.healMon or ItemUse.healMon
  ItemUse.healMon=function(s,mon,id)
    if H.own(s) and tonumber(id)==sitrus and H.value('ITEM_MODE_NEW_CITRUS',s)==1 and mon then
      local hp,max=tonumber(mon.hp)or 0,tonumber(mon.maxHp or mon.maxhp)or 0
      if hp<=0 or hp>=max then return false,0 end
      local amt=math.min(max-hp,math.floor(max/4));mon.hp=hp+amt;return amt>0,amt
    end
    return baseHeal(s,mon,id)
  end
  local baseEvs=old.gainEVs or Pokemon.gainEVs
  Pokemon.gainEVs=function(mon,sp)
    local s=Rt.getSession()
    if H.own(s) and H.value('ITEM_DIFFICULTY_NO_EVS',s)==1 then
      for _,p in ipairs(s.party or {})do if p==mon then return 0 end end
      -- BattleBridge awards on PartyView copies, then writes them to the save.
      for _,p in ipairs(Bridge._battleParty or {})do if p==mon then return 0 end end
    end
    return baseEvs(mon,sp)
  end
  local function banned(st,id)
    return H.battle(st) and H.value('ITEM_DIFFICULTY_ITEM_PLAYER',session(st))==1 and not Items.isBall(id)
  end
  local baseUsable=old.battleUsable or Items.isBattleUsable
  Items.isBattleUsable=function(id)if banned(nil,id)then return false end;return baseUsable(id)end
  local baseCan=old.battleCanUse or Items.canUseOn
  Items.canUseOn=function(st,id,...)if banned(st,id)then return false,'Items cannot be used in battle.'end;return baseCan(st,id,...)end
  local baseUse=old.battleUse or Items.use
  Items.use=function(st,ad,bag,s,id,...)
    if banned(st,id)then local message='Items cannot be used in battle.';if ad and ad.say then ad:say(message)end;return 'error',{message},false,false end
    return baseUse(st,ad,bag,s,id,...)
  end
  local baseEnemy=old.enemyItem or AiItems.shouldUseItem
  AiItems.shouldUseItem=function(st,id)
    if H.battle(st) and H.value('ITEM_DIFFICULTY_ITEM_TRAINER',session(st))==1 then return nil end
    return baseEnemy(st,id)
  end
  function H.poisonSurvives(s)return H.own(s) and H.value('ITEM_MODE_SURVIVE_POISON',s)==1 end
  function H.poisonMessage(name)return name..' survived the poisoning.\nThe poison faded away!\\p'end
  local ownSteps=assert(load(mod:read('hns_step_events.lua'),'@hns/hns_step_events.lua'))()(Steps,H)
  local baseStep=old.onStep or Steps.onStepTaken
  Steps.onStepTaken=function(s,g)if H.own(s)then return ownSteps.onStepTaken(s,g)end;return baseStep(s,g)end
  if not old.hooks then
    mod.hooks:wrap('exp.gain',function(next,ctx)
      local amount=next(ctx)
      if H.battle(ctx.battle)then
        local value=H.value('ITEM_DIFFICULTY_EXP_MULTIPLIER',session(ctx.battle))
        amount=math.floor((tonumber(amount)or 0)*({[0]=1,[1]=1.5,[2]=2,[3]=0})[value])
      end
      return amount
    end)
  end
  game._hnsRules={movesGet=baseGet,battleMove=baseBattleMove,movePp=basePp,moveMaxPp=baseMaxPp,hiddenPower=baseHiddenPower,critRoll=baseCritRoll,pokemonTypes=baseTypes,typeName=baseTypeName,typeCalc=baseCalc,effectiveness=baseEff,
    damageBase=baseDamage,damageCalc=baseDamageCalc,accuracy=baseAccuracy,adjustDamage=baseAdjust,dealDamage=baseDeal,
    selfHit=baseSelfHit,heldNormal=baseHeldNormal,healMon=baseHeal,gainEVs=baseEvs,battleUsable=baseUsable,
    battleCanUse=baseCan,battleUse=baseUse,enemyItem=baseEnemy,onStep=baseStep,hooks=true,rules=H}
end
