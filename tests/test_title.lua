-- Run from an engine checkout against the tiny source-title fixture.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
require('src.core.GameVersion').set('emerald')
require('src.import.gba.versions').select('emerald')
local root=assert(arg[1]);local repo=assert(arg[2]);local w=dofile(root..'/world.lua')
local manifest=assert(io.open(repo..'/runtime/manifest.json','rb'));local version=assert(manifest:read('*a'):match('"version"%s*:%s*"([^"]+)"'));manifest:close()
local mod={version=version,read=function(_,name)
  local f=assert(io.open(root..'/'..name,'rb'));local bytes=f:read('*a');f:close();return bytes
end}
local game={};assert(load(mod:read('boot_presentation.lua')))()(mod,w,game)
local machine=require('src.ui.game3.rse.gba_machine').new()
local title=game._hnsBoot.Title.new(machine,{params={song='MUS_HG_TITLE'}})
local input={wasPressed=function()return false end,isDown=function()return false end}
for i=1,2000 do title:update(input,1/60);if title.phase=='phase3'then break end end
T.eq(title.phase,'phase3','actual HnS title reaches its input phase')
assert(loadfile(repo..'/tests/test_title_banner.lua'))()(T,game,title,machine,input)
title:destroy();T.finish('HnS queued title correction')
