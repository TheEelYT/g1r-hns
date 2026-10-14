-- Five live OBJ palette colors preserve the source banner's shading and fades.
return function(U,font)
  local F={font=font}
  function F.width(text)local n=0;for c in U.chars(text)do n=n+assert(font.glyphs[c],'missing title glyph '..c).advance end;return n end
  function F.draw(text,x,y,color)
    x=math.floor(x);y=math.floor(y)
    for c in U.chars(text)do
      local g=assert(font.glyphs[c]);local q=love.graphics.newQuad(g.x,0,g.w,font.height,tonumber(font.layers['1'].width),font.height)
      for i=1,5 do
        local a=font.layers[tostring(i)];love.graphics.setColor(unpack(color(i)))
        love.graphics.draw(U.image(a.file,a.width,a.height),q,x,y)
      end
      x=x+g.advance
    end
    love.graphics.setColor(1,1,1,1)
  end
  return F
end
