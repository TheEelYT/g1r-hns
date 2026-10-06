-- Source terrain, textbox and selectable Gen 3 / Gen 4 healthbox artwork.
return function(mod,w,game)
  local old=game._hnsBattleVisuals or {};local V={};local H=game._hnsRules.rules
  local Rt=require('src.core.game3.runtime');local Bg=require('src.core.game3.battle.bg')
  local Chrome=require('src.ui.game3.battle_chrome');local HB=require('src.core.game3.battle.healthbox')
  local B=require('src.core.game3.battle');local Rtc=require('src.core.game3.rtc')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui);V.ui=U
  local Owned=assert(load(mod:read('hns_healthbox.lua')))()
  local Entry=assert(load(mod:read('terrain_entry.lua')))()(w.bootPresentation.credits.sineDegrees)
  V.entryState=Entry
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
    if row.entry then
      local Intro=require('src.core.game3.battle.intro_seq');local step=Intro._steps and Intro._steps[Intro._i]
      if Intro._st==B._st and step and step.kind=='bgslide'and H.value('ITEM_BATTLE_FAST_INTRO',B._st.session)~=0 then
        local stage=require('src.core.game3.battle.anim').stage()
        local state=Entry(math.floor((stage.slide or 0)*154+.5),row.entryKind,row.environment)
        local function strip(a,sx,sy,y,h)
          if h<=0 then return end
          local im=image(a);sx=sx%a.width
          local n=math.min(240,a.width-sx)
          love.graphics.draw(im,love.graphics.newQuad(sx,sy,n,h,a.width,a.height),0,y)
          if n<240 then love.graphics.draw(im,love.graphics.newQuad(0,sy,240-n,h,a.width,a.height),n,y)end
        end
        love.graphics.setColor(0,0,0,1);love.graphics.rectangle('fill',0,0,240,112)
        love.graphics.setColor(1,1,1,1)
        local top,bottom=math.max(0,state.top),math.min(112,state.bottom)
        -- The source HBlank DMA targets BG3, not the BG1 entry layer.
        strip(row.introBackground,state.scan,top,top,math.max(0,math.min(80,bottom)-top))
        local lower=math.max(80,top)
        strip(row.introBackground,-state.scan,lower,lower,bottom-lower)
        if state.visible then
          -- BG1 has an independent scroll and a 256px blank second screen
          -- block. Quads preserve the caller's GPU scissor and zoom.
          love.graphics.setColor(1,1,1,state.alpha/16)
          local y=math.max(top,-state.y);local h=math.min(bottom,256-state.y)-y
          strip(row.entry,state.x,y+state.y,y,h)
        end
      else
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(image(row.full),love.graphics.newQuad(0,0,240,160,row.full.width,row.full.height),0,0)
      end
      love.graphics.setColor(1,1,1,1)
      return true
    end
    if not Chrome._terrains[own]then Chrome._terrains[own]={image=image(row.full),w=256,h=160,bgImage=image(row.wallpaper),enemyPlat=image(row.enemy),playerPlat=image(row.player)}end
    return Chrome.drawTerrain(own,eo,po,bo)
  end
  local panel=old.panel or Chrome.drawPanel
  Chrome.drawPanel=function(mode)
    if not H.battle(B._st)then return panel(mode)end
    local a=w.battleVisuals.textbox;local scroll=mode=='menu'and 160 or mode=='moves'and 320 or 0
    love.graphics.setColor(1,1,1,1);love.graphics.draw(image(a),love.graphics.newQuad(0,112+scroll,240,48,a.width,a.height),0,112)
  end
  local frames=old.frames or Chrome.drawMenuFrames
  Chrome.drawMenuFrames=function(mode)
    if not H.battle(B._st)then return frames(mode)end
    local n=(require('src.ui.game3.chrome')._frameType or 0)+1
    local art=n==1 and 'frame'or 'frame'..n
    for _,r in ipairs(Chrome.RSE_MENU_FRAMES[mode]or {})do U.box(r[1]*8,r[2]*8,r[3]*8,r[4]*8,art)end
  end
  local window=old.window or Chrome.window
  Chrome.window=function(id)
    if not H.battle(B._st)then return window(id)end
    local r=assert(w.battleVisuals.windows[(tonumber(id)or 0)+1])
    return {left=r.left,top=r.top%20,w=r.w,h=r.h,x=r.left*8,y=r.top%20*8}
  end
  local origin=old.origin or Chrome.messageOrigin
  Chrome.messageOrigin=function()
    if not H.battle(B._st)then return origin()end
    return Chrome.textOrigin(Chrome.WIN.MSG)
  end
  local colors=old.colors or Chrome.textboxColors
  Chrome.textboxColors=function(fg,shadow)
    if not H.battle(B._st)then return colors(fg,shadow)end
    local p=w.battleVisuals.textboxPalette
    return {fg=color(p[fg+1]),shadow=color(p[shadow+1]),bg={0,0,0,0}}
  end
  -- Native battle messages use a fixed FRLG origin. Shift the printer to the
  -- source B_WIN_MSG while retaining its control-code/reveal/input machinery.
  local Msg=require('src.ui.game3.message');local msg=old.msg or Msg.drawText
  local show=old.show or Msg.show
  Msg.show=function(text,opts)
    if not H.battle(B._st)or not(opts and(opts.battle or opts.frame=='battle'))then return show(text,opts)end
    local o={};for k,v in pairs(opts)do o[k]=v end
    local ctx={};for k,v in pairs(opts.ctx or {})do ctx[k]=v end
    local _,_,width=Chrome.messageOrigin();ctx.maxWidth=ctx.maxWidth or width;o.ctx=ctx
    return show(text,o)
  end
  Msg.drawText=function(...)
    if not H.battle(B._st)or Msg._frame~='battle'then return msg(...)end
    local F=require('src.ui.game3.frlg_font');local fd=F.draw
    F.draw=function(text,x,y,opts)
      local o={};for k,v in pairs(opts or {})do o[k]=v end
      local bx,by,bw=Chrome.messageOrigin();o.maxWidth=bw;o.colors=Chrome.textboxColors(1,6)
      return fd(text,x+bx-10,y+by-122,o)
    end
    local ok,a,b,c=pcall(msg,...);F.draw=fd;if not ok then error(a)end;return a,b,c
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
    local p=V.row().palette;return color(p[3]),{fg=color(p[2]),shadow=color(p[4])},{fg=color(p[12]),shadow=color(p[4])},{fg=color(p[11]),shadow=color(p[4])}
  end
  function source.name(name,gender,x,y)
    local p,fg,sh=palettes();local font=U.width(name,'small')+(gender and Font.advance(0xB5)or 0)>55 and 'small_narrower'or 'small';U.text(name,x,y,fg,sh,font)
    local pos=x+U.width(name,font);if gender=='male'or gender=='M'then Font.drawGlyph(0xB5,pos,y,{colors={fg=color(p[12]),shadow=sh}})
    elseif gender=='female'or gender=='F'then Font.drawGlyph(0xB6,pos,y,{colors={fg=color(p[11]),shadow=sh}})end
  end
  function source.hp(cur,max,x,y)
    local _,fg=palettes();local p=V.row().palette;local text=string.format('%4d/%-4d',cur or 0,max or 0):gsub('%s+$','')
    U.text(text,x+96-U.width(text,'small'),y+21,fg,color(p[5]),'small')
  end
  function source.statusIcon(x,y,ailment)
    local n=tonumber(ailment)or({PSN=1,TOX=1,PAR=2,SLP=3,FRZ=4,BRN=5})[ailment]
    if not n or n<1 or n>5 then return end
    local a=V.row().statusIcons[(V.battler or 0)+1][n]
    love.graphics.setColor(1,1,1,1);love.graphics.draw(image(a),x+6,y)
  end
  Owned.configure(source)
  local hb=old.hb or HB.draw
  HB.draw=function(...)
    if not H.battle(B._st)then return hb(...)end
    local side=select(1,...);V.battler=tonumber(side)or(side=='player'and 0 or 1)
    local row=V.row();local keys={_playerBox='healthbox_singles_player',_enemyBox='healthbox_singles_opponent',_doublesPlayerBox='healthbox_doubles_player',_doublesOpponentBox='healthbox_doubles_opponent',_elements='elements',_elementsExp='elementsExp'}
    local original={};for key,name in pairs(keys)do original[key]=Chrome[key];Chrome[key]=image(row[name])end
    local tried=Chrome._doublesTried;Chrome._doublesTried=true
    local ok,result=pcall(Owned.draw,...)
    for key in pairs(keys)do Chrome[key]=original[key]end;Chrome._doublesTried=tried
    if not ok then error(result)end;return result
  end
  game._hnsBattleVisuals={draw=draw,panel=panel,frames=frames,window=window,origin=origin,colors=colors,msg=msg,show=show,hb=hb,visuals=V}
end
