-- HGSS Plus source list, information and statistics on native saved dex flags.
return function(mod,world,game)
  local Screens=require('src.ui.game3.screens');local Stack=require('src.ui.game3.stack')
  local Dex=require('src.core.game3.dex');local Pokemon=require('src.core.game3.pokemon')
  local Rt=require('src.core.game3.runtime');local Audio=require('src.core.game3.audio')
  local D=game._hnsDexState;local spec=world.pokedex
  local U=assert(load(mod:read('source_ui.lua'),'@hns/source_ui.lua'))()(mod,world.startup.ui)
  local P={ID='hns_pokedex',ui=U}
  local fg,sh={.25,.25,.25,1},{.8,.8,.8,1}
  local function text(t,x,y,font,white)U.text(tostring(t),x,y,white and {1,1,1,1}or fg,white and fg or sh,font or 'small',13)end
  local function image(file,w,h,x,y,qx,qy,qw,qh)
    local im=U.image(file,w,h);local q=love.graphics.newQuad(qx or 0,qy or 0,qw or w,qh or h,w,h)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x,y)
  end
  local function bg(page)image(spec.backgrounds[page],240,160,0,0)end
  local function art(name,x,y,w,h,tile)
    local a=spec.art[name];local tid=tile or 0
    image(a.file,a.width,a.height,x,y,(tid%(a.width/8))*8,math.floor(tid/(a.width/8))*8,w or a.width,h or a.height)
  end
  function P.seen(row)return row and row.species and D.seen(P.dex,row.species)or false end
  function P.caught(row)return row and row.species and D.caught(P.dex,row.species)or false end
  function P.rowsFor(s)
    local out={};local rows=Dex.nationalEnabled(s)and D.national or D.regional
    for _,r in ipairs(rows)do if not P.ownedOnly or D.caught(s.dex,r.species)then out[#out+1]=r end end
    return out
  end
  function P.show(dex,opts)
    P.session=opts and opts.session or Rt.getSession();P.dex=dex or Dex.new()
    P.rows=P.rowsFor({version='emerald',map=P.session and P.session.map,dex=P.dex,flags=P.session and P.session.flags,vars=P.session and P.session.vars})
    P.cursor=math.max(1,math.min(P.cursor or 1,#P.rows));P.page='list';P.moveCursor=1;P.toggle=false;P.animation={kind='in',tick=0,page='list'};P.scroll=nil;P.ballAngle=0;P.tick=0
    Stack.push(P.ID,P,{hideBelow=true,fullscreen=true})
  end
  function P.close()Stack.pop(P.ID)end
  function P.isOpen()return Stack.has(P.ID)end
  function P.number(row)return Dex.nationalEnabled(P.session)and row.obtainableNumber or row.number end
  function P.row()return P.rows[P.cursor]end
  function P.detail(row)return game._hnsCollection.registration.rows[row.species]end
  function P.picture(row,x,y,scaleY)
    if not P.seen(row)then
      local a=spec.art.unknown;local im=U.image(a.file,64,64)
      love.graphics.setColor(1,1,1,1);love.graphics.draw(im,x,y,0,1,scaleY or 1);return
    end
    local r=P.detail(row);local f=r.front
    if r.speciesName=='SPINDA'or r.speciesName=='UNOWN'then f=nil end
    if f then local im=U.image(f.file,64,64);love.graphics.setColor(1,1,1,1);love.graphics.draw(im,x,y,0,1,scaleY or 1)else
      local im=Pokemon.frontPic(row.species,nil,false,Dex.defaultPersonality(P.dex,row.species));im=im and (im.image or im)
      if im then local w,h=im:getDimensions();local q=love.graphics.newQuad(0,0,64,64,w,h);love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x,y,0,1,scaleY or 1)end
    end
  end
  function P.moves(row)
    local r=P.detail(row);local gen='3'
    local H=game._hnsRules and game._hnsRules.rules
    local modern=tostring(spec.modernGeneration)
    if H and H.value('ITEM_MODE_MODERN_MOVES',P.session)==1 then gen=modern end
    local rows={}
    local egg=gen=='3'and r.legacyEggRef or r.eggRef
    local eggset=spec.eggsets[gen][egg]or spec.eggsets[modern][r.eggRef]or {}
    for _,move in ipairs(eggset)do rows[#rows+1]={move=move,kind='egg'}end
    local ref=gen=='3'and r.legacyLearnsetRef or r.learnsetRef
    for _,m in ipairs(spec.learnsets[gen][ref]or spec.learnsets[modern][r.learnsetRef]or {})do
      rows[#rows+1]={move=({VISE_GRIP='VICE_GRIP',HIGH_JUMP_KICK='HI_JUMP_KICK',FEINT_ATTACK='FAINT_ATTACK',SMELLING_SALTS='SMELLING_SALT'})[m.move]or m.move,level=m.level,kind='level'}
    end
    for _,move in ipairs(spec.teachables[r.teachableRef]or {})do
      local label=spec.machineLabels[move];rows[#rows+1]={move=move,label=label,kind=label and label:sub(1,2)or 'tutor'}
    end
    return rows
  end
  function P.go(page)
    P.animation={kind='fade',tick=0,page=page}
  end
  function P.handleInput(input)
    P.tick=(P.tick or 0)+1
    if P.animation then
      local a=P.animation;a.tick=a.tick+1
      local length=a.kind=='portrait'and 25 or a.kind=='in'and 16 or 32
      if a.tick>=length then
        P.page=a.page;P.animation=a.kind=='portrait'and {kind='in',tick=0,page=a.page}or nil
        if a.page=='info'and a.kind~='in'then Audio.playCry(P.row().species)end
      elseif a.kind=='fade'and a.tick==16 then P.page=a.page end
      return
    end
    if P.scroll then
      P.scroll.tick=P.scroll.tick+1;P.ballAngle=(P.ballAngle+2*P.scroll.delta)%256
      if P.scroll.tick>=8 then P.scroll=nil end
      return
    end
    local function k(v)return input:wasPressed(v)end
    if k('b')then if P.page=='list'then P.close()else P.go('list')end;return end
    if k('start')then P.close();return end
    local row=P.row()
    if P.page=='stats'then
      if k('left')or k('l')then P.go('info')
      elseif k('a')then P.toggle=not P.toggle
      elseif k('up')or k('down')then
        local n=#P.moves(row);P.moveCursor=math.max(1,math.min(n,P.moveCursor+(k('up')and -1 or 1)))
      end;return
    end
    if k('select')and P.page=='list'then P.ownedOnly=not P.ownedOnly;P.cursor=1;P.show(P.dex,{session=P.session});return end
    if k('a')and row and P.seen(row)then
      if P.page=='list'then P.animation={kind='portrait',tick=0,page='info'}
      else P.go('stats');P.moveCursor=1 end;return
    end
    if P.page=='info'and(k('right')or k('r'))then P.go('stats');P.moveCursor=1;return end
    local delta=(k('up')and -1 or k('down')and 1 or 0)
    if P.page=='list'and(k('left')or k('right'))then delta=k('left')and -7 or 7 end
    if delta~=0 then
      local next=math.max(1,math.min(#P.rows,P.cursor+delta));if next==P.cursor then return end
      if P.page=='info'then
        while next>0 and next<=#P.rows and not P.seen(P.rows[next])do next=next+delta end
        if next<=0 or next>#P.rows then return end
      end
      local previous=P.cursor;P.cursor=next;P.moveCursor=1
      if P.page=='info'then P.go('info')
      else P.scroll={tick=0,delta=next-previous}end
    end
  end
  function P.drawList()
    bg('listUnderlay')
    -- BG1 masks the full scrolling BG2 text at the actual black frame.
    -- An extra inset scissor leaves a visible gap beside those source lines.
    U.clip(8,8,104,144,function()
    for offset=-5,5 do
      local r=P.rows[P.cursor+offset]
      if r then
        local y=73+offset*16+(P.scroll and P.scroll.delta*(8-P.scroll.tick)*2 or 0)
        text(string.format('%03d',P.number(r)),20,y,'narrow')
        text(P.seen(r)and r.name or '----------',43,y,'narrow')
        if P.caught(r)then art('caught',12,y-1,8,16)end
      end
    end
    end)
    local row=P.row()
    U.clip(114,16,64,128,function()
      for offset=-1,1 do
        local r=P.rows[P.cursor+offset];local angle=(offset*32+(P.scroll and P.scroll.delta*(8-P.scroll.tick)*4 or 0))*math.pi/128
        if r and math.abs(angle)<math.pi/2 and not(offset==0 and P.animation and P.animation.kind=='portrait')then
          local sy=math.cos(angle);P.picture(r,114,80+math.sin(angle)*76-32*sy,sy)
        end
      end
    end)
    bg('listOverlay')
    -- The unused source rotating ball template is an OBJ window, not a
    -- visible sprite. Rendering its mask creates the stray grey rectangle.
    local wave=U.spec.presentation.sine[((P.tick or 0)*8%256)+1]
    if P.cursor>1 then art('scrollArrow',2,-math.floor(wave/64),16,8)end
    if P.cursor<#P.rows then
      local a=spec.art.scrollArrow;local im=U.image(a.file,a.width,a.height)
      love.graphics.setColor(1,1,1,1);love.graphics.draw(im,2,160+math.floor(wave/64),0,1,-1)
    end
    art('scrollBar',2,16+math.floor((P.cursor-1)*120/math.max(1,#P.rows-1)),8,8)
    art(Dex.nationalEnabled(P.session)and 'national'or 'johto',188,13)
    art('seen',172,22);art('owned',172,33)
    local seen,caught=D.counts(P.session)
    for i,n in ipairs({seen,caught})do
      local digits=tostring(n)
      for j=1,#digits do art('digit'..digits:sub(j,j),229-(#digits-j)*7,i==1 and 24 or 34)end
    end
    if row and P.seen(row)then
      local s=P.detail(row).stats
      art('bars',188,91)
      for i,key in ipairs({'hp','atk','def','spa','spd','spe'})do
        local y=94+(i-1)*10
        if P.caught(row)then
          local v=s[key]or 0;local width=v<=100 and math.floor(v/3)or 33+math.floor((v-100)/14)
          if v<=100 and width>=33 then width=width-1 end;width=math.max(3,math.min(39,width))
          local colors=width<=5 and {25,4,2,27,15,13}or width<=15 and {25,17,2,27,22,13}or width<=25 and {25,22,2,27,26,13}or width<=31 and {22,25,2,26,27,13}or width<=37 and {11,25,2,19,27,13}or {2,25,25,13,27,27}
          love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',198,y,width,5)
          love.graphics.setColor(colors[4]/31,colors[5]/31,colors[6]/31,1);love.graphics.rectangle('fill',199,y+1,width-2,1)
          love.graphics.setColor(colors[1]/31,colors[2]/31,colors[3]/31,1);love.graphics.rectangle('fill',199,y+2,width-2,2)
        end
      end
    end
  end
  function P.drawStats(row)
    bg('stats');local r=P.detail(row);local s=r.stats;local owned=P.caught(row)
    U.clip(0,16,96,32,function()
      text(r.name,38,16,U.width(r.name,'small')<=55 and 'small'or 'small_narrower')
      text(string.format('№%04d',P.number(row)),38,26)
      text(({[0]='♂',[12.5]='♀ 1/7 ♂',[25]='♀ 1/3 ♂',[50]='♀ 1/1 ♂',[75]='♀ 3/1 ♂',[87.5]='♀ 7/1 ♂',[100]='♀'})[r.femalePercent]or '---',38,36)
    end)
    if r.icon then
      local a=r.icon;local frame=math.floor((P.tick or 0)/6)%math.max(1,math.floor(a.height/32))
      image(a.file,a.width,a.height,2,15,0,frame*32,32,32)
    else
      local icon=Pokemon.icon(row.species)
      if icon then love.graphics.setColor(1,1,1,1);love.graphics.draw(icon.image,icon.quads[math.floor((P.tick or 0)/6)%icon.frames],2,15)end
    end
    if not owned then return end
    U.clip(0,48,96,96,function()
      local labels={'HP','SPE','ATK','SP.A','DEF','SP.D'};local keys={'hp','spe','atk','spa','def','spd'}
      if not P.toggle then
        for i,key in ipairs(keys)do local col=(i-1)%2;local y=53+math.floor((i-1)/2)*11
          text(labels[i],8+43*col,y);text(string.format('%3d',s[key]or 0),31+47*col,y)
        end
        local rate=s.catchRate or 0;local label=rate<=10 and 'LEGENDARY'or rate<=70 and 'VERY HARD'or rate<=100 and 'DIFFICULT'or rate<=150 and 'MEDIUM'or rate<=200 and 'RELAXED'or 'EASY'
        text('CATCH:',8,86);text(label,51,86)
        local growth=(r.growthRate or '---'):upper():gsub('MEDIUM','MED.')
        text('GROW:',8,97);text(growth,93-U.width(growth,'small'),97)
      else
        local ev={};for i,key in ipairs(keys)do if r.evYield[key]>0 then ev[#ev+1]={label=labels[i],value=r.evYield[key]}end end
        for i,e in ipairs(ev)do
          local cols=#ev<3 and 2 or 3;local x=8+(#ev<3 and 43 or 29)*((i-1)%cols);local y=53+math.floor((i-1)/cols)*11
          U.tokenText(e.label..string.rep('{UP_ARROW_2}',e.value),x,y,'small',fg,sh)
        end
        local y=53+math.ceil(#ev/(#ev<3 and 2 or 3))*11
        text('EXP YIELD:',8,y);text(string.format('%3d',s.expYield or 0),78,y);y=y+11
        text('FRIENDSHIP:',8,y)
        local emotion=({[35]='EMOJI_BIGANGER',[70]='EMOJI_NEUTRAL',[90]='EMOJI_HAPPY',[100]='EMOJI_HAPPY',[140]='EMOJI_BIGSMILE'})[s.friendship]
        if emotion then U.glyph(emotion,85,y)else text(string.format('%3d',s.friendship or 0),78,y)end;y=y+11
        text('HATCH STEPS:',8,y)
        if r.noEggs then text('---',78,y)else
          local cycles=s.eggCycles or 20;local n=cycles<=20 and 1 or cycles<=30 and 2 or 3;local x=94-n*9
          if cycles<=10 then U.glyph('EMOJI_BOLT',76,y);x=85 end
          for i=0,n-1 do U.glyph('EMOJI_DIZZYEGG',x+i*9,y)end
        end
        if r.eggGroups then y=y+11;local a,b=unpack(r.eggGroups);U.tokenText(a==b and a or a..'/'..b,8,y,'small',fg,sh)end
      end
    end)
    local abilities=r.abilityNames or {}
    U.clip(96,96,144,64,function()
      for i=1,2 do local name=abilities[P.toggle and 3 or i];local a=spec.abilities[name]
        if a and name~='NONE'and(i==1 or name~=abilities[1])then
          local y=99+(i-1)*30;text(a.name,101,y,'small',true);text(a.description,101,y+14)
        end
        if P.toggle then break end
      end
    end)
    local moves=P.moves(row);local m=moves[P.moveCursor];local move=m and spec.moveInfo[m.move]
    if m then
      U.clip(96,16,144,32,function()
        text(string.format('%3d / %3d',P.moveCursor,#moves),100,20,'small',true)
        text(move and move.name or m.move:gsub('_',' '),101,36)
        if m.kind=='level'then text('LVL',214,22);text(m.level,214,33)
        else text(m.label or '---',214,28)end
      end)
      local item=m.kind=='level'and 'candy'or m.kind=='egg'and 'egg'or m.kind=='tutor'and 'tutor'or m.kind..(move and move.type or 'NORMAL')
      if spec.art[item]then art(item,191,27)end
      if move then
        local contest=P.toggle and spec.contestMoves[m.move]
        local typeName=move.type
        local im,a=U.art(contest and 'contest'..contest.category or 'type'..typeName);love.graphics.setColor(1,1,1,1);love.graphics.draw(im,151,20)
        U.clip(96,48,144,32,function()text(contest and contest.description or move.description,101,53)end)
        U.clip(96,80,144,16,function()
          text(contest and 'APPEAL'or 'POWER',104,83);text(contest and '+'..contest.appeal or move.power>1 and string.format('%3d',move.power)or '---',149,83)
          text(contest and 'JAM'or 'ACCURACY',170,83);text(contest and '-'..contest.jam or move.accuracy>0 and string.format('%3d',move.accuracy)or '---',contest and 223 or 218,83)
        end)
        if not contest then local im,a=U.art('moveCategory');local frame=({physical=0,special=1,status=2})[move.category]
        love.graphics.setColor(1,1,1,1);love.graphics.draw(im,love.graphics.newQuad(0,frame*16,16,16,a.width,a.height),131,82)end
      end
    end
    U.clip(0,144,96,16,function()U.tokenText('{A_BUTTON}TOGGLE   {DPAD_UPDOWN}MOVES',9,144,'small',{1,1,1,1},fg)end)
  end
  function P.draw()
    love.graphics.push('all')
    local row=P.row()
    if P.page=='list'then P.drawList()
    elseif row then
      if P.page=='stats'then P.drawStats(row)else
        game._hnsCollection.registration.info(P.detail(row),P.session,P.caught(row));P.picture(row,16,24)
      end
    end
    local a=P.animation
    if a then
      local alpha=a.kind=='portrait'and math.min(16,a.tick)/16 or(a.kind=='in'and(16-a.tick)/16 or(a.tick<=16 and a.tick/16 or(32-a.tick)/16))
      love.graphics.setColor(0,0,0,alpha);love.graphics.rectangle('fill',0,0,240,160)
      if a.kind=='portrait'and row then P.picture(row,114-math.min(98,a.tick*4),48-math.min(24,a.tick*4))end
    end
    love.graphics.pop()
  end
  local base=game._hnsDex and game._hnsDex.get or Screens.get
  Screens.get=function(id,s)if id=='pokedex'and D.own(s)then return P end;return base(id,s)end
  game._hnsDex={get=base,ui=P}
end
