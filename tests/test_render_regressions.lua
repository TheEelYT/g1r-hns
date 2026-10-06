-- Graphics boundary fixture: exercise the real tint wrapper under changing
-- world viewports and inherited transforms, including its error cleanup.
return function(T,mod,w,game,s)
  local Field=require('src.core.game3.field_view');local Rtc=require('src.core.game3.rtc')
  local oldDraw,oldTime,oldGraphics=Field.draw,game._hnsTime,love.graphics
  local oldInfo,oldCalc,oldOffset=Rtc.getInfo,Rtc.calcLocalTime,Rtc.calcLocalTimeOffset
  local lg={};local stack={};local released=0;local canvas={name='world'}
  local st={canvas=canvas,x=32,y=24,sx=3,sy=3,clip={1,2,3,4}};local fail=false;local called=0
  function lg.newCanvas(w,h,opts)
    T.eq(opts.dpiscale,1,'tint canvas uses physical world pixels')
    return {w=w,h=h,setFilter=function()end,getWidth=function(a)return a.w end,getHeight=function(a)return a.h end,release=function()released=released+1 end}
  end
  function lg.newShader()return {send=function()end}end
  function lg.getCanvas()return st.canvas end
  function lg.push()local copy={};for k,v in pairs(st)do copy[k]=v end;stack[#stack+1]=copy end
  function lg.pop()st=assert(table.remove(stack))end
  function lg.setCanvas(c)st.canvas=c end
  function lg.origin()st.x=0;st.y=0;st.sx=1;st.sy=1 end
  function lg.setScissor(...)st.clip=select('#',...)>0 and {...}or nil end
  function lg.clear()end
  function lg.setShader(sh)st.shader=sh end
  function lg.setColor(...)st.color={...}end
  function lg.draw(c,x,y)
    T.eq(st.canvas,canvas,'tint returns to caller world canvas')
    T.eq(st.sx,3,'caller zoom is applied once to composite');T.eq(st.x,32,'caller origin restored for composite')
    T.eq(x,0,'composite starts at viewport origin');T.eq(y,0,'composite starts at viewport origin')
    T.check(st.shader~=nil,'composite uses source tint shader')
  end
  Field.draw=function(g,vw,vh,opts)
    called=called+1
    T.eq(st.canvas.w,vw,'world width fills offscreen tint canvas');T.eq(st.canvas.h,vh,'world height fills offscreen tint canvas')
    T.eq(st.sx,1,'world render has identity zoom in offscreen canvas');T.eq(st.x,0,'offscreen render clears inherited origin')
    T.eq(st.clip,nil,'offscreen render clears inherited scissor');T.eq(opts.actorsOnly,false,'field draw options preserved')
    if fail then error('draw failure fixture')end;return 'drawn'
  end
  love.graphics=lg;game._hnsTime=nil
  assert(load(mod:read('time_cycle.lua')))()(mod,w,game)
  local time=game._hnsTime.time
  Rtc.calcLocalTime=function()return {hours=21,minutes=0}end
  for _,size in ipairs({{240,160},{480,320},{1024,640},{320,240}})do
    T.eq(Field.draw(game,size[1],size[2],{actorsOnly=false}),'drawn','night draws entire changing world viewport')
    T.eq(lg.getCanvas(),canvas,'caller canvas restored');T.eq(#stack,0,'graphics stack balanced')
  end
  T.eq(called,4,'actual tint wrapper forwards each viewport');T.eq(released,3,'resizing releases obsolete tint canvases')
  fail=true;T.eq(pcall(Field.draw,game,320,240,{actorsOnly=false}),false,'field error propagates')
  T.eq(lg.getCanvas(),canvas,'field error restores original canvas');T.eq(#stack,0,'field error restores graphics state')
  love.graphics=oldGraphics;Field.draw=oldDraw;game._hnsTime=oldTime
  Rtc.getInfo=oldInfo;Rtc.calcLocalTime=oldCalc;Rtc.calcLocalTimeOffset=oldOffset
end
