-- Native VM, collision, movement, bag and save schema; clock UI is a controlled boundary.
return function(T,game,world,maps)
  local Q=world.startup;local W=world.quest
  local Flags=require('src.core.game3.scripting.flags')
  local Space=require('src.core.game3.scripting.space')
  local Rt=require('src.core.game3.runtime')
  local Vm=require('src.core.game3.scripting.vm')
  local Adapters=require('src.core.game3.scripting.adapters')
  local Objects=require('src.core.game3.objects')
  local Player=require('src.core.game3.player')
  local Collision=require('src.core.game3.collision')
  local Bag=require('src.core.game3.bag')
  local Field=require('src.core.game3.field')
  local C=require('src.core.game3.constants').of('emerald')
  local saved={}
  local function preserve(t,keys) for _,k in ipairs(keys) do saved[#saved+1]={t=t,k=k,v=t[k]} end end
  preserve(Rt,{'session','active'});preserve(Space,{'store','vm','mapId','active','_inTransition'})
  preserve(Field,{'running','locked','_session','_game'});preserve(game,{'currentMap','session'})
  preserve(Player,{'cellX','cellY','px','py','targetX','targetY','facing','moving','currentElevation','elevation'})
  preserve(Objects,{'_byId','_order','_tracks','_mapId','_defs','_bounds','_perm','_templateMt'})
  local s,store,seen,clockCalls
  local function reset(mid,x,y)
    s={version='emerald',map=mid,gender=0,name='GENE',party={},bag=Bag.new(),flags={},vars={}}
    store=Flags.newStore();Space.store=store;Rt.session=s;Rt.active=true;game.session=s;game.currentMap=mid
    Field.running=true;Field.locked=true;Field._session=s;Field._game=game
    Collision.bindMap(game,mid,maps[mid]);Objects.reset();Objects.loadMap(game,mid,maps[mid])
    Player.cellX,Player.cellY=x,y;Player.px,Player.py=x*16,y*16;Player.targetX,Player.targetY=x,y;Player.moving=false;Player.facing='down';Player.currentElevation=3
    seen={};clockCalls=0
  end
  local function run(key,reject)
    local a=Adapters.stub({playerName='GENE',onMessage=function(text)seen[#seen+1]=text end})
    a.applyMovement=Objects.applyMovement;a.pollMovement=Objects.pollMovement;a.turnObject=Objects.turnObject
    a.modifyItem=function(op,id,qty)if reject then return false end;return Bag.add(s.bag,id,qty)end
    a.setObjectState=function(op,row)if op=='setobjectxyperm' then Objects.setObjectXY(row.localId,row[2],row[3])end end
    local N=require('src.core.game3.scripting.natives');local clock=N.ALLOW['native:'..Q.clockNative]
    N.ALLOW['native:'..Q.clockNative]=function()clockCalls=clockCalls+1;return false end
    local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,store=store,adapters=a});Space.vm=vm;Space.mapId=s.map;Space.active=true
    T.check(vm:start(key),'startup script starts '..key)
    for tick=1,2400 do require('src.core.game3.audio').update(1/60);Player.tick(game);Objects.update(game);local help=game._hnsGear.presentation.help;if require('src.ui.game3.stack').has(help.ID)then help.handleInput({wasPressed=function(_,k)return k=='a' end})end;if vm:isRunning()then vm:resume()else break end end
    N.ALLOW['native:'..Q.clockNative]=clock
    T.eq(vm:isRunning(),false,'startup script completes '..key);T.eq(vm.ctx.frozen,false,'startup releases '..key);T.eq(#a.logs,0,'startup no skipped opcodes '..key)
  end
  for _,x in ipairs({9,10}) do
    reset(Q.start.map,x,3);Flags.setFlag(store,nil,Q.newGameFlag,true)
    run('HNS_STARTUP_CLOCK'..(x==9 and '1' or '2'))
    T.eq(clockCalls,1,'clock modal requested once');T.eq(Player.cellX,10,'walk to source clock x');T.eq(Player.cellY,2,'walk to source clock y')
    T.eq(Flags.getVar(store,nil,Q.houseState),1,'clock arms Mom');T.eq(Flags.getFlag(store,nil,Q.clockFlag),true,'clock completion persists')
  end
  reset('EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_1F_HNS',10,3);Flags.setFlag(store,nil,Q.newGameFlag,true);Flags.setVar(store,nil,Q.houseState,1)
  run('HNS_STARTUP_HOUSE_INIT');run('HNS_STARTUP_MOM2')
  T.eq(Flags.getFlag(store,nil,C:flag('FLAG_SYS_B_DASH')),true,'Mom grants native running ability')
  T.eq(Flags.getVar(store,nil,Q.houseState),2,'Mom intro completed');T.eq(Objects.find(1).cellX,8,'Mom returns to table')
  for _,row in ipairs(Q.avatars)do
    for _,female in ipairs({false,true})do
      s.gender=female and 1 or 0
      local p={};if row.state=='MACH_BIKE' or row.state=='ACRO_BIKE'then p.biking=true;p.bikeType=row.state=='ACRO_BIKE' and 'acro' or 'mach' elseif row.state=='FIELD_MOVE'then p.fieldMoveAnim=1 elseif row.state=='SURFING'then p.surfing=true elseif row.state=='UNDERWATER'then p.underwater=true elseif row.state=='FISHING'then p.fishing=true elseif row.state=='WATERING'then p.watering=true end
      local Ow=require('src.core.game3.ow_sprites');local id=Ow.playerGraphicsId(game,p)
      T.eq(id,row[female and 'female' or 'male'],'source player graphics '..row.state)
      T.check(Ow.get(id)~=nil,'source avatar loads '..id)
    end
  end
  local lab='EM_HNS_NEW_BARK_TOWN_LAB_HNS'
  for _,balls in ipairs({false,true})do
    for _,reject in ipairs({false,true})do
      reset(lab,6,12);Flags.setFlag(store,nil,world.opening.flags.received,true)
      if balls then Flags.setFlag(store,nil,W.flags.eggDelivered,true)end
      run('HNS_STARTUP_AIDE_CHECK',reject)
      local item=C:require('items',balls and 'ITEM_POKE_BALL' or 'ITEM_POTION')
      T.eq(Bag.get(s.bag,item),reject and 0 or balls and 5 or 1,'automatic aide gift inventory')
      T.eq(Objects.find(1).cellX,3,'aide returns x even on bag full');T.eq(Objects.find(1).cellY,10,'aide returns y')
      if not reject then run('HNS_STARTUP_AIDE_CHECK');T.eq(Bag.get(s.bag,item),balls and 5 or 1,'aide gift does not duplicate')end
    end
  end
  reset(Q.start.map,9,4)
  local Schema=require('src.core.game3.save_schema_firered')
  local Sections=require('src.core.game3.save_sections');local sectionNew=Sections.newGame
  Sections.newGame=function()end -- imported Easy Chat/Hoenn services are absent in this ROM-free fixture
  local fresh=Schema.newGame({version='emerald',start=Q.start,name='GENE',runScript=function()end})
  Sections.newGame=sectionNew
  require('src.mods.Runtime').emit('save.created',{save=fresh})
  T.eq(Bag.get(fresh.bag,Q.gbItem),1,'new game starts with GB SOUNDS')
  T.eq(Bag.get(fresh.bag,Q.expItem),1,'new game starts with key-item EXP SHARE')
  T.eq(fresh.flags[C:flag('FLAG_SYS_B_DASH')],nil,'new game waits for shoes')
  local Mapsec=require('src.ui.game3.rse.mapsec')
  for mid,m in pairs(maps) do T.eq(Mapsec.name(m.regionMapSectionId),m.hnsAreaName,'source banner name '..mid)end
  local Speech=require('src.ui.game3.boot_modules').load('hns.oak_speech')
  T.check(Speech.TASKS.HnsSettings~=nil,'actual boot module exposes HnS settings')
  local Kit=require('src.ui.game3.rse.scene_kit');local originalManifest=Kit.manifest
  Kit.manifest=function(key)if key=='birch'then return {pics={birch={},lotad={frames=2,species=270},brendan={},may={}},layers={bg={initialState=8}},presetNames={male={'BRENDAN'},female={'MAY'}}}end;return originalManifest(key)end
  local born=Speech.new({textSpeed=2})
  Kit.manifest=originalManifest
  T.eq(born.lotadSpecies,194,'Oak presents Wooper')
  T.eq(born.man.presetNames.male[1],'GOLD','HnS male default name')
  T.eq(born.man.presetNames.female[1],'KRIS','HnS female default name')
  T.check(born.sprites.birch.img~=nil and born.sprites.brendan.img~=nil and born.sprites.may.img~=nil and born.sprites.lotad.img~=nil,'startup constructor loads source pictures')
  local release=born:createReleaseBall(born.sprites.lotad,100,75,0)
  T.check(release.img~=nil,'Oak release animation uses bundled source ball art')
  born.printer=nil;born.tasks={};born.main={func='ThisIsAPokemon'}
  local empty={new={},held={}}
  Speech.TASKS.ThisIsAPokemon(born,born.main,empty)
  for tick=1,180 do born:printersActive(empty);if born.startedBallTask then break end end
  T.eq(born.startedBallTask,true,'source PAUSE control starts the actual Wooper release task')
  T.check(#born.tasks>0,'Wooper reveal schedules native ball task')
  Speech.Sub_InitPokeBall(born,born.tasks[1]);for tick=1,48 do born:spriteCallbacks()end
  T.eq(born.sprites.lotad.invisible,false,'release reveals the source Wooper sprite after the ball opens')
  for _,gender in ipairs({0,1}) do
    local Settings=game._hnsGear.settings
    local intro=setmetatable({pal=require('src.core.game3.pal_fade').new(),events={},frames=0,hnsMenu=Settings.new('challenge'),gender=gender,main={},hnsConfig={speech=Q.speech},hnsOptions={textSpeed=2,battleScene=0,battleStyle=0,sound=0},textSpeed=1,textSpeedOption=2,playerName='GENE'},Speech)
    T.eq(#intro.hnsMenu.pages,6,'all source challenge pages are present')
    Speech.TASKS.HnsSettings(intro,intro.main,{new={right=true}})
    T.eq(intro.hnsMenu.values.ITEM_MODE_GAMEMODE,1,'settings cycle source recommended/custom')
    Speech.TASKS.HnsSettings(intro,intro.main,{new={start=true}})
    T.eq(intro.hnsMenu.confirm,true,'Start opens source confirmation')
    Speech.TASKS.HnsSettings(intro,intro.main,{new={a=true}})
    T.eq(intro.main.func,'HnsChallengeDone','settings confirm after naming')
    intro:print('gText_Birch_Welcome')
    T.check(intro.printer~=nil,'Oak source welcome constructs native printer')
    Speech.TASKS.Cleanup(intro,intro.main)
    T.eq(intro.result.gender,gender,'Oak intro preserves gender')
    T.eq(intro.result.hnsChoices.ITEM_MODE_GAMEMODE,1,'Oak intro passes source choices to new game')
  end
  local town='EM_HNS_NEW_BARK_TOWN_HNS'
  reset(town,0,13);run('HNS_FIDELITY_TOWN_INIT');run('HNS_FIDELITY_BLOCK_EXIT')
  T.eq(Player.cellX,1,'town blocker steps player back from border')
  T.eq(Objects.find(2).cellX,0,'source Lass occupies border before starter')
  T.check(Objects.find(3)~=nil,'Silver exists at lab window at game start')
  Flags.setFlag(store,nil,world.opening.flags.received,true);run('HNS_FIDELITY_TOWN_INIT')
  T.eq(Objects.find(2).cellX,9,'town Lass returns after starter')
  reset(lab,6,8);Flags.setFlag(store,nil,world.opening.flags.received,true);Flags.setFlag(store,nil,world.opening.flags.elmReady,true)
  run('HNS_SCENE_LAB_INIT');run('HNS_FIDELITY_ELM_WAIT')
  T.eq(Player.cellY,7,'Elm stops departing player and steps them back')
  T.eq(Flags.getFlag(store,nil,Q.elmPhoneFlag),false,'exit interruption releases player without registering Elm')
  T.eq(Objects.find(2).cellX,6,'Elm waits at initial mark for manual interaction')
  run('HNS_OPENING_ELM_AFTER')
  T.eq(Flags.getFlag(store,nil,Q.elmPhoneFlag),true,'Elm registers persistent phone contact')
  T.eq(Flags.getVar(store,nil,Q.elmPendingVar),0,'Elm exit interruption disarms after registration')
  T.eq(Objects.find(2).cellX,3,'Elm returns to computer after directions')
  T.eq(Objects.find(2).cellY,2,'Elm returns to source computer y')
  T.check(table.concat(seen,'\n'):find('POKéGEAR',1,true)~=nil,'Elm number receipt appears')
  T.eq(Flags.getFlag(store,nil,Q.gearFlag),false,'Elm does not grant a second gear')
  for i=#saved,1,-1 do local v=saved[i];v.t[v.k]=v.v end
  print('Startup regressions: bedroom/clock/Mom, both avatars and states, automatic aide gifts and full bags, starting inventory, area names')
end
