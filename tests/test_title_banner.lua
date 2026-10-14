-- Actual native OAM callbacks and title drawing, shared by the full suite
-- and the small unreleased-title check. Only the GPU compositor is absent.
return function(T,game,title,machine,input)
  local banner=game._hnsBoot.banner;local draw=banner.draw;local caption
  local ppuDraw=rawget(machine.ppu,'draw');local composed=0;local captions=0
  machine.ppu.draw=function()composed=composed+1 end
  banner.draw=function(label,x,y,color)
    captions=captions+1;caption={label=label,x=x,y=y,fg=color(5),shadow=color(1)}
    return draw(label,x,y,color)
  end
  local ok,err=pcall(title.draw,title)
  T.check(ok,'actual title draws Mod caption '..tostring(err or ''))
  T.eq(composed,1,'Mod caption follows the title compositor')
  T.eq(caption.label,game._hnsBoot.versionText,'title caption uses the installed manifest version')
  T.check(caption.label:match('^Mod v%d+%.%d+%.%d+$')~=nil,'Mod caption is separate from the source version')
  T.eq(caption.x+banner.width(caption.label),236,'Mod caption keeps a four-pixel right margin')
  T.check(caption.x>=0,'Mod caption fits the native viewport')
  T.eq(caption.y,151,'Mod caption sits in the lower-right corner')
  T.eq(banner.font.height,7,'caption uses outlined source-size bitmap lettering')
  T.eq(caption.fg[1],1,'Mod caption uses the source white palette')
  local bubble=0
  for _,s in pairs(machine.ppu.sprites.sprites)do
    if s.inUse and(s.x==98 or s.x==162)and s.y==58 then bubble=bubble+1 end
  end
  T.eq(bubble,2,'both HEART & SOUL sprites reach the HnS source goal, eight pixels above Emerald')
  local start,version={},{}
  for _,s in pairs(machine.ppu.sprites.sprites)do
    if s.inUse and s.y==138 then start[#start+1]=s
    elseif s.inUse and s.y==148 then version[#version+1]=s end
  end
  T.eq(#start,5,'original PRESS START OAM banner is present')
  T.eq(#version,5,'original source-version OAM banner is restored')
  for _,s in ipairs(start)do T.eq(s.data[0],1,'PRESS START retains its blink callback');T.check(s.animNum<5,'PRESS START uses original source frames')end
  for _,s in ipairs(version)do T.eq(s.data[0],1,'source version retains its blink callback');T.check(s.animNum>=5 and s.animNum<10,'source version uses original source frames')end
  local visible,hidden=false,false
  for frame=1,64 do
    title:update(input,1/60)
    local off=start[1].invisible
    if off then hidden=true else visible=true end
    for _,s in ipairs(start)do T.eq(s.invisible,off,'PRESS START tiles blink together')end
    for _,s in ipairs(version)do T.eq(s.invisible,off,'v2.0.6 blinks with PRESS START');T.eq(s.data[1],start[1].data[1],'source banners share the same blink phase')end
    local n=captions;title:draw();T.eq(captions,n+1,'Mod caption draws during both blink phases')
    T.eq(caption.fg[1],1,'Mod caption stays opaque through both blink phases')
  end
  T.check(visible and hidden,'native callbacks exercise both blink phases')
  title:update({wasPressed=function(_,key)return key=='start'end},1/60)
  local result
  for i=1,120 do result=title:update(input,1/60);if result then break end end
  T.eq(result,'menu','START on HnS title enters native main menu')
  title:draw();T.eq(caption.shadow[1],1,'Mod caption follows the native white exit fade')
  banner.draw=draw;machine.ppu.draw=ppuDraw
end
