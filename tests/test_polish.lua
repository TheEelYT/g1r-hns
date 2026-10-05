-- Real VM/movement/party/modal tests for the reported 0.6.4 differences.
return function(T,game,world,maps)
  local Q=world.startup;local S=game._hnsGear.settings;local UI=game._hnsGear.presentation
  local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space');local Flags=require('src.core.game3.scripting.flags')
  local Vm=require('src.core.game3.scripting.vm');local Adapters=require('src.core.game3.scripting.adapters')
  local Objects=require('src.core.game3.objects');local Player=require('src.core.game3.player');local Collision=require('src.core.game3.collision')
  local Field=require('src.core.game3.field');local Party=require('src.core.game3.party');local Bag=require('src.core.game3.bag')
  local Stack=require('src.ui.game3.stack');local Audio=require('src.core.game3.audio');local FX=require('src.core.game3.field_effects')
  local C=require('src.core.game3.constants').of('emerald');local saved={}
  local function keep(t,keys)for _,k in ipairs(keys)do saved[#saved+1]={t=t,k=k,v=t[k]}end end
  keep(Rt,{'session','active'});keep(Space,{'store','vm','mapId','active','_inTransition'});keep(game,{'session','currentMap'})
  keep(Field,{'running','locked','_session','_game'});keep(Player,{'cellX','cellY','px','py','targetX','targetY','moving','facing','elevation','currentElevation','action'})
  keep(Objects,{'_byId','_order','_tracks','_mapId','_defs','_bounds','_perm','_templateMt'});keep(FX,{'_anims'});keep(Stack,{'_layers'})
  -- The ROM-free fixture lacks naming chrome strings. The real native
  -- nickname handler and callback remain in use; only its title is supplied.
  local Naming=require('src.ui.game3.naming');keep(Naming,{'monTitle'});Naming.monTitle=function(name)return name.."'s nickname?"end
  local function press(m,key)return S.frame(m,{new={[key]=true}})end
  local m=S.new('challenge');m.cursor=2;local value=m.values.ITEM_MODE_MODERN_MOVES
  press(m,'right');T.eq(m.values.ITEM_MODE_MODERN_MOVES,value,'recommended mode children refuse edits')
  m.cursor=1;press(m,'right');m.cursor=2;press(m,'left');T.eq(m.values.ITEM_MODE_MODERN_MOVES,0,'custom mode children can be edited')
  m.cursor=1;press(m,'left');T.eq(m.values.ITEM_MODE_MODERN_MOVES,1,'recommended resets source presets')
  m.tab=3;m.cursor=2;value=m.values[m.pages[3].rows[2].id];press(m,'right');T.eq(m.values[m.pages[3].rows[2].id],value,'randomizer-off children refuse edits')
  m.cursor=1;press(m,'right');m.cursor=2;press(m,'right');T.neq(m.values[m.pages[3].rows[2].id],value,'randomizer-on child can change')
  m.tab=4;m.cursor=2;value=m.values[m.pages[4].rows[2].id];press(m,'right');T.eq(m.values[m.pages[4].rows[2].id],value,'nuzlocke-off children refuse edits')
  m.cursor=1;press(m,'right');m.cursor=2;press(m,'right');T.eq(m.values[m.pages[4].rows[2].id],value,'easy nuzlocke locks its clauses')
  m.cursor=1;press(m,'right');m.cursor=2;press(m,'right');T.neq(m.values[m.pages[4].rows[2].id],value,'normal nuzlocke unlocks clauses')
  T.eq(press(m,'start'),nil,'save requires confirmation');T.check(m.confirm,'source confirm screen opens')
  press(m,'down');T.eq(press(m,'a'),nil,'NO returns to settings');T.eq(m.confirm,false,'NO dismisses confirmation without saving')
  press(m,'start');T.eq(press(m,'a'),true,'YES finishes settings')
  local mid=S.new('challenge',nil,false);mid.tab=3;mid.cursor=1;press(mid,'right');T.eq(mid.values.ITEM_RANDOM_OFF_ON,0,'mid-run cannot enable randomizer')
  mid.values.ITEM_RANDOM_OFF_ON=1;press(mid,'left');T.eq(mid.values.ITEM_RANDOM_OFF_ON,0,'mid-run can reduce randomizer')
  mid.tab=4;mid.cursor=6;T.eq(S.active(mid,mid.pages[4],mid.pages[4].rows[6]),false,'mid-run source rare-candy setting stays locked')
  for _,kind in ipairs({'option'})do
    local last=S.new(kind,nil,false);last.tab=#last.pages
    T.eq(press(last,'r'),nil,'loaded last '..kind..' R does not exit')
    T.eq(last.tab,#last.pages,'loaded last '..kind..' R does not wrap')
    T.eq(last.confirm,nil,'loaded last '..kind..' R does not ask to save')
  end
  local pcLast=S.new('challenge',nil,false);pcLast.tab=#pcLast.pages
  press(pcLast,'r');T.eq(pcLast.confirm,true,'PC Game Modes last R asks to save')
  press(pcLast,'down');press(pcLast,'a');T.eq(pcLast.confirm,false,'PC save NO returns to last page')
  press(pcLast,'r');T.eq(press(pcLast,'a'),true,'PC save YES finishes changes')
  local initial=S.new('challenge');initial.tab=#initial.pages;press(initial,'r');T.eq(initial.confirm,true,'opening last R still confirms choices')
  local s,store,trace
  local function reset(map,x,y)
    s={version='emerald',map=map,name='GENE',gender=0,party={},bag=Bag.new(),flags={},vars={}}
    store=Flags.newStore();Space.store=store;Rt.session=s;Rt.active=true;game.session=s;game.currentMap=map;Stack.clear();FX._anims={}
    Field.running=true;Field.locked=true;Field._session=s;Field._game=game
    Collision.bindMap(game,map,maps[map]);Objects.reset();Objects.loadMap(game,map,maps[map])
    Player.cellX,Player.cellY=x,y;Player.px,Player.py=x*16,y*16;Player.targetX,Player.targetY=x,y;Player.moving=false;Player.action=nil;Player.facing='up';Player.currentElevation=3
    trace={}
  end
  local function run(key,opts)
    opts=opts or {};local pending;local pictures=0;local names=0;local ticks=0
    local a=Adapters.stub({playerName='GENE',onMessage=function(t)trace[#trace+1]={text=t,x=Player.cellX,y=Player.cellY,tick=ticks}end})
    a.modifyItem=function(op,id,qty)
      if op=='removeitem'then return Bag.remove(s.bag,id,qty)end
      return Bag.add(s.bag,id,qty)
    end
    a.checkItem=function(id,qty)return Bag.has(s.bag,id,qty)end
    a.applyMovement=Objects.applyMovement;a.pollMovement=Objects.pollMovement;a.turnObject=Objects.turnObject
    a.setObjectState=function(op,row)if op=='setobjectxyperm'then Objects.setObjectXY(row.localId,row[2],row[3])end end
    a.onFlagChanged=function(id,hidden)Objects.syncFlagVisibility(id,hidden,true)end
    a.addObject=Objects.addObject;a.removeObject=Objects.removeObject
    a.giveMonToPlayer=function(sp,lv)return Party.giveMonToPlayer(s,sp,lv)end
    local questions=0;a.askYesNo=function(done)questions=questions+1;done(opts.answer~=false and not (questions==2 and opts.nickname==false))end
    a.showMonPic=function(sp,x,y)require('src.ui.game3.mon_pic').show(sp,x,y);pictures=pictures+1;T.check(require('src.ui.game3.mon_pic')._img~=nil,'starter preview has source pixels')end
    a.hideMonPic=function()require('src.ui.game3.mon_pic').hide()end
    a.openNaming=function(options,done)names=names+1;T.eq(options.template,'NICKNAME','starter uses real nickname template');T.eq(options.maxLen,10,'source nickname length');pending=done end
    local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,store=store,adapters=a});Space.vm=vm;Space.mapId=s.map;Space.active=true
    T.check(vm:start(key),'polish scene starts '..key)
    for tick=1,12000 do
      ticks=tick;Audio.update(1/60);Player.tick(game);Objects.update(game)
      if pending then T.check(vm:isRunning(),'nickname holds field script');local done=pending;pending=nil;done(opts.name or 'LEAF')end
      if vm:isRunning()then vm:resume()else break end
    end
    T.eq(vm:isRunning(),false,'polish scene finishes '..key);T.eq(vm.ctx.frozen,false,'polish scene releases '..key);T.eq(#a.logs,0,'polish scene has no skipped ops '..key)
    return pictures,names,ticks
  end
  local lab='EM_HNS_NEW_BARK_TOWN_LAB_HNS'
  for _,name in ipairs({'CHIKORITA','CYNDAQUIL','TOTODILE'})do
    reset(lab,6,5);Flags.setFlag(store,nil,world.opening.flags.elmReady,true)
    local pic,names=run('HNS_OPENING_'..name)
    T.eq(pic,1,'starter choice opens picture once');T.eq(names,1,'starter nickname offered')
    T.eq(s.party[1].nickname,'LEAF','confirmed nickname changes real party')
    local Schema=require('src.core.game3.save_schema_firered');local restored=Schema.fromSaveTable(Schema.toSaveTable(s))
    T.eq(restored.party[1].nickname,'LEAF','native save/reload retains starter nickname')
    T.eq(require('src.ui.game3.mon_pic').active,false,'accepted preview closes')
    run('HNS_OPENING_'..name);T.eq(#s.party,1,'starter never duplicates after naming')
  end
  reset(lab,6,5);Flags.setFlag(store,nil,world.opening.flags.elmReady,true);run('HNS_OPENING_CHIKORITA',{answer=false})
  T.eq(#s.party,0,'declining starter gives nothing');T.eq(require('src.ui.game3.mon_pic').active,false,'declined preview closes')
  reset(lab,6,5);Flags.setFlag(store,nil,world.opening.flags.elmReady,true);local _,names=run('HNS_OPENING_CYNDAQUIL',{nickname=false});T.eq(names,0,'nickname NO releases without opening keyboard');T.eq(#s.party,1,'nickname NO keeps starter')
  reset(lab,6,5);Flags.setFlag(store,nil,world.opening.flags.elmReady,true)
  for i=1,6 do Party.giveMonToPlayer(s,C:require('species','SPECIES_CHIKORITA'),5);s.party[i].nickname='ORIGINAL'end
  local _,names=run('HNS_OPENING_CHIKORITA');T.eq(names,0,'PC-bound starter does not rename an existing party member');T.eq(s.party[6].nickname,'ORIGINAL','full-party naming guard preserves existing nickname')
  reset('EM_HNS_NEW_BARK_TOWN_HNS',17,9);local silver=Objects.find(3);local sx,sy=silver.cellX,silver.cellY
  run('HNS_FIDELITY_WINDOW');T.eq(Player.cellX,16,'Silver pushes player one tile left');T.eq(Player.cellY,12,'Silver pushes player three tiles down')
  T.eq(silver.cellX,sx,'Silver returns to original window x');T.eq(silver.cellY,sy,'Silver returns to original window y')
  local city='EM_HNS_CHERRYGROVE_CITY_HNS'
  for _,lane in ipairs({'TOP','MID','BOTTOM'})do
    reset(city,57,lane=='TOP'and 9 or lane=='MID'and 10 or 11)
    T.eq(Player.runningDisallowed(57,10),false,'Cherrygrove permits running on its path')
    run('HNS_POLISH_GUIDE_'..lane)
    T.eq(Player.cellX,41,'tour ends outside guide house x');T.eq(Player.cellY,16,'tour ends outside guide house y')
    T.eq(Flags.getFlag(store,nil,Q.guideHiddenFlag),true,'completed tour moves guide indoors')
    T.eq(Flags.getFlag(store,nil,world.quest.flags.guideHidden),false,'completed tour shows indoor guide')
    T.eq(Flags.getVar(store,nil,Q.guideStateVar),1,'completed tour disarms entry trigger')
    local words=table.concat((function()local out={};for _,v in ipairs(trace)do out[#out+1]=v.text end;return out end)(),'\n')
    for _,name in ipairs({'POKéMON CENTER','POKéMON MART','ROUTE 30','sea','house'})do T.check(words:find(name,1,true)~=nil,'tour source stop '..name)end
  end
  reset(city,57,9);run('HNS_POLISH_GUIDE_TOP',{answer=false});T.eq(Flags.getVar(store,nil,Q.guideStateVar),1,'declined tour does not retrigger automatically');T.eq(Flags.getFlag(store,nil,Q.guideHiddenFlag),false,'declined tour guide remains outside')
  run('HNS_POLISH_GUIDE_TALK');T.eq(Flags.getFlag(store,nil,Q.guideHiddenFlag),true,'manual conversation can retry a declined tour')
  if Q.rules then
    local farewell=Q.rules.momFarewellFlag;local town='EM_HNS_NEW_BARK_TOWN_HNS'
    for y=12,14 do
      reset(town,0,y);Flags.setFlag(store,nil,world.opening.flags.received,true);Flags.setFlag(store,nil,world.quest.flags.eggDelivered,true)
      run('HNS_FIDELITY_TOWN_INIT');T.eq(Objects.find(2).cellX,0,'girl returns to gate after second Elm visit');T.eq(Objects.find(2).cellY,11,'girl guards source town exit')
      run('HNS_FIDELITY_BLOCK_EXIT');T.eq(Player.cellX,1,'Mom gate steps player back in exit lane '..y)
      T.check(trace[#trace].text:find('mom',1,true)~=nil or trace[#trace].text:find('MOM',1,true)~=nil,'Mom gate shows source farewell reminder')
      Flags.setFlag(store,nil,farewell,true);Player.cellX=0;Player.px=0;Player.targetX=0
      run('HNS_FIDELITY_BLOCK_EXIT');T.eq(Player.cellX,0,'farewell releases town exit lane '..y)
      run('HNS_FIDELITY_TOWN_INIT');T.eq(Objects.find(2).cellX,9,'girl returns home after farewell')
    end
    reset('EM_HNS_NEW_BARK_TOWN_PLAYERS_HOUSE_1F_HNS',9,4)
    Flags.setFlag(store,nil,world.opening.flags.received,true)
    run('HNS_OPENING_MOM');T.eq(Flags.getFlag(store,nil,farewell),false,'earlier Mom talk cannot satisfy later farewell')
    Flags.setFlag(store,nil,world.quest.flags.eggDelivered,true)
    run('HNS_OPENING_MOM');T.eq(Flags.getFlag(store,nil,farewell),true,'post-egg Mom talk sets actual farewell flag')
    Space.persistSession(nil,game);local loaded=Flags.loadInto(Flags.newStore(),{flags=s.flags,vars=s.vars})
    T.eq(Flags.getFlag(loaded,nil,farewell),true,'Mom farewell survives native session serialization')
    reset(lab,6,5);Flags.setFlag(store,nil,world.opening.flags.received,true);Flags.setFlag(store,nil,world.quest.flags.eggReceived,true);Flags.setFlag(store,nil,world.quest.flags.rivalDone,true)
    Bag.add(s.bag,world.quest.eggItem,1)
    local sounds={};local fanfare=Audio.playFanfare;Audio.playFanfare=function(id)sounds[#sounds+1]=id;return fanfare(id)end
    run('HNS_QUEST_ELM_RETURN')
    local sourceCue;for id,name in pairs(world.audio.songs)do if name=='MUS_HG_LEVEL_UP'then sourceCue=tonumber(id)end end
    T.eq(sounds[1],sourceCue,'egg handoff requests source level-up jingle');T.eq(Bag.get(s.bag,world.quest.eggItem),0,'egg handoff removes actual mystery egg once')
    run('HNS_QUEST_ELM_AFTER');T.eq(#sounds,1,'repeat Elm talk does not repeat handoff cue')
    Audio.playFanfare=fanfare
  end
  reset(city,57,9)
  local actor=Objects.find(1);local bubble=FX.startEmote(actor,'question')
  T.eq(bubble.sheet,'hns_question','question bubble uses source sheet');T.check(FX._sheets.hns_question.image~=nil,'question bubble owns renderable pixels')
  local RomText=require('src.core.game3.rom_text');keep(RomText,{'plain'});local plain=RomText.plain
  RomText.plain=function(key,ctx)
    local text={gText_SomeonesPC="SOMEONE'S PC",gText_PlayersPC="GENE'S PC",gText_LogOff='LOG OFF'}
    return text[key] or plain(key,ctx)
  end
  local PC=require('src.ui.game3.pc_menu');local result
  PC.show({session=s,startMode='select',onClose=function(n)result=n end})
  local rows=PC._rootEntries();T.eq(rows[#rows-1].id,'hns_challenge','native PC includes GAME MODES')
  PC.cursor=#rows-1;PC.handleInput({wasPressed=function(_,k)return k=='a'end})
  local O=game._hnsGear.options;T.check(Stack.has(O.ID),'PC opens actual challenge menu');T.eq(O.model.initial,false,'PC uses mid-run lock policy')
  O.model.tab=#O.model.pages;O.handleInput({wasPressed=function(_,k)return k=='r'end})
  T.check(O.model.confirm,'real PC final R opens confirmation without closing the modal')
  O.handleInput({wasPressed=function(_,k)return k=='b'end});T.check(Stack.has(O.ID),'B at confirmation returns to PC settings')
  O.handleInput({wasPressed=function(_,k)return k=='b'end});T.check(Stack.has('pc_menu'),'cancelling settings returns to PC')
  PC.cursor=#rows;PC.handleInput({wasPressed=function(_,k)return k=='a'end});T.eq(result,2,'added PC entry preserves native quit result')
  for i=#saved,1,-1 do local v=saved[i];v.t[v.k]=v.v end
  print('Polish regressions: menu dependency/confirmation/PC locks; source preview and real nicknames; Silver shove; all three guide tours; Cherrygrove running; source emotes')
end
