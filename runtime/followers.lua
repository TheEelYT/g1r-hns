-- A nonblocking native actor follows the first living non-egg party member.
return function(mod,w,game)
  local old=game._hnsFollower or {};local F=old.follower or {}
  local Rt=require('src.core.game3.runtime');local P=require('src.core.game3.player')
  local O=require('src.core.game3.objects');local Pokemon=require('src.core.game3.pokemon')
  local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
  local C=require('src.core.game3.constants').of('emerald');local H=game._hnsRules.rules
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
    local s=Rt.getSession();local mon=H.own(s)and F.lead(s)
    if not F.allowed(s,mon)then F.actor=nil;F.mon=nil;return end
    local row=F.row(mon);local gid=Pokemon.isShiny(mon)and row.shiny or row.normal
    if F.mon~=mon or F.map~=s.map or not F.actor or F.actor.graphicsId~=gid then
      F.mon,F.map=mon,s.map
      F.actor={localId=0xFD,def={hnsGraphicsId=gid,graphicsId=gid,hnsFollower=true,scriptKey='HNS_FOLLOWER_TALK'},
        graphicsId=gid,cellX=P.cellX,cellY=P.cellY,px=P.cellX*16,py=P.cellY*16,
        facing=P.facing,currentElevation=P.currentElevation,visible=false,hidden=false,animClock=0,
        moving=false,stepFrames=16,passable=true,mapDef=game.data.maps[s.map]}
    end
    return F.actor
  end
  function F.step(x,y,frames)
    local a=F.refresh();if not a then return end
    a.visible=true;a.startPx=a.px;a.startPy=a.py;a.targetX=x;a.targetY=y
    local dx,dy=x*16-a.px,y*16-a.py
    if dx~=0 then a.facing=dx<0 and 'left'or 'right'elseif dy~=0 then a.facing=dy<0 and 'up'or 'down'end
    a.moving=dx~=0 or dy~=0;a.progress=0;a.stepFrames=frames or 16;a.stepFlip=not a.stepFlip
  end
  function F.tick()
    local a=F.refresh();if not a then return end
    a.animClock=a.animClock+1
    if a.moving then
      a.progress=a.progress+1;local f=math.min(1,a.progress/a.stepFrames)
      a.px=a.startPx+(a.targetX*16-a.startPx)*f;a.py=a.startPy+(a.targetY*16-a.startPy)*f
      a.raiseY=(a.progress%a.stepFrames==math.floor(a.stepFrames/2))and -1 or 0
      if f==1 then a.cellX=a.targetX;a.cellY=a.targetY;a.moving=false;a.raiseY=0;O.updateElevation(a)end
    end
  end
  function F.message(mon)
    local name=mon.nickname or Pokemon.name(Pokemon.speciesOf(mon));local key='sHappyMsg02'
    if mon.status=='BRN'then key='sCondMsg42'
    elseif (mon.hp or 0)*4<(mon.maxHp or 1)then key='sSadMsg00'
    elseif (mon.friendship or 70)<50 then key='sNeutralMsg00'end
    local text=w.followers.messages[key]or w.followers.messages.sHappyMsg02
    return text:gsub('{STR_VAR_1}',name)
  end
  local move=old.move or P.tryMove
  P.tryMove=function(dir,g,run)
    local x,y=P.cellX,P.cellY;local result=move(dir,g,run)
    if g==game and result=='step'then F.step(x,y,P.stepFrames)end;return result
  end
  local list=old.list or O.forDraw;local at=old.at or O.at
  O.forDraw=function(...)
    local base=list(...);local a=F.refresh();if not(a and a.visible)then return base end
    local out={};for _,v in ipairs(base)do out[#out+1]=v end;out[#out+1]=a;return out
  end
  O.at=function(x,y)
    local normal=at(x,y);if normal then return normal end
    local a=F.refresh();if a and a.visible and(a.moving and a.targetX or a.cellX)==x and(a.moving and a.targetY or a.cellY)==y then return a end
  end
  if not old.hook then
    mod.hooks:wrap('input.step',function(next,g,dt)
      if g==game and g.phase~='boot'then F.tick()end;return next(g,dt)
    end)
    mod.hooks:wrap('world.talk',function(next,g,object)
      if g~=game or not(object and object.def and object.def.hnsFollower)then return next(g,object)end
      object.facing=({up='down',down='up',left='right',right='left'})[P.facing]
      require('src.core.game3.audio').playCry(Pokemon.speciesOf(F.mon),0)
      require('src.ui.game3.hud').openMessage(g,F.message(F.mon));return true
    end)
  end
  game._hnsFollower={follower=F,move=move,list=list,at=at,hook=true}
end
