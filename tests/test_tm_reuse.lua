return function(T,game,w,s,mon,setting)
  local Use=require('src.core.game3.item_use');local Items=require('src.core.game3.items_data')
  local P=require('src.core.game3.pokemon');local Bag=require('src.core.game3.bag')
  local Menu=require('src.ui.game3.party_menu');local Learn=require('src.core.game3.battle.learn_move')
  local X=game._hnsExpandedMoves.moves;local Teaching=game._hnsTeaching.teaching
  local party,bag=s.party,s.bag;local before={};for k,v in pairs(Menu)do before[k]=v end
  local begin=Learn.begin;local function key(k)return{wasPressed=function(_,name)return name==k end,isDown=function()return false end}end
  local function setup(full)
    local learner=mon(62);learner.moves=full and{901,250,86,150}or{};learner.pp=full and{5,15,20,40}or{}
    s.party={learner};s.bag=Bag.new();Bag.add(s.bag,912,3)
    Menu.open=true;Menu.mode='use';Menu.cursor=1;Menu._party=s.party;Menu._session=s;Menu._bag=s.bag;Menu._item=912
    Menu._layout='single';Menu._hpAnim=nil;Menu._onSelect=nil;Menu._pokedude=nil;Menu._multi=nil;Menu._battle=nil
    return learner
  end
  Menu.cursor=5;Menu.mode='summary';Menu._onClose=function()end
  local callback=Menu._onClose
  local factory=assert(load(T.readAsset('hns_party_tm.lua')))();factory(Menu,Teaching)
  T.eq(Menu.cursor,5,'constructing private TM handler preserves native cursor')
  T.eq(Menu.mode,'summary','constructing private TM handler preserves native mode')
  T.eq(Menu._onClose,callback,'constructing private TM handler preserves native continuation')
  Menu._onClose=nil
  for _,mode in ipairs({0,1})do
    setting('ITEM_MODE_INFINITE_TMS',mode);local learner=setup(false)
    T.eq(Items.info(912).importance,mode,'source TM importance follows saved option')
    T.eq(Use.useTm(s,s.bag,912,1),true,'direct native TM API teaches with mode '..mode)
    T.eq(Bag.get(s.bag,912),mode==1 and 3 or 2,'direct native TM API consumption follows mode')
    T.eq(Use.useTm(s,s.bag,912,1),false,'duplicate direct teaching fails')
    T.eq(Bag.get(s.bag,912),mode==1 and 3 or 2,'duplicate direct teaching never consumes')
    learner=setup(false);local currentBag=s.bag
    Menu.handleInput(key('a'))
    T.eq(learner.moves[1],X.id('DRAIN_PUNCH'),'actual party-menu Use teaches source machine')
    T.eq(Bag.get(currentBag,912),mode==1 and 3 or 2,'actual party-menu immediate learning obeys reuse mode')
    T.eq(Menu.mode,'message','actual native learning message is retained')
    Menu.handleInput(key('a'))
    for _,accepted in ipairs({false,true})do
      learner=setup(true);currentBag=s.bag;local pending
      -- Capture the genuine native party-menu continuation at the graphical
      -- choice boundary. Run its deferred consumption after a later choice.
      Learn.begin=function(opts)pending=opts end
      Menu.handleInput(key('a'));Learn.begin=begin
      T.check(pending and type(pending.onDone)=='function','full move list enters actual native learning continuation')
      T.eq(Bag.get(currentBag,912),3,'opening replacement choice does not consume a TM')
      if accepted then T.eq(P.replaceMove(learner,4,X.id('DRAIN_PUNCH')),150,'native move replacement succeeds')end
      pending.onDone(accepted)
      T.eq(Bag.get(currentBag,912),accepted and mode==0 and 2 or 3,'deferred replacement/cancellation obeys source consumption')
      T.eq(learner.moves[1],901,'replacement never overwrites existing HM-protected slot')
      T.eq(learner.moves[4],accepted and X.id('DRAIN_PUNCH')or 150,'decline preserves original move list')
    end
  end
  -- Source importance is read when the completed replacement consumes the TM.
  for _,initial in ipairs({0,1})do
    setting('ITEM_MODE_INFINITE_TMS',initial);local learner=setup(true);local currentBag=s.bag;local pending
    Learn.begin=function(opts)pending=opts end;Menu.handleInput(key('a'));Learn.begin=begin
    setting('ITEM_MODE_INFINITE_TMS',1-initial);P.replaceMove(learner,4,X.id('DRAIN_PUNCH'));pending.onDone(true)
    T.eq(Bag.get(currentBag,912),initial==0 and 3 or 2,'late continuation reads current source importance')
  end
  setting('ITEM_MODE_INFINITE_TMS',0);local learner=setup(false)
  local row=Teaching.byId[912];local importance=row.importance;row.importance=1
  T.eq(Use.useTm(s,s.bag,912,1),true,'source-important machine can teach');T.eq(Bag.get(s.bag,912),3,'source-important machine stays reusable with option OFF');row.importance=importance
  local learner=setup(false);Menu._item=908;Bag.add(s.bag,908,1)
  Menu.handleInput(key('a'));T.eq(Menu.mode,'message','unreviewed TM effect produces explicit native party message')
  T.eq(#learner.moves,0,'unreviewed TM effect teaches nothing');T.eq(Bag.get(s.bag,908),1,'unreviewed TM effect is not consumed')
  T.eq(Teaching.reusable({map='EM_ROUTE101'},912),false,'foreign sessions do not gain infinite TMs')
  Learn.begin=begin;Menu.close();s.party,s.bag=party,bag
  for k in pairs(Menu)do Menu[k]=nil end;for k,v in pairs(before)do Menu[k]=v end
  setting('ITEM_MODE_INFINITE_TMS',1)
end
