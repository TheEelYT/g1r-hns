-- Optional development tools. All supplies/shortcuts target a separate save.
return function(mod,w,game)
  local old=game._hnsPractice or {};local L=old.lab or {ID='hns_practice'}
  local Rt=require('src.core.game3.runtime');local Stack=require('src.ui.game3.stack')
  local Save=require('src.core.SaveData');local Codec=require('src.core.SaveSerializer')
  local Bag=require('src.core.game3.bag');local Party=require('src.core.game3.party')
  local P=require('src.core.game3.pokemon');local Rng=require('src.core.game3.rng')
  local Warp=require('src.core.game3.warp');local Player=require('src.core.game3.player')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui)
  L.ui=U
  local X=game._hnsExpandedMoves.moves
  local function own(s)return s and w.maps[s.map]~=nil end
  function L.isPractice(s)return own(s)and type(s.meta)=='table'and type(s.meta.hnsPractice)=='table'and s.meta.hnsPractice.schema==1 end
  local function scope()
    local cart=Save.getCart()
    if cart then return {
      active=function()return Save.activeCartSlot(cart)end,
      read=function(id)return Save.readCartSlotSource(cart,id)end,
      duplicate=function(id)return Save.duplicateCartSlot(cart,id,'HnS PRACTICE')end,
      write=function(id,s)return Save.writeCartSlot(cart,id,s)end,
      remove=function(id)return Save.deleteCartSlot(cart,id)end,
    }end
    return {
      active=function()return Save.activeSlot('emerald')end,
      read=function(id)return Save.readSlotSource('emerald',id)end,
      duplicate=function(id)return Save.duplicateSlot('emerald',id,'HnS PRACTICE')end,
      write=function(id,s)return Save.writeSlot('emerald',id,s)end,
      remove=function(id)return Save.deleteSlot('emerald',id)end,
    }
  end
  function L.kit(bag)
    local copy=assert(Codec.decode(Codec.encode(bag or Bag.new())))
    for _,name in ipairs({'DRAIN_PUNCH','WATER_PULSE','PROTECT'})do
      local machine
      for _,r in ipairs(w.teaching.machines)do if r.kind=='TM'and r.move==name then machine=r;break end end
      assert(machine and X.id(name),'practice machine unavailable: '..name)
      if Bag.set(copy,machine.itemId,9)~=9 then return nil,'No room in the TM pocket.'end
    end
    return copy
  end
  function L.prepare(s)
    assert(own(s),'Save once on an HnS map first.')
    assert(not s.surfing and not s.underwater and not s.biking,'Save on dry ground, off your bike first.')
    local origin={map=s.map,x=s.x,y=s.y,facing=s.facing or 'down',elevation=s.elevation}
    assert(type(origin.x)=='number'and type(origin.y)=='number','Save once on dry ground first.')
    s.meta=s.meta or {};s.meta.hnsPractice={schema=1,origin=origin}
    -- The parsed copy is isolated. Original party, PC, bag, flags and RNG are
    -- never passed to a mutating operation or written to their source slot.
    s.bag=assert(L.kit(Bag.new()));s.inventory=s.bag;s.party={};s.move_overlay={}
    s.flags=s.flags or {};s.flags[w.followers.disabledFlag]=nil;s.flags[tostring(w.followers.disabledFlag)]=nil
    s.continueGameWarp=nil;s.specialSaveWarpFlags=nil;s.objectEvents=nil
    local tid=(tonumber(s.trainerId)or 12345)%65536
    local sid=tonumber(P.playerSecretId(s))or 0
    local shiny=bit.bxor(tid,sid%65536)*65536
    local state=Rng.getState()
    local ok,err=xpcall(function()
      for i,pid in ipairs({(shiny+0x10000000)%0x100000000,shiny})do
        local yes,_,mon=Party.giveMon(s,62,25,i==1 and 'NORMAL'or 'SHINY',{fixedPersonality=pid})
        assert(yes and mon,'Could not construct practice follower.')
        mon.isShiny=i==2;mon.moves={};mon.pp={};mon.maxPp={}
        local names=i==1 and {'WATER_GUN'}or {'WATER_GUN','SURF','REST','ICE_BEAM'}
        for n,name in ipairs(names)do
          local id=assert(X.id(name),name);mon.moves[n]=id;mon.pp[n]=P.movePp(id);mon.maxPp[n]=mon.pp[n]
        end
      end
    end,function(e)return tostring(e)end)
    Rng.setState(state)
    assert(ok,err)
    -- Keep the copied point safe from a blackout during a terrain tour.
    s.healMap,s.healX,s.healY=origin.map,origin.x,origin.y
    return s
  end
  function L.create(s)
    if not own(s)then return nil,'Open this from an HnS save.'end
    local fs=scope();local src=fs.active()
    if not src then return nil,'Save your game once first.'end
    local source=fs.read(src);local saved=source and Codec.decode(source)
    if not own(saved)then return nil,'Save your game on an HnS map first.'end
    if L.isPractice(saved)then return nil,'This is already a practice copy.'end
    -- Native duplication gives the copy its own playthrough identity, seal
    -- metadata and per-playthrough storage. It never selects that new slot.
    local id,err=fs.duplicate(src)
    if not id then return nil,err or 'Could not duplicate the saved slot.'end
    local ok,result=xpcall(function()
      local bytes=assert(fs.read(id),'Could not read the new copy.')
      local copy=L.prepare(assert(Codec.decode(bytes)))
      local written,why=fs.write(id,copy);assert(written,why or 'Could not write the practice copy.')
      local readback=assert(fs.read(id),'Could not verify the practice copy.')
      assert(readback==Codec.encode(copy),'Practice save verification failed.')
      return id
    end,function(e)return tostring(e)end)
    if not ok then fs.remove(id);return nil,result end
    return result
  end
  function L.travel(s,destination)
    if not L.isPractice(s)or s~=Rt.getSession()then return nil,'Shortcuts are only for practice saves.'end
    local selected
    if destination=='return'then selected=s.meta.hnsPractice.origin
    else for _,d in ipairs(w.practice.destinations)do if d.id==destination then selected=d;break end end end
    if not(selected and w.maps[selected.map])then return nil,'That test location is unavailable.'end
    if Warp.isBusy()or require('src.core.game3.battle').isActive()then return nil,'Finish the current action first.'end
    -- Source underwater/Surf transitions need their own setup; dry strips only.
    if Player.surfing or Player.underwater or Player.biking then return nil,'Stand on dry ground, off your bike first.'end
    L.close()
    local Options=game._hnsGear.options;if Options.isOpen()then Options.close(true)end
    require('src.ui.game3.start_menu').close(true)
    return Warp.request(mod,game,selected.map,selected.x,selected.y,selected.facing,{onDone=function()
      require('src.ui.game3.hud').openMessage(game,destination=='return'and 'Back at the copied save point.'or 'Practice strip: walk LEFT and RIGHT.\nPORT TEST TOOLS can return you.')
    end})
  end
  function L.rows()
    if L.page=='terrain'then
      local rows={}
      for _,d in ipairs(w.practice.destinations)do rows[#rows+1]={label=d.label,help=d.name..'\nWalk LEFT and RIGHT.',action=function()local ok,e=L.travel(L.session,d.id);if not ok then L.message=e end end}end
      rows[#rows+1]={label='Back',help='Return to practice tools.',action=function()L.page='root';L.cursor=1 end};return rows
    end
    if L.isPractice(L.session)then return {
      {label='Refill TM supplies',help='Set the three practice TMs to 9.\nOnly this practice bag changes.',action=function()
        local bag,e=L.kit(L.session.bag);if bag then L.session.bag=bag;L.message='Three practice TMs refilled to 9.'else L.message=e end
      end},
      {label='Swap first two followers',help='Switch NORMAL and SHINY leads.\nOnly this practice party changes.',action=function()
        local party=L.session.party or {};if #party<2 then L.message='Two party members are needed.';return end
        party[1],party[2]=party[2],party[1];L.message='First two party members swapped.\nClose the menu to see the lead.'
      end},
      {label='Terrain shortcuts',help='Jump to a verified walking strip.\nOnly available in a practice save.',action=function()L.page='terrain';L.cursor=1 end},
      {label='Return to copied point',help='Return to this copy\'s original\nmap and saved position.',action=function()local ok,e=L.travel(L.session,'return');if not ok then L.message=e end end},
      {label='Back',help='Close practice tools.',action=L.close},
    }end
    return {
      {label='Create practice copy',help='Copy your last SAVED point.\nSeparate test party and TMs.',action=function()L.confirm=true;L.yes=false end},
      {label='Back',help='Close without creating a copy.',action=L.close},
    }
  end
  function L.show(opts)
    local s=opts and opts.session or Rt.getSession();if not own(s)then return false end
    L.session=s;L.page='root';L.cursor=1;L.message=nil;L.confirm=nil
    Stack.push(L.ID,L,{hideBelow=true,fullscreen=true});return true
  end
  function L.close()Stack.pop(L.ID)end
  function L.isOpen()return Stack.has(L.ID)end
  function L.handleInput(input)
    local function key(k)return input:wasPressed(k)end
    if L.message then if key('a')or key('b')then L.message=nil end;return end
    if L.confirm then
      if key('b')then L.confirm=nil;return end
      if key('left')or key('right')or key('up')or key('down')then L.yes=not L.yes end
      if key('a')then
        L.confirm=nil
        if L.yes then local id,e=L.create(L.session);L.message=id and 'Created HnS PRACTICE.\nExit to the launcher, choose that\nsave slot, then Continue.\nYour regular slot stays selected.'or U.wrap(e,192,'small')end
      end
      return
    end
    if key('b')or key('start')then if L.page=='terrain'then L.page='root';L.cursor=1 else L.close()end;return end
    local rows=L.rows()
    if key('up')then L.cursor=(L.cursor-2)%#rows+1 elseif key('down')then L.cursor=L.cursor%#rows+1 end
    if key('a')then rows[L.cursor].action()end
  end
  function L.draw()
    local c=U.spec.colors
    love.graphics.setColor(14/31,20/31,24/31,1);love.graphics.rectangle('fill',0,0,240,160)
    U.text('PORT TEST TOOLS',120-U.width('PORT TEST TOOLS','small')/2,2,c[2],c[3],'small')
    U.box(16,32,208,80)
    if L.confirm then
      U.text('Use last SAVED point?\nNew test party and TM supplies.\nCurrent slot stays selected.',24,33,c[6],c[7],'small',16)
      U.text((L.yes and '> YES    NO'or '  YES  > NO'),40,89,c[3],c[4],'small')
      U.text('A CONFIRM   B CANCEL',24,133,c[3],c[4],'small');return
    end
    if L.message then U.text(L.message,24,33,c[6],c[7],'small',16);U.text('A / B BACK',24,133,c[3],c[4],'small');return end
    local rows=L.rows();local first=math.max(1,L.cursor-3)
    for i=first,math.min(#rows,first+3)do
      U.text((i==L.cursor and '> 'or '  ')..rows[i].label,24,33+(i-first)*16,c[6],c[7],'small')
    end
    U.text('A SELECT   B BACK',24,97,c[3],c[4],'small')
    -- Two-line help uses the lower band; keep list and help within 240x160.
    U.text(rows[L.cursor].help,16,122,c[2],c[3],'small',16)
  end
  if not old.hooks then
    mod.hooks:wrap('ui.options.rows',function(next,g,rows)
      rows=next(g,rows)
      local s=Rt.getSession()or g and(g.session or g.save)
      if g==game and own(s)then rows[#rows+1]={id='hns.practice',label='PORT TEST TOOLS',activate=function()return L.show({session=s})end}end
      return rows
    end)
  end
  old.hooks=true;old.lab=L;game._hnsPractice=old
end
