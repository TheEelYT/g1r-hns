-- Source terrain, textbox and selectable Gen 3 / Gen 4 healthbox artwork.
return function(mod,w,game)
  local old=game._hnsBattleVisuals or {};local V={};local H=game._hnsRules.rules
  local Rt=require('src.core.game3.runtime');local Bg=require('src.core.game3.battle.bg')
  local Chrome=require('src.ui.game3.battle_chrome');local HB=require('src.core.game3.battle.healthbox')
  local B=require('src.core.game3.battle');local Rtc=require('src.core.game3.rtc')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui);V.ui=U
  local Owned=assert(load(mod:read('hns_healthbox.lua')))()
  local function color(c)return {(c%32)/31,(math.floor(c/32)%32)/31,(math.floor(c/1024)%32)/31,1}end
  function V.style(s)return H.value('ITEM_BATTLE_NEW_BATTLEUI',s)==1 and 'gen4'or 'gen3'end
  function V.row(s)return w.battleVisuals.ui[V.style(s)]end
  local ids={'GRASS','LONG_GRASS','SAND','UNDERWATER','WATER','POND','MOUNTAIN','CAVE','BUILDING','PLAIN','FRONTIER','GROUDON','KYOGRE','RAYQUAZA','LEADER','CHAMPION','GYM','MAGMA','AQUA','SIDNEY','PHOEBE','GLACIA','DRAKE'}
  function V.terrain(id,s)
    s=s or Rt.getSession();local env=ids[(tonumber(id)or Bg.terrainId())+1]or 'BUILDING'
    local m=s and w.maps[s.map]
    if m and env~='LEADER'and env~='CHAMPION'and env~='FRONTIER'then env=w.battleVisuals.scenes[m.hnsBattleScene]or env end
    local trainer=B._st and B._st.trainerId;local record=trainer and w.trainers.records[tostring(trainer)]
    if record and (record.source=='TRAINER_CLAIR_1_HNS'or record.source=='TRAINER_BLAINE_HNS')then env='VOLCANO_CAVE'end
    local t=Rtc.calcLocalTime(s);local h=t.hours
    local period=(h<6 or h>=20)and 'Night'or (h<10 or h>=18)and 'Twilight'or 'Day'
    local style=H.value('ITEM_BATTLE_NEW_BACKGROUNDS',s)==1 and 'modern'or 'old'
    local key=env..'_'..style..'_'..period
    return w.battleVisuals.terrains[key]or w.battleVisuals.terrains['BUILDING_'..style..'_'..period],key
  end
  local function image(a)return U.image(a.file,a.width,a.height)end
  local draw=old.draw or Bg.draw
  Bg.draw=function(id,eo,po,bo)
    if not H.battle(B._st)then return draw(id,eo,po,bo)end
    local row,key=V.terrain(id);local own='hns_'..key
    if not Chrome._terrains[own]then Chrome._terrains[own]={image=image(row.full),w=256,h=160,bgImage=image(row.wallpaper),enemyPlat=image(row.enemy),playerPlat=image(row.player)}end
    return Chrome.drawTerrain(own,eo,po,bo)
  end
  local panel=old.panel or Chrome.drawPanel
  Chrome.drawPanel=function(mode)
    if not H.battle(B._st)then return panel(mode)end
    local a=w.battleVisuals.textbox;local scroll=mode=='menu'and 160 or mode=='moves'and 320 or 0
    love.graphics.setColor(1,1,1,1);love.graphics.draw(image(a),love.graphics.newQuad(0,112+scroll,240,48,a.width,a.height),0,112)
  end
  local function palettes()local p=V.row().palette;return p,color(p[2]),color(p[4])end
  local Font={CHAR_LV_2=0x105,CHAR_MALE=0xB5,CHAR_FEMALE=0xB6}
  function Font.draw(text,x,y,opts)return U.text(text,x,y,opts and opts.colors and opts.colors.fg,opts and opts.colors and opts.colors.shadow,'small')end
  function Font.measure(text)return U.width(text,'small')end
  function Font.advance(id)return U.spec.fonts.small.widths[id+1]end
  function Font.drawGlyph(id,x,y,opts)
    local f=U.spec.fonts.small;local q=love.graphics.newQuad(id%16*16,math.floor(id/16)*16,f.widths[id+1],16,f.width,f.height)
    local colors=opts and opts.colors or {};love.graphics.setColor(unpack(colors.shadow or U.spec.colors[4]));love.graphics.draw(U.image(f.shadow,f.width,f.height),q,x,y)
    love.graphics.setColor(unpack(colors.fg or U.spec.colors[3]));love.graphics.draw(U.image(f.fg,f.width,f.height),q,x,y);love.graphics.setColor(1,1,1,1)
  end
  local source={font=Font}
  function source.textColors()
    local p=V.row().palette;return color(p[V.style()=='gen4'and 4 or 3]),{fg=color(p[2]),shadow=color(p[4])},{fg=color(p[12]),shadow=color(p[4])},{fg=color(p[11]),shadow=color(p[4])}
  end
  function source.name(name,gender,x,y)
    local p,fg,sh=palettes();local font=U.width(name,'small')>55 and 'small_narrower'or 'small';U.text(name,x,y,fg,sh,font)
    local pos=x+U.width(name,font);if gender=='male'or gender=='M'then Font.drawGlyph(0xB5,pos,y,{colors={fg=color(p[12]),shadow=sh}})
    elseif gender=='female'or gender=='F'then Font.drawGlyph(0xB6,pos,y,{colors={fg=color(p[11]),shadow=sh}})end
  end
  function source.hp(cur,max,x,y)
    local _,fg=palettes();local p=V.row().palette;local text=string.format('%4d/%-4d',cur or 0,max or 0):gsub('%s+$','')
    U.text(text,x+96-U.width(text,'small'),y+21,fg,color(p[5]),'small')
  end
  function source.statusIcon(x,y,ailment)
    local n=({PSN=0,TOX=0,PAR=1,SLP=2,FRZ=3,BRN=4})[ailment];if not n then return end
    local row=V.row();local im=image(row.elementsExp)
    for i=0,2 do local tid=21+n*3+i;local q=love.graphics.newQuad(tid%40*8,math.floor(tid/40)*8,8,8,320,24)
      love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x+6+i*8,y)end
  end
  Owned.configure(source)
  local hb=old.hb or HB.draw
  HB.draw=function(...)
    if not H.battle(B._st)then return hb(...)end
    local row=V.row();local keys={_playerBox='healthbox_singles_player',_enemyBox='healthbox_singles_opponent',_doublesPlayerBox='healthbox_doubles_player',_doublesOpponentBox='healthbox_doubles_opponent',_elements='elements',_elementsExp='elementsExp'}
    local original={};for key,name in pairs(keys)do original[key]=Chrome[key];Chrome[key]=image(row[name])end
    local tried=Chrome._doublesTried;Chrome._doublesTried=true
    local ok,result=pcall(Owned.draw,...)
    for key in pairs(keys)do Chrome[key]=original[key]end;Chrome._doublesTried=tried
    if not ok then error(result)end;return result
  end
  game._hnsBattleVisuals={draw=draw,panel=panel,hb=hb,visuals=V}
end
