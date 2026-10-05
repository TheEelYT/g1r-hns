-- Bitmap fonts and window tiles copied from the pinned HnS source.
return function(mod,spec)
  local U={spec=spec,images={}}
  function U.image(file,w,h)
    if not U.images[file] then
      local im=love.graphics.newImage(love.image.newImageData(w,h,'rgba8',assert(mod:read(file))))
      im:setFilter('nearest','nearest');U.images[file]=im
    end
    return U.images[file]
  end
  function U.art(name) local a=assert(spec.art[name]);return U.image(a.file,a.width,a.height),a end
  function U.chars(s) return s:gmatch('[%z\1-\127\194-\244][\128-\191]*') end
  function U.width(s,font)
    local f=spec.fonts[font or 'normal'];local n=0
    for c in U.chars(s)do n=n+(f.widths[(spec.glyphs[c] or spec.glyphs['?'])+1] or 6) end
    return n
  end
  function U.text(s,x,y,fg,shadow,font,pitch)
    x=math.floor(x);y=math.floor(y)
    font=font or 'normal';local f=spec.fonts[font];local start=x
    local im=U.image(f.fg,f.width,f.height);local sh=U.image(f.shadow,f.width,f.height)
    for c in U.chars(s)do
      if c=='\n' then x=start;y=y+(pitch or 16) else
        local id=spec.glyphs[c] or spec.glyphs['?'];local q=love.graphics.newQuad(id%16*16,math.floor(id/16)*16,16,16,f.width,f.height)
        love.graphics.setColor(unpack(shadow or spec.colors[4]));love.graphics.draw(sh,q,x,y)
        love.graphics.setColor(unpack(fg or spec.colors[3]));love.graphics.draw(im,q,x,y)
        x=x+(f.widths[id+1] or 6)
      end
    end
    love.graphics.setColor(1,1,1,1)
  end
  function U.wrap(s,max,font)
    local out={}
    for line in (s..'\n'):gmatch('(.-)\n')do
      local current=''
      for word in line:gmatch('%S+')do
        local next=current=='' and word or current..' '..word
        if U.width(next,font)>max and current~='' then out[#out+1]=current;current=word else current=next end
      end
      out[#out+1]=current
    end
    return table.concat(out,'\n')
  end
  function U.clip(x,y,w,h,draw)
    local ox,oy,ow,oh=love.graphics.getScissor()
    if ox then local right,bottom=math.min(x+w,ox+ow),math.min(y+h,oy+oh);x,y=math.max(x,ox),math.max(y,oy);w,h=math.max(0,right-x),math.max(0,bottom-y)end
    love.graphics.setScissor(x,y,w,h);draw()
    if ox then love.graphics.setScissor(ox,oy,ow,oh)else love.graphics.setScissor()end
  end
  function U.tokenWidth(s,font)
    font=font or 'small';local pos,width=1,0
    local function glyph(name)
      local a=spec.art[name];local id=spec.tokens[name]or(name=='MN'and spec.tokens.PK+1)
      return a and a.width or spec.fonts[font].widths[id+1]
    end
    while pos<=#s do
      local a,b,name=s:find('{([A-Z_0-9]+)}',pos)
      width=width+U.width(a and s:sub(pos,a-1)or s:sub(pos),font)
      if not a then break end
      width=width+(name=='PKMN'and glyph('PK')+glyph('MN')or glyph(name));pos=b+1
    end
    return width
  end
  function U.tokenText(s,x,y,font,fg,shadow)
    font=font or 'small';local pos=1
    local function glyph(name)
      U.glyph(name,x,y,font,fg,shadow)
      local a=spec.art[name];local id=spec.tokens[name]or(name=='MN'and spec.tokens.PK+1)
      x=x+(a and a.width or spec.fonts[font].widths[id+1])
    end
    while pos<=#s do
      local a,b,name=s:find('{([A-Z_0-9]+)}',pos)
      local plain=a and s:sub(pos,a-1)or s:sub(pos)
      U.text(plain,x,y,fg,shadow,font);x=x+U.width(plain,font)
      if not a then break end
      if name=='PKMN'then glyph('PK');glyph('MN')else glyph(name)end
      pos=b+1
    end
    return x
  end
  function U.glyph(name,x,y,font,fg,shadow)
    if spec.art[name]then local im,a=U.art(name);love.graphics.setColor(1,1,1,1);love.graphics.draw(im,love.graphics.newQuad(0,0,a.width,a.height,a.width,a.height),x,y);return end
    local id=assert(spec.tokens[name]or(name=='MN'and spec.tokens.PK+1),name);local f=spec.fonts[font or 'small']
    local q=love.graphics.newQuad(id%16*16,math.floor(id/16)*16,16,16,f.width,f.height)
    love.graphics.setColor(unpack(shadow or spec.colors[4]));love.graphics.draw(U.image(f.shadow,f.width,f.height),q,x,y)
    love.graphics.setColor(unpack(fg or spec.colors[3]));love.graphics.draw(U.image(f.fg,f.width,f.height),q,x,y)
    love.graphics.setColor(1,1,1,1)
  end
  function U.tile(name,index,x,y,w,h)
    local im,a=U.art(name);local q=love.graphics.newQuad(index%(a.width/8)*8,math.floor(index/(a.width/8))*8,8,8,a.width,a.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x,y,0,(w or 8)/8,(h or 8)/8)
  end
  function U.box(x,y,w,h,name,fill)
    name=name or 'frame';love.graphics.setColor(unpack(fill or {1,1,1,1}));love.graphics.rectangle('fill',x,y,w,h)
    local ids=name=='callFrame' and {0,1,2,3,4,5,6,7} or {0,1,2,3,5,6,7,8}
    U.tile(name,ids[1],x-8,y-8);U.tile(name,ids[2],x,y-8,w);U.tile(name,ids[3],x+w,y-8)
    U.tile(name,ids[4],x-8,y,8,h);U.tile(name,ids[5],x+w,y,8,h)
    U.tile(name,ids[6],x-8,y+h);U.tile(name,ids[7],x,y+h,w);U.tile(name,ids[8],x+w,y+h)
  end
  return U
end
