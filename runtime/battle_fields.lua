-- Core source terrain effects over native damage, status and residual scheduling.
return function(mod,w,game)
  local H=game._hnsRules.rules;local old=game._hnsFields or {};local F={spec=w.battleFields}
  local Adapter=require('src.core.game3.battle.adapter');local Effects=require('src.core.game3.battle.effects')
  local Secondary=require('src.core.game3.battle.effects.secondary');local Status=require('src.core.game3.battle.effects.status')
  local Moves=require('src.core.game3.battle.moves');local Residuals=require('src.core.game3.battle.residuals')
  local Rules=require('src.core.game3.battle.rules');local Weather=require('src.core.game3.battle.effects.weather')
  local Text=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir')
  local Engine=require('src.core.game3.battle.engine');local State=require('src.core.game3.battle.state')
  local Hit=require('src.core.game3.battle.effects.hit')
  for id,text in pairs(F.spec.texts)do Text.overrides[id]=IR.fromAscii(text)end
  local byId={};for name,r in pairs(F.spec.items)do byId[r.index]=name end
  function F.held(b)return byId[tonumber(b and(b.item or b.mon and(b.mon.heldItem or b.mon.item)))or 0]end
  function F.grounded(ad,b)
    if not b or b.semiInvulnerable then return false end
    if b.rooted or b.expIngrain or b.smackDown or ad._st.gravity==true or(tonumber(ad._st.gravity)or 0)>0 then return true end
    if b.magnetRise or b.telekinesis or ad:abilityOf(b)=='LEVITATE'then return false end
    return not ad:hasType(b,2)
  end
  function F.terrain(st)return st and H.battle(st)and st.hnsTerrain end
  function F.blockStatus(ad,b,status)
    local terrain=F.terrain(ad._st)
    return terrain and F.grounded(ad,b)and(terrain=='MISTY'or terrain=='ELECTRIC'and Adapter.normStatus(status)=='SLP')
  end
  function F.prevent(ad,b,terrain)ad:sayText('STRINGID_'..terrain..'TERRAINPREVENTS',{def=b,scrActive=b})end
  function F.boostAffected(ad,user,target,boost)
    return boost and F.terrain(ad._st)==boost.terrain and(boost.groundCheck=='NONE'
      or F.grounded(ad,boost.groundCheck=='TARGET'and target or user))
  end
  function F.pulseType(ad,user,move,typ)
    local terrain=F.terrain(ad._st)
    if move.terrainEffect=='TERRAIN_PULSE'and terrain and F.grounded(ad,user)then
      return ({ELECTRIC=13,GRASSY=12,MISTY=18,PSYCHIC=14})[terrain]
    end
    return typ
  end
  function F.power(ad,user,target,move,power,typ)
    local terrain=ad and F.terrain(ad._st);if not terrain then return power,typ end
    if move.terrainEffect=='TERRAIN_PULSE'and F.grounded(ad,user)then power=power*2;typ=F.pulseType(ad,user,move,typ)
    elseif F.boostAffected(ad,user,target,move.terrainBoost)then
      -- Source CalcTerrainBoostedPower uses half-up rounding, before the
      -- ordinary terrain modifier's separate half-down rounding.
      local modifier=4096+math.floor(move.terrainBoost.percent*4096/100)
      power=math.floor((power*modifier+2048)/4096)
    end
    local modifier=4096
    if F.grounded(ad,user)and((terrain=='GRASSY'and typ==12)or(terrain=='ELECTRIC'and typ==13)or(terrain=='PSYCHIC'and typ==14))then modifier=F.spec.typeBoost end
    if terrain=='MISTY'and typ==16 and F.grounded(ad,target)then modifier=2048 end
    if terrain=='GRASSY'and not target.semiInvulnerable and(move.numId==89 or move.numId==222 or move.id=='BULLDOZE')then modifier=2048 end
    return math.floor((power*modifier+2047)/4096),typ
  end
  H.fieldPower=F.power
  H.blockPriority=function(M)
    if F.terrain(M.st)~='PSYCHIC'or not F.grounded(M.adapter,M.target)or M.user.side==M.target.side
      or F.priority(M.adapter,M.user,M.move)<=0 or M.move.target==32 or M.move.target==64 then return false end
    F.prevent(M.adapter,M.target,'PSYCHIC');M.noEffect=true;M.failed=true;return true
  end
  function F.priority(ad,b,move)
    local base=tonumber(move and move.priority)or 0
    if move and move.terrainEffect=='GRASSY_GLIDE'and F.terrain(ad._st)=='GRASSY'and F.grounded(ad,b)then return base+1 end
    return base
  end
  local targets=old.targets or Engine.forEachTarget
  Engine.forEachTarget=function(M,body)
    if H.battle(M.st)then
      M.move.type=F.pulseType(M.adapter,M.user,M.move,M.move.type)
      if M.move.terrainBoost and M.move.terrainBoost.hitsBothFoes and F.boostAffected(M.adapter,M.user,M.target,M.move.terrainBoost)then M.move.target=8 end
    end
    return targets(M,body)
  end
  local hit=old.hit or Hit.run
  Hit.run=function(M)
    if H.battle(M.st)and M.move.terrainEffect=='STEEL_ROLLER'and not F.terrain(M.st)then
      M:attackString();M:ppReduce();M.failed=true;M.noEffect=true;M.adapter:sayFail();return
    end
    return hit(M)
  end
  function F.remove(ad)
    local st=ad._st;local kind=st.hnsTerrain
    if kind then st.hnsTerrain=nil;st.hnsTerrainTurns=0;ad:sayText('STRINGID_'..kind..'TERRAINENDS')end
  end
  local finish=old.finish or Engine.moveEndEffects
  Engine.moveEndEffects=function(M)
    finish(M)
    local effect=M.move.terrainEffect
    if H.battle(M.st)and F.terrain(M.st)and(M.hpDealt or 0)>0 and not M.noEffect
      and(effect=='STEEL_ROLLER'or effect=='ICE_SPINNER'and M.adapter:hp(M.user)>0 and State.occupant(M.st,M.user)==M.user)then F.remove(M.adapter)end
  end
  if not old.orderHook then mod.hooks:wrap('battle.turn_order',function(next,a,am,b,bm,ctx)
    if not H.battle(ctx.battle)or not(am and bm)then return next(a,am,b,bm,ctx)end
    local ad=Adapter.new(ctx.battle);local ma=Moves.get(am.index or am.id);local mb=Moves.get(bm.index or bm.id)
    local pa,pb=F.priority(ad,a,ma),F.priority(ad,b,mb)
    if pa==(ma.priority or 0)and pb==(mb.priority or 0)then return next(a,am,b,bm,ctx)end
    if pa~=pb then return pa>pb end
    if ma.priority==mb.priority then return next(a,am,b,bm,ctx)end
    local sa,sb=Engine.speedOf(a,ctx.battle,ad),Engine.speedOf(b,ctx.battle,ad)
    if sa~=sb then return sa>sb end
    return ctx.rng(0,1)==1
  end)end
  local run=old.run or Effects.runForMove
  Effects.runForMove=function(ad,user,target,id,M)
    local move=M and M.move or Moves.get(id)
    if not(H.battle(ad._st)and move.hnsHandler=='terrain')then return run(ad,user,target,id,M)end
    local st=ad._st;local kind=move.hnsTerrain
    if st.hnsTerrain==kind or st.isSkyBattle then if M then M.failed=true end;ad:sayFail();return true end
    st.hnsTerrain=kind;st.hnsTerrainTurns=F.held(user)=='TERRAIN_EXTENDER'and F.spec.extendedTurns or F.spec.terrainTurns
    if M then M:attackAnimation()end
    ad:sayText('STRINGID_TERRAINBECOMES'..kind);return true
  end
  local make=old.make or Adapter.new
  Adapter.new=function(st,...)
    local ad=make(st,...);local can,apply,confuse=ad.canApplyStatus,ad.applyStatus,ad.applyConfusion
    ad.canApplyStatus=function(self,b,status,source,opts)
      local ok,why=can(self,b,status,source,opts)
      if ok and F.blockStatus(self,b,status)then F.prevent(self,b,F.terrain(st));return false,'terrain'end
      return ok,why
    end
    ad.applyStatus=function(self,b,status,source,opts)
      if opts and opts.force and F.blockStatus(self,b,status)then F.prevent(self,b,F.terrain(st));return false end
      return apply(self,b,status,source,opts)
    end
    ad.applyConfusion=function(self,b,...)
      if F.terrain(st)=='MISTY'and F.grounded(self,b)then F.prevent(self,b,'MISTY');return false end
      return confuse(self,b,...)
    end
    return ad
  end
  local secondary=old.secondary or Secondary.set
  Secondary.set=function(M,effect,primary,certain,user)
    local b=user and M.user or M.target
    if effect=='CONFUSION'and F.terrain(M.st)=='MISTY'and F.grounded(M.adapter,b)then
      if primary or certain then F.prevent(M.adapter,b,'MISTY')end;return false
    end
    return secondary(M,effect,primary,certain,user)
  end
  local sleep=old.sleep or Status.cantMakeAsleep
  Status.cantMakeAsleep=function(ctx,b)
    if F.blockStatus(ctx.adapter,b,'SLP')then F.prevent(ctx.adapter,b,F.terrain(ctx.adapter._st));return true end
    return sleep(ctx,b)
  end
  local weather={}
  for fn,name in pairs({sunny='HEAT_ROCK',rainy='DAMP_ROCK',sandstorm='SMOOTH_ROCK',hail='ICY_ROCK'})do
    local base=old.weather and old.weather[fn]or Weather[fn];weather[fn]=base
    Weather[fn]=function(ctx)
      local st=ctx.adapter._st;local before=st.weather;local result=base(ctx)
      if H.battle(st)and st.weather~=before and F.held(ctx.user)==name and st.weatherTurns>0 then st.weatherTurns=F.spec.extendedTurns end
      return result
    end
  end
  if not old.residual then
    Residuals.register('ingrain',function(ctx)
      local current=game._hnsFields;local f=current and current.fields;local ad,b=ctx.adapter,ctx.target
      if f and f.terrain(ad._st)=='GRASSY'and not b.expHealBlock and f.grounded(ad,b)and ad:hp(b)>0 and ad:hp(b)<ad:maxHp(b)then
        ad:heal(b,math.max(1,math.floor(ad:maxHp(b)/16)));ad:sayText('STRINGID_GRASSYTERRAINHEALS',{atk=b})
      end
    end)
    Rules.POST_PHASES_ORDER[#Rules.POST_PHASES_ORDER+1]='hns_terrain_end'
    Residuals.register('hns_terrain_end',function(ctx)
      local st=ctx.adapter._st
      if H.battle(st)and st.hnsTerrain and(st.hnsTerrainTurns or 0)>0 then
        st.hnsTerrainTurns=st.hnsTerrainTurns-1
        if st.hnsTerrainTurns==0 then local kind=st.hnsTerrain;st.hnsTerrain=nil;ctx.adapter:sayText('STRINGID_'..kind..'TERRAINENDS')end
      end
    end)
  end
  game._hnsFields={fields=F,run=run,make=make,secondary=secondary,sleep=sleep,weather=weather,residual=true,
    targets=targets,hit=hit,finish=finish,orderHook=true}
end
