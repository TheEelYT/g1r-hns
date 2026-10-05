-- Use native row descriptors and persistence hooks through the installed tab.
return function(T,game,w)
  local Rt=require('src.core.game3.runtime');local Stack=require('src.ui.game3.stack')
  local Options=require('src.core.game3.options');local Rows=require('src.ui.game3.option_rows')
  local old={session=Rt.session,layers=Stack._layers,options=game.options,write=game.writeOptions,apply=game.applyOptions}
  local s={version='emerald',map=w.startup.start.map,flags={},vars={}}
  Rt.session=s;Stack._layers={};game.options={speedOverworld=1,speedBattle=1,speedMenu=1,musicVol=7,sfxVol=7,musicFilter=0}
  local writes=0;local saved
  game.writeOptions=function(self)writes=writes+1;saved={};for k,v in pairs(self.options)do saved[k]=v end end
  game.applyOptions=function()end
  local O=game._hnsGear.options
  local function press(key)O.handleInput({wasPressed=function(_,k)return key==k end})end
  O.show({session=s});local count=#O.model.pages;O.model.tab=count-1;press('r')
  T.eq(O.model.pages[O.model.tab].id,'GEN1RECOMP','loaded options have a separate native tab')
  press('r');T.eq(O.model.tab,count,'native last tab R stays put');T.check(O.isOpen(),'native last R does not close menu')
  T.eq(O.model.confirm,nil,'native last R does not confirm HnS choices')
  local excluded={textSpeed=true,battleScene=true,battleStyle=true,sound=true,buttonMode=true,frameType=true}
  local restored={}
  for i,row in ipairs(O.enginePages[1].rows)do
    if row.group then
      O.enginePages[1].cursor=i;press('a');local p=O.enginePages[#O.enginePages]
      for _,r in ipairs(p.rows)do restored[r.id]=true end
      press('b')
    else restored[row.id]=true end
  end
  for _,r in ipairs(Rows.build(O.engineContext))do if not excluded[r.id]then T.check(restored[r.id],'native setting remains reachable: '..r.id)end end
  local function enter(id)
    O.model.tab=count
    local p=O.enginePages[1];for i,r in ipairs(p.rows)do if r.id==id then p.cursor=i;press('a');return end end
    error('missing native group '..id)
  end
  enter('group.speed');press('right');T.eq(game.options.speedOverworld,2,'native overworld speed changes shared options')
  T.eq(saved.speedOverworld,2,'native speed writes the existing options persistence hook immediately')
  press('r');T.eq(#O.enginePages,2,'R on native category does not leave or save');press('b')
  enter('group.audio');press('left');T.eq(game.options.musicVol,6,'native audio step changes shared music volume')
  T.eq(saved.musicVol,6,'native audio change is persisted');press('b')
  local n=writes;press('r');T.eq(writes,n,'R never writes options on rightmost native page')
  press('l');T.eq(O.model.tab,count-1,'L returns to the HnS sound page')
  press('r');press('b');T.eq(O.isOpen(),false,'B leaves native root cleanly')
  T.eq(saved.speedOverworld,2,'closing HnS options preserves native speed')
  T.eq(saved.musicVol,6,'closing HnS options preserves native volume')
  O.show({session=s});O.model.tab=#O.model.pages
  T.eq(O.engineContext.options.speedOverworld,2,'reopening native tab retains saved speed');O.close(true)
  Rt.session=old.session;Stack._layers=old.layers;game.options=old.options;game.writeOptions=old.write;game.applyOptions=old.apply
  print('Native settings: every platform-filtered row reachable, shared speed/audio persistence, subpage back, terminal R boundary')
end
