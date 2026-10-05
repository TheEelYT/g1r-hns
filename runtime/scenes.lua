-- Source scenes share native movement, modal naming and persisted rivalName.
return function(mod,world,game)
  local Space=require('src.core.game3.scripting.space')
  local Natives=require('src.core.game3.scripting.natives')
  local Flags=require('src.core.game3.scripting.flags')
  local Objects=require('src.core.game3.objects')
  local Player=require('src.core.game3.player')
  local Collision=require('src.core.game3.collision')
  local Movement=require('src.import.gba.movement_emerald')
  local Q=world.quest
  local invisibleType=require('src.core.game3.constants').of('emerald'):require('movement','MOVEMENT_TYPE_INVISIBLE')
  local prior=game._hnsScene or {}
  local baseSpawn=prior.spawn or Objects.spawnFromDefs
  -- Neighbor pools treat vanilla dynamic gfx >=240 as invisible. These IDs
  -- are actual namespaced sheets, so retain the source movement visibility.
  Objects.spawnFromDefs=function(defs,def,id)
    local pool=baseSpawn(defs,def,id)
    for _,eo in pairs(pool.byId or {}) do
      if eo.def and eo.def.hnsGraphicsId and world.opening.sprites[tostring(eo.def.hnsGraphicsId)] then
        local mt=tonumber(eo.movementType)
        eo.invisible=mt==invisibleType or eo.buried==true or eo.rseKind=='berry_tree'
      end
    end
    return pool
  end
  game._hnsScene={spawn=baseSpawn}
  Natives.ALLOW['native:'..Q.nameNative]=function(ctx,a)
    local session=require('src.core.game3.runtime').getSession()
    return Natives.yieldHost(ctx,a,function(done)
      -- RSE has no RIVAL naming template. PLAYER provides the standard
      -- seven-character keyboard; the title and value belong to this rival.
      a.openNaming({template='PLAYER',title="RIVAL'S NAME",maxLen=7,initialText=session.rivalName or 'SILVER',session=session},function(name)
        if type(name)=='string' and name:match('%S') then session.rivalName=name end
        session.rivalName=session.rivalName or 'SILVER'
        a.rivalName=function() return session.rivalName end
        ctx.stringVars[3]=session.rivalName
        ctx.rivalName=session.rivalName
        done()
      end)
    end)
  end
  Natives.ALLOW['native:'..Q.alignNative]=function(ctx,a)
    local kind=Flags.getVar(Space.store,ctx,0x8004)
    local tx,ty,facing=kind==1 and 7 or 5,kind==1 and 6 or 4,kind==1 and 'up' or 'right'
    if kind==3 then tx,ty,facing=57,9,'up' end
    -- The normal doorway uses the source route. Continue/retry positions use
    -- a walkable route to the same mark instead of teleporting the player.
    local start={x=Player.cellX,y=Player.cellY}
    local queue={start};local visited={[start.y*1024+start.x]=start};local goal
    local dirs={{0,-1,'UP','up'},{-1,0,'LEFT','left'},{1,0,'RIGHT','right'},{0,1,'DOWN','down'}}
    local head=1
    while queue[head] do
      local p=queue[head];head=head+1
      if p.x==tx and p.y==ty then goal=p;break end
      for _,d in ipairs(dirs) do
        local x,y=p.x+d[1],p.y+d[2];local id=y*1024+x
        if not visited[id] and Collision.canEnter(game,x,y,{fromX=p.x,fromY=p.y,dir=d[4],elevation=Player.currentElevation,surfing=false}) then
          local n={x=x,y=y,prev=p,step=d[3]};visited[id]=n;queue[#queue+1]=n
        end
      end
    end
    if not goal then Flags.setVar(Space.store,ctx,0x800D,0);return false end
    local path={};local p=goal
    while p.prev do table.insert(path,1,assert(Movement.canonOf('MOVEMENT_ACTION_'..(kind==2 and 'WALK_FAST_' or 'WALK_NORMAL_')..p.step)));p=p.prev end
    path[#path+1]=assert(Movement.canonOf('MOVEMENT_ACTION_FACE_'..facing:upper()))
    path[#path+1]=assert(Movement.canonOf('MOVEMENT_ACTION_STEP_END'))
    Flags.setVar(Space.store,ctx,0x800D,1)
    return Natives.yieldHost(ctx,a,function(done) Objects.applyMovement(255,path,done) end)
  end
end
