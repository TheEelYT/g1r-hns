-- Source-scoped field behavior; native interpolation/effects/party APIs remain
-- responsible for movement completion, drawing, waits and HP/PP restoration.
return function(mod,world,game)
  local Collision=require('src.core.game3.collision')
  local Player=require('src.core.game3.player')
  local Objects=require('src.core.game3.objects')
  local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags')
  local Rt=require('src.core.game3.runtime')
  local Profile=require('src.core.game3.profile')
  local Heal=require('src.core.game3.pokecenter_heal')
  local Ow=require('src.core.game3.ow_sprites')
  local prior=game._hnsField or {}
  local function own(session)
    session=session or Rt.getSession()
    return session and world.maps[session.map]~=nil
  end
  local function sourceBehavior(x,y)
    local m=game.data.maps[Collision._mapId]
    if not (m and world.maps[Collision._mapId] and m.midLayout) then return nil end
    return world.pairs[m.pair].behaviors[tostring(m.midLayout:midAt(x,y))]
  end
  local function side(name)
    if not name then return nil end
    return name:match('^MB_SIDEWAYS_STAIRS_(LEFT)_SIDE') or name:match('^MB_SIDEWAYS_STAIRS_(RIGHT)_SIDE')
  end
  local function top(name)return name and name:match('_SIDE_TOP$')~=nil end
  local function bottom(name)return name and name:match('_SIDE_BOTTOM$')~=nil end
  local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  -- event_object_movement.c GetCollisionAtCoords/GetSidewaysStairsCollision.
  local function stairDecision(dir)
    local d=delta[dir];if not d then return nil end
    local x,y=Player.cellX+d[1],Player.cellY+d[2]
    local cur,next=sourceBehavior(Player.cellX,Player.cellY),sourceBehavior(x,y)
    local cs,ns=side(cur),side(next)
    if not (cs or ns) then return nil end
    if top(next) and ((ns=='LEFT' and dir=='right') or (ns=='RIGHT' and dir=='left'))
      or bottom(next) and (dir=='down' or ns=='RIGHT' and dir=='right' or ns=='LEFT' and dir=='left')
      or top(cur) and dir=='up'
      or not top(cur) and top(next) and dir=='down'
      or not bottom(cur) and bottom(next) and dir=='up' then return 'blocked' end
    local ok,why=Collision.canEnter(game,x,y,{fromX=Player.cellX,fromY=Player.cellY,dir=dir,
      surfing=Player.surfing,elevation=Player.currentElevation})
    if (dir=='up' or dir=='down') and not ok or Collision.isWater(x,y) then return nil end
    local diagonal
    if ns and not top(next) then
      if not (cur~=next and (ns=='LEFT' and dir=='left' or ns=='RIGHT' and dir=='right')) then diagonal=ns end
    elseif cs and cur~=next and (cs=='LEFT' and dir=='left' or cs=='RIGHT' and dir=='right') then diagonal=cs end
    if not diagonal then return nil end
    if dir=='left' then y=y+(diagonal=='LEFT' and 1 or -1)
    elseif dir=='right' then y=y+(diagonal=='LEFT' and -1 or 1)
    else return nil end
    -- Source diagonal collision checks use the actual landing square. Never
    -- step outside the map, into water, or through an event object.
    if not Collision.inBounds(x,y) or Collision.isWater(x,y)
        or Objects.blocks(x,y,nil,Player.currentElevation) then return 'blocked' end
    return 'diagonal',x,y
  end
  local tryMove=prior.tryMove or Player.tryMove
  Player.tryMove=function(dir,g,run)
    if not world.maps[Collision._mapId] then return tryMove(dir,g,run) end
    if Player.moving or Player.boulderPush or not delta[dir] then return nil end
    local decision,x,y=stairDecision(dir)
    if decision then
      if Player.facing~=dir then
        Player.facing=dir
        if Player.turnArmed then Player.turnArmed=false;Player.turnTimer=4;return 'turned' end
      end
      if (Player.turnTimer or 0)>0 then return nil end
      if decision=='blocked' then return 'blocked','tile' end
      Player.bikeStep(x,y,dir,run and 11 or 23)
      Player.running=run==true
      return 'step'
    end
    local cur=sourceBehavior(Player.cellX,Player.cellY)
    local d=delta[dir];local next=sourceBehavior(Player.cellX+d[1],Player.cellY+d[2])
    local slow=dir=='up' and cur=='MB_ROCK_STAIRS' or dir=='down' and next=='MB_ROCK_STAIRS'
    local result,reason=tryMove(dir,g,run)
    if slow and result=='step' then Player.stepFrames=run and 11 or 23 end
    return result,reason
  end
  local loadMap=prior.loadMap or Objects.loadMap
  Objects.loadMap=function(g,id,def)
    if world.maps[id] and Space.store then
      local session=Rt.getSession()
      local time=require('src.core.game3.rtc').calcLocalTime(session or {})
      local hour=tonumber(time.hours) or 12
      local night=hour>=world.fieldPokemon.time.nightBegin or hour<world.fieldPokemon.time.nightEnd
      Flags.setFlag(Space.store,nil,world.fieldPokemon.flags.dayHidden,night)
      Flags.setFlag(Space.store,nil,world.fieldPokemon.flags.nightHidden,not night)
    end
    return loadMap(g,id,def)
  end
  local updateObjects=prior.updateObjects or Objects.update
  local tickPool=prior.tickPool or Objects.tickPool
  local function prepareMovement(pool)
    for _,eo in pairs(pool or {}) do
      local name=eo.def and eo.def.hnsMovementType
      if name=='MOVEMENT_TYPE_WANDER_AROUND_SLOWER' and eo.moving and not eo.scriptBusy then eo.stepFrames=32 end
    end
  end
  local function finishMovement(pool)
    for _,eo in pairs(pool or {}) do
      if eo.def and eo.def.hnsMovementType=='MOVEMENT_TYPE_WANDER_AROUND_SLOWER' and eo.moving and not eo.scriptBusy then eo.stepFrames=32 end
      if eo.def and eo.def.hnsMovementType=='MOVEMENT_TYPE_TOWER_BEAM' and eo.moving and eo.progress==0 and not eo.frozen and not eo.scriptBusy then
        local phase=(eo.hnsBeamPhase or 0)%4+1;eo.hnsBeamPhase=phase
        eo.facing=({'left','left','right','down'})[phase]
        eo.stepFrames=phase==1 and 8 or 16
      end
    end
  end
  Objects.update=function(g)
    prepareMovement(Objects._byId);local result=updateObjects(g);finishMovement(Objects._byId);return result
  end
  Objects.tickPool=function(pool,g,ctx)
    prepareMovement(pool and pool.byId);local result=tickPool(pool,g,ctx);finishMovement(pool and pool.byId);return result
  end
  local forSession=prior.forSession or Profile.forSession
  local function healSpec(session)
    session=session or Rt.getSession()
    local map=session and world.maps[session.map]
    local rse=map and map.hnsLayoutVersion=='emerald'
    return {monitorCenter={rse and 124 or 128,24},monitor={sheet=rse and 'hns_center_monitor_rse' or 'hns_center_monitor',
      w=rse and 24 or 32,h=16,corner={rse and -12 or -16,-8},
      seq={0,1,0,1,0,1,0,1},durs={16,16,16,16,16,16,16,16},loops=0}}
  end
  Profile.forSession=function(session)
    local row=forSession(session)
    if not own(session) then return row end
    local out={};for k,v in pairs(row) do out[k]=v end
    out.heal=healSpec(session)
    -- HnS IsRunningDisallowed tests metatile behaviors, without Emerald's
    -- extra map-header restriction (Cherrygrove carries allow_running=false).
    out.field={};for k,v in pairs(row.field or {})do out.field[k]=v end
    out.field.running={};for k,v in pairs((row.field or {}).running or {})do out.field.running[k]=v end
    out.field.running.mapHeader=false
    return out
  end
  local installHeal=prior.installHeal or Heal.install
  local base=game._hnsField and prior.healCache or Heal._cache
  local function overlayFor(cache)
    return {read=function(_,rel)
      local name=type(rel)=='string' and rel:match('field_effects/([^/]+)$')
      if own() and name then
        for _,file in ipairs(world.presentation.files) do if name==file then return mod:read('field_effects/'..file) end end
      end
      return cache and cache:read(rel)
    end}
  end
  Heal.install=function(cache)return installHeal(overlayFor(cache)) end
  installHeal(overlayFor(base))
  local healStart=prior.healStart or Heal.start
  local healWait=prior.healWait or Heal.wait
  local function nurseId()
    local session=Rt.getSession()
    local lid=Space.store and Flags.getVar(Space.store,nil,0x800B)
    if lid and lid>0 and Objects.find(lid) then return lid end
    for _,n in ipairs(world.worldEvents.nurses) do if session and n.map==session.map then return n.localId end end
  end
  Heal.start=function()
    if own() then
      local lid=nurseId();if lid then Objects.turnObject(lid,'left') end
    end
    local result=healStart()
    if own() and Heal._fx then
      local session=Rt.getSession();local count=0
      for _,mon in ipairs(session and session.party or {}) do if not (mon.isEgg or mon.egg) then count=count+1 end end
      Heal._fx.remaining=math.max(1,math.min(6,count))
    end
    return result
  end
  Heal.wait=function(done)
    local lid=own() and nurseId()
    return healWait(function()
      if lid then Objects.turnObject(lid,'down') end
      if done then done() end
    end)
  end
  local owGet=prior.owGet or Ow.get
  local owPose=prior.owPose or Ow.pose
  Ow.get=function(id)
    local spr=owGet(id)
    local info=world.opening.sprites[tostring(id)]
    if spr and info then spr.hnsAsymmetric=info.asymmetric end
    return spr
  end
  Ow.pose=function(spr,facing,phase,flip,opts)
    if spr and spr.hnsAsymmetric and facing=='right' and not (opts and opts.frame) then
      return phase and phase>0 and (flip and 10 or 11) or 9,false
    end
    return owPose(spr,facing,phase,flip,opts)
  end
  game._hnsField={tryMove=tryMove,loadMap=loadMap,forSession=forSession,installHeal=installHeal,
    healCache=base,healStart=healStart,healWait=healWait,owGet=owGet,owPose=owPose,updateObjects=updateObjects,tickPool=tickPool,stairDecision=stairDecision,sourceBehavior=sourceBehavior}
end
