-- Capture the actual Lua UI draw calls for CPU pixel rendering, without a ROM.
package.path='./?.lua;./?/init.lua;'..package.path
_G.love=require('tests.love_stub')
require('src.core.GameVersion').set('emerald')
require('src.import.gba.versions').select('emerald')
local root=assert(arg[1]);local output=assert(arg[2]);local w=dofile(root..'/world.lua')
local mod={read=function(_,file)local f=assert(io.open(root..'/'..file,'rb'));local b=f:read('*a');f:close();return b end}
local frames={};local draws={};local color={1,1,1,1};local clip
love.graphics.setScissor=function(...)clip=select('#',...)>0 and {...}or nil end
love.graphics.getScissor=function()if clip then return unpack(clip)end end
love.graphics.setColor=function(...)color={...}end
love.graphics.rectangle=function(mode,x,y,width,height)draws[#draws+1]={op='rect',clip=clip,color=color,x=x,y=y,w=width,h=height,mode=mode}end
love.graphics.polygon=function(mode,...)draws[#draws+1]={op='polygon',clip=clip,color=color,points={...}}end
love.graphics.draw=function(...)
  local a={...};local im=a[1];local q,x,y,rotation,sx,sy,ox,oy
  if type(a[2])=='table'then q,x,y,rotation,sx,sy,ox,oy=unpack(a,2)
  else q={x=0,y=0,w=im.w,h=im.h};x,y,rotation,sx,sy,ox,oy=unpack(a,2)end
  assert(q.x>=0 and q.y>=0 and q.x+q.w<=im.w and q.y+q.h<=im.h,'out-of-sheet UI quad: '..tostring(im.file))
  draws[#draws+1]={op='image',clip=clip,file=assert(im.file),iw=im.w,ih=im.h,q={q.x,q.y,q.w,q.h},x=x,y=y,sx=sx or 1,sy=sy or 1,rotation=rotation or 0,ox=ox or 0,oy=oy or 0,color=color}
end
love.graphics.newImage=function(data)return {w=data.w,h=data.h,setFilter=function()end,getDimensions=function(self)return self.w,self.h end}end
local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui)
local img=U.image
U.image=function(file,x,y)local im=img(file,x,y);im.file=file;return im end
local M=assert(load(mod:read('settings.lua')))()(w.startup.settings,U)
local function snap(name,fn)draws={};fn();frames[#frames+1]={name=name,draws=draws}end
local m=M.new('challenge')
local pc=M.new('challenge',nil,false);pc.tab=#pc.pages
snap('pc_last_challenges',function()M.draw(pc)end)
local loaded=M.new('option',nil,false);loaded.tab=#loaded.pages;snap('loaded_last_options',function()M.draw(loaded)end)
local options=M.new('option');options.tab=3;snap('options_sound',function()M.draw(options)end)
options.tab=2;options.cursor=6
for value=0,3 do options.values.ITEM_BATTLE_RUN_TYPE=value;snap('quick_run_'..value,function()M.draw(options)end)end
options.tab=1;options.cursor=7;snap('pending_option',function()M.draw(options)end)
snap('mode_recommended',function()M.draw(m)end)
m.values.ITEM_MODE_GAMEMODE=1;m.cursor=2;snap('mode_custom',function()M.draw(m)end)
m.tab=3;m.cursor=2;snap('randomizer_off',function()M.draw(m)end)
m.tab=4;m.cursor=2;snap('nuzlocke_off',function()M.draw(m)end)
m.tab=6;m.confirm=true;m.yes=true;snap('confirm',function()M.draw(m)end)
local Audio=require('src.core.game3.audio');Audio.playSe=function()end
local UI=assert(load(mod:read('presentation_ui.lua')))()(mod,w,{},M,U,{})
snap('information',UI.help.draw)
UI.phone.show(w.startup.disasterText:gsub('{PLAYER}','GENE'),function()end,'PROF.ELM');UI.phone.offset=0;UI.phone.state='ring';UI.phone.timer=9
snap('phone_ringing',UI.phone.draw)
UI.phone.state='text';UI.phone.reveal=999;UI.phone.complete=true;UI.phone.timer=0
snap('phone_call',UI.phone.draw)
local Gear=assert(load(mod:read('gear_menu.lua')))()(U)
Gear.tick=0;snap('pokegear_glow_low',function()Gear.draw({'MAP','CONDITION','PHONE','SWITCH OFF'},1,'johto')end)
Gear.tick=64;snap('pokegear_glow_peak',function()Gear.draw({'MAP','CONDITION','PHONE','SWITCH OFF'},1,'johto')end)
snap('pokegear_early',function()Gear.draw({'MAP','PHONE','SWITCH OFF'},1,'johto')end)
snap('pokegear_header_slide_06',function()Gear.draw({'MAP','PHONE','SWITCH OFF'},1,'johto',6)end)
snap('pokegear_radio',function()Gear.draw({'MAP','CONDITION','PHONE','RADIO','SWITCH OFF'},4,'johto')end)
snap('pokegear_all',function()Gear.draw({'MAP','CONDITION','PHONE','RADIO','RIBBONS','SWITCH OFF'},5,'johto')end)
local game={};assert(load(mod:read('battle_presentation.lua')))()(mod,w,game)
local P=game._hnsBattlePresentation.presentation
-- Use the source metadata at the missing imported-ROM move boundary.
local Moves=require('src.core.game3.battle.moves');local row=w.startup.rules.moves.TACKLE
Moves.get=function(id)return {numId=id,power=row.power,accuracy=row.accuracy,category=row.category}end
local Bu=require('src.core.game3.battle.ui');Bu.reset({headless=true})
Bu._st={session={map=w.startup.start.map},player={mon={moves={33}}}};Bu._mode='moves'
local imgP=P.ui.image
-- The installer owns its own SourceUI cache, so mark those images too.
local actualUi=game._hnsBattlePresentation.presentation.ui
actualUi.image=function(file,x,y)local im=imgP(file,x,y);im.file=file;return im end
P.hintX=-30;for i=1,8 do P.step()end;snap('battle_hint_slide_08',P.draw)
for i=1,20 do P.step()end;snap('battle_move_hint',P.draw)
P.details=true;snap('battle_move_details',P.draw)
local Pokemon=require('src.core.game3.pokemon')
-- Missing imported-ROM pictures/types are supplied by the pinned source art.
local registrations={};local C=require('src.core.game3.constants').of('emerald')
for _,r in ipairs(w.pokedex.registrationEntries)do registrations[C:require('species','SPECIES_'..r.speciesName)]=r end
Pokemon.frontPic=function(sp)local r=registrations[sp];return r and {image=U.image(r.front.file,64,64)}end
Pokemon.types=function(sp)return ({[158]={11,11},[152]={12,12},[155]={10,10},[161]={0,0}})[sp]or {0,0}end
local session={version='emerald',map=w.startup.start.map,name='GENE',gender=0,dex=require('src.core.game3.dex').new(),flags={},vars={},party={{species=152,nickname='CHIKORITA',level=12,cool=180,beauty=120,cute=40,smart=100,tough=200,ribbons={cool=3,champion=true}}}}
local G={session=session,cursor=1,region='johto',mapX=19,mapY=15,tuning=13,station=w.startup.radioStations[1]}
function G.contacts()return {{name='PROF. ELM',description='{PKMN} PROF.',trainerName='PROF. ELM'},{name='MOM',description='CALM & KIND',trainerName='MOM'}}end
function G.locationName()return 'NEW BARK TOWN'end
local Pages=assert(load(mod:read('gear_pages.lua')))()(mod,w,U,G)
for _,page in ipairs({'map','phone','radio','condition','ribbons','ribbonSummary'})do
  G.page=page;snap('gear_'..page,Pages.draw)
end
local collection={_hnsRules={rules={value=function()return 1 end}}};assert(load(mod:read('dex_state.lua')))()(mod,w,collection);assert(load(mod:read('collection_screens.lua')))()(mod,w,collection)
local R=collection._hnsCollection.registration
local imageR=R.ui.image;R.ui.image=function(file,x,y)local im=imageR(file,x,y);im.file=file;return im end
R.show(161,{session=session});R.phase='wait';R.fade=0
snap('caught_registration',R.draw)
R.phase='out';R.fade=8;R.x=64;R.y=64;snap('registration_slide',R.draw);R.close()
assert(load(mod:read('pokedex.lua')))()(mod,w,collection)
local P=collection._hnsDex.ui;local imageD=P.ui.image
P.ui.image=function(file,x,y)local im=imageD(file,x,y);im.file=file;return im end
local Dex=require('src.core.game3.dex');Dex.setCaught(session.dex,158);Dex.setSeen(session.dex,155)
Pokemon.icon=function()return nil end
P.cursor=7;P.show(session.dex,{session=session});P.animation=nil;snap('pokedex_list',P.draw)
P.ownedOnly=true;for _,sp in ipairs({19,161,10,69})do Dex.setCaught(session.dex,sp)end;P.cursor=1;P.show(session.dex,{session=session});P.animation=nil;snap('pokedex_five_caught',P.draw)
P.ownedOnly=false;P.cursor=7;P.show(session.dex,{session=session});P.animation=nil
P.scroll={tick=4,delta=1};snap('pokedex_scroll_04',P.draw);P.scroll=nil
P.animation={kind='portrait',tick=12,page='info'};snap('pokedex_to_info_12',P.draw);P.animation=nil
P.page='info';snap('pokedex_detail_totodile',P.draw)
P.page='stats';snap('pokedex_stats_totodile',P.draw)
P.tick=6;snap('pokedex_stats_icon_frame1',P.draw)
for _,kind in ipairs({'level','TM','HM','tutor'})do
  for i,m in ipairs(P.moves(P.row()))do if m.kind==kind then P.moveCursor=i;break end end
  snap('pokedex_move_'..kind,P.draw)
end
P.moveCursor=1
P.toggle=true;snap('pokedex_ev_totodile',P.draw)
P.cursor=4;P.page='info';snap('pokedex_seen_only',P.draw)
P.page='list';P.cursor=1;P.tick=0;snap('pokedex_list_first',P.draw)
P.cursor=2;snap('pokedex_list_unseen',P.draw)
P.cursor=#P.rows;snap('pokedex_list_last',P.draw)
P.close()
local Card=require('src.ui.game3.trainer_card');Card._session=session;Card._card={female=false,stars=0,playerName='GENE',trainerId=12345,money=3000,playTimeHours=3,playTimeMinutes=21,hasPokedex=true,badges={[1]=true}}
local cardUi=collection._hnsCollection.card.ui
local imageK=cardUi.image;cardUi.image=function(file,x,y)local im=imageK(file,x,y);im.file=file;return im end
Card.side='front';snap('trainer_card_gold',collection._hnsCollection.card.draw)
Card._card.female=true;snap('trainer_card_kris',collection._hnsCollection.card.draw)
local RomText=require('src.core.game3.rom_text');RomText.overrides.gText_Var1sTrainerCard=require('src.core.game3.scripting.text_ir').fromAscii("{STR_VAR_1}'s TRAINER CARD")
Pokemon.icon=function()return nil end
Card.side='back';snap('trainer_card_back',collection._hnsCollection.card.draw)
-- Actual native bag skin with source assets, including both extra pockets.
assert(load(mod:read('bag_services.lua')))()(mod,w,collection)
local bagUi=collection._hnsBag.ui;local imageB=bagUi.image
bagUi.image=function(file,x,y)local im=imageB(file,x,y);im.file=file;return im end
local Menu=require('src.ui.game3.bag_menu');local Skin=require('src.ui.game3.rse.bag_menu');local Items=require('src.core.game3.items_data');local Bag=require('src.core.game3.bag')
local IR=require('src.core.game3.scripting.text_ir')
for k,t in pairs({gMenuText_Use='USE',gMenuText_Toss='TOSS',gMenuText_Give='GIVE',gText_Cancel2='CANCEL',gText_Var1IsSelected='{STR_VAR_1} is selected.',gText_CloseBag='CLOSE BAG',gText_xVar1='×{STR_VAR_1}',gText_ReturnToVar1='Return to the field.',gText_NumberItem_TMBerry='{STR_VAR_1} {STR_VAR_2}'})do RomText.overrides[k]=IR.fromAscii(t)end
Items._byId={[13]={name='POTION',pocket='ITEMS',description='Restores HP.'},[86]={name='REPEL',pocket='ITEMS',description='Repels wild Pokémon.'},[139]={name='ORAN BERRY',pocket='BERRY_POUCH',description='Restores HP.'},[902]={name='GB SOUNDS',pocket='KEY_ITEMS',importance=1},[903]={name='EXP. SHARE',pocket='KEY_ITEMS',importance=1}}
require('src.core.game3.runtime').session=session;session.bag=Bag.new()
for _,id in ipairs({13,86,139,902,903})do Bag.add(session.bag,id,1)end
for _,p in ipairs({'ITEMS','MEDICINE','BERRY_POUCH','KEY_ITEMS'})do
  Menu.show(session.bag,{session=session,pocket=p});Menu._open=nil
  snap('bag_'..p:lower(),function()Skin.draw(Menu)end);Menu.close()
end
Menu.show(session.bag,{session=session,pocket='ITEMS'});Menu._open=nil;Menu.mode='action';Menu.ACTIONS={'USE','GIVE','TOSS','CANCEL'}
local Window=require('src.ui.game3.window');local stdFrame=Window.stdFrame
Window.stdFrame=function(t)U.box(t.left*8,t.top*8,t.width*8,t.height*8)end
snap('bag_actions',function()Skin.draw(Menu)end);Menu.close();Window.stdFrame=stdFrame
snap('bag_escape_label',function()U.text('ESCAPE ROPE',8,16,nil,nil,'narrow')end)
-- Draw the actual source battle background/healthbox modules. Only imported
-- ROM names/gender and the clock are fixtures, as in the other CPU captures.
if w.battleVisuals then
  local choices={ITEM_BATTLE_NEW_BATTLEUI=0,ITEM_BATTLE_NEW_BACKGROUNDS=0}
  collection._hnsRules={rules={own=function()return true end,battle=function()return true end,value=function(id)return choices[id]or 0 end}}
  local Rtc=require('src.core.game3.rtc');local calc=Rtc.calcLocalTime;Rtc.calcLocalTime=function()return {hours=12,minutes=0}end
  assert(load(mod:read('battle_visuals.lua')))()(mod,w,collection)
  local V=collection._hnsBattleVisuals.visuals;local imageV=V.ui.image
  V.ui.image=function(file,x,y)local im=imageV(file,x,y);im.file=file;return im end
  local Battle=require('src.core.game3.battle');Battle._st={session=session,wild=true}
  local stage=require('src.core.game3.battle.anim').stage();stage.healthbox.player.visible=true;stage.healthbox.enemy.visible=true
  local p={species=158,mon={species=158,nickname='TOTODILE',gender='M',level=20,hp=40,maxHp=60,status='PAR',experience=8000}}
  local e={species=161,mon={species=161,nickname='SENTRET',gender='F',level=18,hp=40,maxHp=60,status='PSN'}}
  for _,style in ipairs({'gen3','gen4'})do
    choices.ITEM_BATTLE_NEW_BATTLEUI=style=='gen4'and 1 or 0
    snap('battle_'..style,function()require('src.core.game3.battle.bg').draw(0,0,0,0);require('src.core.game3.battle.healthbox').draw('player',p);require('src.core.game3.battle.healthbox').draw('enemy',e)end)
  end
  Battle._st=nil;Rtc.calcLocalTime=calc
end
-- Door frames and gold flash are native drawing routines with source buffers.
collection.data={maps=w.maps}
assert(load(mod:read('field_services.lua')))()(mod,w,collection)
local fieldUi=collection._hnsServices.ui;local imageF=fieldUi.image
fieldUi.image=function(file,x,y)local im=imageF(file,x,y);im.file=file;return im end
local door
for pair,rows in pairs(w.services.doors)do for _,a in pairs(rows)do if a.graphic:find('NewBarkTown_Door_Red_hns',1,true)then door=a;break end end;if door then break end end
if door then
  local Doors=require('src.core.game3.doors')
  for f=1,3 do Doors._activeAnim={hns=door,frame=f,x=7,y=6};snap('new_bark_door_'..f,function()bg='';love.graphics.setColor(.6,.7,.5,1);love.graphics.rectangle('fill',0,0,240,160);Doors.draw(0,0)end)end
  Doors.release()
end
local Arrow=require('src.core.game3.warp_arrow')
local Collision=require('src.core.game3.collision')
session.map='EM_HNS_CHERRYGROVE_CITY_POKEMON_CENTER_HNS'
local maps={};for mid,m in pairs(w.maps)do local d={};for k,v in pairs(m)do d[k]=v end
  d.midLayout=require('src.core.game3.layout_native').fromDecoded(require('src.import.gba.native_pack').decodeMidLayout(mod:read(m.hnsLayoutFile)),mid,m.pair);maps[mid]=d
end
collection.data.maps=maps
local Interactions=require('src.core.game3.scripting.interaction_scripts')
for pair,p in pairs(w.pairs)do local b={};for mid,name in pairs(p.behaviors)do b[tonumber(mid)]=require('src.core.game3.mb').id(name)end;Interactions.behaviors[pair]=b end
Collision.bindMap(collection,session.map,maps[session.map])
local exit;for _,warp in ipairs(maps[session.map].warps)do if Collision.arrowWarpDir(Collision.behavior(warp.x,warp.y))=='down'then exit=warp;break end end
assert(exit,'native Pokémon Center exit has arrow warp behavior')
Arrow.hide();Arrow.update({cellX=exit.x,cellY=exit.y,facing='down'})
assert(Arrow._state.visible,'native exit makes arrow visible')
for f=0,1 do
  snap('exit_arrow_gold_'..f,function()Arrow.draw(Arrow._state.cx*16-112,Arrow._state.cy*16-72)end)
  for i=1,32 do Arrow.step()end
end
Arrow.hide();session.map=w.startup.start.map
for _,id in ipairs({'7','1'})do snap('berry_tree_'..id,function()
  local t=w.services.berries[id].tree;local f=t.frames[8];love.graphics.draw(U.image(t.file,t.width,t.height),love.graphics.newQuad(0,f.y,f.w,f.h,t.width,t.height),112,72)
end)end
-- Capture the installed pause-clock wrapper with the absent ROM menu as boundary.
local Start=require('src.ui.game3.start_menu');local RTC=require('src.core.game3.rtc')
local baseStart,baseRTC=Start.draw,RTC.calcLocalTime
Start.draw=function()end;RTC.calcLocalTime=function()return {hours=20,minutes=15}end
collection._hnsGear={hooks=true};assert(load(mod:read('pokegear.lua')))()(mod,w,collection,M,U)
-- Native labels are an imported-ROM boundary, as in the SDK regressions.
for i,label in ipairs({'TEXT SPEED','BATTLE SCENE','BATTLE STYLE','SOUND','BUTTON MODE','FRAME'})do
  RomText.overrides['sOptionMenuItemsNames['..(i-1)..']']=IR.fromAscii(label)
end
collection.options={};local O=collection._hnsGear.options;O.show({session=session});O.model.tab=#O.model.pages
snap('options_gen1recomp',O.draw)
for _,id in ipairs({'speed','video','graphics','audio'})do
  for _,r in ipairs(O.enginePages[1].rows)do if r.id=='group.'..id then r.activate(O.engineContext);break end end
  snap('options_native_'..id,O.draw);table.remove(O.enginePages)
end
O.close(false)
session.flags[w.startup.clockFlag]=true
require('src.core.game3.scripting.space').store=nil
Start.open=true;Start._session=session;snap('pause_clock',Start.draw)
Start.draw=baseStart;Start.open=false;RTC.calcLocalTime=baseRTC
local function encode(t)
  if type(t)=='string'then return string.format('%q',t)end
  if type(t)~='table'then return tostring(t)end
  local out={'{'};for k,v in pairs(t)do out[#out+1]='['..encode(k)..']='..encode(v)..',' end;out[#out+1]='}';return table.concat(out)
end
local f=assert(io.open(output,'w'));f:write('return ',encode(frames));f:close()
