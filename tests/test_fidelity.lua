-- Actual modal stack, item use, XP award and source title loader regressions.
return function(T,game,world,maps)
  local Q=world.startup;local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space');local Flags=require('src.core.game3.scripting.flags')
  local Stack=require('src.ui.game3.stack');local Bag=require('src.core.game3.bag');local Pokemon=require('src.core.game3.pokemon')
  local C=require('src.core.game3.constants').of('emerald');local oldSession,oldStore=Rt.session,Space.store
  local s={version='emerald',map=Q.start.map,name='GENE',gender=0,bag=Bag.new(),party={},flags={},vars={},dex=require('src.core.game3.dex').new()}
  Rt.session=s;Space.store=Flags.newStore();Stack.clear()
  local G=game._hnsGear.gear;G.show({session=s})
  T.check(Stack.has(G.ID),'real Pokégear modal opens')
  T.eq(table.concat(G.homeRows(),','),'MAP,SWITCH OFF','locked gear home follows source two-row menu')
  Flags.setFlag(Space.store,nil,Q.gearFlag,true)
  T.eq(table.concat(G.homeRows(),','),'MAP,PHONE,SWITCH OFF','Mom unlocks source phone menu without Condition or Radio')
  T.eq(#G.contacts(),1,'Mom alone before Elm registration')
  s.party={{species=158,level=5}};T.eq(table.concat(G.homeRows(),','),'MAP,CONDITION,PHONE,SWITCH OFF','first party Pokémon enables Condition before Elm phone registration')
  local original=s;s=require('src.core.game3.save_schema_firered').fromSaveTable(require('src.core.game3.save_schema_firered').toSaveTable(original));G.session=s
  T.check(table.concat(G.homeRows(),','):find('CONDITION',1,true)~=nil,'saved first-party Condition access survives reload without an extra unlock flag')
  s=original;G.session=s;s.party={}
  Flags.setFlag(Space.store,nil,Q.elmPhoneFlag,true);T.eq(#G.contacts(),2,'Elm is listed after registration')
  T.eq(table.concat(G.homeRows(),','),'MAP,PHONE,SWITCH OFF','Elm phone registration alone does not unlock Condition')
  Flags.setFlag(Space.store,nil,Q.radioFlag,true)
  T.eq(table.concat(G.homeRows(),','),'MAP,CONDITION,PHONE,RADIO,SWITCH OFF','Radio card enables source radio row')
  Flags.setFlag(Space.store,nil,C:flag('FLAG_SYS_RIBBON_GET'),true)
  T.eq(#G.homeRows(),6,'ribbon award enables six-row menu');G.draw()
  Flags.setFlag(Space.store,nil,Q.radioFlag,false);Flags.setFlag(Space.store,nil,C:flag('FLAG_SYS_RIBBON_GET'),false)
  T.check(G.contacts()[1].text:find('MR. POKéMON',1,true)~=nil,'Elm call uses source errand dialogue')
  local Dex=require('src.core.game3.dex')
  for _,sp in ipairs({158,69,161,16,19})do Dex.setCaught(s.dex,sp)end
  for _,sp in ipairs({152,155,163,165,10,11,129,74})do Dex.setSeen(s.dex,sp)end
  Flags.setFlag(Space.store,nil,world.quest.flags.eggReceived,true)
  T.check(G.contacts()[1].text:find('quick',1,true)~=nil,'Elm retains the robbery call before Egg delivery')
  Flags.setFlag(Space.store,nil,world.quest.flags.eggDelivered,true)
  local call=G.contacts()[1].text
  T.check(call:find('seen 13 POKéMON',1,true)~=nil,'Elm reports actual regional seen count')
  T.check(call:find('caught 5 POKéMON',1,true)~=nil,'Elm reports actual regional catch count')
  T.check(call:find(Q.elmRatingTexts.gJohtoDexRatingText_LessThan10,1,true)~=nil,'Elm continues into source rating after counts')
  for _,sp in ipairs({152,155,163,165,10})do Dex.setCaught(s.dex,sp)end
  T.check(G.elmRating():find(Q.elmRatingTexts.gJohtoDexRatingText_LessThan20,1,true)~=nil,'ten catches switch to the next source rating')
  Dex.enableNational(s);Dex.setCaught(s.dex,C:require('species','SPECIES_TREECKO'))
  call=G.elmRating();T.check(call:find('nationwide',1,true)~=nil,'national unlock adds nationwide counts')
  T.check(call:find('caught 11 POKéMON',1,true)~=nil,'national count includes nonregional catches')
  T.eq(Flags.getFlag(Space.store,nil,Q.elmAckDexFlag),false,'unported required species prevent premature completion')
  Flags.setFlag(Space.store,nil,world.quest.flags.eggDelivered,false)
  Flags.setFlag(Space.store,nil,world.quest.flags.eggReceived,false)
  s.dex=Dex.new()
  local finished=false;local ctx={};local N=require('src.core.game3.scripting.natives')
  T.eq(N.ALLOW['native:'..Q.callNative](ctx,{}),true,'incoming call yields native script')
  T.eq(ctx.nativePoll(),false,'call does not resume field before dismissal')
  T.check(table.concat(G.phone.pages,'\n'):find('disaster',1,true)~=nil,'incoming disaster call uses source text')
  T.eq(Stack.fullscreen(),false,'call keeps the overworld visible')
  local sePlaying=require('src.core.game3.audio').isSePlaying;require('src.core.game3.audio').isSePlaying=function()return false end
  for tick=1,400 do G.phone.handleInput({wasPressed=function(_,k)return k=='a' and tick%4==0 end});if not Stack.has(G.phone.ID) then break end end
  require('src.core.game3.audio').isSePlaying=sePlaying
  T.eq(ctx.nativePoll(),true,'call animation and hang-up resume native script')
  Bag.add(s.bag,Q.expItem,1)
  local Item=require('src.core.game3.item_use')
  local ok,kind,message=Item.useField(s,s.bag,Q.expItem)
  T.check(ok and message:find('OFF',1,true),'key-item EXP SHARE switches off')
  T.eq(Bag.get(s.bag,Q.expItem),1,'toggling never consumes EXP SHARE')
  Item.useField(s,s.bag,Q.expItem)
  T.eq(Flags.getFlag(Space.store,nil,Q.expOffFlag),false,'key-item EXP SHARE switches on')
  local Exp=require('src.core.game3.battle.experience');local nativeYield=Exp.expYield
  Exp.expYield=function()return 70 end
  local Party=require('src.core.game3.party');for _,sp in ipairs({152,155,158})do Party.giveMonToPlayer(s,sp,5)end;local mon1,mon2,egg=s.party[1],s.party[2],s.party[3];egg.isEgg=true
  local st={session=s,wild=true,playerParty={mon1,mon2,egg},player={mon=mon1,partyIndex=1}}
  local enemy={species=19,level=10,participants={[1]=true}}
  -- Fixture source yield is 100 base points: 2/3 active, 7/25 inactive.
  local nativePokemonMeta=Pokemon.speciesMeta
  Pokemon.speciesMeta=function(id)local m=nativePokemonMeta(id)or {};if id==19 then local c={};for k,v in pairs(m)do c[k]=v end;c.expYield=70;return c end;return m end
  local results=Exp.awardFoe(st,enemy,{getOpts=function()return {}end})
  T.eq(#results,2,'party-wide share includes reserve and excludes eggs')
  T.eq(results[1].amount,66,'source participant ratio is 2/3')
  T.eq(results[2].amount,28,'source nonparticipant ratio is 7/25')
  mon1.level=18;mon2.level=3
  local uneven=Exp.awardFoe(st,enemy,{getOpts=function()return {}end})
  T.eq(uneven[1].amount,66,'source GEN_3 EXP config does not scale higher-level participants')
  T.eq(uneven[2].amount,28,'lower-level reserve retains source 7/25 award')
  mon1.level=5;mon2.level=5
  Flags.setFlag(Space.store,nil,Q.expOffFlag,true)
  local off=Exp.awardFoe(st,enemy,{getOpts=function()return {}end})
  T.eq(#off,1,'disabled key item returns native participant eligibility')
  T.eq(off[1].amount,100,'disabled key item returns native full experience')
  Exp.expYield=nativeYield;Pokemon.speciesMeta=nativePokemonMeta
  local Back=require('src.core.game3.trainer_pic')
  for gender=0,1 do local pic=Back.back(gender);T.check(pic and pic.image and pic.frames==4,'source battle back strip for gender '..gender)end
  local Settings=game._hnsGear.settings;local model=Settings.new();T.eq(#model.pages,9,'all nine source settings pages available')
  local n=0;for _,p in ipairs(model.pages)do for _,r in ipairs(p.rows)do n=n+1;T.check(model.values[r.id]>=0 and (#r.choices==0 or model.values[r.id]<#r.choices),'valid source default '..r.id)end end
  T.eq(n,88,'all 88 source settings rows imported')
  local O=game._hnsGear.options;O.show({session=s});O.model.values.ITEM_MAIN_BATTLESTYLE=1;O.close(true)
  Space.persistSession(nil,game)
  O.show({session=s});T.eq(O.model.values.ITEM_MAIN_BATTLESTYLE,1,'saved options reopen through native string-key vars');O.close(false)
  T.eq(require('src.core.game3.options').battleStyle(s),'set','selected battle style reaches native battle options')
  local challenge=Settings.new('challenge');for _,p in ipairs(challenge.pages)do for _,r in ipairs(p.rows)do T.eq(Flags.getVar(Space.store,nil,r.var),r.default,'first options save initializes source challenge defaults '..r.id)end end
  local function input(key)return {wasPressed=function(_,k)return k==key end}end
  -- Imported native frame pixels are absent in the ROM-free fixture.
  local Chrome=require('src.ui.game3.chrome');local stdFrame,userFrame=Chrome.stdFrame,Chrome.userFrame
  Chrome.stdFrame=function()end;Chrome.userFrame=function()end
  for _,mid in ipairs({'EM_HNS_NEW_BARK_TOWN_HNS','EM_HNS_PALLET_TOWN_HNS'})do
    s.map=mid;G.show({session=s});for i=1,20 do G.handleInput(input(nil))end;G.handleInput(input('a'));for i=1,40 do G.handleInput(input(nil))end
    local def=maps[mid];T.eq(G.region,Q.sectionRegions[def.hnsSection],'map opens in actual source region')
    T.eq(G.locationName(),def.hnsAreaName,'map labels are isolated by region')
    G.draw();G.handleInput(input('select'));G.draw();G.close()
  end
  for _,p in ipairs(model.pages)do local view=Settings.new(p.kind);for i,page in ipairs(view.pages)do if page.id==p.id then view.tab=i end end;Settings.draw(view)end
  mon1.ribbons=0x8000;G.show({session=s});G.page='ribbons';G.draw();G.close()
  Chrome.stdFrame,Chrome.userFrame=stdFrame,userFrame
  s.map=Q.start.map
  -- The actual Center view switches into native time-setting and waits for confirmation.
  local Kit=require('src.ui.game3.rse.scene_kit');local manifest=Kit.manifest
  Kit.manifest=function(key)if key=='wallclock'then return {confirmWindow={tilemapLeft=10,tilemapTop=10}}end;return manifest(key)end
  local clockCtx={};N.ALLOW['native:'..Q.resetClockNative](clockCtx,{})
  local clock=Stack.top().mod._clock;T.check(clock~=nil,'Center clock uses real native modal host')
  Kit.manifest=manifest
  for i=1,80 do clock:frame({new={},held={}})end
  T.eq(clock.state,'view_input','Center clock first displays current time')
  clock:frame({new={r=true},held={}});T.eq(clock.state,'set_input','R enables penalty-free clock setting')
  clock.t.hours,clock.t.minutes=20,15
  clock:frame({new={a=true},held={}});clock:frame({new={},held={}});clock:frame({new={a=true},held={}});clock:frame({new={},held={}})
  for i=1,80 do clock:frame({new={},held={}})end
  T.eq(clockCtx.nativePoll(),true,'confirmed clock closes and resumes field script')
  local now=require('src.core.game3.rtc').calcLocalTime(s);T.eq(now.hours,20,'clock stores native RTC hour');T.eq(now.minutes,15,'clock stores native RTC minute')
  Bag.remove(s.bag,Q.expItem,1);Bag.add(s.bag,C:require('items','ITEM_EXP_SHARE'),1)
  Flags.setFlag(Space.store,nil,Q.shoesFlag,true);Flags.setFlag(Space.store,nil,world.quest.flags.eggDelivered,true)
  require('src.mods.Runtime').emit('map.entered',{mapId=s.map})
  T.eq(Bag.get(s.bag,Q.expItem),1,'older save gets key EXP SHARE on load/map entry')
  T.eq(Bag.get(s.bag,C:require('items','ITEM_EXP_SHARE')),0,'older bag item migrates without duplication')
  T.eq(Flags.getFlag(Space.store,nil,Q.gearFlag),true,'older completed Mom introduction unlocks Pokégear')
  T.eq(Flags.getFlag(Space.store,nil,Q.elmCallFlag),true,'completed errands do not replay disaster call')
  local Mapsec=require('src.ui.game3.rse.mapsec');local man=Mapsec.readLua('chrome/map_popup/manifest.lua')
  for sec,theme in pairs(Q.areaThemes)do T.eq(Mapsec.theme(tonumber(sec)),theme,'source area-title theme '..sec);T.check(man.palettes[theme]~=nil,'source area-title palette exists')end
  for path,file in pairs(Q.popupFiles)do T.eq(#Mapsec.read(path),1920,'native title reads full source index bitmap '..file)end
  -- Clock UI is real; only its imported bitmap boundary is stubbed elsewhere.
  Stack.clear();Rt.session=oldSession;Space.store=oldStore
  print('HnS fidelity: source options, contacts/native call waits, key-item toggle, party XP, battle back strips and area-title assets')
end
