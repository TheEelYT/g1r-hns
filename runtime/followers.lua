-- A nonblocking native actor follows the first living non-egg party member.
return function(mod,w,game)
  local old=game._hnsFollower or {};local F=old.follower or {}
  local Rt=require('src.core.game3.runtime');local P=require('src.core.game3.player')
  local O=require('src.core.game3.objects');local Pokemon=require('src.core.game3.pokemon')
  local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
  local C=require('src.core.game3.constants').of('emerald');local H=game._hnsRules.rules
  local Field=require('src.core.game3.field');local Warp=require('src.core.game3.warp')
  local Map=require('src.core.game3.map');local Coll=require('src.core.game3.collision')
  local Ow=require('src.core.game3.ow_sprites');local Fx=require('src.core.game3.field_effects')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui)
  local Motion=assert(load(mod:read('follower_motion.lua')))()
  local rows={};for name,r in pairs(w.followers.species)do rows[C:require('species','SPECIES_'..name)]=r end
  function F.lead(s)
    for _,mon in ipairs(s and s.party or {})do
      if not(mon.isEgg or mon.egg or mon.isBadEgg)and(tonumber(mon.hp or mon.currentHp)or 0)>0 then return mon end
    end
  end
  function F.row(mon)
    local id=mon and Pokemon.picSpecies(Pokemon.speciesOf(mon),mon.personality)
    return rows[id]or rows[mon and Pokemon.speciesOf(mon)]
  end
  function F.allowed(s,mon)
    local r=F.row(mon);local m=s and w.maps[s.map]
    if not m or not r or H.value('ITEM_MAIN_FOLLOWER',s)==1 then return false end
    if r.height==64 and H.value('ITEM_MAIN_LARGE_FOLLOWER',s)==1 then return false end
    if m.mapType==8 and(r.width>32 or r.height>32)then return false end
    if Space.store and Flags.getFlag(Space.store,nil,w.followers.disabledFlag)then return false end
    if P.surfing or P.underwater or P.biking then return false end
    local Forced=require('src.core.game3.forced_movement')
    if Forced.isForced and Forced.isForced()then return false end
    return true
  end
  function F.refresh()
    if F.seamlessTransfer then return F.actor end
    local s=Rt.getSession();local mon=H.own(s)and F.lead(s)
    if not F.allowed(s,mon)then
      if F.actor and F.actor.visible and not F.transition then F.beginBall('enter')end
      if F.transition then return F.actor end
      F.actor=nil;F.mon=nil;return
    end
    local row=F.row(mon);local gid=Pokemon.isShiny(mon)and row.shiny or row.normal
    if F.mon~=mon or F.map~=s.map or not F.actor or F.actor.graphicsId~=gid then
      F.mon,F.map=mon,s.map
      F.transition=nil
      F.actor={localId=0xFD,def={hnsGraphicsId=gid,graphicsId=gid,hnsFollower=true,scriptKey='HNS_FOLLOWER_TALK'},
        graphicsId=gid,cellX=P.cellX,cellY=P.cellY,px=P.cellX*16,py=P.cellY*16,
        facing=P.facing,currentElevation=P.currentElevation,visible=false,hidden=false,animClock=0,idleClock=0,
        moving=false,stepFrames=16,passable=true,mapDef=game.data.maps[s.map]}
    end
    return F.actor
  end
  function F.step(x,y,frames,playerJump)
    local a=F.refresh();if not a then return end
    if F.transition then return end
    if a.moving then a.pendingStep={x=x,y=y,frames=frames,playerJump=playerJump};return end
    if not a.visible then
      -- Source invisible followers shadow jumps rather than emerging mid-hop.
      if playerJump then a.cellX=P.cellX;a.cellY=P.cellY;a.px=a.cellX*16;a.py=a.cellY*16;return end
      a.cellX=x;a.cellY=y;a.px=x*16;a.py=y*16;a.facing=P.facing;a.moving=false
      F.beginBall('exit',frames and frames<16);return
    end
    if x==a.cellX and y==a.cellY then return end
    local dir=x>a.cellX and 'right'or x<a.cellX and 'left'or y>a.cellY and 'down'or 'up'
    local lx,ly=Coll.ledgeLanding(game,a.cellX,a.cellY,dir)
    a.jumping=lx~=nil
    a.jumpStride=playerJump and 1 or (frames or 16)<=8 and 4 or 2
    if lx then x,y=lx,ly;frames=32/a.jumpStride elseif playerJump then frames=32 end
    a.visible=true;a.startPx=a.px;a.startPy=a.py;a.targetX=x;a.targetY=y
    local dx,dy=x*16-a.px,y*16-a.py
    if dx~=0 then a.facing=dx<0 and 'left'or 'right'elseif dy~=0 then a.facing=dy<0 and 'up'or 'down'end
    a.moving=dx~=0 or dy~=0;a.progress=0;a.animClock=0;a.stepFrames=frames or 16;a.stepFlip=not a.stepFlip
    Motion.begin(a,w.followers.motion,(a.stepFrames<=8)and not a.jumping)
    if not a.jumping and game._hnsFieldShadows then game._hnsFieldShadows.shadows.step(a,x,y,false)end
  end
  function F.tick()
    local a=F.refresh();if not a then return end
    a.animClock=a.animClock+1
    if F.transition then
      local tr=F.transition;tr.elapsed=tr.elapsed+1
      if tr.elapsed>=tr.frames then
        F.transition=nil;a.visible=tr.kind=='exit'
        if tr.done then tr.done()end
      end
      return
    end
    if F.interaction then
      local it=F.interaction;it.elapsed=it.elapsed+1
      it.y=it.y+it.velocity;if it.y~=0 then it.velocity=it.velocity+1 else it.velocity=0 end
      if it.elapsed>=85 then
        F.interaction=nil
        require('src.ui.game3.hud').openMessage(game,it.text,{done=function()Field.unlock('hnsFollowerTalk')end})
      end
    end
    if a.moving then
      Motion.tick(a)
      a.progress=a.progress+1;local f=math.min(1,a.progress/a.stepFrames)
      a.px=a.startPx+(a.targetX*16-a.startPx)*f;a.py=a.startPy+(a.targetY*16-a.startPy)*f
      if a.jumping then
        local shape=a.jumpStride==1 and w.followers.motion.jumpY or w.followers.motion.jumpNormalY
        a.raiseY=shape[math.floor((a.progress-1)*a.jumpStride/2)+1]or 0
      elseif w.followers.motion.bobbing then a.raiseY=math.floor((a.progress+2)/8)%2==0 and -1 or 0 end
      if f==1 then
        if a.jumping and game._hnsFieldShadows then game._hnsFieldShadows.shadows.step(a,a.targetX,a.targetY,true)end
        a.cellX=a.targetX;a.cellY=a.targetY;a.moving=false;a.jumping=false;a.raiseY=0;a.idleClock=0;O.updateElevation(a)
        local pending=a.pendingStep;a.pendingStep=nil
        if pending then F.step(pending.x,pending.y,pending.frames,pending.playerJump)end
      end
    elseif not F.interaction and a.visible then
      a.idleClock=(a.idleClock or 0)+1
      -- A one-frame walking gap must not restart the pose cycle.
      if not a.poseDuration or a.poseDuration~=w.followers.motion.walkPoseDuration then Motion.begin(a,w.followers.motion,false)else Motion.tick(a)end
      a.raiseY=w.followers.motion.bobbing and(math.floor((a.idleClock+2)/8)%2==1 and -1 or 0)or 0
    end
  end
  function F.beginBall(kind,fast,done)
    local a=F.actor;if not a then if done then done()end;return end
    a.visible=true;a.moving=false;a.raiseY=0;a.pendingStep=nil
    F.transition={kind=kind,elapsed=0,frames=fast and 8 or 16,done=done}
  end
  function F.ballPose()
    local tr=F.transition;if not tr then return end
    local remaining=tr.frames-tr.elapsed
    local switch=tr.frames==8 and 3 or 7;local half=math.floor(switch/2)
    if tr.kind=='exit'then
      if remaining>switch then return 'ball',1 end
      if remaining>half then return 'white',(switch-remaining+1)/4 end
      return 'mon',1
    end
    if remaining>11 then return 'mon',1 end
    if remaining>7 then return 'white',(remaining-7)/4 end
    return 'ball',1
  end
  function F.message(mon)
    local name=Pokemon.displayName(mon);local key='sHappyMsg02'
    if mon.status=='BRN'then key='sCondMsg42'
    elseif (mon.hp or 0)*4<(mon.maxHp or 1)then key='sSadMsg00'
    elseif (mon.friendship or 70)<50 then key='sNeutralMsg00'end
    local text=w.followers.messages[key]or w.followers.messages.sHappyMsg02
    return text:gsub('{STR_VAR_1}',function()return name end),key=='sSadMsg00'and 2 or key=='sNeutralMsg00'and 1 or key=='sCondMsg42'and 7 or 0
  end
  local move=old.move or P.tryMove
  P.tryMove=function(dir,g,run)
    local x,y=P.cellX,P.cellY;local result=move(dir,g,run)
    if g==game then
      if result=='step'or result=='ledge'then F.step(x,y,P.stepFrames,result=='ledge')
      elseif result=='connection'then F.step(P.cellX,P.cellY,P.stepFrames)end
    end;return result
  end
  -- Seamless loads change the coordinate origin, not follower visibility.
  local mapLoad=old.mapLoad or Map.load
  Map.load=function(modArg,g,id,opts)
    local a=F.actor
    if g==game and opts and opts.seamless and a and w.maps[id]and H.own(g.session or g.save)then
      local d=({left={-1,0},right={1,0},up={0,-1},down={0,1}})[opts.facing]
      if d then
        local dx,dy=opts.x-d[1]-P.cellX,opts.y-d[2]-P.cellY
        a.cellX=a.cellX+dx;a.cellY=a.cellY+dy;a.px=a.px+dx*16;a.py=a.py+dy*16
        if a.targetX then a.targetX=a.targetX+dx;a.targetY=a.targetY+dy;a.startPx=a.startPx+dx*16;a.startPy=a.startPy+dy*16 end
        if a.pendingStep then a.pendingStep.x=a.pendingStep.x+dx;a.pendingStep.y=a.pendingStep.y+dy end
        F.map=id;a.mapDef=g.data.maps[id];F.seamlessTransfer=true
      end
    end
    local ok,result=pcall(mapLoad,modArg,g,id,opts);F.seamlessTransfer=nil
    if not ok then error(result,0)end;return result
  end
  local walkPhase=old.walkPhase or O.walkPhase
  O.walkPhase=function(a)
    if a==F.actor and a.visible and not(a.moving or F.transition or F.interaction)then
      return math.floor(a.animClock/8)%2
    end
    return walkPhase(a)
  end
  local list=old.list or O.forDraw;local at=old.at or O.at
  O.forDraw=function(...)
    local base=list(...);local a=F.refresh();if not(a and a.visible)then return base end
    local out={};for _,v in ipairs(base)do out[#out+1]=v end;out[#out+1]=a;return out
  end
  O.at=function(x,y)
    local normal=at(x,y);if normal then return normal end
    local a=F.refresh();if a and a.visible and not F.transition and(a.moving and a.targetX or a.cellX)==x and(a.moving and a.targetY or a.cellY)==y then return a end
  end
  local owDraw=old.owDraw or Ow.draw
  Ow.draw=function(id,px,py,cx,cy,facing,phase,flip,opts)
    local a=F.actor
    if a and id==a.graphicsId and px==a.px and py==a.py+(a.raiseY or 0)and a.moving and not(F.transition or F.interaction)then
      local out={};for k,v in pairs(opts or {})do out[k]=v end
      local spr=Ow.get(id);local right=facing=='right'and spr and spr.hnsAsymmetric
      local frames=right and {9,11}or({down={0,4},up={1,6},left={2,8},right={2,8}})[facing]or {0,4}
      out.frame=frames[Motion.frame(a,w.followers.motion)+1]
      return owDraw(id,px,py,cx,cy,right and'left'or facing,phase,flip,out)
    end
    if a and id==a.graphicsId and px==a.px and py==a.py+(a.raiseY or 0)and not(a.moving or F.transition or F.interaction)then
      local out={};for k,v in pairs(opts or {})do out[k]=v end
      local spr=Ow.get(id);local right=facing=='right'and spr and spr.frameCount==12
      local base=right and 10 or({down=0,up=1,left=2,right=2})[facing]or 0
      local second=right and 11 or({down=4,up=6,left=8,right=8})[facing]or 4
      out.frame=Motion.frame(a,w.followers.motion)==1 and second or base
      return owDraw(id,px,py,cx,cy,right and'left'or facing,phase,flip,out)
    end
    if not(a and id==a.graphicsId and px==a.px and py==a.py+(a.raiseY or 0)and F.transition)then
      return owDraw(id,px,py,cx,cy,facing,phase,flip,opts)
    end
    local kind,scale=F.ballPose();local lg=love.graphics
    if kind=='ball'then
      local base=({down=0,up=2,left=4,right=4})[facing]or 0
      return owDraw(w.followers.ball.graphicsId,px,py,cx,cy,facing,0,false,{frame=base+math.floor(F.transition.elapsed/4)%2})
    end
    lg.push('all')
    if kind=='white'and lg.newShader then
      F.whiteShader=F.whiteShader or lg.newShader('vec4 effect(vec4 c,Image tex,vec2 uv,vec2 sc){return vec4(1.0,1.0,1.0,Texel(tex,uv).a)*c;}')
      lg.setShader(F.whiteShader)
      -- Source affine commands compress horizontally about the sprite centre.
      local x,y=px-cx+8,py-cy+16;lg.translate(x,y);lg.scale(math.min(1,scale),1);lg.translate(-x,-y)
    end
    local result=owDraw(id,px,py,cx,cy,facing,phase,flip,opts);lg.pop();return result
  end
  local collect=old.collect or Fx.collectActors
  Fx.collectActors=function(actors)
    collect(actors);local it=F.interaction;local a=F.actor
    if not(it and a and a.visible)then return end
    local row=F.row(F.mon);local sx,sy=a.px,a.py-math.floor(row.height/2)-8+it.y
    local art=w.followers.emotes;local frame=it.emotion*2+(it.elapsed>=30 and it.elapsed<55 and 1 or 0)
    actors[#actors+1]={kind='field_effect_emote',oamPriority=1,elevation=a.currentElevation,i=92000,sortY=a.py+.5,x=sx,y=sy,
      draw=function(_,cx,cy)
        love.graphics.setColor(1,1,1,1);love.graphics.draw(U.image(art.file,art.width,art.height),love.graphics.newQuad(frame*16,0,16,16,art.width,art.height),sx-cx,sy-cy)
      end}
  end
  local entrance=old.entrance or Warp.startDoorEntrance;local exit=old.exit or Warp.startDoorExit
  local function door(next,...)
    local args={...};local g=args[2];local a=g==game and F.refresh()
    if a and a.visible and not F.transition then
      Field.lock('hnsFollowerWarp')
      F.beginBall('enter',false,function()Field.unlock('hnsFollowerWarp');next(unpack(args))end)
      return true
    end
    if g==game and F.transition then return true end
    return next(...)
  end
  Warp.startDoorEntrance=function(...)return door(entrance,...)end
  Warp.startDoorExit=function(...)return door(exit,...)end
  if not old.hook then
    mod.hooks:wrap('input.step',function(next,g,dt)
      if g==game and g.phase~='boot'then F.tick()end;return next(g,dt)
    end)
    mod.hooks:wrap('world.talk',function(next,g,object)
      if g~=game or not(object and object.def and object.def.hnsFollower)then return next(g,object)end
      if F.interaction or F.transition then return true end
      object.facing=({up='down',down='up',left='right',right='left'})[P.facing]
      require('src.core.game3.audio').playCry(Pokemon.speciesOf(F.mon),0)
      local text,emotion=F.message(F.mon);Field.lock('hnsFollowerTalk')
      F.interaction={text=text,emotion=emotion,elapsed=0,y=0,velocity=-5};return true
    end)
  end
  game._hnsFollower={follower=F,move=move,mapLoad=mapLoad,walkPhase=walkPhase,list=list,at=at,owDraw=owDraw,collect=collect,entrance=entrance,exit=exit,hook=true}
end
