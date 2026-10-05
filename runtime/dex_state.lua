-- One HnS regional/national count for menus, saved summaries and Elm.
return function(mod,world,game)
  local Dex=require('src.core.game3.dex')
  local Rt=require('src.core.game3.runtime')
  local C=require('src.core.game3.constants').of('emerald')
  local D={regional={},national={}}
  for _,row in ipairs(world.pokedex.registrationEntries)do
    row.species=C:require('species','SPECIES_'..row.speciesName)
  end
  for _,row in ipairs(world.pokedex.ratingNationalEntries)do
    if row.supported then row.species=C:require('species','SPECIES_'..row.speciesName)end
    D.national[#D.national+1]=row
  end
  for _,row in ipairs(world.pokedex.entries)do
    if row.supported then row.species=C:require('species','SPECIES_'..row.speciesName)end
    D.regional[#D.regional+1]=row
  end
  function D.own(s)
    if not s then return false end
    if s.map then return world.maps[s.map]~=nil end
    -- Native SaveMenu/TrainerCard pass a map-less view of the live dex.
    local live=Rt.getSession()
    return live and world.maps[live.map]~=nil and s.dex~=nil and s.dex==live.dex or false
  end
  local function marked(t,id)
    if not t or not id then return false end
    local v=t[id];if v==nil then v=t[tostring(id)]end
    local name=C.species.byId.SPECIES_[id]
    if v==nil and name then v=t[name] or t[name:sub(9)]end
    return v~=nil and v~=false and v~=0
  end
  function D.caught(dex,id)return dex and (marked(dex.caught,id) or marked(dex.owned,id))or false end
  function D.seen(dex,id)return dex and (marked(dex.seen,id) or D.caught(dex,id))or false end
  local function copy(v)
    if type(v)~='table'then return v end
    local c={};for k,x in pairs(v)do c[k]=copy(x)end;return c
  end
  function D.sourceSave(s)
    local m=s and s.modData and s.modData.hnsDexState
    if D.own(s)and s.dex and s.dex.hnsSummary070 and m and m.format==1 then
      local c={};for k,v in pairs(s)do c[k]=v end
      c.dex=m.dex;c.flags=m.flags;c.vars=m.vars;c.pokedex=m.pokedex;return c
    end
    return s
  end
  function D.counts(s,national)
    s=D.sourceSave(s)
    if national==nil then national=Dex.nationalEnabled(s)end
    local seen,caught=0,0
    for _,r in ipairs(national and D.national or D.regional)do
      if r.species then
        if D.seen(s and s.dex,r.species)then seen=seen+1 end
        if D.caught(s and s.dex,r.species)then caught=caught+1 end
      end
    end
    return seen,caught
  end
  function D.rating(s,national)
    s=D.sourceSave(s)
    local caught,max=0,0
    for _,r in ipairs(national and world.pokedex.ratingNationalEntries or D.regional)do
      if not r.dexNotRequired and (not r.isMythical or r.dexForceRequired)then
        max=max+1
        local id=r.species or (r.supported and C.species.byName['SPECIES_'..r.speciesName])
        if id and D.caught(s and s.dex,id)then caught=caught+1 end
      end
    end
    return caught,max,caught>=max and max>0
  end
  local base=game._hnsDexState and game._hnsDexState.summaryCount or Dex.summaryCount
  Dex.summaryCount=function(s)if D.own(s)then local _,caught=D.counts(s);return caught end;return base(s)end
  -- Emerald's own title screen has a separate Hoenn counter.
  local Title=require('src.ui.game3.rse.main_menu_rse')
  local title=game._hnsDexState and game._hnsDexState.titleInfo or Title.continueInfoFromSave
  Title.continueInfoFromSave=function(s,v)
    local r=title(s,v);if r and D.own(s)then local _,n=D.counts(s);r.dexCount=n end;return r
  end
  -- Launcher metadata has no mod loader and always interprets regional
  -- flags as Hoenn. Export a count-compatible view and retain the exact
  -- source state in modData. Only the view is expanded; gameplay is restored
  -- before native save-schema loading. No launcher/engine patch is needed.
  local Schema=require('src.core.game3.save_schema_firered')
  local previous=game._hnsDexState or {}
  local export=previous.export or Schema.toSaveTable
  local restore=previous.restore or Schema.fromSaveTable
  Schema.toSaveTable=function(s,...)
    local out=export(s,...);if not(out and D.own(s))then return out end
    local national=Dex.nationalEnabled(s)
    out.modData=copy(out.modData or {})
    out.modData.hnsDexState={format=1,dex=copy(s.dex),flags=copy(out.flags),vars=copy(out.vars),pokedex=copy(s.pokedex)}
    out.dex=copy(s.dex or {});out.flags=copy(out.flags);out.vars=copy(out.vars)
    out.dex.caught={};out.dex.owned={}
    for _,r in ipairs(national and D.national or D.regional)do
      if r.species and D.caught(s.dex,r.species)then out.dex.caught[r.species]=true;out.dex.owned[r.species]=true end
    end
    Dex.enableNational(out);out.dex.hnsSummary070=true
    return out
  end
  Schema.fromSaveTable=function(s,...)
    return restore(D.sourceSave(s),...)
  end
  D.titleInfo=title;D.export=export;D.restore=restore
  D.summaryCount=base;game._hnsDexState=D
end
