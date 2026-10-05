-- Real native binding/stepping/uploads, with a byte-accurate GPU boundary.
return function(T,game,world)
  local A=require('src.core.game3.tileset_anim');local N=require('src.core.game3.tileset_native')
  local Pack=require('src.import.gba.native_pack')
  local savedImage,savedNew=love.image.newImageData,love.graphics.newImage
  local Data={};Data.__index=Data
  function Data:getDimensions()return self.w,self.h end
  function Data:getWidth()return self.w end
  function Data:getHeight()return self.h end
  function Data:getPixel(x,y)local a,b,c,d=self.rows[y+1]:byte(x*4+1,x*4+4);return a/255,b/255,c/255,d/255 end
  function Data:setPixel(x,y,r,g,b,a)
    local row=self.rows[y+1];self.rows[y+1]=row:sub(1,x*4)..string.char(math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5),math.floor((a or 1)*255+.5))..row:sub(x*4+5)
  end
  function Data:paste(src,dx,dy,sx,sy,w,h)
    for y=0,h-1 do local row=self.rows[dy+y+1];self.rows[dy+y+1]=row:sub(1,dx*4)..src.rows[sy+y+1]:sub(sx*4+1,(sx+w)*4)..row:sub((dx+w)*4+1)end
  end
  love.image.newImageData=function(w,h,format,raw)
    raw=raw or string.rep('\0',w*h*4);local rows={};for y=0,h-1 do rows[y+1]=raw:sub(y*w*4+1,(y+1)*w*4)end
    return setmetatable({w=w,h=h,rows=rows},Data)
  end
  local uploads=0
  love.graphics.newImage=function(d)
    local img={w=d.w,h=d.h,rows={}};for i,r in ipairs(d.rows)do img.rows[i]=r end
    function img:getDimensions()return self.w,self.h end
    function img:setFilter()end
    function img:replacePixels(data)uploads=uploads+1;self.rows={};for i,r in ipairs(data.rows)do self.rows[i]=r end end
    return img
  end
  local total,banks,middle,changed=0,0,0,0
  for pair,def in pairs(world.pairs)do if def.animationFiles then
    N.invalidate();A.invalidate();local ts=assert(N.get(pair));local entry=A._pairs[pair]
    T.check(entry and entry.rse,'owned animation manifest binds through real native cache '..pair)
    A.enterMap(pair,false);local before=table.concat(ts.imageData.rows)..(ts.midImageData and table.concat(ts.midImageData.rows)or '')..(ts.overImageData and table.concat(ts.overImageData.rows)or '')
    local seen={};local count=math.max(A._rse.primaryMax,A._rse.secondaryMax);local differs=false
    for t=1,count do
      A.step()
      if t%8==0 then differs=differs or before~=table.concat(ts.imageData.rows)..(ts.midImageData and table.concat(ts.midImageData.rows)or '')..(ts.overImageData and table.concat(ts.overImageData.rows)or '')end
      for i,bank in ipairs(entry.banks)do if bank and bank.frame~=nil then seen[i]=true end end
    end
    for i,bank in ipairs(entry.banks)do T.check(seen[i],'native engine reaches source bank '..pair..':'..i);banks=banks+1;if bank.middle then middle=middle+1 end end
    local after=table.concat(ts.imageData.rows)..(ts.midImageData and table.concat(ts.midImageData.rows)or '')..(ts.overImageData and table.concat(ts.overImageData.rows)or '')
    if differs or after~=before then changed=changed+1 end
    T.check(ts.image.rows~=nil,'source animation retains uploaded native texture '..pair)
    total=total+1
  end end
  T.eq(total,world.animations.animated_pairs,'all animated source pairs are exercised')
  T.eq(banks,world.animations.banks,'all callback banks advance')
  T.check(changed>20,'actual atlas pixels differ from the static map at source frames')
  T.check(middle>0 and uploads>100,'middle-layer animations reach real image uploads')
  N.invalidate();A.invalidate();love.image.newImageData=savedImage;love.graphics.newImage=savedNew
  print(string.format('HnS tile animation: %d pairs/%d banks, native counters, layer blits and texture uploads',total,banks))
end
