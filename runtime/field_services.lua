-- Source door/arrow presentation and HnS berry trees on native save/VM state.
return function(mod,world,game)
  local S=world.services;local old=game._hnsServices or {}
  local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags');local O=require('src.core.game3.objects')
  local Doors=require('src.core.game3.doors');local Arrow=require('src.core.game3.warp_arrow')
  local FE=require('src.core.game3.field_effects');local Fx=require('src.core.game3.field_effects_rse')
  local B=require('src.core.game3.rse.berry_trees');local Bag=require('src.core.game3.bag')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,world.startup.ui)
  local function own(s)s=s or Rt.getSession();return s and world.maps[s.map]end
  local function image(a)return U.image(a.file,a.width,a.height)end
  local entry=old.entry or Doors.getDoorEntryAt
  Doors.getDoorEntryAt=function(map,x,y)
    local live=Rt.getSession();map=live and own(live)and live.map or map
    local m=world.maps[map];local def=game.data.maps[map];local mid=def and def.midLayout and def.midLayout:midAt(x,y)
    local a=m and mid and S.doors[m.pair]and S.doors[m.pair][tostring(mid)..':'..m.hnsLayoutVersion]
    if m then
      local beh=mid and (world.pairs[m.pair].behaviors[mid]or world.pairs[m.pair].behaviors[tostring(mid)])
      if a and (beh=='MB_WARP_DOOR'or beh=='MB_ANIMATED_DOOR'or beh=='MB_PETALBURG_GYM_DOOR')then
        return {tile='hns_'..a.file,file=a.file,sound=a.sound,size=a.h==16 and '1x1'or '1x2',hns=a},a
      end
      return nil
    end
    return entry(map,x,y)
  end
  local doorMethods={}
  for _,name in ipairs({'open','holdOpen','close','closeAfterDelay'})do
    local base=old[name]or Doors[name];doorMethods[name]=base
    Doors[name]=function(map,x,y,...)
      local e=Doors.getDoorEntryAt(map,x,y);local anim=base(map,x,y,...)
      if e and e.hns and anim then
        anim.hns=e.hns;anim.frame=(name=='open')and 0 or 3;anim.targetFrame=(name=='open'or name=='holdOpen')and 3 or 0
      end
      return anim
    end
  end
  local isOpen=old.isOpen or Doors.isOpen
  Doors.isOpen=function(map,x,y)local a=Doors.getActiveAnim(map,x,y);if a and a.hns then return a.frame==3 end;return isOpen(map,x,y)end
  local update=old.update or Doors.update;local draw=old.draw or Doors.draw
  Doors.update=function(dt)
    local a=Doors._activeAnim
    if not(a and a.hns)then return update(dt)end
    if a.mode=='hold'then return end
    if a.mode=='delay_close'then a.delayTimer=a.delayTimer-1;if a.delayTimer<=0 then a.mode='close';a.timer=0 end;return end
    a.timer=a.timer+1
    if a.timer<4 then return end;a.timer=0
    if a.mode=='open'and a.frame<3 then a.frame=a.frame+1;return end
    if a.mode=='close'and a.frame>0 then a.frame=a.frame-1;return end
    local done=a.onDone;a.onDone=nil
    if a.mode=='open'then a.mode='hold'else Doors._activeAnim=nil end
    if done then done()end
  end
  Doors.draw=function(cx,cy,w,h)
    local a=Doors._activeAnim;if not(a and a.hns)then return draw(cx,cy,w,h)end
    if a.frame==0 then return end
    local p=a.hns;local im=image(p);local q=love.graphics.newQuad(0,(a.frame-1)*p.h,p.w,p.h,p.width,p.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,a.x*16-(cx or 0),a.y*16-(cy or 0)-(p.h>16 and 16 or 0))
  end
  local arrowShow=old.arrowShow or Arrow.show;local arrowDraw=old.arrowDraw or Arrow.draw
  local frames={down={3,7},up={0,4},left={1,5},right={2,6}}
  Arrow.show=function(dir,x,y)
    arrowShow(dir,x,y)
    if own()then local a=Arrow._state;a.seq={{frames[dir][1],32},{frames[dir][2],32}}end
  end
  Arrow.draw=function(cx,cy)
    if not own()then return arrowDraw(cx,cy)end
    local a=Arrow._state;if not(a.visible and a.seq)then return end
    local info=S.arrow[tostring((Rt.getSession()or {}).gender or 0)]or S.arrow['0'];local im=image(info)
    local frame=a.seq[a.step][1];local cols=info.width/16
    local q=love.graphics.newQuad(frame%cols*16,math.floor(frame/cols)*16,16,16,info.width,info.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,a.cx*16-(cx or 0),a.cy*16-(cy or 0))
  end
  local info=old.info or B.info;local grow=old.grow or B.grow;local time=old.time or B.timeUpdate
  B.info=function(id)if own()and S.berries[tostring(id)]then return S.berries[tostring(id)]end;return info(id)end
  B.grow=function(t,random)
    if not own()then return grow(t,random)end
    if t.stopGrowth or t.stage==0 then return false end
    if t.stage<5 then t.berryYield=B.calcYield(t,random);t.stage=5 end;return true
  end
  B.timeUpdate=function(session,minutes,random)
    if not own(session)then return time(session,minutes,random)end
    for _,t in pairs(B.state(session))do
      if t.berry and t.berry>0 and t.stage>0 and t.stage~=5 and not t.stopGrowth then
        if minutes<(t.minutesUntilNextStage or 0)then t.minutesUntilNextStage=t.minutesUntilNextStage-minutes
        else B.grow(t,random);t.minutesUntilNextStage=B.stageDuration(t.berry)*4 end
      end
    end
  end
  local bm=old.berryManifest or Fx.berryManifest
  local manifest={trees={}}
  for id,r in pairs(S.berries)do local c={};for k,v in pairs(r.tree)do c[k]=v end;c.file=c.nativeFile;manifest.trees[tonumber(id)]=c end
  Fx.berryManifest=function()if own()then return manifest end;return bm()end
  -- Native field-effect cache resets rebind the scoped source tree sheets.
  local install=old.feInstall or FE.install;local cache=old.feCache or FE._cache
  local function overlay(base)return {read=function(_,rel)
    local id=type(rel)=='string'and rel:match('berry_trees/(%d+)%.rgba$')
    if own()and id and S.berries[id]then return mod:read('services/tree_'..id..'.rgba')end
    return base and base:read(rel)
  end}end
  FE.install=function(c)return install(overlay(c))end;install(overlay(cache))
  local function initialize(s)
    if not own(s)then return end
    local done=Space.store and Flags.getFlag(Space.store,nil,S.initializedFlag)or s.flags and(s.flags[S.initializedFlag]or s.flags[tostring(S.initializedFlag)])
    if done then return end
    local state=B.state(s)
    for _,r in ipairs(S.objects)do local t=state[r.id]or state[tostring(r.id)];if not t or(t.berry or 0)==0 then B.plant(r.id,r.berry,5,false,s)end end
    s.flags=s.flags or {};s.flags[S.initializedFlag]=true
    if Space.store then Flags.setFlag(Space.store,nil,S.initializedFlag,true)end
  end
  local loadMap=old.loadMap or O.loadMap
  O.loadMap=function(g,id,def)initialize(Rt.getSession());return loadMap(g,id,def)end
  local N=require('src.core.game3.scripting.natives');local Rse=require('src.core.game3.rse.init')
  N.ALLOW['native:'..S.harvestNative]=function(ctx)
    local NB=require('src.core.game3.scripting.natives_berry');local id,eo=NB.treeId(ctx)
    Rse.setSpecialVar(ctx,0x8004,0)
    if not own()or not eo then return false end
    local s=Rt.getSession();local t=B.get(s,id);B.allowGrowth(id)
    if t.stage~=5 or NB.sparkling(eo)then return false end
    local meta=assert(S.berries[tostring(t.berry)]);local qty=t.berryYield
    ctx.stringVars=ctx.stringVars or {};ctx.stringVars[1]=meta.name..(qty==1 and ' BERRY'or ' BERRIES');ctx.stringVars[2]=tostring(qty)
    if not Bag.add(s.bag,meta.item,qty)then Rse.setSpecialVar(ctx,0x8004,1);return false end
    Rse.setSpecialVar(ctx,0x8006,qty)
    NB.BY_NAME.IncrementDailyPickedBerries(ctx);NB.BY_NAME.IncrementDailyPlantedBerries(ctx)
    B.plant(id,t.berry,2,true,s);eo.berryTree.justPicked=true
    Rse.setSpecialVar(ctx,0x8004,2);return false
  end
  initialize(Rt.getSession())
  game._hnsServices={entry=entry,isOpen=isOpen,update=update,draw=draw,arrowShow=arrowShow,arrowDraw=arrowDraw,info=info,grow=grow,time=time,berryManifest=bm,feInstall=install,feCache=cache,loadMap=loadMap,ui=U,initialize=initialize}
  for k,v in pairs(doorMethods)do game._hnsServices[k]=v end
end
