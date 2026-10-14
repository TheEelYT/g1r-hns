return function(T,game,w,s,keep)
  local G=game._hnsGbSounds.sounds;local Audio=require('src.core.game3.audio');local Player=require('src.core.game3.m4a_player')
  local Mix=require('src.core.game3.m4a_mix');local ItemUse=require('src.core.game3.item_use');local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
  local Writer=require('src.import.LuaWriter');local before=s.map;s.map='EM_HNS_NEW_BARK_TOWN_HNS';Flags.setFlag(Space.store,nil,G.spec.flag,false)
  local ordinary={};T.check(Player.start(Audio._pack,Audio._cache,ordinary,w.audio.mapSongs[s.map]),'ordinary source music starts');T.eq(ordinary.hnsGB,nil,'GB OFF selects M4A')
  local ok,kind,text=ItemUse.useField(s,s.bag,w.startup.gbItem)
  T.eq(ok,true,'real bag dispatch uses GB SOUNDS');T.eq(kind,'gb_sounds','GB SOUNDS field-use kind');T.eq(text,G.spec.onText,'source GB enabled text');T.eq(G.enabled(s),true,'GB flag enables player')
  local flags=assert(load(Writer.encode(Space.store.flags)))();T.check(flags[G.spec.flag]or flags[tostring(G.spec.flag)],'GB enabled flag serializes with save')
  local slot={};T.check(Player.start(Audio._pack,Audio._cache,slot,w.audio.mapSongs[s.map]),'native music player starts GBS');T.check(slot.hnsGB,'GB ON selects source trace')
  local peak=0;local energy=0
  for f=1,180 do
    Player.updateSlot(slot,1);peak=math.max(peak,#slot.voices)
    local l,r=Player.renderSlot(slot,64,{raw=true});for i=1,#l do energy=energy+math.abs(l[i])+math.abs(r[i])end
  end
  dofile((arg[0]:match('^(.*)[/\\]')or'.')..'/test_gb_channels.lua')(T,game,w)
  local four
  for id,name in pairs(w.audio.songs)do if name=='MUS_HG_TITLE'then four=tonumber(id)end end
  local battle={};Player.start(Audio._pack,Audio._cache,battle,assert(four));local noise=false;local channels={}
  for f=1,1200 do Player.updateSlot(battle,1);for _,v in ipairs(battle.voices)do channels[v.cgbChan]=true;noise=noise or v.kind=='cgb_noise'end end
  T.check(noise and channels[1]and channels[2]and channels[3]and channels[4],'source four-channel GB title runs both pulses, wave and sampled drum noise')
  T.check(peak>=3,'New Bark GBS plays both pulses and wave');T.check(energy>1,'native GBS mixer produces audible PCM')
  for f=1,12000 do Player.updateSlot(slot,1)end;T.eq(slot.done,false,'GB bytecode keeps looping without truncating long songs')
  local heal=w.audio.roles.heal;local cue={};T.check(Player.start(Audio._pack,Audio._cache,cue,heal),'GB healing fanfare starts')
  for f=1,300 do Player.updateSlot(cue,1)end
  T.eq(cue.done,true,'GB healing cue terminates');T.eq(#cue.voices,0,'finished GB fanfare releases voices')
  local fallback
  for id in pairs(w.audio.songs)do if not G.spec.songs[tostring(id)]then fallback=tonumber(id);break end end
  if fallback then local unknown={};T.check(Player.start(Audio._pack,Audio._cache,unknown,fallback),'unmapped GB song keeps source M4A fallback');T.eq(unknown.hnsGB,nil,'source song without GB mapping retains original')end
  local l,r=Player.renderBuffered(slot,1500,{raw=true});T.eq(#l,1500,'GB PCM uses native buffered queue sample count');T.eq(#r,1500,'GB buffered stereo remains synchronized')
  ok,kind,text=ItemUse.useField(s,s.bag,'HNS_GB_PLAYER');T.eq(ok,true,'registered/name item dispatch toggles GB OFF');T.eq(text,G.spec.offText,'source GB disabled text');T.eq(G.enabled(s),false,'second use restores M4A')
  Player.start(Audio._pack,Audio._cache,slot,w.audio.mapSongs[s.map]);T.eq(slot.hnsGB,nil,'reused slot clears GB state after toggle')
  local Hud=require('src.ui.game3.hud');local Rt=require('src.core.game3.runtime');local Field=require('src.core.game3.field');local Bag=require('src.core.game3.bag')
  keep(Hud,{'openMessage'});keep(Rt,{'uiBusy'});keep(Field,{'locked'});keep(game,{'input'})
  local said;Hud.openMessage=function(_,message)said=message end;Rt.uiBusy=function()return false end;Field.locked=false
  game.input={wasPressed=function(_,key)return key=='select'end};s.registeredItem=w.startup.gbItem;Bag.add(s.bag,w.startup.gbItem,1)
  require('src.core.Game3')._handleRegisteredItem(game)
  T.eq(G.enabled(s),true,'actual native SELECT handler uses registered GB SOUNDS');T.eq(said,G.spec.onText,'registered SELECT opens source item message')
  T.eq(Bag.get(s.bag,w.startup.gbItem),1,'registered GB player is not consumed');s.registeredItem=nil;Flags.setFlag(Space.store,nil,G.spec.flag,false)

  s.map='EM_ROUTE101';Flags.setFlag(Space.store,nil,G.spec.flag,true);local native={};Player.start(Audio._pack,Audio._cache,native,w.audio.mapSongs[before]);T.eq(native.hnsGB,nil,'GB bridge is scoped away from vanilla sessions')
  Flags.setFlag(Space.store,nil,G.spec.flag,false);s.map=before
end
