-- Connect source callback schedules to native atlas animation/caching.
return function(mod,world,game)
  local A=require('src.core.game3.tileset_anim')
  local N=require('src.core.game3.tileset_native')
  local Pack=require('src.import.gba.native_pack')
  local Palette=require('src.core.game3.palette')
  local old=game._hnsTileAnimation or {}
  local frame=old.frame or A.rseFrame;local bind=old.bind or A.bindPair;local step=old.step or A.stepRse
  A.rseFrame=function(row,timer)
    if row.timeline then local index=row.timeline[timer+1];return index and index>=0 and index or nil end
    return frame(row,timer)
  end
  A.bindPair=function(pair,ts)
    local result=bind(pair,ts)
    if result and world.pairs[pair] then
      local entry=A._pairs[pair]
      if entry and not entry.hnsMiddle then
        entry.hnsMiddle=true
        local rel='native/'..pair..'/'
        if ts.midImage then
          local idx=assert(Pack.decodeIdx(mod:read(rel..'mids_mid.idx')))
          local rgb=assert(Palette.load(mod:read(rel..'palettes.bin')))
          local raw,w,h=Pack.bakeRgba(idx,rgb,{transparentZero=true})
          ts.midImageData=love.image.newImageData(w,h,'rgba8',raw)
        end
        for _,bank in ipairs(entry.banks)do if bank and bank.row.middleFile then bank.middle=mod:read(rel..bank.row.middleFile)end end
      end
    end
    return result
  end
  local hnsStep=assert(load(mod:read('hns_tile_animation.lua'),'@hns/hns_tile_animation.lua'))()(A)
  A.stepRse=function()if A._rse and world.pairs[A._rse.pair]then return hnsStep()end;return step()end
  game._hnsTileAnimation={frame=frame,bind=bind,step=step}
end
