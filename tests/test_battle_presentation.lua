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
  local Audio=require('src.core.game3.audio');local fanfare=Audio.playFanfare;local waitSe=Audio._waitSe
  local played;Audio.playFanfare=function(id)played=id;return true end
  Audio.playSe(Audio.resolveSong('MUS_CAUGHT_INTRO'))
  T.eq(played,world.audio.roles.evolved,'capture-click sound routes to exact source HG_EVOLVED')
  Audio._waitSe={};Audio.waitSe(Audio.resolveSong('MUS_CAUGHT_INTRO'),function()end)
  T.eq(Audio._waitSe[1].id,world.audio.roles.evolved,'native capture wait follows source click cue')
  Audio.playFanfare=fanfare;Audio._waitSe=waitSe
  local function key(k)return {wasPressed=function(_,v)return v==k end}end
  Ui.reset({headless=true});Ui._headless=false;Ui._st=st
  Ui.openMenu(0);Ui.handleInput(key('a'))
  T.eq(Ui._mode,'moves','actual Fight action enters native move selection')
  T.check(P.eligible(),'HnS move selection displays START hint')
  P.hintX=-30
  for i=1,28 do Ui.tick();T.eq(P.hintX,-30+i,'source hint slides one pixel/frame '..i)end
  Ui._mode='menu';Ui.tick();T.eq(P.hintX,-3,'source hint slides away on leaving move selection');Ui._mode='moves';Ui.tick()
  Ui.handleInput(key('start'));T.check(P.details,'START opens source move information')
  local move,row=P.selected();T.eq(move.numId,33,'details describe highlighted move');T.eq(row.description,world.startup.rules.moves.TACKLE.description,'details use HnS description')
  P.draw();Ui.handleInput(key('right'));T.eq(Ui._moveIndex,2,'directions select another move while details stay open');T.check(P.details,'details remain open on cursor move')
  Ui.handleInput(key('a'));T.eq(P.details,false,'A closes description');T.eq(Ui._pendingCommand,nil,'closing description does not select an attack')
  Ui.handleInput(key('start'));Ui.handleInput(key('b'));T.eq(Ui._mode,'moves','B closes details without returning to action menu')
  Ui.handleInput(key('start'));Ui.handleInput(key('start'));T.eq(P.details,false,'START toggles description closed')
  Ui._mode='menu';T.eq(P.eligible(),false,'action menu keeps native START behavior')
  Ui._mode='moves';Ui._swap={};T.eq(P.eligible(),false,'move rearrangement keeps native controls');Ui._swap=nil
  s.map='EM_LITTLEROOT_TOWN';T.eq(P.eligible(),false,'vanilla selection has no HnS overlay');s.map=world.startup.start.map
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
  Catch.reset();Ui.reset({headless=true});Text.get=get;Font.wrap=wrap;Anim._headless=animHeadless;Rt.session=oldSession
  print('HnS battle presentation: START/details navigation and native automatic throw continuation')
end
