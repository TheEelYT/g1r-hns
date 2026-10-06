-- HnS clock, timed encounters and 5-bit outdoor palette transitions.
return function(mod,w,game)
  local old=game._hnsTime or {};local Time=old.time or {}
  local H=game._hnsRules.rules;local Rt=require('src.core.game3.runtime')
  local Rtc=require('src.core.game3.rtc');local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags');local O=require('src.core.game3.objects')
  local Enc=require('src.core.game3.encounters');local Field=require('src.core.game3.field_view')
  -- Content registration resolves species names to native IDs. Timed pools
  -- bypass that registry, so resolve them once before handing them to RSE.
  local Pokemon=require('src.core.game3.pokemon');local timed={}
  for id,pools in pairs(w.encounters.timed or {})do
    timed[id]={}
    for period,pool in pairs(pools)do
      local out={};timed[id][period]=out
      for kind,area in pairs(pool)do
        local slots={};out[kind]={rate=area.rate,slots=slots}
        for i,entry in ipairs(area.slots)do
          local copy={};for k,v in pairs(entry)do copy[k]=v end
          copy.species=assert(tonumber(entry.species)or Pokemon.speciesFromName(entry.species),'unresolved timed encounter species '..tostring(entry.species))
          slots[i]=copy
        end
      end
    end
  end
  local function fake(s)return H.own(s)and H.value('ITEM_FEATURES_RTC_TYPE',s)==1 end
  function Time.save(s)
    s.modData=s.modData or {};local t=s.modData.hnsTime
    if not t then t={format=1,seconds=36000,frames=0};s.modData.hnsTime=t end
    return t
  end
  local info=old.info or Rtc.getInfo;local calc=old.calc or Rtc.calcLocalTime
  local offset=old.offset or Rtc.calcLocalTimeOffset
  Rtc.getInfo=function(s)
    s=s or Rt.getSession();if not fake(s)then return info(s)end
    local f=Rtc._fieldsOf(Time.save(s).seconds)
    return {year=f.year-2000,month=f.month,day=f.day,hour=f.hour,minute=f.minute,second=f.second}
  end
  Rtc.calcLocalTime=function(s)
    s=s or Rt.getSession();if not fake(s)then return calc(s)end
    local n=Time.save(s).seconds
    Rtc.localTime=Rtc.newTime(math.floor(n/86400),math.floor(n/3600)%24,math.floor(n/60)%60,n%60)
    Rtc._info=Rtc.getInfo(s);return Rtc.copyTime(Rtc.localTime)
  end
  Rtc.calcLocalTimeOffset=function(s,d,h,m,sec)
    if fake(s)then local t=Time.save(s);t.seconds=(d or 0)*86400+(h or 0)*3600+(m or 0)*60+(sec or 0);t.frames=0 end
    return offset(s,d,h,m,sec)
  end
  function Time.period(t)
    local h=t.hours;return (h>=19 or h<6)and 'Night'or h<10 and 'Morning'or h>=18 and 'Evening'or 'Day'
  end
  local night,morning,day={116,116,157},{224,176,168},{256,256,256}
  function Time.blend(t)
    local n=t.hours*60+t.minutes
    if n<360 or n>=1200 then return night,night,256 end
    if n<480 then return night,morning,256-math.floor(256*(n-360)/120)end
    if n<600 then return morning,day,256-math.floor(256*(n-480)/120)end
    if n<1080 then return day,day,256 end
    if n<1140 then return day,morning,256-math.floor(256*(n-1080)/60)end
    return morning,night,256-math.floor(256*(n-1140)/60)
  end
  function Time.channel(c,a,b,weight)
    local x,z=math.floor(c*a/256),math.floor(c*b/256)
    return z+math.floor((x-z)*weight/256)
  end
  function Time.tick(s,dt)
    if not H.own(s)then return end
    local Clock=require('src.ui.game3.rse.wall_clock')
    if fake(s)and not Clock.isOpen()then
      local t=Time.save(s);t.frames=t.frames+(dt or 1/60)*60
      local seconds=math.floor((t.frames+1e-7)/60);t.frames=t.frames-seconds*60;t.seconds=t.seconds+seconds*24
    end
    local period=Time.period(Rtc.calcLocalTime(s))
    if Space.store and w.fieldPokemon then
      local f=w.fieldPokemon.flags;local changed=false
      for id,value in pairs({[f.dayHidden]=period=='Night',[f.nightHidden]=period~='Night'})do
        if Flags.getFlag(Space.store,nil,id)~=value then
          Flags.setFlag(Space.store,nil,id,value);changed=true
        end
      end
      if changed then O.refreshVisibility()end
    end
    Enc.ensureLoaded()
    for id,pools in pairs(timed)do Enc._tables[id]=pools[period]or pools.Day end
    Time.currentPeriod=period
  end
  local draw=old.draw or Field.draw
  Field.draw=function(g,vw,vh,opts)
    local s=Rt.getSession();local m=H.own(s)and w.maps[s.map]
    local outdoors=m and ({[1]=true,[2]=true,[3]=true,[6]=true})[m.mapType]
    if not outdoors or not love.graphics.newShader or not love.graphics.getCanvas then return draw(g,vw,vh,opts)end
    local t=Rtc.calcLocalTime(s);local a,b,weight=Time.blend(t)
    if a[1]==256 and b[1]==256 then return draw(g,vw,vh,opts)end
    local lg=love.graphics
    if not Time.shader then Time.shader=lg.newShader([[extern vec3 lut[32];
      vec4 effect(vec4 c,Image tex,vec2 uv,vec2 sc){vec4 p=Texel(tex,uv);
      ivec3 n=ivec3(floor(p.rgb*31.0+0.5));
      return vec4(lut[n.r].r,lut[n.g].g,lut[n.b].b,p.a)*c;}]])end
    local lut={};for c=0,31 do local r={};for k=1,3 do r[k]=Time.channel(c,a[k],b[k],weight)/31 end;lut[c+1]=r end
    Time.shader:send('lut',unpack(lut))
    local cw,ch=math.ceil(vw or 240),math.ceil(vh or 160)
    if not Time.canvas or Time.canvas:getWidth()~=cw or Time.canvas:getHeight()~=ch then
      if Time.canvas then Time.canvas:release()end
      Time.canvas=lg.newCanvas(cw,ch,{dpiscale=1});Time.canvas:setFilter('nearest','nearest')
    end
    lg.push('all');lg.setCanvas(Time.canvas);lg.origin();lg.setScissor();lg.clear(0,0,0,0)
    local ok,result=pcall(draw,g,vw,vh,opts);lg.pop();if not ok then error(result)end
    lg.push('all');lg.setShader(Time.shader);lg.setColor(1,1,1,1);lg.draw(Time.canvas,0,0);lg.pop();return result
  end
  if not old.hook then mod.hooks:wrap('input.step',function(next,g,dt)
    if g==game and g.phase~='boot'then Time.tick(Rt.getSession(),dt)end;return next(g,dt)
  end)end
  game._hnsTime={time=Time,timed=timed,info=info,calc=calc,offset=offset,draw=draw,hook=true}
end
