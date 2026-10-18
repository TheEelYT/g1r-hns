-- Source follower tracks and actor-owned ground effects. Native RSE animation
-- entries retain source frame/flip commands; no player-global ground state.
return function(mod,w,game)
  local G=game._hnsFollowerGround or{cover={}};G.spec=w.fieldShadows.ground
  local R=require('src.core.game3.field_effects_rse');local C=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  local Audio=require('src.core.game3.audio');local Rt=require('src.core.game3.runtime')
  local sets={};for key,names in pairs(G.spec.behaviors)do local t={};sets[key]=t;for _,name in ipairs(names)do local id=MB.id(name);if id then t[id]=true end end end
  local function is(key,b)return sets[key][b]==true end
  local dir={down=1,up=2,left=3,right=4}
  local function active(a)return a.visible and not a.hidden and a.active~=false end
  local function source(a)return w.opening.sprites[tostring(a.graphicsId)]end
  local function tag(e,a,attached)
    if e then e.hnsFollowerGround=true;e.hnsGroundOwner=a;e.hnsAttached=attached end
    return e
  end
  local function stationary(a,name,x,y,anim)
    return tag(R.spawnAt(name,x,y,8,8,{anim=anim,layer='behind',stopOnEnd=false,
      onStep=function(e)if e.timer>G.spec.trackWaitFrames+1 then e.hidden=not e.hidden end;return e.timer>G.spec.trackEndFrame end}),a,false)
  end
  local function following(a,name,opts)
    opts=opts or{};opts.follow=a;opts.elevation=a.elevation or a.currentElevation;opts.sortBias=.5
    opts.x=a.px+8;opts.y=a.py+16+(type(opts.y2)=='function'and opts.y2(32)-16 or 0)
    local keep=opts.keep;opts.keep=function(e)return active(a)and(not keep or keep(e))end
    return tag(R.spawn(name,opts),a,true)
  end
  function G.leave(a)
    G.cover[a]=nil;a.inSandPile=false;a.inHotSprings=false;a.inShallowFlowingWater=false
    R.clear(function(e)return e.hnsFollowerGround and e.hnsGroundOwner==a and e.hnsAttached end)
  end
  function G.clear()
    for a in pairs(G.cover)do a.inSandPile=false;a.inHotSprings=false;a.inShallowFlowingWater=false end
    G.cover={};R.clear(function(e)return e.hnsFollowerGround end)
  end
  local function cover(a,cur,prev)
    local st=G.cover[a]or{};G.cover[a]=st
    local sand=is('deep',cur)and is('deep',prev)
    local flow=is('flow',cur)and is('flow',prev)or is('logs',cur)and is('logs',prev)
    local hot=is('spring',cur)and is('spring',prev)
    a.inSandPile=sand;a.inHotSprings=hot;a.inShallowFlowingWater=flow
    if sand and not st.sand then
      st.sand=true;following(a,'sand_pile',{seek=2,restart=true,stopOnEnd=false,y2=function(h)return h/2-2 end,keep=function()return a.inSandPile end})
    elseif not sand then st.sand=false end
    if flow and not st.flow then
      st.flow=true;following(a,'splash',{anim=2,stopOnEnd=false,y2=function(h)return h/2-4 end,keep=function()return a.inShallowFlowingWater end,
        onStep=function(e)
          local x,y=a.moving and a.targetX or a.cellX,a.moving and a.targetY or a.cellY
          if e.lastCellX~=x or e.lastCellY~=y then e.lastCellX,e.lastCellY=x,y;Audio.playSe(G.spec.puddleSe)end
        end})
    elseif not flow then st.flow=false end
    if hot and not st.hot then
      st.hot=true;following(a,'hot_springs_water',{stopOnEnd=false,y2=function(h)return h/2-8 end,keep=function()return a.inHotSprings end})
    elseif not hot then st.hot=false end
  end
  local function splash(a)
    following(a,'splash',{y2=function(h)return h/2-4 end});Audio.playSe(G.spec.puddleSe)
  end
  function G.begin(a,x,y)
    if not active(a)then return end
    local cur,prev=C.behavior(x,y),C.behavior(a.cellX,a.cellY)
    if not a.directionOverwrite and(is('sand',prev)or is('prints',prev))then
      local row=source(a);local track=row and row.trackType or'TRACKS_NONE';local anim=(dir[a.facing]or 1)+1;local name
      if track=='TRACKS_FOOT'then name=is('deep',prev)and'deep_sand_footprints'or'sand_footprints'
      -- These two source dispatch functions intentionally select the opposite
      -- label: preserve HnS's table, rather than guessing from enum names.
      elseif track=='TRACKS_SPOT'then name='bug_tracks'
      elseif track=='TRACKS_BUG'then name='spot_tracks'
      elseif track=='TRACKS_SLITHER'or track=='TRACKS_BIKE_TIRE'then
        name=track=='TRACKS_SLITHER'and'slither_tracks'or'bike_tire_tracks'
        anim=G.spec.turns[dir[a.hnsPreviousDirection]or 1][dir[a.facing]or 1]+1
      end
      if name then stationary(a,name,a.cellX,a.cellY,anim)end
    end
    a.hnsPreviousDirection=a.facing
    cover(a,cur,prev)
    if is('puddle',cur)and is('puddle',prev)then splash(a)end
  end
  function G.finish(a,x,y,jumped)
    if not active(a)then return end
    local cur=C.behavior(x,y);cover(a,cur,cur)
    if is('puddle',cur)and not jumped then splash(a)end
    if is('ripple',cur)then
      tag(R.spawn('ripple',{x=a.px+8,y=a.py+14,layer='behind'}),a,false)
    end
  end
  function G.land(a,x,y)
    if not active(a)then return end
    local cur=C.behavior(x,y)
    if is('puddle',cur)or is('flow',cur)then
      tag(R.spawnAt('jump_small_splash',x,y,8,12,{elevation=a.elevation or a.currentElevation}),a,false);return true
    elseif C.isSurfable and C.isSurfable(cur)then
      tag(R.spawnAt('jump_big_splash',x,y,8,8,{elevation=a.elevation or a.currentElevation}),a,false);return true
    end
    return false
  end
  if not G.hook then mod.events:on('map.entered',function()G.clear()end);G.hook=true end
  game._hnsFollowerGround=G;return G
end
