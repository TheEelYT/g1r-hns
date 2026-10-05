-- Build-time only: use the pinned engine's decoder on source-assembled sound
-- data. No game ROM, map/header scanners or copyrighted ROM dumps are used.
package.path='./?.lua;./?/init.lua;'..package.path
local Extract=require('src.import.gba.extract_audio')
local function up(name)
  for i=1,100 do local key,value=debug.getupvalue(Extract.run,i);if not key then break end;if key==name then return value end end
  error('pinned native audio extractor changed: '..name)
end
local tracks=up('dump_song_tracks');local voices=up('dump_voicegroup')
local file=assert(io.open(arg[1],'rb'));local bytes=file:read('*a');file:close()
local songs=assert(loadfile(arg[2]))();local root=arg[3]
local cache={write=function(_,path,value)local f=assert(io.open(path,'wb'));f:write(value);f:close();return true end}
local sampleMap,parts,cursor,vgMap,vgs={},{},{0},{},{}
local function u32(off)local a,b,c,d=bytes:byte(off+1,off+4);return a+b*256+c*65536+d*16777216 end
for _,id in ipairs((function()local keys={};for id in pairs(songs) do keys[#keys+1]=id end;table.sort(keys);return keys end)()) do
  local song=songs[id];local h=song.header
  local n,count,loop=tracks(bytes,h,tonumber(id),cache,root)
  assert(count>0 and n>8,'empty source song '..song.name)
  song.id=tonumber(id);song.tracks=count;song.hasGoto=loop;song.loop=loop;song.songBytes=n
  song.priority=bytes:byte(h+3);song.reverb=bytes:byte(h+4)
  song.voicegroupId=voices(bytes,u32(h+4)-0x08000000,sampleMap,parts,cursor,vgMap,vgs,0)
  song.header=nil
end
local samples={};for _,sample in pairs(sampleMap) do samples[sample.id]=sample;assert(sample.size>0,'empty instrument sample') end
local index={version=1,songs=songs,samples=samples,voicegroups=vgs,roles={},fanfares={}}
local Writer=require('src.import.LuaWriter')
cache:write(root..'/index.lua',Writer.encode(index));cache:write(root..'/samples.bin',table.concat(parts))
