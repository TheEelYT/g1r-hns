-- Private source boot machines; the imported Emerald profile stays intact.
return function(mod,w,game)
  local old=game._hnsBoot or {};local U=assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui)
  local BM=require('src.ui.game3.boot_modules');local Boot=require('src.ui.game3.boot')
  local Movie=assert(load(mod:read('hns_intro.lua')))()
  local Title=assert(load(mod:read('hns_title.lua')))()
  local Ppu=require('src.core.game3.gba_ppu');local B=w.bootPresentation
  local songs={};for id,name in pairs(w.audio.songs)do songs[name]=tonumber(id)end
  local Credits=assert(load(mod:read('intro_credits.lua')))()(U,B.credits)
  Movie.configure({song=assert(songs.MUS_HG_INTRO),credits=Credits})
  local Intro={}
  function Intro.new()
    local assets={};for name,a in pairs(B.intro)do assets[name]=U.image(a.file,a.width,a.height)end
    local m=Movie.new(assets)
    return {movie=m,update=function(self,input,dt)if m:update(input,dt)then return 'title'end end,
      draw=function()return m:draw()end,destroy=function()return m:destroy()end}
  end
  local function image(a)return U.image(a.file,a.width,a.height)end
  local function layer(a)return {image=image(a),w=a.w,h=a.h,bpp=a.bpp}end
  local function template(a,extra)
    local t={w=a.w,h=a.h,bpp=a.bpp,anims=a.anims,priority=a.priority or 0,affineMode=a.affineMode or 0,objMode=a.objMode or 0,
      sheet={image=image(a),w=a.width,h=a.height,frameW=a.w,frameH=a.h}}
    for k,v in pairs(extra or {})do t[k]=v end;return t
  end
  local id=assert(songs.MUS_HG_TITLE);local Seq=require('src.core.game3.m4a_seq')
  local p=Seq.newPlayer(Seq.parseSongBin(assert(mod:read('audio/songs/'..id..'.bin'))))
  local frames
  for n=1,100000 do Seq.update(p,1);local done=true;for _,tr in ipairs(p.tracks)do if not tr.done then done=false;break end end;if done then frames=n;break end end
  Title.configure({manifest=B.title,layer=layer,template=template,song=id,songFrames=frames})
  -- Replace the baked source-version banner with a centered caption. Read the
  -- installed mod version from the native API so every release stays current.
  local versionText='v2.0.6 · Mod v'..assert(mod.version,'HnS mod version missing')
  Title.createCopyrightBanner=function(self,x,y)
    self.versionText=versionText;self.versionX=x;self.versionY=y-8
  end
  local titleDraw=Title.draw
  Title.draw=function(self)
    titleDraw(self)
    if not self.versionText then return end
    -- Use the title's live OBJ palette, including its native exit/RTC fades.
    local ppu=self.m.ppu;local bank=ppu.sprites:indexOfPaletteTag(1001)
    local function color(index)
      local c=ppu.palette.pltt[256+bank*16+index]
      return {c%32/31,math.floor(c/32)%32/31,math.floor(c/1024)%32/31,1}
    end
    U.text(self.versionText,self.versionX-U.width(self.versionText,'small')/2,self.versionY,color(5),color(1),'small')
  end
  local loadScreen=old.loadScreen or BM.load
  BM.load=function(name)if name=='hns.intro'then return Intro elseif name=='hns.title'then return Title end;return loadScreen(name)end
  local new=old.new or Boot.new
  local function configure(b)
    if b and b.custom then
      b.custom.mods.intro='hns.intro';b.custom.mods.title='hns.title'
      if b.phase==Boot.PHASE.INTRO and b.custom.intro then b.custom.intro:destroy();b.custom.intro=nil end
    end
    return b
  end
  Boot.new=function(g)return g==game and configure(new(g))or new(g)end
  configure(game.boot)
  game._hnsBoot={new=new,loadScreen=loadScreen,Intro=Intro,Title=Title,Movie=Movie,Credits=Credits,ui=U,versionText=versionText}
end
