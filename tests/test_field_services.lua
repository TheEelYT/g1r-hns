-- Native doors, saved berry trees/VM harvests, six-pocket actions and animation waits.
return function(T,game,w,maps)
  local S=w.services;local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags');local O=require('src.core.game3.objects')
  local B=require('src.core.game3.rse.berry_trees');local Bag=require('src.core.game3.bag');local Menu=require('src.ui.game3.bag_menu')
  local Skin=require('src.ui.game3.rse.bag_menu');local Items=require('src.core.game3.items_data');local Stack=require('src.ui.game3.stack')
  local saved,store,layers=Rt.session,Space.store,Stack._layers;local C=require('src.core.game3.constants').of('emerald')
  local s={version='emerald',map='EM_HNS_ROUTE29_HNS',name='GENE',party={},bag=Bag.new(),flags={},vars={},dex=require('src.core.game3.dex').new()}
  Rt.session=s;Space.store=Flags.newStore();Stack._layers={}
  s.berryTrees={[102]=B.blank()};game._hnsServices.initialize(s)
  T.eq(s.berryTrees[102].stage,5,'older blank berry record initializes to source ripe Oran')
  local count=0;for _ in pairs(s.berryTrees)do count=count+1 end
  T.eq(count,33,'all 33 source tree IDs initialize once')
  O.loadMap(game,s.map,maps[s.map]);local tree=O.find(16)
  T.check(tree and tree.berryTree and tree.rseKind=='berry_tree','source Route29 tree uses the actual native growth actor')
  O.tickRse(tree);T.eq(tree.berryTree.visible,true,'ripe source tree is visible')
  T.check(tree.berryTree.tree~=nil,'native tree actor resolves the source manifest')
  local N=require('src.core.game3.scripting.natives');local ctx={stringVars={},specialVars={[0x800F]=16}}
  require('src.core.game3.rse.init').setSpecialVar(ctx,0x800F,16)
  local meta=S.berries['7'];local berryInfo=Items._byId[meta.item];Items._byId[meta.item]={name='ORAN BERRY',pocket='BERRY_POUCH',fieldUse='heal',price=20}
  local qty=B.get(s,102).berryYield;local before=Bag.get(s.bag,meta.item)
  N.ALLOW['native:'..S.harvestNative](ctx)
  T.eq(require('src.core.game3.rse.init').specialVar(ctx,0x8004),2,'ripe native interaction selects success branch')
  T.eq(Bag.get(s.bag,meta.item),before+qty,'harvest adds the exact source yield')
  T.eq(B.get(s,102).stage,2,'HnS automatically replants at sprouted stage')
  T.eq(ctx.stringVars[2],tostring(qty),'source harvest dialogue buffers actual yield')
  N.ALLOW['native:'..S.harvestNative](ctx)
  T.eq(require('src.core.game3.rse.init').specialVar(ctx,0x8004),0,'unripe repeat does not grant another harvest')
  local Schema=require('src.core.game3.save_schema_firered');local encoded=Schema.toSaveTable(s);local restored=Schema.fromSaveTable(encoded)
  T.eq(restored.berryTrees[102].stage,2,'actual save export/reload retains harvested tree stage')
  T.eq(restored.berryTrees[102].berry,7,'actual save retains source berry species')
  game._hnsServices.initialize(s);T.eq(B.get(s,102).stage,2,'re-entry cannot reset harvested trees to ripe')
  B.timeUpdate(s,B.stageDuration(7)-1);T.eq(B.get(s,102).stage,2,'sprout remains until source duration elapses')
  B.timeUpdate(s,1);T.eq(B.get(s,102).stage,5,'elapsed source duration makes HnS berries ripe immediately')
  B.timeUpdate(s,100000);T.eq(B.get(s,102).stage,5,'source ripe berries never wither')
  local add=Bag.add;Bag.add=function()return false end;tree.berryTree.func='normal'
  N.ALLOW['native:'..S.harvestNative](ctx);Bag.add=add
  T.eq(require('src.core.game3.rse.init').specialVar(ctx,0x8004),1,'full bag follows source failure branch')
  T.eq(B.get(s,102).stage,5,'rejected harvest retains ripe berries for retry')
  -- Real authored VM includes berry cue and releases without an extra A.
  local Vm=require('src.core.game3.scripting.vm');local Adapters=require('src.core.game3.scripting.adapters')
  local vmStore=Space.store;Flags.setVar(vmStore,nil,0x800F,16)
  local audio=require('src.core.game3.audio');local fanfare=audio.playFanfare;local cue
  audio.playFanfare=function(id,...)cue=id;return fanfare(id,...)end
  local ad=Adapters.stub({playerName='GENE'});local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,store=vmStore,adapters=ad})
  require('src.core.game3.rse.init').setSpecialVar(vm.ctx,0x800F,16);local presses=0;ad.waitButton=function(done)presses=presses+1;if done then done()end;return true end
  T.check(vm:start('HNS_BERRY_INTERACT'),'native berry VM starts')
  for i=1,1800 do if not vm:isRunning()then break end;audio.update(1/60);vm:resume()end
  audio.playFanfare=fanfare
  T.eq(vm:isRunning(),false,'success VM releases after source fanfare without waiting for A')
  local expected;for id,name in pairs(w.audio.songs)do if name=='MUS_HG_OBTAIN_BERRY'then expected=tonumber(id)end end;T.eq(cue,expected,'harvest uses imported HGSS berry jingle')
  T.eq(vm.ctx.frozen,false,'harvest releases the player')
  T.eq(presses,0,'successful berry script never waits for another A');T.eq((s.gameStats or {})[3],1,'native planted-berries statistic increments once')
  -- Display Medicine and Items independently; retain native storage/actions.
  local potion=C:require('items','ITEM_POTION');local repel=C:require('items','ITEM_REPEL')
  -- Fixture omits most item definitions; add only these real Emerald rows.
  local pInfo=Items._byId[potion];local rInfo=Items._byId[repel]
  Items._byId[potion]=pInfo or {name='POTION',pocket='ITEMS',fieldUse='heal',price=300}
  Items._byId[repel]=rInfo or {name='REPEL',pocket='ITEMS',fieldUse='repel',price=350}
  Bag.add(s.bag,potion,2);Bag.add(s.bag,repel,1)
  Menu.show(s.bag,{session=s,pocket='MEDICINE'})
  T.eq(table.concat(Items.BAG_POCKET_ORDER,','),'ITEMS,MEDICINE,POKE_BALLS,TM_CASE,BERRY_POUCH,KEY_ITEMS','source six-pocket order')
  T.eq(Menu.currentPocket(),'MEDICINE','Medicine opens at its source index')
  T.eq(#Menu.list('MEDICINE'),1,'Medicine contains the Potion only')
  T.eq(#Menu.list('ITEMS'),1,'Items contains the Repel only')
  T.eq(#Menu.list('BERRY_POUCH'),1,'harvested berries appear in Berries pocket')
  T.eq(Bag.get(s.bag,potion),2,'virtual medicine pocket retains saved quantities')
  local nakedOrder=#s.bag.pockets.ITEMS;T.eq(nakedOrder,2,'Medicine uses existing saved Items storage')
  local Text=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir');local overrides={}
  for k,t in pairs({gText_xVar1='×{STR_VAR_1}',gText_CloseBag='CLOSE BAG',gText_ReturnToVar1='Return to the field.'})do overrides[k]=Text.overrides[k];Text.overrides[k]=IR.fromAscii(t)end
  local ok,err=pcall(Skin.draw,Menu);
  for k in pairs({gText_xVar1=true,gText_CloseBag=true,gText_ReturnToVar1=true})do Text.overrides[k]=overrides[k]end
  T.check(ok,'native bag skin draws source art and six-pocket chrome '..tostring(err or ''))
  Menu.close();T.eq(#Items.BAG_POCKET_ORDER,5,'closing source bag restores vanilla display order')
  Menu.show(s.bag,{session=s,pocket='MEDICINE'});T.eq(#S.bag.pockets,6,'native profile reset cannot mutate source pocket order');T.eq(Menu.currentPocket(),'MEDICINE','second opening retains Medicine');Menu.close()
  local foreign={version='emerald',map='EM_LITTLEROOT_TOWN',bag=Bag.new(),party={}}
  Rt.session=foreign;Menu.show(foreign.bag,{session=foreign});T.eq(#Items.BAG_POCKET_ORDER,5,'foreign bag keeps vanilla pockets');Menu.close()
  Items._byId[potion]=pInfo;Items._byId[repel]=rInfo;Items._byId[meta.item]=berryInfo
  -- Door state advances through all three source frames plus the closed beat.
  Rt.session=s;s.map='EM_HNS_NEW_BARK_TOWN_HNS';local def=maps[s.map];local Doors=require('src.core.game3.doors')
  local x,y
  for _,a in ipairs(def.warps)do local e=Doors.getDoorEntryAt(s.map,a.x,a.y);if e and e.hns then x,y=a.x,a.y;break end end
  T.check(x~=nil,'source New Bark door lookup resolves imported metatile/palette')
  if x then
    local done=0;local a=Doors.open(s.map,x,y,{playSound=false},function()done=done+1 end)
    for t=1,15 do Doors.update();T.eq(done,0,'door callback waits through source frame '..t)end
    T.eq(a.frame,3,'third source door frame is drawn before completion');Doors.update();T.eq(done,1,'door opens after all sixteen source ticks')
    Doors.closeAfterDelay(s.map,x,y,3,{playSound=false},function()done=done+1 end)
    for t=1,18 do Doors.update()end;T.eq(done,1,'delayed close retains callback until delay and source frames finish')
    Doors.update();T.eq(done,2,'native delayed-close signature/callback is retained');T.eq(Doors.isOpen(s.map,x,y),false,'closed source door clears overlay')
  end
  Doors.release()
  local Arrow=require('src.core.game3.warp_arrow');Arrow.show('down',1,2)
  T.eq(Arrow._state.seq[1][1],3,'source down arrow uses Gold frame three')
  for t=1,32 do Arrow.step()end;T.eq(Arrow._state.seq[Arrow._state.step][1],7,'source gold flash advances after thirty-two ticks');Arrow.hide()
  local Collision=require('src.core.game3.collision');s.map='EM_HNS_CHERRYGROVE_CITY_POKEMON_CENTER_HNS'
  Collision.bindMap(game,s.map,maps[s.map]);local exit
  for _,warp in ipairs(maps[s.map].warps)do if Collision.arrowWarpDir(Collision.behavior(warp.x,warp.y))=='down'then exit=warp;break end end
  T.check(exit~=nil,'actual native Center exit resolves an arrow warp')
  if exit then Arrow.update({cellX=exit.x,cellY=exit.y,facing='down'});T.eq(Arrow._state.visible,true,'standing on the exit shows the gold arrow');Arrow.update({cellX=exit.x,cellY=exit.y,facing='up'});T.eq(Arrow._state.visible,false,'turning away hides the exit arrow')end
  local draw=love.graphics.draw;local selected
  love.graphics.draw=function(im,q,x,y)selected={q=q,x=x,y=y}end
  for gender=0,1 do
    s.gender=gender;local info=S.arrow[tostring(gender)];local pixels=T.readAsset(info.file)
    for _,dir in ipairs({'down','up','left','right'})do
      Arrow.hide();Arrow.show(dir,7,9)
      for beat=1,2 do
        selected=nil;Arrow.draw(16,32);T.check(selected~=nil,'visible '..dir..' arrow draws')
        local q=selected.q
        T.check(q.x>=0 and q.y>=0 and q.x+q.w<=info.width and q.y+q.h<=info.height,'arrow quad stays inside the source sheet')
        T.eq(selected.x,96,'arrow retains native camera x');T.eq(selected.y,112,'arrow retains native camera y')
        local opaque=0;for y=q.y,q.y+q.h-1 do for x=q.x,q.x+q.w-1 do if pixels:byte((y*info.width+x)*4+4)>0 then opaque=opaque+1 end end end
        T.check(opaque>0,'both source flash frames contain visible arrow pixels')
        for t=1,32 do Arrow.step()end
      end
    end
  end
  love.graphics.draw=draw;s.gender=0;Arrow.hide()
  -- Real menu animation waits and scrolling transitions.
  local D=game._hnsDex.ui;local Dex=require('src.core.game3.dex');Dex.setCaught(s.dex,152);D.cursor=1;D.show(s.dex,{session=s})
  local function key(k)return {wasPressed=function(_,v)return k==v end}end
  for i=1,16 do D.handleInput(key(nil))end;D.handleInput(key('a'))
  T.eq(D.animation.kind,'portrait','Dex selection begins its source portrait movement')
  for i=1,24 do D.handleInput(key(nil))end;T.eq(D.page,'list','Dex info waits for portrait to reach its source position')
  D.handleInput(key(nil));T.eq(D.page,'info','twenty-fifth movement tick enters info');D.close()
  Stack._layers=layers;Rt.session=saved;Space.store=store
  print('HnS services: source door frames/waits, gold arrows, saved harvest/regrowth/VM, six-pocket bag and Dex transitions')
end
