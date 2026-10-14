return function(T,game,w)
  local G=game._hnsGbSounds.sounds;local Audio=require('src.core.game3.audio');local Player=require('src.core.game3.m4a_player');local Mix=require('src.core.game3.m4a_mix')
  local seen={};local songs,forced,mart=0,0,0
  for id,row in pairs(G.spec.songs)do if not seen[row.header]then
    seen[row.header]=true;songs=songs+1;local slot={};Player.start(Audio._pack,Audio._cache,slot,tonumber(id))
    for frame=1,2400 do
      Player.updateSlot(slot,1);local st=slot.hnsGB;local regs=st.source.regs;local wave=st.channels[3]
      if regs[19]>=128 and wave and wave.alive then
        forced=forced+1;T.eq(wave.envVol,11,'GBA force-75% wave output '..row.name)
        if row.name=='gbs_hg_poke_mart_Header'then
          mart=mart+1;local l,r=Mix.render({wave},256,{raw=true,hpfState={l=0,r=0},hpfCapL=0,hpfCapR=0})
          local energy=0;for i=1,#l do energy=energy+math.abs(l[i])+math.abs(r[i])end
          T.check(energy>0.001,'Pokemart wave voice reaches native PCM')
        end
      end
      if slot.done then break end
    end
  end end
  T.eq(songs,G.spec.trackCount,'channel audit covers every distinct mapped GB song')
  T.check(forced>0,'source songs exercise force-75% wave output');T.check(mart>0,'Pokemart exercises the missing wave voice')
end
