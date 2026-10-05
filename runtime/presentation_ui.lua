-- Source-shaped field overlays; script completion waits for their real lifetime.
return function(mod,world,game,Settings,U,O,old)
  old=old or {};local Q=world.startup
  local Stack=require('src.ui.game3.stack');local Rt=require('src.core.game3.runtime')
  local Audio=require('src.core.game3.audio');local N=require('src.core.game3.scripting.natives')
  local Flags=require('src.core.game3.scripting.flags');local Space=require('src.core.game3.scripting.space')
  local C=require('src.core.game3.constants').of('emerald')
  local function own() local s=Rt.getSession();return s and world.maps[s.map]~=nil end
  local function se(name) Audio.playSe(C:require('songs',name)) end
  local H={ID='hns_help'}
  function H.show(done)
    H.done=done;se('SE_RG_HELP_OPEN');Stack.push(H.ID,H,{hideBelow=false,fullscreen=false})
  end
  function H.handleInput(input)
    if input:wasPressed('a') or input:wasPressed('b') then
      se('SE_RG_HELP_CLOSE');Stack.pop(H.ID);local done=H.done;H.done=nil;if done then done() end
    end
  end
  function H.draw()
    U.box(16,24,208,112)
    U.text(Q.clockHelp.header,16,25,{.12,.46,.94,1},{.63,.78,1,1})
    U.text(Q.clockHelp.body,16,41)
  end
  local P={ID='hns_phone'}
  function P.show(text,done,caller)
    P.done=done;P.caller=caller;P.state='slide_in';P.offset=32;P.timer=0;P.page=1;P.reveal=0;P.pages={}
    text=text:gsub('\\n','\n'):gsub('\\p','\f'):gsub('\\l','\n')
    -- Source caller is in the namebox; avoid repeating its prefix in the body.
    text=text:gsub('^PROF%. ?ELM:%s*',''):gsub('^MOM:%s*','')
    for para in (text..'\f'):gmatch('(.-)\f')do
      local lines={};for line in U.wrap(para,184):gmatch('[^\n]+')do lines[#lines+1]=line end
      for i=1,#lines,2 do P.pages[#P.pages+1]=table.concat(lines,'\n',i,math.min(i+1,#lines)) end
    end
    if #P.pages==0 then P.pages[1]='' end
    se('SE_POKENAV_CALL');Stack.push(P.ID,P,{hideBelow=false,fullscreen=false})
  end
  function P.finish()
    Stack.pop(P.ID);local done=P.done;P.done=nil;P.state='closed';if done then done() end
  end
  function P.handleInput(input)
    P.timer=P.timer+1;local press=input:wasPressed('a') or input:wasPressed('b')
    if P.state=='slide_in' then P.offset=math.max(0,P.offset-6);if P.offset==0 then P.state='ring';P.timer=0 end
    elseif P.state=='ring' then if press and P.timer>=6 then P.state='text';P.timer=0;P.reveal=0 end
    elseif P.state=='text' then
      local chars=0;for _ in U.chars(P.pages[P.page])do chars=chars+1 end
      local speed=({8,4,1})[require('src.core.game3.options').textSpeed(Rt.getSession())+1]
      if P.timer%speed==0 then P.reveal=math.min(chars,P.reveal+1) end
      P.complete=P.reveal>=chars
      if press then
        if P.reveal<chars then P.reveal=chars
        elseif P.page<#P.pages then P.page=P.page+1;P.reveal=0;P.timer=0;P.complete=false
        elseif not Audio.isSePlaying(C:require('songs','SE_POKENAV_CALL')) then se('SE_POKENAV_HANG_UP');P.state='slide_out' end
      end
    elseif P.state=='slide_out' then
      P.offset=P.offset+6
      if P.offset>=64 and not Audio.isSePlaying(C:require('songs','SE_POKENAV_HANG_UP')) then P.finish() end
    end
  end
  function P.draw()
    local y=120+P.offset;U.box(8,y,224,32,'callFrame',U.spec.iconColors[9])
    local icon,a=U.art('callIcon');local frame=math.floor(P.timer/9)%8
    local quad=love.graphics.newQuad(0,frame*32,32,32,a.width,a.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(icon,quad,8,y)
    if P.state=='ring' or P.state=='slide_in' then U.text('………………',40,y+1,U.spec.iconColors[11],U.spec.iconColors[15])
    else
      local name=P.caller or 'PROF. ELM';local w=math.max(24,math.ceil(U.width(name,'small')/8)*8)
      local im,info=U.art('callName')
      for tile=0,w/8+1 do
        local x=8+tile*8;local index=tile==0 and 0 or tile==w/8+1 and 2 or 1
        U.tile('callName',index,x,104+P.offset);U.tile('callName',index+3,x,112+P.offset)
      end
      U.text(name,16+(w-U.width(name,'small'))/2,104+P.offset,U.spec.callColors[2],U.spec.callColors[1],'small')
      local s={};local n=0;for c in U.chars(P.pages[P.page]or '')do n=n+1;if n>P.reveal then break end;s[#s+1]=c end
      U.text(table.concat(s),40,y+1,U.spec.iconColors[11],U.spec.iconColors[15])
      if P.complete and P.timer%32<16 then love.graphics.setColor(1,0,0,1);love.graphics.polygon('fill',219,y+20,225,y+20,222,y+25) end
    end
  end
  N.ALLOW['native:'..Q.helpNative]=function(ctx,a)return N.yieldHost(ctx,a,function(done)H.show(done)end)end
  local nameMon=assert(N.handlerFor('ChangePokemonNickname'))
  N.ALLOW['native:'..Q.nicknameNative]=function(ctx,a)
    if Flags.getVar(Space.store,ctx,0x8005)~=0 then return false end
    local s=Rt.getSession();local sp=Flags.getVar(Space.store,ctx,world.opening.vars.species);local index
    -- Normally slot zero. A continued/debug game may already have a party;
    -- rename only the newly added matching starter, never another species.
    for i=#(s.party or {}),1,-1 do if s.party[i].species==sp then index=i-1;break end end
    if index==nil then return false end
    Flags.setVar(Space.store,ctx,0x8004,index);return nameMon(ctx,a)
  end
  -- Extend the native PC hub while retaining its storage and item services.
  local PC=require('src.ui.game3.pc_menu');local root=old.pcRoot or PC._rootEntries;local handle=old.pcInput or PC.handleInput
  PC._rootEntries=function()
    local rows=root();if not own() then return rows end
    local copy={};for _,r in ipairs(rows)do if r.id=='quit' then copy[#copy+1]={id='hns_challenge',label='GAME MODES'} end;copy[#copy+1]=r end
    return copy
  end
  PC.handleInput=function(input)
    if own() and PC.mode=='root' and input:wasPressed('a') then
      local row=PC._rootEntries()[PC.cursor]
      if row and row.id=='hns_challenge' then O.show({session=Rt.getSession(),kind='challenge'});return end
      if row and row.id=='quit' and PC._select then PC._silentClose=true;PC.close(#root()-1);return end
    end
    return handle(input)
  end
  N.ALLOW['native:'..Q.pcNative]=function(ctx,a)return N.yieldHost(ctx,a,function(done)
    se('SE_PC_ON');PC.show({session=Rt.getSession(),onClose=done})
  end)end
  local MonPic=require('src.ui.game3.mon_pic');local show=old.monShow or MonPic.show
  MonPic.show=function(species,x,y,opts)
    show(species,x,y,opts)
    if own() then
      local names={[C:require('species','SPECIES_CHIKORITA')]='chikorita',[C:require('species','SPECIES_CYNDAQUIL')]='cyndaquil',[C:require('species','SPECIES_TOTODILE')]='totodile'}
      if names[species] then MonPic._img=U.art(names[species]);MonPic._w=64;MonPic._h=64 end
    end
  end
  local FX=require('src.core.game3.field_effects');local emote=old.emote or FX.startEmote
  FX.startEmote=function(obj,kind,done)
    if own() then
      local ex,a=U.art('exclamation');local qu,b=U.art('question')
      -- Native emote frame numbers share one sheet. Supply the exact two
      -- source images as quads on separate sheets through a scoped profile.
      for name,img in pairs({hns_exclamation=ex,hns_question=qu})do
        FX._sheets[name]={image=img,quads={[0]=love.graphics.newQuad(0,0,16,16,16,16)},fw=16,fh=16,frames=1}
      end
    end
    return emote(obj,kind,done)
  end
  local Profile=require('src.core.game3.profile');local profile=old.profile or Profile.forSession
  Profile.forSession=function(session)
    local row=profile(session);local s=session or Rt.getSession()
    if not(s and world.maps[s.map])then return row end
    local copy={};for k,v in pairs(row)do copy[k]=v end
    copy.field={};for k,v in pairs(row.field or {})do copy.field[k]=v end
    copy.field.emotes={exclamation={sheet='hns_exclamation',frame=0},question={sheet='hns_question',frame=0},heart=(row.field.emotes or {}).heart,frames=60,yVelocity=-5}
    return copy
  end
  return {help=H,phone=P,pcRoot=root,pcInput=handle,monShow=show,emote=emote,profile=profile,ui=U}
end
