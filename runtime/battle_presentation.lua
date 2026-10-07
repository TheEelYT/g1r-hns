-- HnS selection information and automatic throw-text continuation.
return function(mod,world,game)
  local old=game._hnsBattlePresentation or {}
  local U=assert(load(mod:read('source_ui.lua'),'@hns/source_ui.lua'))()(mod,world.startup.ui)
  local Ui=require('src.core.game3.battle.ui')
  local Catch=require('src.core.game3.battle.catch_seq')
  local State=require('src.core.game3.battle.state')
  local Moves=require('src.core.game3.battle.moves')
  local C=require('src.core.game3.constants').of('emerald')
  local rows={};for name,row in pairs(world.startup.rules.moves)do rows[C:require('moves','MOVE_'..name)]=row end
  for _,row in pairs(world.expandedMoves and world.expandedMoves.moves or {})do rows[row.id]=row end
  if world.campaign then rows[world.campaign.roostMove]=world.pokedex.moveInfo.ROOST end
  for _,row in pairs(world.moveTable and world.moveTable.moves or {})do rows[row.id]=row end
  local P={ui=U,hintX=-30}
  local function own(st)return (st and st.session and world.maps[st.session.map] and not (st.link or st.kinds and st.kinds.link)) and true or false end
  function P.eligible()
    return own(Ui._st) and Ui._mode=='moves' and not Ui._swap and not Ui.busy() and not Ui._pendingCommand
      and not (Ui._wally or Ui._st.oldManTutorial or Ui._st.pokedude)
  end
  function P.selected()
    local b=State.battler(Ui._st,Ui._active or 0) or Ui._st.player
    local moves=b and (b.moves or b.mon and b.mon.moves) or {}
    local id=moves[Ui._moveIndex or 1];if type(id)=='table'then id=id.id or id.move end
    if not id or id==0 then return nil end
    return Moves.get(id),rows[tonumber(id)]
  end
  local input=old.input or Ui.handleInput
  Ui.handleInput=function(keys)
    if not P.eligible()then P.details=false;return input(keys)end
    if P.details and (keys:wasPressed('a') or keys:wasPressed('b') or keys:wasPressed('start'))then P.details=false;return true end
    if keys:wasPressed('start')then P.details=true;return true end
    if P.details and keys:wasPressed('select')then return true end
    return input(keys)
  end
  function P.step()
    if not own(Ui._st)then P.details=false;P.hintX=-30;return end
    if P.eligible()then P.hintX=math.min(-2,P.hintX+1)
    else P.details=false;P.hintX=math.max(-30,P.hintX-1)end
  end
  local tick=old.tick or Ui.tick
  Ui.tick=function(...)local result=tick(...);P.step();return result end
  function P.draw()
    if not own(Ui._st)then return end
    if P.hintX<=-30 then return end
    local im,a=U.art('moveHint');local q=love.graphics.newQuad(0,0,32,32,a.width,a.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(im,q,P.hintX,(Ui._st.double and 86 or 76))
    if not P.details then return end
    local move,row=P.selected();if not move or not row then return end
    -- Emerald B_WIN_MOVE_DESCRIPTION at tile (1,47), BG0 scrolled 320px.
    U.box(8,56,144,48)
    local fg,sh={.25,.25,.25,1},{.8,.8,.8,1}
    U.text('CAT:',11,57,fg,sh,'small');U.text('PWR: '..(move.power>1 and move.power or '---'),64,57,fg,sh,'small')
    U.text('ACC: '..(move.accuracy>1 and move.accuracy or '---'),116,57,fg,sh,'small')
    local cat=move.category or row.category;local index=cat=='physical' and 0 or cat=='special' and 1 or 2
    local icon,info=U.art('moveCategory');local quad=love.graphics.newQuad(0,index*16,16,16,info.width,info.height)
    love.graphics.setColor(1,1,1,1);love.graphics.draw(icon,quad,30,56)
    U.text(U.wrap(row.description,140,'small'),11,73,fg,sh,'small',14)
  end
  local draw=old.draw or Ui.draw
  Ui.draw=function(...)local result=draw(...);P.draw();return result end
  local reset=old.reset or Ui.reset
  Ui.reset=function(...)P.details=false;P.hintX=-30;return reset(...)end
  local begin=old.begin or Catch.begin
  Catch.begin=function(st,id,caught,shakes,opts)
    if not own(st) or not opts or opts.headless or st.oldManTutorial or st.pokedude or st.kinds and st.kinds.tutorial then return begin(st,id,caught,shakes,opts)end
    local copy={};for k,v in pairs(opts)do copy[k]=v end
    local first=true;local push=opts.pushMsg
    copy.pushMsg=function(text,wait)
      if first then first=false;Ui.pushTimed(text,0)
      elseif push then push(text,wait)end
    end
    -- Source BattleScript_BallThrow prints the item text then handleballthrow,
    -- with no waitmessage or input wait. Native capture/result flow is retained.
    return begin(st,id,caught,shakes,copy)
  end
  game._hnsBattlePresentation={input=input,draw=draw,tick=tick,reset=reset,begin=begin,presentation=P}
end
