-- Drive every message/choice through the real installed party/summary menus.
-- ROM strings are the only fixture boundary; no LearnMove callback is mocked.
return function(T,game,w,s,mon,setting)
  local Menu=require('src.ui.game3.party_menu');local Summary=require('src.ui.game3.summary_menu')
  local Learn=require('src.core.game3.battle.learn_move');local Bag=require('src.core.game3.bag')
  local Text=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir')
  local Stack=require('src.ui.game3.stack');local X=game._hnsExpandedMoves.moves
  local oldParty,oldBag,layers=s.party,s.bag,Stack._layers;local saved={};for k,v in pairs(Menu)do saved[k]=v end
  local overrides={};local fixtures={
    gText_ThreeHyphens='---',
    gText_PkmnNeedsToReplaceMove='{STR_VAR_1} wants to learn {STR_VAR_2}.\\p{STR_VAR_1} already has 4 moves.\\pDelete a move for {STR_VAR_2}?',
    gText_StopLearningMove2='Stop learning {STR_VAR_2}?',gText_MoveNotLearned='{STR_VAR_1} did not learn {STR_VAR_2}.',
    gText_12PoofForgotMove='1, 2 and Poof!\\p{STR_VAR_1} forgot {STR_VAR_2}.\\pAnd...',gText_PkmnLearnedMove3='{STR_VAR_1} learned {STR_VAR_2}!',
  }
  for k,v in pairs(fixtures)do overrides[k]=Text.overrides[k];Text.overrides[k]=IR.fromAscii(v)end
  local function key(k)return{wasPressed=function(_,name)return name==k end,isDown=function()return false end}end
  local function press(k)Menu.handleInput(key(k))end
  local function start(mode)
    Learn.reset();Stack._layers={};setting('ITEM_MODE_INFINITE_TMS',mode)
    local m=mon(62);m.nickname='SHINY';m.moves={57,86,150,33};m.pp={15,20,40,35}
    s.party={m};s.bag=Bag.new();Bag.add(s.bag,912,3)
    Menu.open=true;Menu.mode='use';Menu.cursor=1;Menu._party=s.party;Menu._session=s;Menu._bag=s.bag;Menu._item=912
    Menu._layout='single';Menu._hpAnim=nil;Menu._onSelect=nil;Menu._pokedude=nil;Menu._multi=nil;Menu._battle=nil;Menu._onClose=nil
    press('a');T.eq(Menu.mode,'message','full party member begins native learning message')
    press('a');T.eq(Menu.mode,'message','A advances to already-four-moves message')
    T.check(Menu._messageText and Menu._messageText:find('already has 4',1,true),'actual already-four-moves page remains visible')
    press('a');T.eq(Menu.mode,'yesno','A after four-moves page opens delete/replace question')
    T.check(Menu._yesNoPrompt and Menu._yesNoPrompt:find('Delete',1,true),'actual native replacement question is shown')
    T.eq(Bag.get(s.bag,912),3,'messages and question consume no TM')
    return m
  end
  for _,mode in ipairs({0,1})do
    for _,accept in ipairs({false,true})do
      local m=start(mode)
      if accept then
        press('a');T.check(Summary.isOpen(),'YES opens real native move-selection summary')
        Summary.handleInput(key('a'));T.eq(m.moves[1],57,'real summary refuses to forget Surf')
        T.check(Summary.isOpen(),'HM refusal keeps selection open')
        Summary.handleInput(key('down'));Summary.handleInput(key('a'))
        T.eq(Summary.isOpen(),false,'selecting an ordinary move closes the native summary')
        for i=1,8 do if Menu.mode=='message'then press('a')end end
        T.eq(m.moves[2],X.id('DRAIN_PUNCH'),'real input continuation replaces selected ordinary move')
        T.eq(m.moves[1],57,'native replacement retains protected HM')
        T.eq(Bag.get(s.bag,912),mode==1 and 3 or 2,'real completed workflow obeys Infinite TMs setting')
        T.eq(Learn.busy(),false,'successful native teaching releases continuation')
      else
        press('b');T.eq(Menu.mode,'yesno','decline opens native stop-learning question')
        press('a');for i=1,4 do if Menu.mode=='message'then press('a')end end
        T.eq(m.moves[2],86,'declining replacement preserves all four moves')
        T.eq(Bag.get(s.bag,912),3,'declining replacement consumes no TM')
        T.eq(Learn.busy(),false,'declining native teaching releases continuation')
      end
    end
    local m=start(mode);press('a');T.check(Summary.isOpen(),'cancellation case opens real move selection')
    Summary.handleInput(key('b'));T.eq(Menu.mode,'yesno','B from native move selection offers stop-learning question')
    press('a');for i=1,4 do if Menu.mode=='message'then press('a')end end
    T.eq(m.moves[2],86,'cancelled summary preserves existing moves');T.eq(Bag.get(s.bag,912),3,'cancelled summary consumes no TM')
    T.eq(Learn.busy(),false,'cancelled summary releases learning flow')
  end
  Learn.reset();Summary.close();s.party,s.bag=oldParty,oldBag;Stack._layers=layers
  for k in pairs(Menu)do Menu[k]=nil end;for k,v in pairs(saved)do Menu[k]=v end
  for k in pairs(fixtures)do Text.overrides[k]=overrides[k]end
  setting('ITEM_MODE_INFINITE_TMS',1)
  print('TM replacement: actual message A presses, delete/stop choices, summary selection/HM refusal/cancel and successful consumption')
end
