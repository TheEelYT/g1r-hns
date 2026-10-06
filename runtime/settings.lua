-- Source values, dependency checks, presets and mid-run lock policies.
return function(spec,U)
  local M={}
  function M.new(kind,values,initial)
    local s={pages={},values={},tab=1,cursor=1,initial=initial~=false}
    for _,p in ipairs(spec.pages)do
      for _,r in ipairs(p.rows)do local v=values and values[r.id];s.values[r.id]=v~=nil and v or r.default end
      if not kind or p.kind==kind then s.pages[#s.pages+1]=p end
    end
    return s
  end
  function M.active(s,p,r)
    local v=s.values;local id=r.id
    if not s.initial and r.lock=='FULL' then return false end
    if #r.choices==0 then return true end
    if p.id=='MODE' and id~='ITEM_MODE_GAMEMODE' then
      return v.ITEM_MODE_GAMEMODE==1 and not (id=='ITEM_MODE_FAIRY_TYPES' and v.ITEM_CHALLENGES_ONE_TYPE==17)
    elseif p.id=='RANDOMIZER' and id~='ITEM_RANDOM_OFF_ON' then
      if v.ITEM_RANDOM_OFF_ON==0 then return false end
      local any=v.ITEM_RANDOM_WILD_PKMN>0 or v.ITEM_RANDOM_STARTER>0 or v.ITEM_RANDOM_TRAINER>0 or v.ITEM_RANDOM_STATIC>0
      if id=='ITEM_RANDOM_MAP_BASED' then return v.ITEM_RANDOM_WILD_PKMN>0 end
      if id=='ITEM_RANDOM_SIMILAR' then return any and v.ITEM_RANDOM_CHAOS==0 end
      if id=='ITEM_RANDOM_LEGENDARIES' or id=='ITEM_RANDOM_GEN_SCOPE' then return any end
      if id=='ITEM_RANDOM_CHAOS' then
        for _,key in ipairs({'TYPE','MOVES','ABILITIES','EVOLUTIONS','EVO_METHODS','TYPE_EFFEC'})do any=any or v['ITEM_RANDOM_'..key]>0 end
        return any
      end
    elseif p.id=='NUZLOCKE' and id~='ITEM_NUZLOCKE_NUZLOCKE' then
      local n=v.ITEM_NUZLOCKE_NUZLOCKE
      return n>0 and (id=='ITEM_NUZLOCKE_RARE_CANDY' or n~=1)
    elseif id=='ITEM_CHALLENGES_MIRROR_THIEF' then return v.ITEM_CHALLENGES_MIRROR==1
    elseif id=='ITEM_BATTLE_LR_RUN' then return v.ITEM_BATTLE_RUN_TYPE==1 or v.ITEM_BATTLE_RUN_TYPE==3 end
    return true
  end
  function M.frame(s,inp)
    local keys=inp.new
    if s.confirm then
      if keys.up or keys.down then s.yes=not s.yes end
      if keys.b then s.confirm=false elseif keys.a then if s.yes then return true else s.confirm=false end end
      return
    end
    if keys.b and not s.initial then s.cancelled=s.pages[s.tab].kind=='challenge';return true end
    if keys.l and s.tab>1 then s.tab=s.tab-1;s.cursor=1 end
    if keys.r then if s.tab<#s.pages then s.tab=s.tab+1;s.cursor=1 elseif s.initial or s.pages[s.tab].kind=='challenge' then if s.pages[s.tab].kind=='option' then return true end;s.confirm=true;s.yes=true;return end end
    local p=s.pages[s.tab]
    if p.kind=='engine'then return end
    if keys.up then s.cursor=(s.cursor-2)%#p.rows+1 end
    if keys.down then s.cursor=s.cursor%#p.rows+1 end
    local row=p.rows[s.cursor];local v=s.values
    if #row.choices>0 and (keys.left or keys.right) and M.active(s,p,row) then
      local old=v[row.id];local next=(old+(keys.left and -1 or 1))%#row.choices
      if s.initial or row.lock~='ONEWAY_DOWN' or next<=old then v[row.id]=next end
      if row.id=='ITEM_MODE_GAMEMODE' and v[row.id]==0 then
        for _,id in ipairs({'MODERN_MOVES','SYNCHRONIZE','STURDY','NEW_CITRUS','FAIRY_TYPES','LEGENDARY_ABILITIES','INFINITE_TMS','MINTS','SURVIVE_POISON','SPLIT'})do v['ITEM_MODE_'..id]=1 end
        v.ITEM_MODE_GEN_ONE_RECHARGE=0
      end
      if row.id=='ITEM_NUZLOCKE_NUZLOCKE' and v[row.id]<=1 then
        for _,id in ipairs({'SPECIES_CLAUSE','SHINY_CLAUSE','NICKNAMING','DELETION'})do v['ITEM_NUZLOCKE_'..id]=0 end
        v.ITEM_NUZLOCKE_RARE_CANDY=1
      end
      if row.id=='ITEM_CHALLENGES_ONE_TYPE' and v[row.id]==17 then v.ITEM_MODE_FAIRY_TYPES=1 end
    end
    if keys.a and #row.choices==0 then
      if row.name=='SAVE' then if p.kind=='option' then return true end;s.confirm=true;s.yes=true else s.tab=s.tab+1;s.cursor=1 end
    end
    if keys.start then if p.kind=='option' then return true end;s.confirm=true;s.yes=true end
  end
  function M.native(s)
    local out={}
    for _,p in ipairs(s.pages)do for _,r in ipairs(p.rows)do if r.native then out[r.native]=r.native=='textSpeed' and math.min(2,s.values[r.id]) or s.values[r.id] end end end
    return out
  end
  function M.draw(s)
    local c=U.spec.colors;love.graphics.setColor(14/31,20/31,24/31,1);love.graphics.rectangle('fill',0,0,240,160)
    love.graphics.setColor(unpack(c[16]));love.graphics.rectangle('fill',0,0,240,16)
    local p=s.pages[s.tab];U.text(p.name,120-U.width(p.name,'small')/2,1,c[2],c[3],'small')
    if p.kind=='challenge' and not s.initial then
      local right=240-U.tokenWidth('{R_BUTTON}NEXT','small')-5
      if s.tab>1 then U.tokenText('{L_BUTTON}PREVIOUS',5,1,'small',c[2],c[3])end
      U.tokenText(s.tab<#s.pages and '{R_BUTTON}NEXT' or '{R_BUTTON}SAVE',right,1,'small',c[2],c[3])
      local cancelX=(120+U.width(p.name,'small')/2+right)/2-U.tokenWidth('{B_BUTTON}CANCEL','small')/2
      U.tokenText('{B_BUTTON}CANCEL',math.floor(cancelX),1,'small',c[2],c[3])
    else
      if s.tab>1 then U.glyph('L_BUTTON',2,1,'small',c[2],c[3])end
      if s.tab<#s.pages or s.initial and p.kind=='challenge' then U.glyph('R_BUTTON',222,1,'small',c[2],c[3])end
    end
    local frame=p.kind=='option' and s.values.ITEM_MAIN_FRAMETYPE>0 and 'frame'..(s.values.ITEM_MAIN_FRAMETYPE+1) or 'frame'
    U.box(16,24,208,80,frame,p.kind=='option' and {192/255,192/255,192/255,1} or nil)
    local offset=math.max(0,s.cursor-5)
    for i=offset+1,math.min(#p.rows,offset+5)do
      local r=p.rows[i];local y=25+(i-offset-1)*16;local active=M.active(s,p,r)
      if i==s.cursor then local shade=p.kind=='option' and .69 or .88;love.graphics.setColor(shade,shade,shade,1);love.graphics.rectangle('fill',16,y-1,208,16) end
      U.text(r.name,24,y,active and c[6] or c[5],active and c[7] or c[4])
      local n=#r.choices;local selected=s.values[r.id];local orders={}
      if n==2 then orders={0,1} elseif n==3 then orders=selected==0 and {0,1} or {1,2}
      elseif n>=4 and n<=6 then local first=math.max(0,math.min(n-3,selected-1));orders={first,first+1,first+2}
      elseif n>0 then orders={selected} end
      local left=r.id=='ITEM_MODE_GAMEMODE' and 90 or 120
      for j,index in ipairs(orders)do
        local value=r.choices[index+1];local x=left
        if #orders==1 or j==#orders then x=214-U.tokenWidth(value,'normal')
        elseif j==2 then x=120+(U.tokenWidth(r.choices[orders[1]+1],'normal')-U.tokenWidth(value,'normal')-U.tokenWidth(r.choices[orders[3]+1],'normal')+94)/2 end
        local chosen=index==selected
        U.tokenText(value,x,y,'normal',active and (chosen and c[8] or c[3]) or (chosen and c[14] or c[5]),active and chosen and c[9] or not active and chosen and c[15] or c[4])
      end
    end
    if s.confirm then
      U.box(16,120,160,32);U.box(192,120,32,32)
      U.text('Confirm your choices?',24,121)
      U.text((s.yes and '▶' or ' ')..'YES\n'..(s.yes and ' ' or '▶')..'NO',192,121)
    else
      U.box(16,120,208,32,frame)
      local r=p.rows[s.cursor];local desc=r.descriptions[s.values[r.id]+1] or r.descriptions[1] or ''
      if #r.choices>0 and not r.implemented then desc='NOT IMPLEMENTED YET.\nChoice saved; has no effect.'
      elseif r.partial then desc=r.partial end
      desc=desc:gsub('{([ABLR])_BUTTON}','%1')
      U.text(desc,24,121)
    end
  end
  return M
end
