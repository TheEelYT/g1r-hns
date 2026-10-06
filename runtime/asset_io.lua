-- G1R's installer now writes .rgba/.idx through CacheFs, which deflates
-- those extensions. mod:read still reads the stored bytes directly.
return function(mod)
  if mod._hnsAssetRead then return end
  local ok, Blob=pcall(require,'src.import.CacheBlob')
  if not ok then return end -- Older engines install the original raw files.
  local read=mod.read
  mod.read=function(self,file)
    local bytes,extra=read(self,file)
    if type(bytes)=='string' and (file:match('%.rgba$') or file:match('%.idx$')) then
      -- Accept both fresh compressed installs and raw installs carried over
      -- from older G1R versions. Inflate validates the complete zlib stream.
      local a,b=bytes:byte(1,2)
      if a and b and a%16==8 and a<=120 and (a*256+b)%31==0 then
        local decoded,raw=pcall(Blob.inflate,bytes)
        if decoded then bytes=raw;if type(extra)=='number'then extra=#bytes end end
      end
    end
    return bytes,extra
  end
  mod._hnsAssetRead=read
end
