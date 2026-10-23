return function(T,game,w,s,F)
  local state=game._hnsReflections;local S=state.state
  local R=require('src.core.game3.field_effects_rse');local Ow=require('src.core.game3.ow_sprites')
  local C=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  local O=require('src.core.game3.objects');local P=require('src.core.game3.player');local Map=require('src.core.game3.map')
  local a=F.actor;local gid=a.graphicsId;local info=S.register(gid)
  T.check(info,'owned normal follower registers reflection palette')
  local base=S.palettes[info.paletteTag];T.eq(#base,16,'source reflection retains sixteen palette entries')
  for _,mode in ipairs({'pond','ice','bridge'})do
    local p=S.palettes['hns:'..mode..':'..gid];T.eq(p[1],base[1],'reflection preserves transparent index '..mode)
    T.eq(#p,16,'reflection filter has complete palette '..mode)
  end
  T.eq(S.filter(0,'pond'),10*1024,'pond adds source blue');T.eq(S.filter(32767,'pond'),32767,'pond clamps blue')
  T.eq(S.filter(0,'ice'),3*32+16*1024,'ice clamps red and adds green/blue')
  T.eq(S.filter(32767,'ice'),26+31*32+31*1024,'ice upper clamps')
  T.eq(S.filter(0,'bridge'),0x55C9,'bridge uses source fixed blue')
  local shiny=F.row(F.mon).shiny;T.check(S.register(shiny),'shiny follower has independent source palette')
  T.check(S.gfx[shiny].paletteTag~=info.paletteTag,'normal and shiny do not alias palette cache')
  local map=s.map;s.map='EM_ROUTE101';T.eq(R.fc(),state.fc(),'foreign map delegates native FC')
  T.eq(R.reflectionPaletteTag(gid,0),state.tag(gid,0),'foreign map delegates native reflection tag');s.map=map
  local saved={};local function replace(t,k,v)saved[#saved+1]={t,k,t[k]};t[k]=v end
  local lg=love.graphics;local behavior=MB.id('ICE');local mapped,drawn,poseFrame,poseFacing
  local palette=base[2];local red,green,blue=palette[1]/255,palette[2]/255,palette[3]/255
  local data={clone=function()return {mapPixel=function(_,fn)
    local r,g,b,alpha=fn(0,0,red,green,blue,1);mapped={r,g,b,alpha}
    local r0,g0,b0,a0=fn(0,0,red,green,blue,0);T.eq(a0,0,'native recolor preserves transparent pixels')
  end}end}
  local spr={width=16,height=16,frameCount=12,hnsAsymmetric=true,imageData=data,image={getDimensions=function()return 16,192 end},quads={}}
  for f=0,11 do spr.quads[f]={}end
  replace(Ow,'getDraw',function()return spr end);replace(Ow,'peekDraw',function()return spr end);replace(Ow,'get',function()return spr end)
  replace(C,'worldBehavior',function()return behavior end)
  replace(lg,'newImage',function()return {getDimensions=function()return 16,192 end,setFilter=function()end}end)
  replace(lg,'newQuad',function()return {setViewport=function(_,x,y,w,h,iw,ih)
    T.check(x>=0 and y>=0 and x+w<=iw and y+h<=ih,'native reflection samples within source sheet')
  end}end)
  replace(lg,'draw',function(_,_,_,_,_,sx,sy)drawn=(drawn or 0)+1;T.eq(sy,-1,'native reflection vertically flips source pixels')end)
  local obj={cellX=3,cellY=4,px=48,py=64}
  R._images[gid]=nil;T.eq(R.drawReflection(obj,gid,0,false,0,0,0,0),true,'actual native ice projection draws')
  T.check((drawn or 0)>0,'native ice projection reaches draw boundary')
  local expected=S.palettes['hns:ice:'..gid][2]
  for i=1,3 do T.eq(mapped[i],expected[i]/255,'actual native recolor uses ice palette channel '..i)end
  behavior=MB.id('POND_WATER');R._images[gid]=nil;R.drawReflection(obj,gid,0,false,0,0,0,0)
  T.eq(R.lastReflectionTag,'hns:pond:'..gid,'native water projection selects pond palette')
  behavior=MB.id('BRIDGE_OVER_POND_LOW');R.reflectionType(3,4,3,4,16,16)
  T.eq(R.reflectionPaletteTag(gid,1),'hns:bridge:'..gid,'native bridge tag selects source fixed palette')
  -- Exercise actual drawBehind dispatcher with the follower pose wrapper.
  behavior=MB.id('NORMAL');replace(O,'forDraw',function()return{a}end);replace(P,'isVisible',function()return false end);replace(Map,'world',nil)
  local actor={};for k,v in pairs(a)do actor[k]=v end
  local transition,interaction=F.transition,F.interaction;F.transition=nil;F.interaction=nil
  replace(Ow,'pose',function(_,facing,_,_,opts)poseFrame=opts.frame;poseFacing=facing;return opts.frame or 0,false end)
  for _,moving in ipairs({false,true})do for _,direction in ipairs({'down','up','left','right'})do
    a.moving=moving;a.facing=direction;a.animClock=0;a.customFrame=nil;a.hideReflection=nil
    local frame,facing=F.pose(a,spr);R.drawBehind(0,0)
    T.eq(poseFrame,frame,'native reflection uses shared follower pose '..direction)
    T.eq(poseFacing,facing,'native reflection retains asymmetric convention '..direction)
    T.eq(a.customFrame,nil,'draw restores actor custom frame');T.eq(a.facing,direction,'draw restores actor facing')
  end end
  F.transition={};poseFrame=nil;R.drawBehind(0,0);T.eq(poseFrame,nil,'ball transition suppresses stale full-size reflection');T.eq(a.hideReflection,nil,'transition suppression restores actor flag')
  F.transition=nil;replace(Ow,'pose',function()error('reflection fixture failure')end)
  T.eq(pcall(R.drawBehind,0,0),false,'native draw error propagates');T.eq(a.customFrame,nil,'draw error restores temporary pose');T.eq(a.facing,'right','draw error restores facing')
  F.transition,F.interaction=transition,interaction
  for k in pairs(a)do a[k]=nil end;for k,v in pairs(actor)do a[k]=v end
  for i=#saved,1,-1 do local r=saved[i];r[1][r[2]]=r[3]end
  R._images[gid]=nil
end
