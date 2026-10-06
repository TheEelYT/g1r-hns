-- Real engine behavior for the 0.7.3 expansion. Only unavailable ROM text
-- and the escape effect's graphical handoff are replaced by fixtures.
return function(T,game,w,maps)
  local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags');local P=require('src.core.game3.player')
  local O=require('src.core.game3.objects');local Pokemon=require('src.core.game3.pokemon')
  local State=require('src.core.game3.battle.state');local Engine=require('src.core.game3.battle.engine')
  local Adapter=require('src.core.game3.battle.adapter');local Moves=require('src.core.game3.battle.moves')
  local E=require('src.core.game3.battle.effect_ids');local Rules=require('src.core.game3.battle.rules')
  local C=require('src.core.game3.constants').of('emerald');local Rtc=require('src.core.game3.rtc')
  local Bag=require('src.core.game3.bag');local ItemUse=require('src.core.game3.item_use')
  local Warp=require('src.core.game3.warp');local Map=require('src.core.game3.map')
  local Msg=require('src.ui.game3.message');local Ui=require('src.core.game3.battle.ui')
  local B=require('src.core.game3.battle');local Intro=require('src.core.game3.battle.intro_seq')
  local IR=require('src.core.game3.scripting.text_ir');local Text=require('src.core.game3.rom_text')
  local Writer=require('src.import.LuaWriter');local Enc=require('src.core.game3.encounters')
  local H=game._hnsRules.rules;local Time=game._hnsTime.time;local F=game._hnsFollower.follower
  local V=game._hnsBattleVisuals.visuals;local S=game._hnsBattleSettings.settings
  local saved={};local function keep(t,keys)for _,key in ipairs(keys)do saved[#saved+1]={t=t,k=key,v=t[key]}end end
  keep(Rt,{'session','active','_game'});keep(Space,{'store','active','vm','mapId'});keep(game,{'session','currentMap','phase','boot','input'})
  keep(B,{'_st','_adapter','_phase','_pendingEnd'});keep(Map,{'current'});keep(Warp,{'_pending','_busy','startEscapeRope'})
  keep(ItemUse,{'setUpOnFieldCallback'});keep(Msg,{'show'});keep(Enc,{'_tables'})
  Enc._tables={};for k,v in pairs(saved[#saved].v or {})do Enc._tables[k]=v end
  local s={version='emerald',map='EM_HNS_ROUTE29_HNS',name='GENE',party={},bag=Bag.new(),flags={},vars={}}
  Rt.active=true;Rt.session=s;Rt._game=game;game.session=s;game.currentMap=s.map;game.phase='field'
  Space.store=Flags.newStore();Flags.setFlag(Space.store,nil,w.startup.settings.initializedFlag,true)
  local rows={};for _,page in ipairs(w.startup.settings.pages)do for _,r in ipairs(page.rows)do rows[r.id]=r;Flags.setVar(Space.store,nil,r.var,r.default)end end
  local function setting(name,v)Flags.setVar(Space.store,nil,assert(rows[name],name).var,v)end
  local fixtures={sText_WildPkmnAppeared='A wild Pokémon appeared!',sText_GoPkmn='Go Pokémon!',sText_ExclamationMark='!',sText_WildPkmnPrefix='Wild ',sText_FoePkmnPrefix='Foe ',STRINGID_SUPEREFFECTIVE='Super effective!',sText_SuperEffective='Super effective!',STRINGID_NOTVERYEFFECTIVE='Not very effective.',sText_NotVeryEffective='Not very effective.',sText_CriticalHit='A critical hit!',sText_AttackerUsedX='{B_ATK_NAME_WITH_PREFIX} used {B_BUFF2}',
    STRINGID_PKMNWASPARALYZED='The Pokémon is paralyzed!',STRINGID_BUTNOTHINGHAPPENED='But nothing happened!',
    gText_PlayerUsedVar2='{PLAYER} used the {STR_VAR_2}.',gText_DadsAdvice='This is not the time.',gText_CantUseHere='Cannot use that here.',
    STRINGID_PKMNWASFROZEN='The Pokémon is frozen!',STRINGID_PKMNENERGYDRAINED='Energy drained!',STRINGID_PKMNREGAINEDHEALTH='Health regained!',STRINGID_GOTAWAYSAFELY='Got away safely!',STRINGID_CANTESCAPE="Can't escape!",STRINGID_CANTESCAPE2="Can't escape!"}
  for key,text in pairs(fixtures)do keep(Text.overrides,{key});Text.overrides[key]=IR.fromAscii(text)end
  keep(Moves._rom,{86,150});keep(Pokemon._moveNames,{86,150})
  Moves._rom[86]={effect=E.PARALYZE,power=0,type=13,accuracy=100,pp=20,target=0,flags=0}
  Moves._rom[150]={effect=E.SPLASH,power=0,type=0,accuracy=0,pp=40,target=0,flags=0}
  Pokemon._moveNames[86]='THUNDER WAVE';Pokemon._moveNames[150]='SPLASH'
  local function mon(sp)
    return {species=sp or 158,nickname='MON',level=20,hp=100,maxHp=100,attack=60,defense=60,spAtk=60,spDef=60,speed=80,
      ability=0,otId=12345,otName='GENE',personality=8,moves={86,150},pp={20,40},ivs={},evs={}}
  end
  local p,e=mon(),mon(19);s.party={p}
  local st=State.new({session=s,wild=true,playerParty=s.party,foeParty={e}});st.session=s;st.rng=function(lo,hi)if hi==100 then return 1 end;return hi end
  local ad=Adapter.new(st);st.player.type1=0;st.player.type2=0;st.enemy.type1=0;st.enemy.type2=0
  Engine.resolveMove(st.player,st.enemy,86,1,ad,st,{})
  T.eq(st.enemy.mon.status,'PAR','real Thunder Wave inflicts persistent paralysis')
  T.eq(Engine.speedOf(st.enemy,st,ad),20,'paralysis quarters speed under HnS source Gen 3 configuration')
  for turn=1,5 do
    Engine.clearTurnFlags(st.player);Engine.clearTurnFlags(st.enemy);Engine.resolveMove(st.enemy,st.player,150,2,ad,st,{})
    Engine.collectResidualEvents(st,ad);T.eq(st.enemy.mon.status,'PAR','paralysis survives end of turn '..turn)
  end
  State.syncBattlerToParty(st.enemy,{e});local reloaded=assert(load(Writer.encode(e)))()
  T.eq(reloaded.status,'PAR','paralysis persists through save serialization')
  ad:clearStatus(st.enemy);T.eq(st.enemy.mon.status,nil,'native cure clears persistent paralysis')
  local legacy=mon();legacy.status=64;legacy.status1=64
  local migrated=State.makeBattler(legacy,'player',{st=st});T.eq(legacy.status,'PAR','GBA numeric status migrates');T.eq(legacy.status1,nil,'stale legacy bitfield removed')
  ad:clearStatus(migrated);State.makeBattler(legacy,'player',{st=st});T.eq(legacy.status,nil,'cured legacy paralysis does not return')
  local bd=Pokemon.stats(158);T.eq(bd.hp,50,'Totodile source base HP');T.eq(bd.atk,65,'Totodile source base Attack')
  if game._hnsExpandedMoves then
    local X=game._hnsExpandedMoves.moves
    local ice=assert(X.id('ICE_FANG'));local drain=assert(X.id('DRAIN_PUNCH'));local tail=assert(X.id('AQUA_TAIL'))
    setting('ITEM_MODE_MODERN_MOVES',1);setting('ITEM_MODE_SPLIT',1)
    T.eq(Moves.get(ice).power,65,'expanded Ice Fang uses source power');T.eq(Moves.get(drain).category,'physical','Drain Punch uses source physical category')
    T.eq(Pokemon.movePp(tail),10,'expanded moves give correct PP');T.eq(Pokemon.moveName(ice),'ICE FANG','expanded names work in native menus')
    local learnt=Pokemon.learnset(158);local found=false;for _,entry in ipairs(learnt)do if entry[2]==ice then found=true end end
    T.check(found,'Modern Moves uses source Totodile Ice Fang learnset')
    setting('ITEM_MODE_MODERN_MOVES',0);local legacy=Pokemon.learnset(158);found=false;for _,entry in ipairs(legacy)do if entry[2]==ice then found=true end end
    T.eq(found,false,'classic source learnset excludes later Ice Fang');setting('ITEM_MODE_MODERN_MOVES',1)
    st.player.mon.moves={drain,tail,ice};st.player.mon.pp={10,10,15};st.player.mon.hp=50;st.enemy.mon.hp=100;st.enemy.mon.status=nil;st.enemy.status=nil
    Engine.resolveMove(st.player,st.enemy,drain,1,ad,st,{})
    T.check(st.enemy.mon.hp<100,'real Drain Punch deals damage');T.check(st.player.mon.hp>50,'real Drain Punch absorbs HP')
    st.enemy.mon.hp=100;st.enemy.mon.status=nil;st.enemy.status=nil;st.enemy.expMovedThisTurn=nil
    local M=Engine.newContext(st.player,st.enemy,ice,3,ad,st,{},{hits={}},{});M.move=Moves.get(ice)
    local Secondary=require('src.core.game3.battle.effects.secondary');local roll=ad.roll
    ad.roll=function()return 10 end;Secondary.withChance(M,'HNS_ADDITIONAL_LIST');T.eq(st.enemy.mon.status,nil,'source 10 percent effect excludes roll 10');T.eq(st.enemy.flinched,nil,'independent flinch chance excludes roll 10')
    ad.roll=function()return 9 end;Secondary.withChance(M,'HNS_ADDITIONAL_LIST');T.eq(st.enemy.mon.status,'FRZ','source Ice Fang freeze chance includes roll 9');T.eq(st.enemy.flinched,true,'source Ice Fang rolls flinch independently')
    ad.roll=roll
  end
  -- Record escape entry using native Warp.request, then retain it across stairs.
  Map.current='EM_HNS_VIOLET_CITY_HNS';P.facing='up';Warp._busy=false
  Warp.request(nil,game,'EM_HNS_SPROUT_TOWER_1F_HNS',8,14,'up',{doorX=19,doorY=6})
  T.eq(s.escapeWarp.map,'EM_HNS_VIOLET_CITY_HNS','native tower entry saves escape destination')
  local entrance=s.escapeWarp;Warp._busy=false;Map.current='EM_HNS_SPROUT_TOWER_1F_HNS'
  Warp.request(nil,game,'EM_HNS_SPROUT_TOWER_2F_HNS',4,4,'up',{})
  T.eq(s.escapeWarp,entrance,'internal tower stairs retain outdoor escape destination')
  local escaped;Warp.startEscapeRope=function(_,map,x,y)escaped={map,x,y}end
  ItemUse.setUpOnFieldCallback=function(fn)fn();return true end;Msg.show=function(_,opts)opts.done()end
  local rope=C:require('items','ITEM_ESCAPE_ROPE')
  for _,floor in ipairs({'1F','2F','3F'})do
    s.map='EM_HNS_SPROUT_TOWER_'..floor..'_HNS';Bag.add(s.bag,rope,1)
    T.eq(maps[s.map].allowEscaping,1,'source escape flag on '..floor)
    T.eq(ItemUse.useEscapeRope(s,s.bag,rope),true,'native Escape Rope works on tower '..floor)
    T.eq(Bag.get(s.bag,rope),0,'successful rope consumes one on '..floor)
    T.eq(escaped[1],entrance.map,'rope returns to saved entrance '..floor)
  end
  setting('ITEM_DIFFICULTY_ESCAPE_ROPE_DIG',1);Bag.add(s.bag,rope,1)
  T.eq(ItemUse.useEscapeRope(s,s.bag,rope),false,'source difficulty option prevents Escape Rope');T.eq(Bag.get(s.bag,rope),1,'forbidden rope not consumed')
  setting('ITEM_DIFFICULTY_ESCAPE_ROPE_DIG',0)
  setting('ITEM_DIFFICULTY_LESS_ESCAPES',1)
  local rng=ad.rng;ad.rng=function()return function()return 0 end end
  st.player.mon.speed=200;st.enemy.mon.speed=100;st.fleeAttempts=0
  T.eq(Engine.tryFlee(st,ad,st.player),false,'Less Escapes preserves source byte wrap at 256')
  st.player.mon.speed=80;st.fleeAttempts=0;T.eq(Engine.tryFlee(st,ad,st.player),true,'Less Escapes succeeds with zero source threshold')
  ad.rng=function()return function()return 512 end end;st.fleeAttempts=0
  T.eq(Engine.tryFlee(st,ad,st.player),false,'Less Escapes fails with source threshold 512')
  ad.rng=rng;setting('ITEM_DIFFICULTY_LESS_ESCAPES',0)
  s.map='EM_HNS_ROUTE29_HNS';setting('ITEM_FEATURES_RTC_TYPE',1)
  Rtc.calcLocalTimeOffset(s,0,18,59,0);for i=1,150 do Time.tick(s,1/60)end
  T.eq(Time.save(s).seconds,18*3600+59*60+48,'Fake RTC advances 24 game seconds per played second')
  T.eq(Time.period(Rtc.calcLocalTime(s)),'Evening','encounter evening before 19:00')
  for i=1,30 do Time.tick(s,1/60)end;T.eq(Time.period(Rtc.calcLocalTime(s)),'Night','night encounters begin at 19:00')
  T.eq(Flags.getFlag(Space.store,nil,w.fieldPokemon.flags.dayHidden),true,'day Pokémon hidden at night')
  T.eq(Flags.getFlag(Space.store,nil,w.fieldPokemon.flags.nightHidden),false,'night Pokémon visible at night')
  local persisted=Flags.serialize(Space.store);s.flags=persisted.flags;s.vars=persisted.vars
  local copy=assert(load(Writer.encode(s)))();T.eq(Rtc.calcLocalTime(copy).hours,19,'Fake RTC serialized time used on reload')
  for mid,pools in pairs(w.encounters.timed)do
    local expected=pools.Night or pools.Day;local actual=Enc._tables[mid]
    for kind,area in pairs(expected)do
      T.eq(actual[kind].rate,area.rate,'timed native encounter rate '..mid..kind)
      for i,entry in ipairs(area.slots)do
        T.eq(actual[kind].slots[i].species,C:require('species','SPECIES_'..entry.species),'timed species resolves to native ID '..mid..kind..i)
      end
    end
  end
  -- Exercise the real RSE grass-step path, not merely its table assignment.
  local Rng=require('src.core.game3.rng');Rng.SeedRng(12345)
  local MB=require('src.core.game3.mb');local behavior=MB.require('TALL_GRASS')
  for _,hour in ipairs({7,12,18,21})do
    Rtc.calcLocalTimeOffset(s,0,hour,0,0);Time.tick(s,0)
    local pool=Enc.tableFor(s.map).land;local encounters=0
    for i=1,1000 do
      local enc=Enc.onStep(s.map,'land',{behavior=behavior,x=9,y=8})
      if enc then
        encounters=encounters+1;T.check(type(enc.species)=='number','native grass step produces numeric species')
        local found=false;for _,entry in ipairs(pool.slots)do
          if enc.species==entry.species and enc.level>=entry.minLevel and enc.level<=entry.maxLevel then found=true end
        end
        T.check(found,'actual wild encounter belongs to current source time pool')
      end
    end
    T.check(encounters>0,'wild battles roll in source grass at hour '..hour)
  end
  -- Palette channel arithmetic is checked against the C oracle separately.
  local a,b,weight=Time.blend({hours=7,minutes=0});T.eq(weight,128,'source halfway morning fade')
  T.eq(Time.channel(31,a[1],b[1],weight),20,'source integer 5-bit channel blend')
  local fixtureMod={hooks={wrap=function()end},read=function(_,file)
    local f=assert(io.open(arg[1]..'/'..file,'rb'));local text=f:read('*a');f:close();return text
  end}
  dofile((arg[0]:match('^(.*)[/\\]')or'.')..'/test_render_regressions.lua')(T,fixtureMod,w,game,s)
  setting('ITEM_MAIN_FOLLOWER',0);setting('ITEM_MAIN_LARGE_FOLLOWER',1)
  local faint=mon(152);faint.hp=0;local egg=mon(175);egg.isEgg=true;local lead=mon(158);s.party={faint,egg,lead}
  T.eq(F.lead(s),lead,'follower chooses first healthy non-egg')
  O.loadMap(game,s.map,maps[s.map]);P.reset(9,8,'left');F.actor=nil;F.refresh();T.eq(F.actor.visible,false,'new follower waits for player step')
  F.step(9,8,16);for i=1,16 do F.tick()end;F.step(8,8,16);for i=1,16 do F.tick()end
  T.eq(F.actor.cellX,8,'follower reaches previous player cell');T.eq(F.actor.facing,'left','follower faces movement')
  T.eq(O.walkPhase(F.actor),0,'native follower walking animation accepts actor state')
  T.eq(O.at(8,8),F.actor,'native talk query finds follower');T.eq(O.blocks(8,8),false,'follower does not block player path')
  local found=false;for _,actor in ipairs(O.forDraw())do if actor==F.actor then found=true end end;T.check(found,'native renderer gets follower')
  local Coll=require('src.core.game3.collision');Coll.bindMap(game,s.map,maps[s.map]);T.check(pcall(require('src.core.game3.field_view').draw,game),'actual field draws follower')
  T.check(F.message(lead):find('MON',1,true)~=nil,'source follower message uses nickname')
  lead.nickname='';T.check(F.message(lead):find(Pokemon.name(158),1,true)~=nil,'unnicknamed follower shows species name');lead.nickname='MON'
  local Field=require('src.core.game3.field');local Hud=require('src.ui.game3.hud');local ModRt=require('src.mods.Runtime')
  keep(Hud,{'openMessage'});local said;Hud.openMessage=function(_,text,opts)said=text;opts.done()end
  ModRt.call('world.talk',function()error('follower talk fell through')end,game,F.actor)
  T.eq(said,nil,'follower dialogue waits for source emote');T.check(Field._locks.hnsFollowerTalk,'follower interaction locks movement')
  local actors={};require('src.core.game3.field_effects').collectActors(actors)
  local bubble;for _,a in ipairs(actors)do if a.i==92000 then bubble=a end end
  T.check(bubble,'source emote is in native sorted actor pass');T.check(pcall(bubble.draw,bubble,0,0),'source emote draws before message')
  for i=1,85 do F.tick()end
  T.check(said:find('MON',1,true)~=nil,'named dialogue opens after complete emote');T.eq(Field._locks.hnsFollowerTalk,nil,'closing follower dialog releases lock')
  F.beginBall('enter');T.eq(F.ballPose(),'mon','source recall starts with normal follower')
  for i=1,5 do F.tick()end;T.eq(F.ballPose(),'white','source recall whitens at remaining frame 11')
  for i=1,4 do F.tick()end;T.eq(F.ballPose(),'ball','source recall switches to ball at frame 7')
  for i=1,7 do F.tick()end;T.eq(F.actor.visible,false,'completed recall hides follower')
  F.step(8,8,16);T.eq(F.ballPose(),'ball','first step releases follower from ball')
  for i=1,9 do F.tick()end;T.eq(F.ballPose(),'white','source release grows white follower')
  for i=1,7 do F.tick()end;T.eq(F.transition,nil,'source release restores palette and actor')
  -- Native door warp is delayed until the visible follower has been recalled.
  keep(Field,{'_locks'});Field._locks={};Warp._busy=false
  Warp.startDoorEntrance(nil,game,'EM_HNS_NEW_BARK_TOWN_LAB_HNS',7,11,8,8)
  T.eq(F.transition.kind,'enter','door entrance starts follower recall')
  T.eq(Warp.isBusy(),false,'native door fade waits for follower recall')
  T.check(Field._locks.hnsFollowerWarp,'recall prevents a second player step')
  for i=1,16 do F.tick()end
  T.eq(Field._locks.hnsFollowerWarp,nil,'recall releases its own movement lock')
  T.eq(Warp.isBusy(),true,'finished recall resumes actual native door sequence')
  Warp.clear();Field._locks={};F.step(8,8,16);for i=1,16 do F.tick()end
  lead.isShiny=true;local normal=F.actor.graphicsId;F.refresh();T.neq(F.actor.graphicsId,normal,'shiny follower selects source shiny palette')
  setting('ITEM_MAIN_FOLLOWER',1);F.refresh();T.eq(F.actor,nil,'Follower OFF removes actor');setting('ITEM_MAIN_FOLLOWER',0)
  local big=mon(C:require('species','SPECIES_LUGIA'));s.party={big};T.eq(F.allowed(s,big),false,'Big Followers OFF hides 64px Lugia')
  setting('ITEM_MAIN_LARGE_FOLLOWER',0);T.eq(F.allowed(s,big),true,'Big Followers ON permits outdoors')
  local indoor;for mid,map in pairs(maps)do if map.mapType==8 then indoor=mid;break end end;s.map=assert(indoor);T.eq(F.allowed(s,big),false,'source MAP_TYPE_INDOOR hides large sprites')
  s.map='EM_HNS_NEW_BARK_TOWN_LAB_HNS';T.eq(F.allowed(s,big),true,'source MAP_TYPE_NONE lab preserves source large-follower behavior')
  P.surfing=true;T.eq(F.allowed(s,big),false,'surfing hides follower');P.surfing=false
  s.map='EM_HNS_ROUTE29_HNS';s.party={lead};Rtc.calcLocalTimeOffset(s,0,20,0,0);setting('ITEM_BATTLE_NEW_BACKGROUNDS',0)
  local row,key=V.terrain(0,s);T.check(key:find('_old_Night',1,true)~=nil,'old terrain uses night palette')
  T.check(row.sourceTiles:find('/tall_grass/',1,true)~=nil,'grass imports its own table entry, not COUNT/building fallback')
  setting('ITEM_BATTLE_NEW_BACKGROUNDS',1);row,key=V.terrain(0,s);T.check(key:find('_modern_Night',1,true)~=nil,'modern terrain selection works')
  T.check(row.sourceTiles:find('/tall_grass_modern/',1,true)~=nil,'Modern grass selects the source Modern tile sheet')
  Rtc.calcLocalTimeOffset(s,0,19,0,0);row,key=V.terrain(0,s);T.check(key:find('_Twilight',1,true)~=nil,'battle twilight lasts to 20:00 independently of encounters')
  setting('ITEM_BATTLE_NEW_BATTLEUI',1);T.eq(V.style(s),'gen4','Gen4 UI option selects source art');setting('ITEM_BATTLE_NEW_BATTLEUI',0);T.eq(V.style(s),'gen3','Gen3 UI option selects HnS art')
  B._st=st;st.session=s;T.check(pcall(BgDraw or require('src.core.game3.battle.bg').draw,0,0,0,0),'actual battle background draws source terrain')
  local Chrome=require('src.ui.game3.battle_chrome')
  local x,y,width=Chrome.messageOrigin();T.eq(x,16,'battle message uses HnS window x');T.eq(y,121,'battle message uses source printer y');T.eq(width,208,'battle message uses source window width')
  T.eq(Chrome.window(3).x,16,'first move uses source expanded window origin')
  local stage=require('src.core.game3.battle.anim').stage();stage.healthbox.player.visible=true;stage.healthbox.enemy.visible=true
  st.player.mon.status='PAR';st.player.status='PAR'
  T.check(pcall(require('src.core.game3.battle.healthbox').draw,'player',st.player,{st=st}),'actual source healthbox draws native battler')
  setting('ITEM_BATTLE_BALL_PROMPT',0);Bag.add(s.bag,4,2);T.check(S.enabled(st),'ball prompt requires usable balls and wild battle')
  Ui.reset({headless=true});Ui._st=st;Ui.openMenu(0);local held='r'
  local function keys(pressed)return {wasPressed=function(_,k)return k==pressed end,isDown=function(_,k)return held==k end}end
  Ui.handleInput(keys('r'));held=nil;Ui.handleInput(keys());T.eq(Ui._pendingCommand.itemId,4,'R release sends actual throw command without bag menu')
  Ui.reset({headless=true});Ui._st=st;Ui.openMenu(0);setting('ITEM_BATTLE_RUN_TYPE',2)
  Ui.handleInput(keys('b'));T.eq(Ui._menuIndex,4,'Run Type B highlights native RUN command')
  setting('ITEM_BATTLE_FAST_INTRO',0);Intro.begin(st,{})
  local quick=true;for _,step in ipairs(Intro._steps)do if step.kind=='bgslide'then quick=quick and step.data.frames==1 end end
  T.check(quick,'Fast Intro shortens the actual background slide')
  Intro.reset();Ui.reset({headless=true});st.player.mon.speed=100;st.enemy.mon.speed=80;st.over=nil;st.result=nil
  B._st=st;B._adapter=ad;T.eq(S.quickRun(),true,'quick-run shortcut uses native successful escape')
  T.eq(st.result,'run','quick-run resolves the real battle outcome');T.eq(B._phase,'ending','quick-run enters native battle completion')
  Ui.reset({headless=true});S.ballX=14;T.check(pcall(S.drawPrompt),'closing a battle cannot leave a nil-state ball prompt')
  -- Source boot machines complete without Emerald movie/title assets.
  local Boot=require('src.ui.game3.boot');local boot=Boot.new(game);T.eq(boot.custom.mods.intro,'hns.intro','new boot selects HnS intro')
  T.eq(boot.custom.mods.title,'hns.title','new boot selects HnS title')
  local movie=game._hnsBoot.Intro.new();local input=keys();local result
  local creditsSeen=false
  for i=1,1800 do result=movie:update(input,1/60);if movie.movie.phase=='expansion'then creditsSeen=true end;if result then break end end
  T.check(creditsSeen,'real boot reaches custom source credits before Game Freak')
  T.eq(result,'title','HnS intro finishes at title without Emerald scene');movie:destroy()
  local credits=game._hnsBoot.Credits.new();for i=1,128 do credits:frame(false)end
  T.eq(credits.eggX,172,'source credits egg reaches collision position after 128 callbacks')
  T.eq(credits.poryState,'hit','source Porygon reaches collision animation')
  for i=129,180 do credits:frame(false)end;T.eq(credits.poryState,'up','source Porygon finishes its hit animation')
  for i=181,260 do credits:frame(false)end;T.eq(credits.state,'done','source credits finish and fade without input')
  local Machine=require('src.ui.game3.rse.gba_machine');local machine=Machine.new()
  local title=game._hnsBoot.Title.new(machine,{params=boot.custom.mods.params.titleParams})
  for i=1,2000 do title:update(input,1/60);if title.phase=='phase3'then break end end
  T.eq(title.phase,'phase3','actual source title reaches input phase');T.eq(machine.ppu.bg[1].layer,nil,'source HnS omits Emerald clouds')
  T.check(machine.ppu:_bgEnabled(0),'actual title enables source backdrop')
  T.eq(machine.ppu.palette.pltt[225],32767,'title bank 14 contains source white instead of PNG padding')
  title:update(keys('start'),1/60);for i=1,120 do result=title:update(input,1/60);if result then break end end
  T.eq(result,'menu','START on HnS title enters native main menu');title:destroy()
  Intro.reset();Ui.reset({headless=true});F.actor=nil;F.mon=nil
  for i=#saved,1,-1 do local r=saved[i];r.t[r.k]=r.v end
  print('HnS expansion: persistent status, source stats, tower escape, RTC/time encounters, native followers, terrain/UI options, shortcuts and boot machines')
end
