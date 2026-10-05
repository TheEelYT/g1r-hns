-- Native Player/Objects/VM/Fade/healing state machine and source assets.
-- The GPU boundary is recorded; no ROM or desktop LÖVE session is simulated.
return function(T,game,world,maps)
  local Player=require('src.core.game3.player')
  local Objects=require('src.core.game3.objects')
  local Collision=require('src.core.game3.collision')
  local Rt=require('src.core.game3.runtime')
  local Space=require('src.core.game3.scripting.space')
  local Flags=require('src.core.game3.scripting.flags')
  local Party=require('src.core.game3.party')
  local Vm=require('src.core.game3.scripting.vm')
  local Adapters=require('src.core.game3.scripting.adapters')
  local Audio=require('src.core.game3.audio')
  local Fx=require('src.core.game3.field_effects')
  local Heal=require('src.core.game3.pokecenter_heal')
  local Fade=require('src.ui.game3.fade')
  local Ow=require('src.core.game3.ow_sprites')
  local saved={}
  local function preserve(t,keys)for _,k in ipairs(keys) do saved[#saved+1]={t=t,k=k,v=t[k]} end end
  preserve(Rt,{'session','active'});preserve(Space,{'store','vm','active','mapId'})
  preserve(Objects,{'_byId','_order','_tracks','_mapId','_defs','_bounds','_perm','_templateMt'})
  preserve(game,{'currentMap'})
  preserve(Player,{'cellX','cellY','px','py','targetX','targetY','moving','progress','facing','currentElevation','elevation','running','stepFrames','turnArmed','turnTimer','surfing','biking','_scriptedStep','_onStepDone'})
  local bindMap=Collision._mapId;local bindDef=Collision._mapDef
  local session={version='emerald',party={},flags={},vars={},bag={slots={}},map='EM_HNS_ROUTE31_HNS'}
  Rt.session=session;Rt.active=true;Space.store=Flags.newStore()
  Player.turnArmed=false;Player.turnTimer=0;Player.surfing=false;Player.biking=false
  local function at(mid,x,y)
    game.currentMap=mid;session.map=mid;Objects.reset();Collision.bindMap(game,mid,maps[mid])
    Player.cellX,Player.cellY=x,y;Player.px,Player.py=x*16,y*16
    Player.moving=false;Player.currentElevation=3;Player.elevation=3
    Player._onStepDone=nil;Player._scriptedStep=false
  end
  local function step(dir,x,y)
    T.eq(Player.tryMove(dir,game,false),'step','source stairs begin a native step')
    T.eq(Player.targetX,x,'stair landing x');T.eq(Player.targetY,y,'stair landing y')
    local frames=Player.stepFrames;T.check(frames==23 or frames==16,'stairs walk at source slow speed or flat entry speed')
    for _=1,frames do Player.tick(game) end
    T.eq(Player.cellX,x,'stair traversal arrives x');T.eq(Player.cellY,y,'stair traversal arrives y')
    T.eq(Player.px,x*16,'native stair interpolation ends exactly x');T.eq(Player.py,y*16,'native stair interpolation ends exactly y')
    T.eq(Player.moving,false,'stair traversal finishes')
  end
  -- Exact source layout marks, both copies/edges and both orientations.
  at('EM_HNS_ROUTE31_HNS',24,12)
  step('right',25,11);step('right',26,10);step('right',27,10)
  step('left',26,10);step('left',25,11);step('left',24,12)
  at('EM_HNS_ROUTE32_HNS',17,45)
  step('left',16,44);step('left',15,43);step('left',14,43)
  step('right',15,43);step('right',16,44);step('right',17,45)
  at('EM_HNS_ROUTE31_HNS',26,10)
  T.eq(Player.tryMove('up',game,false),'blocked','cannot walk north through stair top edge')
  at('EM_HNS_ROUTE31_HNS',27,10)
  Objects._byId[99]={cellX=25,cellY=11,currentElevation=3,localId=99,visible=true};Objects._order={99}
  step('left',26,10)
  T.eq(Player.tryMove('left',game,false),'blocked','diagonal landing respects occupied cell')
  at('EM_HNS_ROUTE31_HNS',32,23)
  step('up',32,22);T.eq(Player.stepFrames,16,'walking onto vertical stairs from below uses normal speed')
  step('up',32,21);T.eq(Player.stepFrames,23,'ascending from rock stairs slows walking')
  step('down',32,22);T.eq(Player.stepFrames,23,'descending onto rock stairs slows walking')

  local day='EM_HNS_ROUTE30_HNS'
  local Rtc=require('src.core.game3.rtc');local oldLocal=Rtc.calcLocalTime
  for _,hour in ipairs({6,18,19,23,0,5}) do
    Rtc.calcLocalTime=function()return {hours=hour} end
    session.map=day;Objects.loadMap(game,day,maps[day])
    local night=hour>=19 or hour<6;local tested=0
    for _,entry in ipairs(world.fieldPokemon.objects) do if entry.map==day and entry.sourceFlag~='0' then
      local eo=Objects.find(entry.localId)
      T.eq(eo.visible,entry.sourceFlag=='FLAG_NIGHT_POKEMON' and night or entry.sourceFlag=='FLAG_DAY_POKEMON' and not night,'source day/night Pokémon visibility at '..hour)
      tested=tested+1
    end end
    T.check(tested>0,'day/night checks exercise actual source objects')
  end
  Rtc.calcLocalTime=oldLocal
  local town=maps.EM_HNS_NEW_BARK_TOWN_HNS
  local pineco=0
  for _,o in ipairs(town.objects) do if world.opening.sprites[tostring(o.hnsGraphicsId)].source=='OBJ_EVENT_GFX_MON_BASE+SPECIES_PINECO' then pineco=pineco+1 end end
  T.eq(pineco,4,'all four in-bounds New Bark Pineco restored')
  local interactive=0
  for _,e in ipairs(world.fieldPokemon.objects) do if e.script then
    interactive=interactive+1
    local a=Adapters.stub();local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,adapters=a})
    vm:start(e.script)
    for _=1,1200 do Audio.update(1/60);if vm:isRunning() then vm:resume() else break end end
    T.eq(vm:isRunning(),false,'source Pokémon dialogue/cry finishes');T.eq(#a.logs,0,'Pokémon interaction has no skipped command')
    T.check(a.lastMessage and a.lastMessage~='(missing text)','Pokémon speaks source dialogue')
  end end
  T.check(interactive>=50,'restore supported Pokémon interactions across the world')
  local Field=require('src.core.game3.field');preserve(Field,{'locked'});Field.locked=false
  session.map='EM_HNS_RUINS_OF_ALPH_OUTSIDE_HNS'
  Objects.loadMap(game,session.map,maps[session.map])
  local beam
  for _,eo in pairs(Objects._byId) do if eo.def.hnsMovementType=='MOVEMENT_TYPE_TOWER_BEAM' then beam=eo;break end end
  local beamFaces={}
  for _=1,80 do Objects.update(game);if beam then beamFaces[beam.facing]=true end end
  T.check(beam~=nil and beamFaces.left and beamFaces.right and beamFaces.down,'source Unown movement cycles through left/right/down')

  -- Record native draw commands with CPU image data so missing/wrong sheets
  -- fail instead of silently progressing an invisible animation.
  preserve(love.image,{'newImageData'});preserve(love.graphics,{'newImage','draw'})
  local oldData=love.image.newImageData;local oldImage=love.graphics.newImage
  love.image.newImageData=function(w,h,format,rgba)
    if format=='rgba8' then
      T.eq(#rgba,w*h*4,'healing/mon sprite RGBA dimensions')
      return {w=w,h=h,rgba=rgba}
    end
    return oldData(w,h)
  end
  love.graphics.newImage=function(data)
    if data.rgba then return {rgba=data.rgba,w=data.w,h=data.h,setFilter=function()end} end
    return oldImage(data)
  end
  local draws=0
  love.graphics.draw=function()draws=draws+1 end
  Ow.invalidate()
  local asymmetric=0
  for id,info in pairs(world.opening.sprites) do if info.asymmetric then
    local spr=Ow.get(tonumber(id));T.check(spr~=nil,'asymmetric Pokémon sheet loads')
    local frame,flip=Ow.pose(spr,'right',0,false)
    T.eq(frame,9,'separate source right-facing pose');T.eq(flip,false,'asymmetric pose is not mirrored')
    local walk=Ow.pose(spr,'right',1,false);T.eq(walk,11,'separate right-facing walk frame')
    asymmetric=asymmetric+1
  end end
  T.check(asymmetric>0,'actual source asymmetric Pokémon tested')

  local center='EM_HNS_CHERRYGROVE_CITY_POKEMON_CENTER_HNS'
  local function healing(key,n,black,egg)
    at(center,8,5);session.party={};Space.store=Flags.newStore()
    for _=1,n do Party.giveMonToPlayer(session,152,5) end
    for _,mon in ipairs(session.party) do mon.hp=1;mon.status='poison';mon.pp[1]=0 end
    if egg then session.party[#session.party].isEgg=true end
    Objects.loadMap(game,center,maps[center]);Audio.stopAll();Fade.clear()
    local healed,healFrame,frame=0,nil,0;local covered,maxBalls,monitorFrames=0,0,{}
    local fadeModes={};local a=Adapters.stub({
      nurseHeal=function(done)
        T.eq(Audio.isFanfareFinished(),true,'party heals after source healing jingle finishes')
        if black then T.eq(Fade.t,16,'scripted party heals while screen is black') end
        Party.healAll(session.party);healed=healed+1;healFrame=frame;done()
      end,
      fadeScreen=function(mode,speed,done)fadeModes[#fadeModes+1]=mode;Fade.begin(mode,speed,done)end,
      doFieldEffect=Fx.doFieldEffect,waitFieldEffect=Fx.waitFieldEffect})
    local vm=Vm.new({scripts=game.data.gen3Scripts,text=game.data.gen3Text,adapters=a,store=Space.store})
    local nurse=world.worldEvents.nurses[1].localId
    for _,row in ipairs(world.worldEvents.nurses) do if row.map==center then nurse=row.localId end end
    T.check(vm:startTalk(key,nurse),'healing interaction begins through VM')
    for tick=1,1600 do
      frame=tick;Audio.update(1/60);Fade.tick(1/60);Heal.step()
      if Fade.t==16 then covered=covered+1 end
      local fx=Heal._fx
      if fx then
        maxBalls=math.max(maxBalls,#fx.balls)
        if fx.monitorVisible then monitorFrames[fx.monitorFrame]=true end
        Heal.draw(0,0)
        T.check(Heal._monImg~=nil and Heal._ballIdx~=nil,'native healing draws source monitor and balls')
        T.eq(fx.monitorX,112,'source HnS monitor left coordinate')
        T.eq(fx.monitorY,16,'source HnS monitor top coordinate')
      end
      if healed==0 then T.eq(session.party[1].hp,1,'party waits for full healing presentation') end
      if vm:isRunning() then vm:resume() else break end
    end
    T.eq(vm:isRunning(),false,'healing VM completes');T.eq(#a.logs,0,'healing has no skipped commands')
    T.eq(healed,1,'party heals exactly once');T.eq(Fade.t,0,'healing finishes with screen visible')
    T.eq(Heal.isActive(),false,'healing effect and wait are finished')
    for _,mon in ipairs(session.party) do T.eq(mon.hp,mon.maxHp,'healing restores HP');T.eq(mon.status,nil,'healing clears status');T.check(mon.pp[1]>0,'healing restores PP') end
    if black then
      T.eq(#fadeModes,2,'scripted healing fades twice');T.eq(fadeModes[1],1,'fade to black');T.eq(fadeModes[2],0,'fade from black')
      T.check(covered>=160,'black screen spans the complete source healing jingle');T.eq(maxBalls,0,'out-of-center heal does not run Center effect')
    else
      T.eq(maxBalls,egg and n-1 or n,'Center places one ball per non-egg Pokémon');T.check(monitorFrames[0] and monitorFrames[1],'source monitor flickers through both frames')
      T.eq(#fadeModes,0,'Center animation retains visible field');T.check(draws>0,'native healing animation makes draw commands')
      T.eq(Objects.find(nurse).facing,'down','nurse faces the player after healing')
    end
  end
  healing('HNS_WORLD_NURSE_HEAL',1,false);healing('HNS_WORLD_NURSE_HEAL',3,false);healing('HNS_WORLD_NURSE_HEAL',6,false)
  healing('HNS_WORLD_NURSE_HEAL',3,false,true)
  healing('HNS_OPENING_HEAL_PARTY',2,true)
  local egg,dex
  for _,rows in pairs(game.data.gen3Scripts) do for i,row in ipairs(rows) do
    if row.op=='message' and type(row.ptr)=='string' then
      if row.ptr:match('MrPokemonHouse_Text_GotEgg$') then egg=rows[i-1];T.eq(rows[i+1].op,'waitfanfare','Mystery Egg waits with receipt text visible') end
      if row.ptr:match('MrPokemonHouse_Text_GetDex$') then dex=rows[i-1];T.eq(rows[i+1].op,'waitfanfare','Pokédex waits with receipt text visible') end
    end
  end end
  T.eq(egg and egg.songName,'MUS_HG_OBTAIN_KEY_ITEM','Mystery Egg uses source key-item cue')
  T.eq(dex and dex.songName,'MUS_HG_OBTAIN_ITEM','Pokédex uses source item cue')
  Audio.stopAll();Fade.clear();Heal.invalidate();Ow.invalidate()
  for i=#saved,1,-1 do local s=saved[i];s.t[s.k]=s.v end
  if bindDef then Collision.bindMap(game,bindMap,bindDef) end
  print('Field regressions: both stair orientations/edges, ambient Pokémon/cry/asymmetry/day-night, 1/3/6-ball Center animations, black healing and gift cues')
end
