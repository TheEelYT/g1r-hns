return function(T,game,world)
  local Rt=require('src.core.game3.runtime');local Stack=require('src.ui.game3.stack')
  local Dex=require('src.core.game3.dex');local P=require('src.core.game3.pokemon')
  local NativeDex=require('src.ui.game3.rse.pokedex');local Card=require('src.ui.game3.trainer_card')
  local Audio=require('src.core.game3.audio');local saved=Rt.session;local layers=Stack._layers
  local s={map=world.startup.start.map,version='emerald',name='GENE',gender=0,dex=Dex.new(),flags={},vars={},party={}}
  Rt.session=s;Stack._layers={}
  local function key(k)return {wasPressed=function(_,v)return v==k end}end
  local R=game._hnsCollection.registration
  T.eq(#world.pokedex.registrationEntries,386,'all supported national species have source registration data')
  local done,cries=0,0;local cry=Audio.playCry;Audio.playCry=function(sp)T.eq(sp,161,'registration cry is the caught species');cries=cries+1 end
  Dex.setCaught(s.dex,161);require('src.core.game3.party').giveMon(s,161,5,'SCOUT')
  local row=R.rows[161];T.eq(row.speciesName,'SENTRET','native Sentret resolves correct source entry')
  T.check(row.footprint~=nil,'source registration includes footprint')
  local ht,wt=R.measurements(row,false);T.eq(ht,'0.8 m','metric height uses source units');T.eq(wt,'6.0 kg.','metric weight uses source units')
  ht,wt=R.measurements(row,true);T.eq(ht,'2’07”','imperial height rounds with source integer formula');T.eq(wt,'13.2 lbs.','imperial weight rounds with source formula')
  NativeDex.showCaughtMon(161,{session=s,personality=1234,onDone=function()done=done+1 end})
  T.eq(Stack.top().id,R.ID,'actual capture entry dispatch uses HnS modal')
  NativeDex.Host.handleInput(key('a'));T.eq(R.phase,'in','input cannot skip registration fade-in')
  R.update(16/60);T.eq(R.phase,'wait','source palette fade completes');T.eq(cries,1,'entry cry plays exactly once')
  T.check(pcall(R.draw),'HGSS Plus registration background/text/types draw')
  NativeDex.Host.handleInput(key('b'));T.eq(R.phase,'out','native battle input closes source registration')
  R.update(10/60);T.eq(R.x,68,'source sprite slides two pixels/frame');T.eq(R.y,66,'source sprite slides one pixel/frame');T.eq(done,0,'nickname callback waits for transition')
  R.update(26/60);T.eq(done,1,'native nickname continuation runs once');T.eq(R.isOpen(),false,'registration modal releases')
  T.check(Dex.isCaught(s.dex,161),'registered catch flag remains native');T.eq(#s.party,1,'registration does not duplicate catch storage')
  Audio.playCry=cry
  -- Reproduce the complete native post-catch continuation, not just an arbitrary
  -- onDone callback. The captured mon, nickname prompt and naming UI are real.
  do
    local Battle=require('src.core.game3.battle');local Ui=require('src.core.game3.battle.ui')
    local Msg=require('src.ui.game3.message');local Hud=require('src.ui.game3.hud')
    local Choice=require('src.ui.game3.choice');local Anim=require('src.core.game3.battle.anim')
    local RomText=require('src.core.game3.rom_text');local TextIR=require('src.core.game3.scripting.text_ir')
    local Font=require('src.ui.game3.frlg_font')
    local wrap=Font.wrap;local active,headless,st,phase=Battle._active,Battle._headless,Battle._st,Battle._phase
    local animHeadless=Anim._headless
    local savedText={}
    for k,v in pairs({gText_BattleYesNoChoice='YES\nNO',gText_PkmnsNickname='’s nickname?'})do savedText[k]=RomText.overrides[k];RomText.overrides[k]=TextIR.fromAscii(v)end
    Font.wrap=function(v)return v end
    local mon=s.party[1]
    Battle._active=true;Battle._headless=false;Anim._headless=true
    Battle._st=require('src.core.game3.battle.state').new({session=s,wild=true,playerParty={mon},foeParty={mon}})
    Battle._st.session=s;Ui.reset({headless=true});Ui._headless=false;Ui._st=Battle._st
    local input=key(nil);input.isDown=function()return false end
    local host={input=input};Battle.startPostCatchFlow({firstTimeCaught=true,mon=mon,location='party'})
    local function frame(k)
      host.input=key(k);host.input.isDown=function()return false end
      Battle.update(1/60,host);Msg.tick();Hud.update(host,1/60,Stack.top())
    end
    for i=1,20 do frame()end;frame('a');for i=1,220 do frame()end
    T.eq(Battle._phase,'catch_nickname_prompt','real native capture returns to nickname prompt')
    if Ui.beginCaughtDexScene then
      T.check(Ui._caughtDexScene and Ui._caughtDexScene.sprite.img,'new engine receives the actual registration sprite')
      T.eq(Ui._caughtDexScene.species,161,'new engine caught return retains the captured species')
      T.eq(Ui._caughtDexScene.sprite.x,120,'registration sprite returns to battle center')
    end
    T.check(Msg.isOpen(),'native nickname text remains open after registration')
    T.check(Choice.active,'native Yes/No opens after registration prompt prints')
    T.check(Msg.currentPage():find('SCOUT',1,true)~=nil,'source nickname prompt identifies the actual captured mon')
    frame('a')
    local Naming=require('src.ui.game3.naming')
    T.eq(Battle._phase,'catch_naming','Yes enters actual naming state')
    T.check(Naming.isOpen() and Stack.has('naming'),'native keyboard modal opens')
    Naming._state.name='SENTINEL';frame('start');frame('a')
    T.eq(Naming.isOpen(),false,'native keyboard OK input confirms and closes')
    T.eq(mon.nickname,'SENTINEL','native nickname continuation writes the caught mon')
    T.eq(Battle._phase,'ending','confirmed nickname releases battle into its ending state')
    T.eq(#s.party,1,'nickname does not store a duplicate party mon')
    -- A previously registered catch takes the direct prompt; B declines safely.
    Ui.reset({headless=true});Ui._headless=false;Ui._st=Battle._st
    Battle.startPostCatchFlow({firstTimeCaught=false,mon=mon,location='party'})
    for i=1,220 do frame()end
    T.check(Choice.active,'repeat catch presents native Yes/No without registration')
    frame('b');T.eq(Battle._phase,'ending','declining repeat-catch nickname releases battle')
    T.eq(mon.nickname,'SENTINEL','declining retains the caught nickname')
    Msg.reset();Choice.reset();Ui.reset({headless=true});Stack._layers={}
    Battle._active=active;Battle._headless=headless;Battle._st=st;Battle._phase=phase;Battle._rseDex=nil
    for k,v in pairs({gText_BattleYesNoChoice=true,gText_PkmnsNickname=true})do RomText.overrides[k]=savedText[k]end
    Font.wrap=wrap;Anim._headless=animHeadless
  end
  -- Imported Hoenn order data is unavailable in the ROM-free fixture.
  local packReader=Dex.packReader;Dex.resetPacks()
  Dex.packReader=function(version,rel)if rel:match('hoenn')or rel:match('regional_dex')then return 'return {count=202,order={},toHoenn={}}'end;return packReader(version,rel)end
  Card.show({session=s});T.check(Card.open and Card._card,'actual native card gathers save data')
  T.check(pcall(Card.draw),'HnS front card draws source palette/portrait/badges')
  Card.handleInput(key('a'));T.check(Card._flip~=nil,'native card retains flip animation')
  for i=1,60 do Card.update(1/60)end
  local RomText=require('src.core.game3.rom_text');local title=RomText.overrides.gText_Var1sTrainerCard
  RomText.overrides.gText_Var1sTrainerCard=require('src.core.game3.scripting.text_ir').fromAscii("{STR_VAR_1}'s TRAINER CARD")
  T.eq(Card.side,'back','native card flip reaches reverse side');T.check(pcall(Card.draw),'HnS reverse card draws saved party and native statistics')
  local cached=P._icons[161];local image=love.graphics.newImage(love.image.newImageData(32,32));local quad=love.graphics.newQuad(0,0,32,32,32,32)
  P._icons[161]={image=image,quads={[0]=quad},frames=1,w=32,h=32}
  local nativeDraw=love.graphics.draw;local icons=0
  love.graphics.draw=function(im,q,x,y,...)if im==image then icons=icons+1;T.eq(x,24,'saved-party icon uses source X');T.eq(y,108,'saved-party icon uses source Y')end;return nativeDraw(im,q,x,y,...)end
  Card.draw();T.eq(icons,1,'reverse card submits actual saved-party species icon')
  love.graphics.draw=nativeDraw;P._icons[161]=cached
  RomText.overrides.gText_Var1sTrainerCard=title
  Card.handleInput(key('a'));T.eq(Card.open,false,'native card exit releases modal')
  Dex.packReader=packReader;Dex.resetPacks()
  local G=game._hnsGear.gear;G.show({session=s})
  G.page='condition';T.check(pcall(G.draw),'source condition page draws saved graph')
  local points=G.pages.graph({cool=255,tough=255,smart=255,cute=255,beauty=255})
  T.eq(points[1],155,'condition graph source center X');T.eq(points[2],56,'max cool reaches source graph top')
  s.party[1].ribbons={champion=true,cool=2};G.page='ribbons';G.cursor=1;T.eq(#G.pages.ribbonRows(),1,'ribbons list only contains actual ribbon winners')
  for i=1,20 do G.handleInput(key(nil))end;G.handleInput(key('a'));for i=1,40 do G.handleInput(key(nil))end;T.eq(G.page,'ribbonSummary','ribbons opens actual earned ribbon icons')
  T.eq(#G.pages.ribbonIds(s.party[1]),3,'native packed ribbons expand contest ranks')
  T.check(pcall(G.draw),'source ribbon summary draws');G.handleInput(key('b'));for i=1,40 do G.handleInput(key(nil))end;T.eq(G.page,'ribbons','summary returns to list')
  for _,page in ipairs({'phone','radio','map'})do G.page=page;G.region='johto';G.mapX=10;G.mapY=10;G.tuning=13;T.check(pcall(G.draw),'source gear '..page..' page draws')end
  G.close();Rt.session=saved;Stack._layers=layers
  print('HnS collection: native caught-entry/nickname callback, source card with native flip, condition graph and earned ribbon services')
end
