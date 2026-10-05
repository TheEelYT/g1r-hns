-- Source six-pocket bag over the engine's unchanged saved item storage.
return function(mod,world,game)
  local S=world.services.bag;local old=game._hnsBag or {}
  local Rt=require('src.core.game3.runtime');local Menu=require('src.ui.game3.bag_menu')
  local Items=require('src.core.game3.items_data');local Skin=require('src.ui.game3.rse.bag_menu')
  local Chrome=require('src.ui.game3.rse.bag_chrome');local Kit=require('src.ui.game3.rse.scene_kit')
  local U=assert(load(mod:read('source_ui.lua')))()(mod,world.startup.ui)
  local function own(s)s=s or Rt.getSession();return s and world.maps[s.map]end
  local function active()return Menu.open and own(Menu._session)end
  local function row(id)return S.items[tostring(Items.toNumericId(id))]end
  local info=old.info or Items.info
  Items.info=function(id)
    local r=info(id);local a=own()and row(id)
    if not(r and a)then return r end
    local c={};for k,v in pairs(r)do c[k]=v end
    c.name=a.name or c.name;c.description=a.description or c.description;return c
  end
  local labels=old.labels or Items.POCKET_LABEL
  local function displayPockets()local c={};for i,v in ipairs(S.pockets)do c[i]=v end;Items.BAG_POCKET_ORDER=c;local l={};for k,v in pairs(S.labels)do l[k]=v end;Items.POCKET_LABEL=l end
  local apply=old.apply or Items.applyProfile
  Items.applyProfile=function(v)local r=apply(v);if active()then displayPockets()else Items.POCKET_LABEL=labels end;return r end
  local show=old.show or Menu.show;local close=old.close or Menu.close;local list=old.list or Menu.list
  Menu.show=function(bag,opts)
    show(bag,opts)
    if active()then
      displayPockets()
      if opts and opts.pocket then for i,p in ipairs(S.pockets)do if p==opts.pocket or(opts.pocket=='BERRIES'and p=='BERRY_POUCH')then Menu.pocketIdx=i;Menu.cursor=1;Menu.scroll=0 end end end
    end
  end
  Menu.close=function()close();if not active()then apply(require('src.core.game3.profile').sessionVersion(Rt.getSession()));Items.POCKET_LABEL=labels end end
  Menu.list=function(p)
    if not active()then return list(p)end
    p=p or Menu.currentPocket();local rows=list(p=='MEDICINE'and 'ITEMS'or p);local out={}
    for _,r in ipairs(rows)do
      local a=row(r.id);local medicine=a and a.medicine or false
      if(p~='ITEMS'and p~='MEDICINE')or(p=='MEDICINE'and medicine)or(p=='ITEMS'and not medicine)then
        local copy={};for k,v in pairs(r)do copy[k]=v end;copy.info=Items.info(r.id);copy.name=Items.displayName(r.id);copy.description=Items.description(r.id);out[#out+1]=copy
      end
    end;return out
  end
  local kitImage=old.image or Kit.image;local manifest=old.manifest or Chrome.manifest
  local paths={};for _,a in pairs(S.images)do paths[a.file]=a end
  Kit.image=function(path)local a=active()and paths[path];if a then return U.image(a.file,a.width,a.height)end;return kitImage(path)end
  Chrome.manifest=function()
    local m=manifest();if not active()then return m end
    local c={};for k,v in pairs(m or {})do c[k]=v end
    c.layers={bg={png=S.images.bg_male.file,variants={female=S.images.bg_female.file}},indicator={png=S.images.indicator_male.file,variants={female=S.images.indicator_female.file}}}
    c.palettes={male=S.malePalette,female=S.femalePalette};c.sprites={}
    for k,v in pairs(m and m.sprites or {})do c.sprites[k]=v end
    c.sprites.male={png=S.images.bag_male.file,w=64,h=64};c.sprites.female={png=S.images.bag_female.file,w=64,h=64}
    c.sprites.arrows={png=S.images.arrows.file,w=16,h=16};c.sprites.ball={png=S.images.ball.file,w=16,h=16}
    return c
  end
  local icon=old.icon or Chrome.drawItemIcon;local returnIcon=old.returnIcon or Chrome.returnIconIndex
  Chrome.returnIconIndex=function()if active()then return -1 end;return returnIcon()end
  Chrome.drawItemIcon=function(id,x,y,rot,ox,oy)
    local a=active()and(id==-1 and S.returnIcon or(row(id)or {}).icon)
    if not a then return icon(id,x,y,rot,ox,oy)end
    love.graphics.setColor(1,1,1,1);love.graphics.draw(U.image(a.file,a.width,a.height),x,y,rot or 0,1,1,ox or 0,oy or 0)
  end
  local draw=old.draw or Skin.draw;local frames=old.frames or Skin.BAG_FRAME;local grids=old.grids or Skin.GRIDS
  Skin.draw=function(b)
    if not active()then return draw(b)end
    local f,g=Skin.BAG_FRAME,Skin.GRIDS;Skin.BAG_FRAME=S.frame;Skin.GRIDS={}
    for k,v in pairs(grids)do Skin.GRIDS[k]=v end;Skin.GRIDS.MEDICINE=grids.ITEMS
    local Font=require('src.ui.game3.frlg_font');local fd,fm,fw,fg=Font.draw,Font.measure,Font.wrap,Font.drawGlyph
    local function pure(t)return type(t)=='string'and not t:find(string.char(0xFC),1,true)end
    local function font(o)return o and(o.font or(o.small and 'small'))or 'normal'end
    Font.draw=function(t,x,y,o)
      if not pure(t)then return fd(t,x,y,o)end;o=o or {};local c=o.colors or Font.COLOR.NORMAL
      if o.maxWidth then t=U.wrap(t,o.maxWidth,font(o))end
      U.text(t,x,y,c.fg,c.shadow,font(o),o.linePitch or 16)
    end
    Font.measure=function(t,o)if pure(t)then local n=0;for l in(t..'\n'):gmatch('(.-)\n')do n=math.max(n,U.width(l,font(o)))end;return n end;return fm(t,o)end
    Font.wrap=function(t,w,o)if pure(t)then return U.wrap(t,w,font(o))end;return fw(t,w,o)end
    Font.drawGlyph=function(id,x,y,o)if id==Font.CHAR_SELECTOR_ARROW then local c=o and o.colors or Font.COLOR.NORMAL;return U.glyph('RIGHT_ARROW',x,y,font(o),c.fg,c.shadow)end;return fg(id,x,y,o)end
    local ok,e=pcall(draw,b)
    Font.draw,Font.measure,Font.wrap,Font.drawGlyph=fd,fm,fw,fg;Skin.BAG_FRAME=f;Skin.GRIDS=g;if not ok then error(e)end
  end
  -- Action grids are built during input as well as drawing.
  local input=old.input or Skin.handleInput
  Skin.handleInput=function(i,b)
    if not active()then return input(i,b)end
    local g=Skin.GRIDS;Skin.GRIDS={};for k,v in pairs(grids)do Skin.GRIDS[k]=v end;Skin.GRIDS.MEDICINE=grids.ITEMS
    local ok,e=pcall(input,i,b);Skin.GRIDS=g;if not ok then error(e)end
  end
  game._hnsBag={labels=labels,info=info,apply=apply,show=show,close=close,list=list,image=kitImage,manifest=manifest,icon=icon,returnIcon=returnIcon,draw=draw,frames=frames,grids=grids,input=input,ui=U}
end
