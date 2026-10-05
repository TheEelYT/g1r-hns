-- Actual menu dispatch, source regional order, native dex flags and UI draw.
return function(T,game,world,maps)
  local C=require('src.core.game3.constants').of('emerald')
  local Screens=require('src.ui.game3.screens')
  local Stack=require('src.ui.game3.stack')
  local Dex=require('src.core.game3.dex')
  local P=game._hnsDex.ui
  local session={version='emerald',map='EM_HNS_NEW_BARK_TOWN_HNS',dex=Dex.new()}
  local RomText=require('src.core.game3.rom_text')
  local typeOverrides={}
  for name,id in pairs(require('src.core.game3.battle.types').ID) do
    local key=RomText.key('gTypeNames',id);typeOverrides[key]=RomText.overrides[key];RomText.overrides[key]=require('src.core.game3.scripting.text_ir').fromAscii(name)
  end
  local base=Screens.get('pokedex',{version='emerald',map='EM_LITTLEROOT_TOWN'})
  T.check(base~=P,'vanilla maps retain their original Pokédex')
  T.eq(Screens.get('pokedex',session),P,'HnS menu selects its own Pokédex')
  T.eq(world.pokedex.count,282,'all source regional numbers retained')
  T.eq(world.pokedex.entries[1].speciesName,'CHIKORITA','Johto list starts with Chikorita')
  T.eq(world.pokedex.entries[4].speciesName,'CYNDAQUIL','Johto Cyndaquil number is source order')
  T.eq(world.pokedex.entries[7].speciesName,'TOTODILE','Johto Totodile number is source order')
  T.eq(world.pokedex.entries[282].speciesName,'CELEBI','Johto list ends at source Celebi number')
  T.eq(#world.pokedex.art.unknown.file>0,true,'source circled question image is available for unseen entries')
  T.eq(world.pokedex.art.scrollArrow.width,16,'source red scroll arrows use a valid two-tile image')
  T.eq(world.pokedex.art.egg.width,24,'egg moves have their source egg item icon')
  T.eq(world.pokedex.art.tutor.width,24,'tutor moves have their source teaching TV icon')
  local displayMoves=0;for _ in pairs(world.pokedex.moveInfo)do displayMoves=displayMoves+1 end
  T.eq(displayMoves,934,'expanded move information is independent of the 354 native battle IDs')
  local oldSession=P.session;P.session=session
  local full=P.moves(game._hnsDexState.regional[7]);P.session=oldSession
  T.eq(world.pokedex.modernGeneration,7,'modern learnsets use the source-configured generation seven')
  T.eq(#full,87,'Totodile includes all modern egg, level-up, machine and tutor rows from the pinned source')
  T.eq(full[1].move,'CRUNCH','Totodile begins with source egg move Crunch')
  T.eq(full[1].kind,'egg','egg move is labeled separately from level-up moves')
  T.eq(full[15].kind,'level','modern Totodile level-up list follows all fourteen egg moves')
  local kinds={};for _,m in ipairs(full)do kinds[m.kind]=true;T.check(world.pokedex.moveInfo[m.move]~=nil,'learnable move has source display metadata: '..m.move)end
  T.check(kinds.TM and kinds.HM and kinds.tutor,'expanded list includes TM, HM and tutor entries')
  local unsupported=0
  for _,row in ipairs(world.pokedex.entries) do if not row.supported then T.eq(row.species,nil,'expanded species do not alias Emerald IDs');unsupported=unsupported+1 end end
  T.check(unsupported>0,'expanded species keep explicit reserved numbers')
  Dex.setCaught(session.dex,152);Dex.setSeen(session.dex,155)
  local saved={}
  local function preserve(t,k) saved[#saved+1]={t=t,k=k,v=t[k]} end
  preserve(Stack,'_layers');preserve(P,'cursor');preserve(P,'ownedOnly')
  preserve(love.image,'newImageData');preserve(love.graphics,'newImage');preserve(love.graphics,'draw')
  -- Record only GPU upload/draw: UI selection/data/text layout run normally.
  local images,draws=0,0
  love.image.newImageData=function(w,h,format,bytes)
    T.eq(#bytes,w*h*4,'source Pokédex RGBA buffer has exact dimensions')
    return {getDimensions=function() return w,h end}
  end
  love.graphics.newImage=function(data)
    images=images+1;return {getDimensions=data.getDimensions,setFilter=function() end}
  end
  love.graphics.draw=function() draws=draws+1 end
  local D=game._hnsDexState;local Rt=require('src.core.game3.runtime');local Space=require('src.core.game3.scripting.space')
  local save=require('src.ui.game3.save_menu');local live,store=Rt.session,Space.store
  local five={158,69,161,16,19};local thirteen={158,69,161,16,19,152,155,163,165,10,11,129,74}
  local counted={version='emerald',map=session.map,name='GENE',dex=Dex.new(),flags={},vars={}}
  for _,sp in ipairs(five)do Dex.setCaught(counted.dex,sp)end
  for _,sp in ipairs(thirteen)do Dex.setSeen(counted.dex,sp)end
  Rt.session=counted;Space.store=nil
  local nSeen,nCaught=D.counts(counted)
  T.eq(nSeen,13,'one HnS counter returns all thirteen seen regional species')
  T.eq(nCaught,5,'one HnS counter returns all five unique catches')
  T.eq(save.countDex(counted),5,'actual native save menu counts HnS, not Hoenn membership')
  local badge=C:flag('FLAG_BADGE01_GET');counted.flags[badge]=true
  T.eq(save.countBadges(counted),1,'one earned badge remains one badge')
  T.eq(require('src.ui.game3.boot').continueInfoFromSave(counted).dexCount,5,'actual Continue panel uses HnS saved count')
  T.eq(require('src.ui.game3.rse.main_menu_rse').continueInfoFromSave(counted,'emerald').dexCount,5,'actual Emerald title panel uses HnS counts')
  local exported=require('src.core.game3.save_schema_firered').toSaveTable(counted)
  T.check(exported.modData.hnsDexState~=nil,'serialized save preserves actual source Dex state')
  T.eq(D.summaryCount(exported),5,'unmodified launcher counter reads exported regional count without a mod')
  T.eq(Dex.nationalEnabled(counted),false,'export does not unlock the live National Dex')
  local restored=require('src.core.game3.save_schema_firered').fromSaveTable(exported)
  T.eq(Dex.nationalEnabled(restored),false,'reload restores the actual regional unlock state')
  T.eq(D.counts(restored),13,'reload restores all thirteen actual seen entries')
  T.eq(require('src.core.SaveData').slotSummary(exported)~=nil,true,'export remains a valid launcher slot summary')
  local _,summary=require('src.core.SaveData').slotSummary(exported);T.eq(summary.dexCount,5,'launcher summary shows five caught');T.eq(summary.badges,1,'launcher still shows the actual one badge')
  Dex.setCaught(counted.dex,C:require('species','SPECIES_TREECKO'))
  local filtered=require('src.core.game3.save_schema_firered').toSaveTable(counted)
  T.eq(D.summaryCount(filtered),5,'regional summary excludes a caught non-Johto species')
  restored=require('src.core.game3.save_schema_firered').fromSaveTable(filtered)
  T.check(D.caught(restored.dex,C:require('species','SPECIES_TREECKO')),'nonregional actual catch survives summary filtering and reload')
  local encoded={version='emerald',map=session.map,dex={seen={},caught={},owned={}}}
  for _,sp in ipairs(thirteen)do encoded.dex.seen[tostring(sp)]=true end
  for _,sp in ipairs(five)do encoded.dex.caught[tostring(sp)]=true;encoded.dex.owned[sp]=true end
  T.eq(Dex.summaryCount(encoded),5,'serialized string keys and owned aliases count once')
  T.eq(D.own({version='emerald',map='EM_LITTLEROOT_TOWN',dex=counted.dex}),false,'an explicit vanilla map delegates even with shared dex data')
  Dex.enableNational(counted);Dex.setCaught(counted.dex,C:require('species','SPECIES_TREECKO'))
  T.eq(Dex.summaryCount(counted),6,'national unlock includes a caught non-Johto species')
  Rt.session=live;Space.store=store
  P.ownedOnly=false;P.cursor=1;P.show(session.dex,{session=session})
  T.eq(Stack.top().id,'hns_pokedex','HnS Pokédex owns the active UI modal')
  T.eq(#P.rows,282,'unseen slots preserve source list numbering')
  local function idle()P.handleInput({wasPressed=function()return false end})end
  local function settle()for i=1,80 do idle()end end
  local function key(name)P.handleInput({wasPressed=function(_,button)return button==name end});settle()end
  settle()
  T.check(pcall(P.draw),'source list background draws without base-game dex chrome')
  key('a');T.eq(P.page,'info','caught Johto starter opens its entry')
  local ok,err=pcall(P.draw);T.check(ok,'source category/height/weight/description entry draws '..tostring(err or ''))
  T.check((world.pokedex.entries[1].description or ''):find('leaf')~=nil,'Chikorita has source description')
  key('a');T.eq(P.page,'stats','entry opens HnS source statistics');T.check(pcall(P.draw),'base stats page draws')
  T.eq(P.detail(P.row()).stats.hp,45,'Chikorita page uses pinned source HP instead of fixture Emerald HP')
  local move=P.moveCursor;key('down');T.eq(P.moveCursor,move+1,'stats directions browse real source level-up moves')
  key('a');T.check(P.toggle,'A toggles source EV/hidden-ability display');T.check(pcall(P.draw),'EV and hidden-ability layout draws')
  key('b');key('right');T.eq(P.cursor,8,'list moves one page without renumbering')
  key('select');T.eq(#P.rows,1,'owned filter shows only native caught species')
  T.eq(P.rows[1].number,1,'owned filter retains regional number')
  key('b');T.eq(Stack.has('hns_pokedex'),false,'B returns to underlying menu')
  P.ownedOnly=false;P.cursor=4;P.show(session.dex,{session=session});settle();key('a')
  T.eq(P.page,'info','seen starter can open identification page');T.check(pcall(P.draw),'seen-only entry draws')
  key('start');T.eq(Stack.has('hns_pokedex'),false,'Start closes HnS dex')
  T.check(images>=3,'source page artwork, portraits and glyphs are uploaded');T.check(draws>=4,'source UI submits background images')
  for name,id in pairs(require('src.core.game3.battle.types').ID) do local key=RomText.key('gTypeNames',id);RomText.overrides[key]=typeOverrides[key] end
  for i=#saved,1,-1 do local s=saved[i];s.t[s.k]=s.v end
  print('HnS Pokédex: actual menu route, 282 source numbers, seen/caught, expanded reservations, list/info/stats draw, scrolling/filter/back')
end
