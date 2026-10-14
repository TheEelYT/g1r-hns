return function(T,game,w,s)
  local G=game._hnsGear.gear;local Q=w.startup;local Audio=require('src.core.game3.audio');local Stack=require('src.ui.game3.stack')
  local Start=require('src.ui.game3.start_menu');local Window=require('src.ui.game3.window');local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
  local C=require('src.core.game3.constants').of('emerald');local played={};local oldPlay=Audio.playSe
  Audio.playSe=function(id)played[#played+1]=id;return true end
  local function input(key)return {wasPressed=function(_,k)return k==key end}end
  G.show({session=s});T.eq(played[#played],w.audio.menuSounds.SE_POKENAV_ON,'opening gear uses source ON cue')
  for i=1,16 do G.handleInput(input(nil))end
  local n=#played;G.handleInput(input('down'));T.eq(#played,n+1,'home cursor plays one selection sound');T.eq(played[#played],w.audio.menuSounds.SE_SELECT,'home cursor uses source SELECT cue')
  G.cursor=1;G.handleInput(input('a'));T.eq(played[#played],w.audio.menuSounds.SE_SELECT,'opening map uses source SELECT cue')
  for i=1,40 do G.handleInput(input(nil))end
  G.handleInput(input('b'));T.eq(played[#played],w.audio.menuSounds.SE_SELECT,'back to home uses source SELECT cue')
  for i=1,40 do G.handleInput(input(nil))end
  G.handleInput(input('b'));T.eq(played[#played],w.audio.menuSounds.SE_POKENAV_OFF,'closing gear uses source OFF cue')
  n=#played;for i=1,16 do G.handleInput(input(nil))end;T.eq(#played,n,'fade completion does not duplicate close sound');T.eq(Stack.has(G.ID),false,'gear closes after its fade')
  T.eq(Q.gearLabel,'{POKE}GEAR','start label retains source compound glyph token')
  T.eq(table.concat(Q.ui.composites.POKE,','),'85,86','POKE token uses both source glyphs')
  Flags.setFlag(Space.store,nil,C:flag('FLAG_SYS_POKENAV_GET'),true)
  local Text=require('src.core.game3.rom_text');local IR=require('src.core.game3.scripting.text_ir');local saved={}
  for _,key in pairs(require('src.ui.game3.rse.start_menu_data').TEXT)do if not saved[key]then saved[key]={Text.overrides[key]};Text.overrides[key]=IR.fromAscii(key)end end
  Start.show({session=s,game={session=s}})
  local label;for _,row in ipairs(Start.ENTRIES)do if row.id=='pokenav'then label=row.label end end
  T.eq(label,Q.gearLabel,'actual start-menu hook uses source label')
  local lg=love.graphics;local draw,quad=lg.draw,lg.newQuad;local calls={}
  lg.newQuad=function(a,b,c,d)return {a,b,c,d}end
  lg.draw=function(_,q,x,y)calls[#calls+1]={q[1],q[2],q[3],q[4],x,y}end
  Window.printPx(label,100,50)
  lg.draw=draw;lg.newQuad=quad
  T.eq(#calls,12,'source label draws two compound glyphs and four letters, with shadows')
  T.eq(calls[1][1],80,'first compound glyph is source 0x55');T.eq(calls[3][1],96,'second compound glyph is source 0x56')
  T.eq(calls[1][2],80,'compound glyph source row');T.eq(calls[1][6],50,'compound glyph aligns to native menu text origin')
  Start.close(true);Flags.setFlag(Space.store,nil,C:flag('FLAG_SYS_POKENAV_GET'),false);Audio.playSe=oldPlay
  for key,row in pairs(saved)do Text.overrides[key]=row[1]end
  G.show({session=s})
end
