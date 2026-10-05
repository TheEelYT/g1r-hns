-- HnS Pokégear home: source tilemaps, palettes and four-part OBJ buttons.
return function(U)
  local M={tick=0}
  local function art(name,x,y,w,h,qx,qy)
    local im,a=U.art(name);w=w or a.width;h=h or a.height
    local q=love.graphics.newQuad(qx or 0,qy or 0,w,h,a.width,a.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x,y)
  end
  function M.update(rows,cursor)
    M.tick=M.tick+1;M.positions=M.positions or {}
    for i,name in ipairs(rows or {})do
      local target=i==cursor and 114 or 124;local x=M.positions[name]or target
      M.positions[name]=x<target and math.min(target,x+2)or math.max(target,x-2)
    end
  end
  function M.draw(rows,cursor,region,headerTick)
    love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',0,0,240,160)
    art('gearDots',0,0,240,160,math.floor(M.tick/2)%16)
    art('gearDevice',0,0,240,160);art('gearMessage',0,0,240,160)
    art('gearHeader',0,0,240,160);art('gearTitle',-128+math.floor(128*math.min(12,headerTick or 12)/12),32,128,32)
    art('gearIcon',204,-4,32,32,0,math.floor(M.tick/8)%8*32)
    local y=#rows==2 and 56 or #rows==6 and 40 or 42
    local delta=#rows==6 and 16 or 20
    M.positions=M.positions or {}
    for i,name in ipairs(rows)do
      local target=i==cursor and 114 or 124;local x=M.positions[name]or target
      local glow=i==cursor and math.floor(U.spec.presentation.sine[((M.tick*3)%128)+1]/32)or 0
      art('gearButton'..name:gsub(' ','')..(glow>0 and 'Glow'..glow or ''),x,y+(i-1)*delta-8)
    end
    local descriptions={MAP=region=='kanto' and 'Check the combined region map' or 'Check the map of the JOHTO region',PHONE='Call a registered TRAINER.',CONDITION='Check POKéMON in detail.',RADIO='Listen to the radio.',RIBBONS='Check obtained RIBBONS.',['SWITCH OFF']='Put away the POKéGEAR.'}
    local desc=descriptions[rows[cursor]]or ''
    U.text(desc,24+math.floor((192-U.width(desc))/2),137,{.32,.32,.29,1},{.67,.67,.67,1},'normal')
  end
  return M
end
