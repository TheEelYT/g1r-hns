-- Source Pokégear service artwork, coordinates, fonts and condition geometry.
return function(mod,world,U,G)
  local meta=U.spec.presentation
  local Pokemon=require('src.core.game3.pokemon')
  local Ribbons=require('src.core.game3.rse.ribbons')
  local M={tick=0}
  local fg,sh={.25,.25,.25,1},{.8,.8,.8,1}
  local function color(p,n)local c=meta.colors[p][n+1];return {c[1]/255,c[2]/255,c[3]/255,1}end
  local function art(name,x,y,w,h,qx,qy)
    local im,a=U.art(name);local q=love.graphics.newQuad(qx or 0,qy or 0,w or a.width,h or a.height,a.width,a.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x,y)
  end
  local function text(s,x,y,font)U.text(s,x,y,fg,sh,font or 'normal')end
  local function header(title)
    if title then art('gearTitle'..title,-128+math.floor(128*math.min(12,G.headerTick or 12)/12),0,128,32)end
  end
  local function help(t)
    -- The common BG0 footer is stored at tilemap row 22. Subpages scroll
    -- that header upward by 32 pixels; row 18 is transparent.
    art('gearHeader',0,144,240,16,0,176)
    local x=7
    for part in t:gmatch('%S+')do
      local button=part:match('^([ABLR])$')
      if button then U.glyph(button..'_BUTTON',x,145,'normal',{0,0,0,1},{1,1,1,1});x=x+10
      else U.text(part,x,145,{0,0,0,1},{1,1,1,1},'normal');x=x+U.width(part)+3 end
    end
  end
  local function monPic(mon,x,y)
    local sp=Pokemon.speciesOf(mon);local im=sp and Pokemon.frontPic(sp,nil,Pokemon.isShiny(mon),mon.personality)
    im=im and (im.image or im)
    if im then local w,h=im:getDimensions();local q=love.graphics.newQuad(0,0,64,64,w,h);love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x,y)end
  end
  function M.graph(mon)
    local points={};local index=0;local angle=64
    for i,key in ipairs({'cool','tough','smart','cute','beauty'})do
      local v=math.max(0,math.min(255,tonumber(mon[key] or mon.contest and mon.contest[key]) or 0))
      local n=meta.lineLengths[v+1];local x,y=155,91-n
      if i>1 then
        angle=(angle+51)%256;index=(index-1)%5;if index==2 then angle=(angle+1)%256 end
        x=155+math.floor(n*meta.sine[64+angle+1]/256);y=91-math.floor(n*meta.sine[angle+1]/256)
        if index<=2 and (n~=32 or index~=2)then x=x+1 end
      end
      points[index+1]={x,y}
    end
    local flat={};for _,p in ipairs(points)do flat[#flat+1]=p[1];flat[#flat+1]=p[2]end;return flat
  end
  function M.ribbonRows()
    local rows={};Ribbons.forEachMon(G.session,function(mon,box,slot)
      if Ribbons.count(mon)>0 then rows[#rows+1]={mon=mon,box=box,slot=slot}end
    end);return rows
  end
  function M.ribbonIds(mon)
    local ids={}
    for _,name in ipairs(Ribbons.COUNTED)do
      local base=Ribbons.ID[name:upper()] or Ribbons.ID[name:upper()..'_NORMAL']
      for i=0,Ribbons.get(mon,name)-1 do ids[#ids+1]=base+i end
    end
    table.sort(ids);return ids
  end
  function M.draw()
    love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',0,0,240,160)
    if G.page=='map'then
      local info=world.startup.gearMaps[G.region];local im=U.image(info.file,info.width,info.height)
      local q=love.graphics.newQuad(0,0,240,160,info.width,info.height);love.graphics.draw(im,q,0,0)
      local def=world.maps[G.session.map]
      for _,s in ipairs(world.startup.sections)do if s.id==def.hnsSection and world.startup.sectionRegions[s.id]==G.region then
        if math.floor(M.tick/17)%2==0 then local px,py=G.playerMap and G.playerMap(s)or s.x,s.y;if G.playerMap then px,py=G.playerMap(s)end;art(G.session.gender==1 and 'gearMapKris' or 'gearMapGold',(px+1)*8-4,(py+2)*8-4,16,16)end
      end end
      art('gearMapCursor',(G.mapX+1)*8-4,(G.mapY+2)*8-4,16,16,0,math.floor(M.tick/20)%2*16)
      header('Map')
      U.box(G.region=='kanto' and 8 or 136,128,96,104)
      text(U.wrap(G.locationName(),92,'narrow'),G.region=='kanto' and 8 or 136,129,'narrow')
      help('B CANCEL')
    elseif G.page=='phone'then
      local rows=G.contacts()
      love.graphics.setColor(unpack(color('phone',1)));love.graphics.rectangle('fill',0,0,240,160)
      U.clip(104,8,128,128,function()
      local first=math.max(1,G.cursor-7)
      for i,r in ipairs(rows)do
        if i>=first and i<first+8 then
        local y=9+(i-first)*16
        U.clip(112,y,69,16,function()U.tokenText(r.description or r.name,112,y,'narrow',color('phone',2),color('phone',3))end)
        U.clip(181,y,51,16,function()U.text(r.trainerName or '',181,y,color('phone',2),color('phone',3),'narrow')end)
        end
      end
      end)
      -- Source BG2 has priority over the scrolling BG3 list; draw its
      -- opaque border after the rows, then the OBJ cursor above both.
      art('gearPhone',0,0)
      local cy=8+(math.min(G.cursor,8)-1)*16
      art('gearListCursor',103,cy,8,8,0,0);art('gearListCursor',103,cy+8,8,8,8,0)
      local place='NEW BARK TOWN';U.text(place,math.floor((88-U.width(place,'narrow'))/2),41,color('phoneInfo',2),color('phoneInfo',3),'narrow')
      U.text('No. registered',2,73,color('phoneInfo',2),color('phoneInfo',3),'narrow')
      local n=tostring(#rows);U.text(n,86-U.width(n,'narrow'),89,color('phoneInfo',2),color('phoneInfo',3),'narrow')
      U.text('No. of battles',2,105,color('phoneInfo',2),color('phoneInfo',3),'narrow')
      local stats=require('src.core.game3.rse.rematch');local b=tostring(stats.gameStat(G.session,stats.GAME_STAT_TRAINER_BATTLES)or 0)
      U.text(b,86-U.width(b,'narrow'),121,color('phoneInfo',2),color('phoneInfo',3),'narrow')
      header('Phone')
      help('A MENU B CANCEL')
    elseif G.page=='radio'then
      art('gearRadio',0,0);art('gearRadioDial',136+(G.tuning or 0),20,16,16)
      local name=G.station and G.station.name or '- - - -'
      U.text(name,48+math.floor((152-U.width(name))/2),65,color('radio',7),color('radio',5))
      U.box(8,104,224,32)
      if G.station then
        local lines={};for line in (U.wrap(G.station.text or '',220)..'\n'):gmatch('(.-)\n')do lines[#lines+1]=line end
        local index=math.floor((G.radioTick or 0)/90)%math.max(1,#lines)+1
        text(lines[index] or '',10,121)
      end
      header()
    elseif G.page=='condition'then
      art('gearCondition',0,0);local party=G.session.party or {};local mon=party[G.cursor]
      if mon then
        monPic(mon,6,72);text(Pokemon.displayMonName(mon)..' /Lv'..tostring(mon.level or 1),104,9)
        -- GBA BG2 uses BLDALPHA(11,4) over the pale blue graph backdrop.
        local base=meta.colors.conditionBackdrop
        local green=meta.colors.graph[2]
        love.graphics.setColor((green[1]*11+base[1]*4)/4080,(green[2]*11+base[2]*4)/4080,(green[3]*11+base[3]*4)/4080,1)
        love.graphics.polygon('fill',unpack(M.graph(mon)))
      end
      for i=1,6 do
        if i<=#party then art('gearConditionBall',218,(i-1)*20,16,16,0,i==G.cursor and 0 or 16)
        else art('gearConditionEmpty',226,4+(i-1)*20,8,8)end
      end
      art('gearConditionCancel'..(G.cursor==#party+1 and '0' or '1'),206,120,32,16)
      -- The graph screen owns the whole top row; source does not show a title.
    elseif G.page=='ribbons'then
      art('gearRibbons',0,0);local rows=M.ribbonRows()
      love.graphics.setColor(unpack(color('ribbons',2)));love.graphics.rectangle('fill',104,32,136,128)
      local first=math.max(1,G.cursor-7)
      for i=first,math.min(first+7,#rows)do
        local mon=rows[i].mon;local y=33+(i-first)*16
        text(Pokemon.displayMonName(mon)..' /Lv'..tostring(mon.level or 1),112,y)
        if i==G.cursor then text('▶',104,y)end
      end
      if #rows==0 then text('No RIBBONS.',112,41)end
      text(string.format('%d/%d',math.min(G.cursor,#rows),#rows),12,49);header('Ribbons')
    elseif G.page=='ribbonSummary'then
      art('gearRibbonSummary',0,0);local row=M.ribbonRows()[G.cursor];if not row then return end
      local mon=row.mon;monPic(mon,8,72);text(Pokemon.displayMonName(mon)..' /Lv'..tostring(mon.level or 1),112,9)
      local ids=M.ribbonIds(mon);text('RIBBONS '..#ids,96,105)
      for i,id in ipairs(ids)do
        local gfx=meta.ribbonGraphics[id+1];if gfx then
          art('gearRibbonIcons'..gfx.palette,104+(i-1)%9*12,40+math.floor((i-1)/9)*20,8,16,0,gfx.tile*16)
        end
      end
      local selected=math.min(G.ribbonCursor or 1,#ids);local id=ids[selected]
      if id then
        love.graphics.setColor(1,.3,.3,1);love.graphics.rectangle('line',102+(selected-1)%9*12,38+math.floor((selected-1)/9)*20,12,20)
        local desc=meta.ribbonDescriptions[id+1]
        if desc then text(table.concat(desc,'\n'),96,120,'small')end
      end
    end
    love.graphics.setColor(1,1,1,1)
  end
  function M.update()M.tick=M.tick+1;if G.page=='radio'then G.radioTick=(G.radioTick or 0)+1 end end
  return M
end
