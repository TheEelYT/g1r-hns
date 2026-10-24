-- Real slot duplication/read/write and native item/party/schema paths.
return function(T,game,w)
  local Save=require('src.core.SaveData');local Codec=require('src.core.SaveSerializer')
  local Rt=require('src.core.game3.runtime');local Stack=require('src.ui.game3.stack')
  local Bag=require('src.core.game3.bag');local P=require('src.core.game3.pokemon')
  local Rng=require('src.core.game3.rng');local Schema=require('src.core.game3.save_schema_firered')
  local Rows=require('src.ui.game3.option_rows');local Options=require('src.core.game3.options')
  local Space=require('src.core.game3.scripting.space');local Warp=require('src.core.game3.warp')
  local Player=require('src.core.game3.player');local Battle=require('src.core.game3.battle')
  local L=game._hnsPractice.lab
  local practiceSession
  local saved={fs=love.filesystem,portable=Save.portableFs,cart=Save.getCart(),hash=Save.getCartHash(),session=Rt.session,layers=Stack._layers,store=Space.store,
    gameSession=game.session,options=game.options,warp=Warp.request,busy=Warp._busy,active=Battle._active,rng=Rng.getState(),surf=Player.surfing,underwater=Player.underwater,bike=Player.biking}
  Save.portableFs=function()return nil end
  Space.store=nil;Stack._layers={};Warp._busy=false;Battle._active=false;Player.surfing=false;Player.underwater=false;Player.biking=false
  local function key(k)return{wasPressed=function(_,n)return n==k end}end
  local source={engine='game3',generation=3,version='emerald',name='GENE',trainerId=12345,secretId=54321,
    map=w.startup.start.map,x=5,y=6,facing='up',flags={[123]=true},vars={[777]=19},party={{species=158,hp=7}},
    bag=Bag.new(),meta={playthroughId='original',cartHash='cafe'},modData={},dex={seen={},owned={},caught={}}}
  local machine=assert(game._hnsTeaching.teaching.byName.TM_DRAIN_PUNCH)
  for _,cart in ipairs({false,'pokemon_heart_soul'})do
    local files={};local failWrites=false
    local function diritems(path)
      local out,seen={},{};local prefix=path==''and ''or path..'/'
      for name in pairs(files)do if name:sub(1,#prefix)==prefix then local child=name:sub(#prefix+1):match('^[^/]+');if child and not seen[child]then out[#out+1]=child;seen[child]=true end end end
      table.sort(out);return out
    end
    love.filesystem={read=function(p)return files[p]end,write=function(p,b)
      if failWrites and p:find('slot2',1,true)and b:find('hnsPractice',1,true)then return false,'fixture disk full'end
      files[p]=b;return true end,
      remove=function(p)files[p]=nil;return true end,createDirectory=function()return true end,
      getDirectoryItems=diritems,getInfo=function(p)if files[p]then return{type='file'}end;if #diritems(p)>0 then return{type='directory'}end end}
    Save.resetSlotState();Save.setCart(cart or nil,cart and 'cafe'or nil)
    local create=cart and Save.createCartSlot or Save.createSlot
    local write=cart and Save.writeCartSlot or Save.writeSlot
    local active=cart and Save.activeCartSlot or Save.activeSlot
    local set=cart and Save.setActiveCartSlot or Save.setActiveSlot
    local scope=cart or 'emerald';local slot=create(scope);write(scope,slot,source);set(scope,slot)
    local prefix='saves/'..(cart and 'cart_'..cart or 'emerald')..'/'
    local original=files[prefix..slot..'.lua']
    local live=assert(Codec.decode(original));live.x=99 -- unsaved changes must not leak into the last-saved copy.
    Rt.session=live;game.session=live;game.options={};Options.bind(live,game.options)
    local before=Codec.encode(live);local rng=Codec.encode(Rng.getState())
    local rows=Rows.build({session=live,game=game,options=game.options});local entry,count
    count=0;for _,r in ipairs(rows)do if r.id=='hns.practice'then entry=r;count=count+1 end end
    T.eq(count,1,'practice tools are reachable through actual native option descriptors')
    entry.activate({game=game});T.check(L.isOpen(),'native option opens practice modal')
    L.handleInput(key('a'));T.eq(L.confirm,true,'create requires a concrete confirmation')
    T.eq(L.yes,false,'confirmation defaults to No');L.handleInput(key('a'))
    T.eq(files[prefix..'slot2.lua'],nil,'default No creates no slot')
    L.handleInput(key('a'));L.handleInput(key('right'));L.handleInput(key('a'))
    T.check(L.message and L.message:find('Created HnS PRACTICE',1,true),'confirmed native input creates practice copy')
    local copied=assert(Codec.decode(assert(files[prefix..'slot2.lua'])))
    T.eq(copied.x,5,'practice uses last saved position, not unsaved live position')
    T.eq(copied.meta.hnsPractice.origin.x,5,'copy retains return location')
    T.check(copied.meta.playthroughId~='original','native duplicate creates independent playthrough identity')
    T.eq(copied.vars[777],19,'copied story variables preserved')
    T.eq(copied.flags[123],true,'copied story flags preserved')
    T.eq(#copied.party,2,'practice copy has two supplied followers')
    T.eq(P.speciesOf(copied.party[1]),62,'practice supplies Poliwrath')
    T.eq(P.isShiny(copied.party[1]),false,'NORMAL practice follower is normal')
    T.eq(P.isShiny(copied.party[2]),true,'SHINY practice follower is shiny')
    T.eq(#copied.party[1].moves,1,'normal preset can test immediate learning')
    T.eq(#copied.party[2].moves,4,'shiny preset can test replacement/cancellation')
    T.eq(Bag.get(copied.bag,machine.itemId),9,'practice kit supplies 9 Drain Punch TMs')
    T.eq(files[prefix..slot..'.lua'],original,'original save bytes remain untouched')
    T.eq(active(scope),slot,'current slot remains selected')
    T.eq(Codec.encode(live),before,'live party/bag/flags/position unchanged')
    T.eq(Codec.encode(Rng.getState()),rng,'practice generation preserves all live RNG streams')
    T.eq(Bag.get(live.bag,machine.itemId),0,'main save receives no test supplies')
    local session=Schema.fromSaveTable(copied);T.check(L.isPractice(session),'marker survives actual native schema load')
    practiceSession=session
    local round=Schema.toSaveTable(session);T.check(L.isPractice(round),'marker survives native schema save')
    Rt.session=session;game.session=session
    local escaped,why=L.travel(live,w.practice.destinations[1].id)
    T.eq(escaped,nil,'ordinary save cannot use practice shortcuts')
    T.check(why~=nil,'blocked shortcut explains practice restriction')
    L.show({session=session});L.rows()[1].action()
    T.eq(Bag.get(session.bag,machine.itemId),9,'practice refill sets supplied count')
    L.message=nil;L.rows()[2].action();T.eq(session.party[1].nickname,'SHINY','swap selects shiny without editing original party')
    L.message=nil
    -- Capture only the boundary into the genuine native warp sequencer; map
    -- loading and returned coordinates are checked separately below/source audit.
    local captured
    Warp.request=function(_,g,map,x,y,facing,opts)captured={map=map,x=x,y=y,facing=facing,opts=opts};return true end
    T.eq(L.travel(session,w.practice.destinations[1].id),true,'practice shortcut dispatches native warp')
    local d=w.practice.destinations[1];T.eq(captured.map,d.map,'shortcut exact map');T.eq(captured.x,d.x,'shortcut exact x');T.eq(captured.y,d.y,'shortcut exact y')
    T.eq(L.isOpen(),false,'shortcut closes its modal before field handoff')
    T.eq(L.travel(session,'return'),true,'practice return dispatches native warp')
    T.eq(captured.map,source.map,'return uses copied source map');T.eq(captured.x,source.x,'return uses copied saved x')
    T.eq(captured.y,source.y,'return uses copied saved y')
    Warp.request=saved.warp
    -- Test write failure after successful native duplication: only the new
    -- temporary slot is removed; the original slot and bytes survive.
    if cart then Save.deleteCartSlot(scope,'slot2')else Save.deleteSlot(scope,'slot2')end
    Rt.session=live;game.session=live;failWrites=true
    local id,err=L.create(live)
    T.eq(id,nil,'failed practice write is reported');T.check(err~=nil,'write failure includes explanation')
    T.eq(files[prefix..'slot2.lua'],nil,'failed practice creation rolls back only allocated copy')
    T.eq(files[prefix..slot..'.lua'],original,'failed practice write preserves original file')
    T.eq(active(scope),slot,'failed practice creation preserves selected slot')
    failWrites=false
    L.close()
  end
  Rt.session={map='EM_ROUTE101'};game.session=Rt.session
  local rows=Rows.build({game=game,session=Rt.session,options=game.options})
  local found=false;for _,r in ipairs(rows)do if r.id=='hns.practice'then found=true end end
  T.eq(found,false,'practice option absent from vanilla sessions')
  T.eq(L.show({session=Rt.session}),false,'vanilla cannot open practice tools')
  -- Exercise real native map loading/arrival/position synchronisation. Only
  -- the fade and sound are disabled at the warp boundary in headless tests.
  local Collision=require('src.core.game3.collision');local MB=require('src.core.game3.mb')
  Rt.session=practiceSession;Rt.active=true;Rt._game=game;game.session=practiceSession
  Warp.request=function(mod,g,map,x,y,facing,opts)opts.fade=false;opts.se=false;return saved.warp(mod,g,map,x,y,facing,opts)end
  for _,d in ipairs(w.practice.destinations)do
    local ok,err=L.travel(practiceSession,d.id)
    T.check(ok,'real native practice map load: '..d.id..' '..tostring(err))
    T.eq(practiceSession.map,d.map,'native arrival synchronises practice map')
    T.eq(practiceSession.x,d.x,'native arrival synchronises practice x')
    T.eq(practiceSession.y,d.y,'native arrival synchronises practice y')
    T.eq(Warp.isBusy(),false,'native practice warp releases field lock')
    for dx=-2,2 do
      T.eq(Collision.isWalkable(d.x+dx,d.y),true,'native collision permits walking across '..d.id)
      T.eq(Collision.elevationAt(d.x+dx,d.y),d.elevation,'native practice strip elevation '..d.id)
      T.eq(Collision.behavior(d.x+dx,d.y),MB.require(d.behavior:sub(4)),'native practice strip behavior '..d.id)
    end
  end
  local ok,err=L.travel(practiceSession,'return');T.check(ok,'actual native return loads copied point '..tostring(err))
  T.eq(practiceSession.map,source.map,'actual return map');T.eq(practiceSession.x,source.x,'actual return x');T.eq(practiceSession.y,source.y,'actual return y')
  require('src.ui.game3.message').reset();require('src.core.game3.task').clear()
  love.filesystem=saved.fs;Save.resetSlotState();Save.portableFs=saved.portable;Save.setCart(saved.cart,saved.hash)
  Rt.session=saved.session;Stack._layers=saved.layers;Space.store=saved.store;game.session=saved.gameSession;game.options=saved.options
  Warp.request=saved.warp;Warp._busy=saved.busy;Battle._active=saved.active;Rng.setState(saved.rng)
  Player.surfing=saved.surf;Player.underwater=saved.underwater;Player.biking=saved.bike
  print('Practice tools: native cart/manual save copies, isolation, identity, failure rollback, option/input dispatch, supplied party/TMs and return shortcuts')
end
