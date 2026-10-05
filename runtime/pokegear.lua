-- HnS-owned map, phone, clock and settings, using native saves/modal stack.
return function(mod,world,game,Settings,UI)
  local Q=world.startup;local old=game._hnsGear or {}
  local CenterClock=assert(load(mod:read('hns_wall_clock.lua'),'@hns/hns_wall_clock.lua'))()
  local Stack=require('src.ui.game3.stack')
  local Font=require('src.ui.game3.frlg_font')
  local Window=require('src.ui.game3.window')
  local Flags=require('src.core.game3.scripting.flags')
  local Space=require('src.core.game3.scripting.space')
  local Rt=require('src.core.game3.runtime')
  local Audio=require('src.core.game3.audio')
  local C=require('src.core.game3.constants').of('emerald')
  local function own(s) return s and world.maps[s.map]~=nil end
  local function flag(id,s) if Space.store and s==Rt.getSession() then return Flags.getFlag(Space.store,nil,id) end;return s and s.flags and (s.flags[id] or s.flags[tostring(id)]) end
  local function setflag(id,value,s) if Space.store and s==Rt.getSession() then Flags.setFlag(Space.store,nil,id,value) else s.flags=s.flags or {};s.flags[id]=value or nil end end
  local function song(name) for id,n in pairs(world.audio.songs)do if n==name then return tonumber(id) end end end
  local function text(s,x,y) Font.draw(s,x,y,{colors=Font.COLOR.NORMAL,font='narrow',linePitch=14}) end
  local function frame(title)
    love.graphics.setColor(.43,.63,.75,1);love.graphics.rectangle('fill',0,0,240,160)
    Window.stdFrame(Window.template(1,3,28,15));text(title,12,7)
  end
  local function values(s)
    local out={};local init=flag(Q.settings.initializedFlag,s)
    for _,p in ipairs(Q.settings.pages)do for _,r in ipairs(p.rows)do
      if init and Space.store and s==Rt.getSession() then out[r.id]=Flags.getVar(Space.store,nil,r.var)
      else out[r.id]=init and (s.vars and (s.vars[r.var] or s.vars[tostring(r.var)]) or r.default) or r.default end
    end end
    return out
  end
  local O={ID='hns_options'}
  function O.show(opts)
    O.session=opts and opts.session or Rt.getSession();O.model=Settings.new(opts and opts.kind or 'option',values(O.session),false)
    O.enginePages=nil
    if not opts or not opts.kind or opts.kind=='option' then
      O.model.pages[#O.model.pages+1]={id='GEN1RECOMP',name='GEN1RECOMP',kind='engine',rows={}}
      local Options=require('src.core.game3.options');local Rows=require('src.ui.game3.option_rows')
      local engine=Options.engine(O.session)or game.options or {};Options.bind(O.session,engine)
      O.engineContext={session=O.session,game=game,options=engine}
      -- HnS already owns these six cartridge rows. All native engine and
      -- hook-provided rows retain their own actions and platform filtering.
      local cart={textSpeed=true,battleScene=true,battleStyle=true,sound=true,buttonMode=true,frameType=true}
      local rows={};for _,r in ipairs(Rows.build(O.engineContext))do if not cart[r.id]then rows[#rows+1]=r end end
      O.enginePages={};local top=Rows.group(rows,function(title,members)
        O.enginePages[#O.enginePages+1]={title=title,rows=members,cursor=1}
      end)
      O.enginePages[1]={title='GEN1RECOMP',rows=top,cursor=1}
    end
    Stack.push(O.ID,O,{hideBelow=true,fullscreen=true})
  end
  function O.close(save)
    if save then
      local s=O.session;s.vars=s.vars or {}
      local existing=values(s)
      for _,p in ipairs(Q.settings.pages)do for _,r in ipairs(p.rows)do
        local v=O.model.values[r.id];if v==nil then v=existing[r.id] end;s.vars[r.var]=v
        if Space.store and s==Rt.getSession() then Flags.setVar(Space.store,nil,r.var,v) end
      end end
      setflag(Q.settings.initializedFlag,true,s)
      local Options=require('src.core.game3.options');game.options=game.options or {};local block=Options.block(game.options,Options.blockId(s))
      for k,v in pairs(Settings.native(O.model))do block[k]=v end
      Options.bind(s,game.options)
      if game.applyOptions then game:applyOptions(game.options);game:writeOptions() end
    end
    Stack.pop(O.ID)
  end
  function O.handleInput(input)
    local new={};for _,key in ipairs({'a','b','start','up','down','left','right','l','r'})do new[key]=input:wasPressed(key) end
    if O.model.pages[O.model.tab].kind=='engine' then
      local p=O.enginePages[#O.enginePages]
      if new.l then O.model.tab=O.model.tab-1;O.model.cursor=1;return end
      if new.r then return end
      if new.b or new.start then
        if #O.enginePages>1 then table.remove(O.enginePages)else O.close(true)end;return
      end
      if new.up then p.cursor=(p.cursor-2)%#p.rows+1 elseif new.down then p.cursor=p.cursor%#p.rows+1 end
      local r=p.rows[p.cursor]
      if new.a and r.activate then r.activate(O.engineContext)
      elseif r.step and (new.a or new.left or new.right)then
        if r.step(O.engineContext,new.left and -1 or 1) and game.writeOptions then game:writeOptions()end
      end
      return
    end
    if Settings.frame(O.model,{new=new}) then O.close(not O.model.cancelled) end
  end
  function O.draw()
    if O.model.pages[O.model.tab].kind~='engine'then return Settings.draw(O.model)end
    local p=O.enginePages[#O.enginePages];local c=UI.spec.colors
    love.graphics.setColor(14/31,20/31,24/31,1);love.graphics.rectangle('fill',0,0,240,160)
    love.graphics.setColor(unpack(c[16]));love.graphics.rectangle('fill',0,0,240,16)
    UI.text(p.title,120-UI.width(p.title,'small')/2,1,c[2],c[3],'small');UI.glyph('L_BUTTON',2,1)
    UI.box(16,32,208,96);local first=math.max(1,p.cursor-5)
    for i=first,math.min(#p.rows,first+5)do
      local r=p.rows[i];local y=33+(i-first)*16
      if i==p.cursor then love.graphics.setColor(.69,.69,.69,1);love.graphics.rectangle('fill',16,y-1,208,16)end
      local value=r.value and tostring(r.value(O.engineContext))or '▶'
      -- Native labels and values may be longer than a cartridge option.
      local font='small';local vx=214-UI.width(value,font)
      UI.clip(24,y,math.max(0,vx-28),16,function()UI.text(r.label,24,y,c[6],c[7],font)end)
      UI.text(value,vx,y,c[3],c[4],font)
    end
    UI.text('A SELECT   B BACK',24,144,c[3],c[4],'small')
  end
  function O.isOpen() return Stack.has(O.ID) end
  local G={ID='hns_pokegear',tab=1,cursor=1,images={}}
  local function substitute(t,s)
    return (t:gsub('{PLAYER}',s.name or 'PLAYER'):gsub('{KUN}',''):gsub('{STR_VAR_1}',tostring(G.seen or 0)):gsub('{STR_VAR_2}',tostring(G.caught or 0)))
  end
  function G.call(t,onDone)
    G.session=G.session or Rt.getSession()
    local returnToGear=Stack.has(G.ID);Stack.pop(G.ID)
    G.phone.show(substitute(t,G.session),function()
      if onDone then onDone() elseif returnToGear then G.page='phone';Stack.push(G.ID,G,{hideBelow=true,fullscreen=true}) end
    end,G.caller or 'PROF. ELM')
  end
  function G.show(opts)
    G.session=opts and opts.session or Rt.getSession();G.page='home';G.cursor=1
    G.fade=16;G.headerTick=0;G.nav=nil
    Stack.push(G.ID,G,{hideBelow=true,fullscreen=true})
  end
  function G.go(page)
    G.nav={page=page,tick=0};G.headerTick=0
  end
  function G.close()
    Stack.pop(G.ID);G.page='home'
    local done=G.done;G.done=nil;if done then done() end
  end
  function G.isOpen()return Stack.has(G.ID)end
  function G.contacts()
    local rows={{name='MOM',description='CALM & KIND',trainerName='MOM',text=Q.momCall}}
    if flag(Q.elmPhoneFlag,G.session) then
      local t=not flag(world.quest.flags.eggReceived,G.session) and Q.elmCalls.GoFindMrPokemon or not flag(world.quest.flags.eggDelivered,G.session) and Q.elmCalls.Robbery or G.elmRating()
      table.insert(rows,1,{name='PROF. ELM',description='{PKMN} PROF.',trainerName='PROF. ELM',text=t,rating=flag(world.quest.flags.eggDelivered,G.session)})
    end
    return rows
  end
  function G.elmRating(commit)
    local D=game._hnsDexState;local Dex=require('src.core.game3.dex')
    local s=G.session;local national=Dex.nationalEnabled(s);local ack=flag(Q.elmAckDexFlag,s)
    local function counts(t,nat)
      local seen,caught=D.counts(s,nat)
      return t:gsub('{STR_VAR_1}',tostring(seen)):gsub('{STR_VAR_2}',tostring(caught))
    end
    local function rating(nat)
      local n,_,complete=D.rating(s,nat);local prefix=nat and 'gNationalDexRatingText_' or 'gJohtoDexRatingText_'
      if complete then return Q.elmRatingTexts[prefix..'Complete'],true end
      for _,limit in ipairs(nat and {100,150,200,250,300,350,400,435,465,475}or {10,20,35,50,65,80,95,110,125,140,155,170,185,200,215,230,245,260,275})do
        if n<limit then return Q.elmRatingTexts[prefix..'LessThan'..limit],false end
      end
      return Q.elmRatingTexts[prefix..'LessThanMaxDex'],false
    end
    local out={}
    if not ack or not national then
      out[#out+1]=Q.elmCalls.AreYouCurious
      out[#out+1]=counts(Q.elmCountTexts.SoYouveSeenAndCaught,false)
      local text,complete=rating(false);out[#out+1]=text
      if complete and commit then setflag(Q.elmAckDexFlag,true,s)end
    else out[#out+1]=Q.elmCalls.AreYouCuriousNational end
    if national then
      out[#out+1]=counts(ack and Q.elmCountTexts.SoYouveSeenAndCaught or Q.elmCountTexts.OnANationwideBasis,true)
      local text,complete=rating(true)
      if ack or complete then out[#out+1]=text end
    end
    return table.concat(out,'\f')
  end
  function G.clock()
    require('src.ui.game3.rse.wall_clock').open({mode='view',session=G.session,gender=G.session.gender or 0,onDone=function()end})
  end
  local GearMenu=assert(load(mod:read('gear_menu.lua'),'@hns/gear_menu.lua'))()(UI)
  local Pages=assert(load(mod:read('gear_pages.lua'),'@hns/gear_pages.lua'))()(mod,world,UI,G)
  G.pages=Pages
  local function restoreMusic()
    local id=world.audio.mapSongs[G.session.map];if id then Audio.playSong(id)end
  end
  function G.homeRows()
    local phone=flag(Q.gearFlag,G.session)
    local radio=phone and flag(Q.radioFlag,G.session)
    local ribbons=phone and flag(C:flag('FLAG_SYS_RIBBON_GET'),G.session)
    local condition=flag(Q.conditionFlag,G.session) or #(G.session.party or {})>0 or radio or ribbons
    local home={'MAP'}
    if condition then home[#home+1]='CONDITION' end
    if phone then home[#home+1]='PHONE' end
    if radio then home[#home+1]='RADIO' end
    if ribbons then home[#home+1]='RIBBONS' end
    home[#home+1]='SWITCH OFF';return home
  end
  function G.playerMap(section)
    local def=world.maps[G.session.map];local sx=math.max(1,math.floor(def.width/section.width));local sy=math.max(1,math.floor(def.height/section.height))
    return section.x+math.max(0,math.min(section.width-1,math.floor((G.session.x or 0)/sx))),section.y+math.max(0,math.min(section.height-1,math.floor((G.session.y or 0)/sy)))
  end
  function G.handleInput(input)
    Pages.update()
    GearMenu.update(G.homeRows(),G.cursor)
    if G.nav then
      G.nav.tick=G.nav.tick+1;G.fade=G.nav.tick
      if G.nav.tick>=16 then
        local page=G.nav.page;G.nav=nil
        if page=='closed'then G.close();return end
        G.page=page;G.fade=16;G.headerTick=0
      end
      return
    end
    G.headerTick=math.min(12,(G.headerTick or 12)+1)
    if (G.fade or 0)>0 then G.fade=G.fade-1;return end
    local function pressed(k)return input:wasPressed(k)end
    if G.page=='call' then
      if pressed('a') or pressed('b') then
        if G.callPage<#G.callPages then G.callPage=G.callPage+1 elseif G.done then G.close() else G.page='phone' end
      end
      return
    end
    if pressed('b') then
      if G.page=='home' then G.go('closed')
      elseif G.page=='ribbonSummary'then G.go('ribbons')
      else if G.page=='radio'then restoreMusic()end;G.go('home');G.cursor=1 end
      return
    end
    if G.page=='ribbonSummary'then
      local row=Pages.ribbonRows()[G.cursor];local count=row and #Pages.ribbonIds(row.mon) or 0
      local delta=pressed('left')and -1 or pressed('right')and 1 or pressed('up')and -9 or pressed('down')and 9 or 0
      G.ribbonCursor=math.max(1,math.min(count,(G.ribbonCursor or 1)+delta));return
    end
    if G.page=='radio' then
      if pressed('left') or pressed('right')then G.tuning=math.max(0,math.min(63,(G.tuning or 0)+(pressed('left')and -1 or 1)));G.tune()end
      return
    end
    if G.page=='map' then
      if pressed('select') then G.region=G.region=='johto' and 'kanto' or 'johto' end
      if pressed('left')then G.mapX=math.max(0,G.mapX-1)end;if pressed('right')then G.mapX=math.min(27,G.mapX+1)end
      if pressed('up')then G.mapY=math.max(0,G.mapY-1)end;if pressed('down')then G.mapY=math.min(17,G.mapY+1)end
      return
    end
    if G.page=='condition' or G.page=='ribbons' then
      local count=G.page=='ribbons' and #Pages.ribbonRows() or #(G.session.party or {})+1
      if pressed('up') or pressed('down')then G.cursor=(G.cursor-1+(pressed('up') and -1 or 1))%math.max(1,count)+1 end
      if pressed('a')then
        if G.page=='ribbons' and count>0 then G.go('ribbonSummary');G.ribbonCursor=1
        elseif G.page=='condition' and G.cursor==count then G.go('home');G.cursor=1 end
      end
      return
    end
    local home=G.homeRows();local rows=G.page=='phone' and G.contacts() or home
    if pressed('up') or pressed('down')then G.cursor=(G.cursor-1+(pressed('up')and -1 or 1))%#rows+1 end
    if pressed('a')then
      if G.page=='phone'then local row=rows[G.cursor];G.caller=row.name;G.call(row.rating and G.elmRating(true)or row.text);return end
      local choice=home[G.cursor];G.cursor=1
      if choice=='SWITCH OFF'then G.go('closed')
      elseif choice=='CLOCK'then G.clock()
      elseif choice=='RADIO'then G.go('radio');G.tuning=G.tuning or 0;G.tune()
      elseif choice=='MAP'then
        G.go('map');local def=world.maps[G.session.map];G.region=def.hnsRegion=='REGION_KANTO' and 'kanto' or 'johto';G.mapX,G.mapY=10,10
        for _,s in ipairs(Q.sections)do if s.id==def.hnsSection then G.mapX,G.mapY=G.playerMap(s) end end
      else G.go(choice:lower()) end
    end
  end
  function G.tune()
    G.radioTick=0
    G.station=nil
    if not flag(Q.radioFlag,G.session)then return end
    local def=world.maps[G.session.map]
    for _,r in ipairs(Q.radioStations or {})do
      local available=r.region=='johto' and def.hnsRegion=='REGION_JOHTO'
      if r.id=='UNOWN'then available=def.hnsSection=='MAPSEC_RUINS_OF_ALPH' end
      if available and r.position==G.tuning then G.station=r;Audio.playSong(song(r.song),{restart=true});break end
    end
    if not G.station then local id=world.audio.mapSongs and world.audio.mapSongs[G.session.map];if id then Audio.playSong(id)end end
  end
  function G.locationName()
    local name=''
    for _,s in ipairs(Q.sections)do if Q.sectionRegions[s.id]==G.region and G.mapX>=s.x and G.mapX<s.x+s.width and G.mapY>=s.y and G.mapY<s.y+s.height then name=s.name or '' end end
    return name
  end
  function G.draw()
    if G.page=='home'then
      local home=G.homeRows();G.cursor=math.max(1,math.min(#home,G.cursor))
      local def=world.maps[G.session.map]
      GearMenu.draw(home,G.cursor,def and def.hnsRegion=='REGION_KANTO' and 'kanto' or 'johto',G.headerTick)
    elseif G.page~='call'then Pages.draw()
    else frame('POKéGEAR');text(G.callPages[G.callPage] or '',16,30)
    end
    if (G.fade or 0)>0 then love.graphics.setColor(0,0,0,G.fade/16);love.graphics.rectangle('fill',0,0,240,144);love.graphics.setColor(1,1,1,1)end
  end
  local Screens=require('src.ui.game3.screens');local baseGet=old.screensGet or Screens.get
  Screens.get=function(name,s) if own(s or Rt.getSession())then if name=='pokenav'then return G elseif name=='option'then return O end end;return baseGet(name,s) end
  local Start=require('src.ui.game3.start_menu');local baseDraw=old.startDraw or Start.draw
  Start.draw=function()
    baseDraw()
    local s=Start._session
    if Start.open and own(s) and flag(Q.clockFlag,s)then
      local t=require('src.core.game3.rtc').calcLocalTime(s);local h=t.hours%12;if h==0 then h=12 end
      UI.box(8,8,48,16)
      local clock=string.format('%d:%02d',h,t.minutes)
      UI.text(clock,8,9);UI.text(t.hours>=12 and 'PM' or 'AM',11+UI.width(clock),9)
    end
  end
  local function migrate(s)
    if not own(s)then return end
    local Bag=require('src.core.game3.bag');local native=C:require('items','ITEM_EXP_SHARE')
    if Bag.get(s.bag,native)>0 and Bag.get(s.bag,Q.expItem)==0 then Bag.remove(s.bag,native,1);Bag.add(s.bag,Q.expItem,1) end
    if flag(Q.shoesFlag,s)then setflag(Q.gearFlag,true,s);setflag(C:flag('FLAG_SYS_POKENAV_GET'),true,s)end
    if flag(world.quest.flags.eggDelivered,s)then setflag(Q.elmCallFlag,true,s)end
  end
  if not old.hooks then
    mod.events:on('map.entered',function()migrate(Rt.getSession())end)
    mod.hooks:wrap('ui.start_menu.items',function(next,g,rows)
      rows=next(g,rows)
      local s=g and (g.session or g.save) or Rt.getSession();if not own(s)then return rows end
      for _,r in ipairs(rows)do if r.id=='pokenav'then r.label='POKéGEAR' end end
      return rows
    end)
    mod.hooks:wrap('item.use',function(next,g,mon,id,slot,bag)
      local s=Rt.getSession();if own(s) and id==Q.expItem then
        local off=not flag(Q.expOffFlag,s);setflag(Q.expOffFlag,off,s)
        return true,'hns_toggle','EXP. SHARE is now '..(off and 'OFF.' or 'ON.')
      end
      return next(g,mon,id,slot,bag)
    end)
  end
  local N=require('src.core.game3.scripting.natives')
  N.ALLOW['native:'..Q.callNative]=function(ctx,a)return N.yieldHost(ctx,a,function(done)G.session=Rt.getSession();G.caller='PROF.ELM';G.call(Q.disasterText,done)end)end
  N.ALLOW['native:'..Q.resetClockNative]=function(ctx,a)
    Flags.setVar(Space.store,ctx,0x8004,(Rt.getSession()or {}).gender or 0)
    return N.yieldHost(ctx,a,function(done)CenterClock.open({mode='view',session=Rt.getSession(),gender=(Rt.getSession()or {}).gender or 0,onDone=function()done()end})end)
  end
  local Trainer=require('src.core.game3.trainer_pic');local baseBack=old.trainerBack or Trainer.back;local backCache={}
  Trainer.back=function(gender)
    local s=Rt.getSession();local info=Q.battleBacks[tostring(tonumber(gender)or 0)]
    if own(s)and info then
      if not backCache[gender]then local im=love.graphics.newImage(love.image.newImageData(info.width,info.height,'rgba8',assert(mod:read(info.file))));im:setFilter('nearest','nearest');backCache[gender]={image=im,w=64,h=info.height,frames=4}end
      return backCache[gender]
    end
    return baseBack(gender)
  end
  local Mapsec=require('src.ui.game3.rse.mapsec');local baseRead=old.mapRead or Mapsec.read;local baseLua=old.mapLua or Mapsec.readLua
  Mapsec.read=function(rel)local path=Q.popupFiles[rel];if path then return mod:read(path)end;return baseRead(rel)end
  Mapsec.readLua=function(rel)
    if rel=='chrome/map_popup/manifest.lua'then
      local man=baseLua(rel)or {palettes={}};local copy={};for k,v in pairs(man)do copy[k]=v end
      copy.palettes={};for k,v in pairs(man.palettes or {})do copy.palettes[k]=v end
      for k,v in pairs(Q.popupPalettes)do copy.palettes[k]=v end;return copy
    end
    return baseLua(rel)
  end
  local Exp=require('src.core.game3.battle.experience');local baseAward=old.expAward or Exp.awardFoe
  local HnsExp=assert(load(mod:read('hns_experience.lua'),'@hns/hns_experience.lua'))()
  Exp.awardFoe=function(st,foe,opts)
    if own(st and st.session)and not flag(Q.expOffFlag,st.session)then return HnsExp.awardFoe(st,foe,opts) end
    return baseAward(st,foe,opts)
  end
  -- One-time migration: 0.6.3's ordinary EXP.SHARE moves to key items.
  migrate(game.session or game.save)
  local Presentation=assert(load(mod:read('presentation_ui.lua'),'@hns/presentation_ui.lua'))()(mod,world,game,Settings,UI,O,old.presentation)
  G.phone=Presentation.phone
  game._hnsGear={screensGet=baseGet,startDraw=baseDraw,trainerBack=baseBack,mapRead=baseRead,mapLua=baseLua,expAward=baseAward,hooks=true,gear=G,options=O,settings=Settings,presentation=Presentation}
end
