-- HnS palettes/poses over the native projection, clipping and water distortion.
return function(mod,w,game)
  local R=require('src.core.game3.field_effects_rse');local Rt=require('src.core.game3.runtime')
  local Ow=require('src.core.game3.ow_sprites')
  local old=game._hnsReflections or{};local S=old.state or{gfx={},palettes={}}
  S.spec=w.fieldShadows.reflection
  local fc=old.fc or R.fc;local kind=old.kind or R.reflectionType
  local tag=old.tag or R.reflectionPaletteTag;local draw=old.draw or R.drawBehind
  local function own()local s=Rt.getSession();return s and w.maps[s.map]end
  function S.filter(color,mode)
    if mode=='bridge'then return S.spec.bridgeColor end
    local d=assert(S.spec.filters[mode]);local function clamp(v)return math.max(0,math.min(31,v))end
    return clamp(color%32+d[1])+32*clamp(math.floor(color/32)%32+d[2])+1024*clamp(math.floor(color/1024)%32+d[3])
  end
  local function rgb(c)return{math.floor((c%32)*255/31+.5),math.floor((math.floor(c/32)%32)*255/31+.5),math.floor((math.floor(c/1024)%32)*255/31+.5)}end
  function S.register(gid)
    if S.gfx[gid]then return S.gfx[gid]end
    if not w.opening.sprites[tostring(gid)]then return end
    local bytes=mod:read('ow/'..gid..'.meta')
    if not(bytes and bytes:sub(1,4)=='SVOW'and bytes:byte(5)==2 and #bytes>=54)then return end
    local base='hns:source:'..gid;local p={};local raw={}
    for i=1,16 do local offset=23+(i-1)*2;raw[i]=bytes:byte(offset)+256*bytes:byte(offset+1);p[i]=rgb(raw[i])end
    S.palettes[base]=p
    for _,mode in ipairs({'pond','ice','bridge'})do
      local out={};for i=1,16 do out[i]=i==1 and p[i]or rgb(S.filter(raw[i],mode))end
      S.palettes['hns:'..mode..':'..gid]=out
    end
    local info={paletteTag=base,slot=0,noReflectionLoad=false}
    S.gfx[gid]=info;return info
  end
  R.fc=function()
    local base=fc()
    if not own()then return base end
    -- Retain native tags/tables for unowned graphics and lazy source records.
    if S.base~=base or not S.view then
      S.base=base;S.view=setmetatable({gfx=setmetatable(S.gfx,{__index=base and base.gfx}),palettes=setmetatable(S.palettes,{__index=base and base.palettes})},{__index=base})
    end
    return S.view
  end
  R.reflectionType=function(...)
    local value=kind(...);S.kind=value;return value
  end
  R.reflectionPaletteTag=function(gid,bridge,...)
    if own()and S.register(gid)then
      return 'hns:'..(bridge~=0 and'bridge'or S.kind==1 and'ice'or'pond')..':'..gid
    end
    return tag(gid,bridge,...)
  end
  R.drawBehind=function(...)
    if not own()then return draw(...)end
    local F=game._hnsFollower and game._hnsFollower.follower;local a=F and F.actor
    if not a then return draw(...)end
    local frame,facing,hidden=a.customFrame,a.facing,a.hideReflection
    if F.transition then a.hideReflection=true
    elseif F.pose then local f,d=F.pose(a,Ow.get(a.graphicsId));if f~=nil then a.customFrame=f;a.facing=d end end
    local ok,result=pcall(draw,...)
    a.customFrame,a.facing,a.hideReflection=frame,facing,hidden
    if not ok then error(result,0)end;return result
  end
  game._hnsReflections={state=S,fc=fc,kind=kind,tag=tag,draw=draw}
end
