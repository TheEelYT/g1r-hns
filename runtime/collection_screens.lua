-- HnS HGSS Plus registration and trainer card; native callbacks/saves stay owned.
return function(mod,world,game)
  local old=game._hnsCollection or {}
  local U=assert(load(mod:read('source_ui.lua'),'@hns/source_ui.lua'))()(mod,world.startup.ui)
  local Rt=require('src.core.game3.runtime')
  local Stack=require('src.ui.game3.stack')
  local Pokemon=require('src.core.game3.pokemon')
  local Dex=require('src.core.game3.dex')
  local Audio=require('src.core.game3.audio')
  local C=require('src.core.game3.constants').of('emerald')
  local function own(s)return s and world.maps[s.map]~=nil end
  local function art(name,x,y,w,h,qx,qy)
    local im,a=U.art(name);local q=love.graphics.newQuad(qx or 0,qy or 0,w or a.width,h or a.height,a.width,a.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,x,y)
  end
  local fg,sh={.25,.25,.25,1},{.8,.8,.8,1}
  local function text(t,x,y)U.text(t,x,y,fg,sh)end
  local rows={};for _,r in ipairs(world.pokedex.registrationEntries)do rows[C:require('species','SPECIES_'..r.speciesName)]=r end
  local unit
  for _,p in ipairs(world.startup.settings.pages)do for _,r in ipairs(p.rows)do if r.id=='ITEM_MAIN_UNIT_TYPE'then unit=r end end end
  local function imperial(s)
    if not unit then return false end
    local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
    local v=s and s.vars and (s.vars[unit.var] or s.vars[tostring(unit.var)])
    if s==Rt.getSession() and Space.store then v=Flags.getVar(Space.store,nil,unit.var)end
    return (v or unit.default)==1
  end
  local R={ID='hns_caught_entry',ui=U,rows=rows}
  function R.measurements(row,us)
    if us then
      local inches=math.floor((row.height or 0)*10000/254)
      if inches%10>=5 then inches=inches+10 end
      local feet=math.floor(inches/120);inches=math.floor((inches-feet*120)/10)
      local pounds=math.floor((row.weight or 0)*100000/4536)
      if pounds%10>=5 then pounds=pounds+10 end
      return string.format('%d’%02d”',feet,inches),string.format('%.1f lbs.',math.floor(pounds/10)/10)
    end
    return string.format('%.1f m',(row.height or 0)/10),string.format('%.1f kg.',(row.weight or 0)/10)
  end
  function R.info(row,s,owned)
    local im=U.image(world.pokedex.backgrounds.info,240,160);local q=love.graphics.newQuad(0,0,240,160,240,160)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,0,0)
    local number=(Dex.nationalEnabled(s) or row.number==0)and row.obtainableNumber or row.number
    U.text('№',123,17,{1,1,1,1},fg)
    U.text(string.format('%03d',number),123+U.width('№')+1,17,{1,1,1,1},fg)
    U.text(row.name,157,17,{1,1,1,1},fg)
    if owned==nil then owned=true end
    text(owned and (row.category or '')..' POKéMON' or '????? POKéMON',123,31)
    local types=Pokemon.types(C:require('species','SPECIES_'..row.speciesName));local Types=require('src.core.game3.battle.types');local names={}
    for name,id in pairs(Types.ID)do names[id]=name end
    for i,id in ipairs(types)do if owned and (i==1 or id~=types[1])then
      local name='type'..(names[id] or 'MYSTERY')
      if U.spec.art[name]then art(name,147+(i-1)*33,48,32,16)end
    end end
    if owned and row.footprint then local f=row.footprint;local pic=U.image(f.file,f.width,f.height);local fq=love.graphics.newQuad(0,0,f.width,f.height,f.width,f.height);love.graphics.setColor(1,1,1,1);love.graphics.draw(pic,fq,120,56)end
    local height,weight=R.measurements(row,imperial(s))
    text('HT',155,64);text(owned and height or '?????',180,64);text('WT',155,77);text(owned and weight or '?????',180,77)
    local desc=owned and (row.descriptionLines or row.description or '')or ''
    local width=0
    for line in desc:gmatch('[^\n]+')do width=math.max(width,U.width(line))end
    U.text(desc,math.max(0,math.floor((240-width)/2)),93,fg,sh,'normal',16)
  end
  function R.show(species,opts)
    opts=opts or {};local s=opts.session or Rt.getSession()
    R.session=s;R.row=assert(rows[species],'missing supported HnS registration species')
    R.species=species;R.personality=opts.personality;R.onDone=opts.onDone
    R.phase='in';R.fade=16;R.x=48;R.y=56;R.acc=0
    Stack.push(R.ID,R,{hideBelow=true,fullscreen=true});return R
  end
  function R.isOpen()return Stack.has(R.ID)end
  function R.close()
    Stack.pop(R.ID);local cb=R.onDone;R.onDone=nil;R.phase=nil
    if cb then
      local Battle=require('src.core.game3.battle')
      if Battle.isActive() and Battle._phase=='pokedex_reg' then R.pendingCallback=cb else cb()end
    end
  end
  function R.step()
    if R.phase=='in'then
      R.fade=R.fade-1
      if R.fade<=0 then R.phase='wait';R.fade=0;Audio.playCry(R.species)end
    elseif R.phase=='out'then
      R.fade=math.min(16,R.fade+1);R.x=math.min(120,R.x+2);R.y=math.min(80,R.y+1)
      if R.fade==16 and R.x==120 and R.y==80 then R.close()end
    end
  end
  function R.update(dt)
    R.acc=(R.acc or 0)+(dt or 1/60)*60
    while R.acc>=1 and R.isOpen()do R.acc=R.acc-1;R.step()end
  end
  function R.handleInput(keys)
    if R.phase=='wait' and (keys:wasPressed('a') or keys:wasPressed('b'))then R.phase='out';R.fade=0 end
  end
  function R.draw()
    if not R.isOpen()then return end
    R.info(R.row,R.session)
    if R.phase=='out'then love.graphics.setColor(0,0,0,R.fade/16);love.graphics.rectangle('fill',0,0,240,160)end
    -- Source registration intentionally uses the normal palette, including shinies.
    local front=R.row.front
    if R.row.speciesName=='UNOWN' or R.row.speciesName=='SPINDA'then front=nil end
    local pic=front and U.image(front.file,64,64) or Pokemon.frontPic(R.species,nil,false,R.personality)
    pic=pic and (pic.image or pic)
    if pic then local w,h=pic:getDimensions();local q=love.graphics.newQuad(0,0,64,64,w,h);love.graphics.setColor(1,1,1,1);love.graphics.draw(pic,q,R.x-32,R.y-32)end
    if R.phase=='in'then love.graphics.setColor(0,0,0,R.fade/16);love.graphics.rectangle('fill',0,0,240,160)end
    love.graphics.setColor(1,1,1,1)
  end
  local NativeDex=require('src.ui.game3.rse.pokedex')
  local show=old.dexShow or NativeDex.showCaughtMon
  NativeDex.showCaughtMon=function(species,opts)
    if own(opts and opts.session or Rt.getSession()) and rows[species]then return R.show(species,opts)end
    return show(species,opts)
  end
  local dexInput=old.dexInput or NativeDex.Host.handleInput
  NativeDex.Host.handleInput=function(keys)if R.isOpen()then return R.handleInput(keys)end;return dexInput(keys)end
  -- Restore battle text from the battle update, after the registration stack
  -- has released. Hud's modal tick must not own (or swallow) this continuation.
  local Battle=require('src.core.game3.battle');local Ui=require('src.core.game3.battle.ui')
  local update=old.battleUpdate or Battle.update
  Battle.update=function(...)
    if R.pendingCallback then
      local cb=R.pendingCallback;R.pendingCallback=nil
      Ui.clearLinger();Ui._timed=nil;Ui._showing=false
      cb()
    end
    return update(...)
  end
  local BattleText=require('src.core.game3.battle.battle_text')
  local battleText=old.battleText or BattleText.get
  BattleText.get=function(id,fill)
    if id=='STRINGID_GIVENICKNAMECAPTURED' and own(Rt.getSession())then
      local name=fill and fill.opponentMon1
      if type(name)=='table'then name=name.name or Pokemon.name(Pokemon.speciesOf(name.mon or name))end
      return world.pokedex.nicknamePrompt:gsub('{B_DEF_NAME}',function()return name or ''end)
    end
    return battleText(id,fill)
  end
  local Card=require('src.ui.game3.trainer_card')
  local draw=old.cardDraw or Card.draw
  local K={ui=U}
  function K.draw()
    local c=Card._card;if not c then return end
    local stars=math.max(0,math.min(4,c.stars or 0));local suffix=tostring(stars)..(c.female and 'Female' or 'Male')
    art('cardBg'..suffix,0,0)
    local f=Card._flip
    if f then love.graphics.push();love.graphics.translate(0,80);love.graphics.scale(1,math.max(0,(160-2*f.top)/160));love.graphics.translate(0,-80)end
    art('card'..(Card.side=='back'and 'Back' or 'Front')..suffix,0,0)
    if Card.side=='front'then
      local pic=world.startup.portraits[c.female and 'female' or 'male'];local im=U.image(pic.file,pic.width,pic.height);local q=love.graphics.newQuad(0,0,64,64,pic.width,pic.height)
      love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,160,40)
      text('NAME: '..c.playerName,24,41)
      local id=string.format('IDNo.%05d',c.trainerId);text(id,128+math.floor((96-U.width(id))/2),17)
      text('MONEY',24,65);local money='¥'..c.money..'/0';text(money,136-U.width(money),65)
      if c.hasPokedex then
        local _,n=game._hnsDexState.counts(Card._session)
        text('POKéDEX',24,81);local val=tostring(n);text(val,136-U.width(val),81)
      end
      text('TIME',24,97);local time=string.format('%d:%02d',c.playTimeHours,c.playTimeMinutes)
      local blink=love.timer and love.timer.getTime and math.floor(love.timer.getTime()*60/61)%2==1
      local x=136-U.width(time);U.text(time:gsub(':',blink and ' ' or ':'),x,97,fg,sh)
      for i=0,stars-1 do U.tile('cardStar',143,120+i*8,56)end
      for i=1,8 do if c.badges[i]then art('cardBadgesJohto',32+(i-1)*24,120,16,16,(i-1)*16,0)end end
    else
      local title=c.playerName..'’s TRAINER CARD';text(title,224-U.width(title),17)
      for _,row in ipairs(Card.backTextsRse(c))do if row.y>30 and row.y<88 then U.text(row.text,row.x,row.y,row.stat and {.9,.2,.2,1}or fg,row.stat and {1,.6,.6,1}or sh)end end
      -- Source HnS displays the saved party on the reverse side.
      for i,mon in ipairs(Card._session.party or {})do
        local icon=Pokemon.icon(Pokemon.speciesOf(mon));if icon then love.graphics.setColor(1,1,1,1);love.graphics.draw(icon.image,icon.quads[0],24+(i-1)*32,108)end
      end
    end
    if f then
      love.graphics.pop();local blend=math.floor((f.top+40)/10)
      if blend>4 then love.graphics.setColor(0,0,0,math.min(1,blend/16));love.graphics.rectangle('fill',0,0,240,160)end
    end
    love.graphics.setColor(1,1,1,1)
  end
  Card.draw=function(...)if Card.open and own(Card._session)then return K.draw()end;return draw(...)end
  game._hnsCollection={dexShow=show,dexInput=dexInput,cardDraw=draw,battleUpdate=update,battleText=battleText,registration=R,card=K}
end
