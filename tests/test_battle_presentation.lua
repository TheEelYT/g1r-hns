-- Exercise the installed bridge through actual native input/message/capture APIs.
return function(T,game,world)
  local Ui=require('src.core.game3.battle.ui');local Catch=require('src.core.game3.battle.catch_seq')
  local Msg=require('src.ui.game3.message');local Anim=require('src.core.game3.battle.anim')
  local State=require('src.core.game3.battle.state');local Rt=require('src.core.game3.runtime')
  local oldSession=Rt.session
  local s={map=world.startup.start.map,version='emerald',name='GENE',flags={},vars={}}
  Rt.session=s
  local mon={species=152,level=5,hp=20,maxHp=20,moves={33,45},pp={35,40},nickname='CHIKORITA'}
  local enemy={species=19,level=3,hp=15,maxHp=15,moves={33},pp={35}}
  local st=State.new({session=s,wild=true,playerParty={mon},foeParty={enemy}});st.session=s
  local P=game._hnsBattlePresentation.presentation
  local S=game._hnsBattleSettings.settings
  local Bag=require('src.core.game3.bag');s.bag=Bag.new();Bag.add(s.bag,4,20)
  local Space=require('src.core.game3.scripting.space');local Flags=require('src.core.game3.scripting.flags');local oldStore=Space.store
  Space.store=Flags.newStore();Flags.setFlag(Space.store,nil,world.startup.settings.initializedFlag,true)
  for _,page in ipairs(world.startup.settings.pages)do for _,r in ipairs(page.rows)do Flags.setVar(Space.store,nil,r.var,r.id=='ITEM_BATTLE_BALL_PROMPT'and 0 or r.default)end end
  -- Exercise the real fixed-step dispatcher; only its unrelated arena front
  -- end is a fixture. Menu input must not advance these callbacks twice.
  local Game3=require('src.core.Game3');local phase,arena,alias=game.phase,game.arena,game._aliasLA
  game._aliasLA=function()end;game.phase='arena';game.arena={update=function()end}
  local function frame()Game3.fixedUpdate(game,1/60)end
  local Audio=require('src.core.game3.audio');local fanfare=Audio.playFanfare;local waitSe=Audio._waitSe
  local played;Audio.playFanfare=function(id)played=id;return true end
  Audio.playSe(Audio.resolveSong('MUS_CAUGHT_INTRO'))
  T.eq(played,world.audio.roles.evolved,'capture-click sound routes to exact source HG_EVOLVED')
  Audio._waitSe={};Audio.waitSe(Audio.resolveSong('MUS_CAUGHT_INTRO'),function()end)
  T.eq(Audio._waitSe[1].id,world.audio.roles.evolved,'native capture wait follows source click cue')
  Audio.playFanfare=fanfare;Audio._waitSe=waitSe
  local function key(k)return {wasPressed=function(_,v)return v==k end,isDown=function()return false end}end
  Ui.reset({headless=true});Ui._headless=false;Ui._st=st
  Ui.openMenu(0);Ui.handleInput(key('a'))
  T.eq(Ui._mode,'moves','actual Fight action enters native move selection')
  T.check(P.eligible(),'HnS move selection displays START hint')
  P.hintX=-30
  for i=1,28 do Ui.tick();frame();T.eq(P.hintX,-30+i,'source hint slides once per native frame '..i)end
  Ui._mode='menu';frame();T.eq(P.hintX,-3,'source hint slides away on leaving move selection');Ui._mode='moves';frame()
  Ui.handleInput(key('start'));T.check(P.details,'START opens source move information')
  local move,row=P.selected();T.eq(move.numId,33,'details describe highlighted move');T.eq(row.description,world.startup.rules.moves.TACKLE.description,'details use HnS description')
  P.draw();Ui.handleInput(key('right'));T.eq(Ui._moveIndex,2,'directions select another move while details stay open');T.check(P.details,'details remain open on cursor move')
  Ui.handleInput(key('a'));T.eq(P.details,false,'A closes description');T.eq(Ui._pendingCommand,nil,'closing description does not select an attack')
  Ui.handleInput(key('start'));Ui.handleInput(key('b'));T.eq(Ui._mode,'moves','B closes details without returning to action menu')
  Ui.handleInput(key('start'));Ui.handleInput(key('start'));T.eq(P.details,false,'START toggles description closed')
  Ui._mode='menu';T.eq(P.eligible(),false,'action menu keeps native START behavior')
  Ui._mode='moves';Ui._swap={};T.eq(P.eligible(),false,'move rearrangement keeps native controls');Ui._swap=nil
  -- The SDK registry previously populated this row, hiding the real desktop
  -- failure. Explicitly remove it and draw the complete native selection UI.
  local Moves=require('src.core.game3.battle.moves');local roost=world.campaign.roostMove
  local rom=Moves._rom[roost];Moves._rom[roost]=nil
  local beforeMoves,beforePp=mon.moves,mon.pp;mon.moves={roost,33};mon.pp={5,35}
  st.player.moves=mon.moves
  local H=game._hnsRules.rules;local value=H.value;local style=0
  H.value=function(id,session)if id=='ITEM_BATTLE_NEW_BATTLEUI'then return style end;return value(id,session)end
  local Battle=require('src.core.game3.battle');local battleSt=Battle._st;Battle._st=st
  -- The ROM-free fixture has no imported sprite-coordinate cache. Supply only
  -- this graphical boundary; the native move lookup and menu draw stay real.
  local Coords=require('src.core.game3.battle.pic_coords')
  local front,back,elev=rawget(Coords,'front'),rawget(Coords,'back'),rawget(Coords,'elev')
  Coords.front={[152]=0,[19]=0};Coords.back={[152]=0,[19]=0};Coords.elev={}
  local RomText=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir')
  local textSaved={}
  for k,v in pairs({gText_MoveInterfacePP='PP',gText_MoveInterfaceType='TYPE/', ['gTypeNames[2]']='FLYING'})do
    textSaved[#textSaved+1]={k,RomText.overrides[k]};RomText.overrides[k]=IR.fromAscii(v)
  end
  for i=0,1 do
    style=i;Ui._moveIndex=1;P.details=false
    local ok,err=pcall(Ui.draw,240,160)
    T.check(ok,'native GEN '..(i==0 and 3 or 4)..' Roost selection draws without a ROM move row '..tostring(err or ''))
    Ui.handleInput(key('start'));T.check(P.details,'Roost START details open')
    local def,info=P.selected();T.eq(def.numId,roost,'shared HnS lookup resolves selected Roost')
    T.eq(info.description,world.moveTable.moves.ROOST.description,'Roost details use the complete source move table')
    T.eq(def.pp,5,'Roost battle panel uses source PP')
    ok,err=pcall(Ui.draw,240,160)
    T.check(ok,'Roost native menu and source details draw together '..tostring(err or ''))
    Ui.handleInput(key('right'));T.eq(Ui._moveIndex,2,'cursor can leave Roost while details are open')
    Ui.handleInput(key('b'));T.eq(P.details,false,'Roost details close normally')
  end
  Coords.front=front;Coords.back=back;Coords.elev=elev
  for _,row in ipairs(textSaved)do RomText.overrides[row[1]]=row[2]end
  Battle._st=battleSt;H.value=value;Moves._rom[roost]=rom;mon.moves=beforeMoves;mon.pp=beforePp;st.player.moves=beforeMoves
  s.map='EM_LITTLEROOT_TOWN';T.eq(P.eligible(),false,'vanilla selection has no HnS overlay');s.map=world.startup.start.map
  for _,wait in ipairs({1,8,28,60})do
    Ui.reset({headless=true});Ui._st=st;Ui.openMenu(0);S.ballX=-14
    for i=1,wait do frame()end
    T.eq(S.ballX,math.min(14,-14+wait),'ball prompt enters at source speed')
    Ui._mode='moves';P.hintX=-30
    for i=1,wait do frame()end
    T.eq(S.ballX,-14,'ball prompt completes hide while selecting moves')
    local before=P.hintX;Ui._pendingCommand={kind='move'};Ui._mode='none'
    Ui.push('Battle message');for i=1,28 do frame()end
    T.eq(P.hintX,-30,'move prompt completes hide during a queued message '..wait)
    T.eq(P.details,false,'turn selection closes details')
    T.check(before>=-30,'animation fixture remains bounded')
  end
  Ui.reset({headless=true});Ui._st=st;Ui.openMenu(0);S.ballX=14
  Ui._pendingCommand={kind='bag'};Ui._mode='none'
  for i=1,28 do frame()end;T.eq(S.ballX,-14,'ball prompt completes exit during throw/capture without menu input')
  Ui.openMenu(0);S.ballX=-14;for i=1,28 do frame()end
  T.eq(S.ball,4,'prompt retains the displayed ball icon')
  Bag.remove(s.bag,4,20);Ui._mode='none';frame()
  T.eq(S.ballX,13,'using the final ball still begins animated exit');T.eq(S.ball,4,'final ball icon remains during exit')
  S.drawPrompt();for i=1,27 do frame()end;T.eq(S.ballX,-14,'final ball exit completes');T.eq(S.ball,nil,'final ball icon releases after exit')
  Ui._st=nil;frame();T.eq(S.ballX,-14,'closed battle clears ball animation');T.eq(P.hintX,-30,'closed battle clears START animation')
  game.phase,game.arena,game._aliasLA=phase,arena,alias
  -- Only unavailable imported battle strings/font metrics are supplied below.
  -- The native message printer, timed queue and catch-step state machine run.
  local Text=require('src.core.game3.battle.battle_text');local get=Text.get
  Text.get=function(id,...)if id=='STRINGID_PLAYERUSEDITEM'then return 'GENE used a POKé BALL!'elseif id=='STRINGID_ITDODGEDBALL'then return 'It dodged the ball!'elseif id=='STRINGID_PKMNBROKEFREE'then return 'It broke free!'end;return get(id,...)end
  local Font=require('src.ui.game3.frlg_font');local wrap=Font.wrap
  Font.wrap=function(text)return text end
  Ui.reset({headless=true});Ui._headless=false;Ui._st=st
  local delivered=0;local options={session=s,headless=false,pushMsg=function(text)delivered=delivered+1;Ui.push(text)end}
  local animHeadless=Anim._headless;Anim._headless=true
  Catch.begin(st,4,false,0,options);Catch.update()
  T.eq(delivered,0,'throw announcement uses timed queue rather than confirmation callback')
  T.check(type(Ui._queue[1])=='table' and Ui._queue[1].timed,'throw announcement is automatic')
  Ui.pump()
  for i=1,200 do Msg.tick();Ui.pump() end
  T.eq(Ui.dialogPending(),false,'actual throw text completes with no A input')
  Catch.update();T.check(Catch._i>1,'native capture advances into ball throw with no A input')
  Catch.update();T.eq(delivered,1,'breakout still uses native acknowledged result message')
  T.eq(options.pushMsg~=nil,true,'caller options remain intact')
  Catch.reset();Msg.reset();Ui.reset({headless=true})
  st.session.map='EM_LITTLEROOT_TOWN';delivered=0
  Catch.begin(st,4,false,0,options);Catch.update();T.eq(delivered,1,'vanilla capture keeps original announcement callback')
  Catch.reset();Ui.reset({headless=true});Text.get=get;Font.wrap=wrap;Anim._headless=animHeadless;Rt.session=oldSession;Space.store=oldStore
  print('HnS battle presentation: ROM-free Roost in both UIs, START/details navigation and native automatic throw continuation')
end
