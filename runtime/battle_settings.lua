-- Source battle pacing and optional shortcuts, using native command dispatch.
return function(mod,w,game)
  local old=game._hnsBattleSettings or {};local S={ballX=-18};local H=game._hnsRules.rules
  local Rt=require('src.core.game3.runtime');local Ui=require('src.core.game3.battle.ui')
  local Intro=require('src.core.game3.battle.intro_seq');local AnimSeq=require('src.core.game3.battle.anim_seq')
  local B=require('src.core.game3.battle');local Engine=require('src.core.game3.battle.engine')
  local Items=require('src.core.game3.battle.items');local Bag=require('src.core.game3.bag')
  local U=game._hnsBattleVisuals and game._hnsBattleVisuals.visuals.ui or assert(load(mod:read('source_ui.lua')))()(mod,w.startup.ui)
  function S.balls(st)
    local rows={};for _,row in ipairs(Bag.listPocket(st.session.bag,'POKE_BALLS'))do if Items.isBall(row.id)then rows[#rows+1]=row.id end end
    return rows
  end
  function S.enabled(st)
    return H.battle(st)and st.wild and not(st.safari or st.oldManTutorial or st.pokedude or st.kinds and(st.kinds.tutorial or st.kinds.frontier))
      and H.value('ITEM_BATTLE_BALL_PROMPT',st.session)==0 and #S.balls(st)>0
  end
  local begin=old.begin or Intro.begin
  Intro.begin=function(st,opts)
    local result=begin(st,opts);S.quickTried=false
    if H.battle(st)and H.value('ITEM_BATTLE_FAST_INTRO',st.session)==0 then
      for _,step in ipairs(Intro._steps or {})do
        if step.kind=='bgslide'then step.data.frames=1;step.data.unlockAt=0;step.data.slideFrames=1
        elseif step.kind=='wait'then step.data.frames=1 end
      end
    end
    return result
  end
  local pushTimed=old.pushTimed or Ui.pushTimed
  Ui.pushTimed=function(text,wait,cb)
    if H.battle(Ui._st)and H.value('ITEM_BATTLE_FAST_BATTLES',Ui._st.session)==0 then wait=0 end
    return pushTimed(text,wait,cb)
  end
  local anim=old.anim or AnimSeq.update
  AnimSeq.update=function(...)
    if H.battle(B._st)and H.value('ITEM_BATTLE_FAST_BATTLES',B._st.session)==0 then AnimSeq._waitFrames=0 end
    return anim(...)
  end
  function S.quickWindow()
    local st=Intro._st
    if S.quickTried or not H.battle(st)or not st.wild or st.oldManTutorial or st.pokedude or not Intro._waitingMsg then return false end
    local first
    for i,step in ipairs(Intro._steps or {})do if step.kind=='msg'then first=i;break end end
    return first==Intro._i
  end
  function S.quickRun()
    local st=B._st;local ad=B._adapter;if not st or not ad then return false end
    local mark=ad:eventMark();local say=ad._say;ad._say=function()end
    local allowed,why=Engine.canRun(st,ad,st.player);local success=st.safari or allowed and Engine.tryFlee(st,ad,st.player)
    ad._say=say
    if not allowed and why then Ui.push(why)end
    for _,e in ipairs(ad:eventsSince(mark))do if e.kind=='msg'then Ui.push(e.text)end end
    if success then st.over=true;st.result='run';st.endReason='flee';B._pendingEnd='run';B._phase='ending';Intro.reset()end
    return success
  end
  local update=old.update or Intro.update
  Intro.update=function(...)
    if S.quickWindow()and not Ui.dialogPending()then
      S.quickTried=true;local keys=game.input;local kind=H.value('ITEM_BATTLE_RUN_TYPE',Intro._st.session)
      if keys and((kind==1 and keys:isDown('l')and keys:isDown('r'))or(kind==3 and keys:isDown('b')))then
        if S.quickRun()then return false end
      end
    end
    return update(...)
  end
  -- Presentation reinstalls its wrappers on game.ready. Capture that current
  -- chain, so repeated loading never retains a previous move-details instance.
  local input,tick,draw=Ui.handleInput,Ui.tick,Ui.draw
  Ui.handleInput=function(keys)
    local st=Ui._st
    if H.battle(st)and Ui._mode=='menu'and not Ui.busy()then
      if keys:wasPressed('b')and H.value('ITEM_BATTLE_RUN_TYPE',st.session)==2 then Ui._menuIndex=4;return true end
      if S.enabled(st)then
        local balls=S.balls(st);local last=st.session.modData and st.session.modData.hnsLastBall
        if not S.ball then S.ball=last or balls[1]end
        local index=1;for i,id in ipairs(balls)do if id==S.ball then index=i;break end end
        if keys:isDown('r')then
          S.rHeld=true
          if keys:wasPressed('left')or keys:wasPressed('up')then index=(index-2)%#balls+1;S.cycled=true
          elseif keys:wasPressed('right')or keys:wasPressed('down')then index=index%#balls+1;S.cycled=true end
          S.ball=balls[index];return true
        elseif S.rHeld then
          S.rHeld=false
          if not S.cycled and not keys:wasPressed('b')then
            Ui._pendingCommand={kind='bag',user='player',itemId=balls[index],battler=Ui._active or 0};Ui._mode='none'
          end
          S.cycled=false;return true
        end
      end
    else S.rHeld=false;S.cycled=false end
    return input(keys)
  end
  Ui.tick=function(...)
    local result=tick(...);local enabled=Ui._st and S.enabled(Ui._st)and Ui._mode=='menu'and not Ui.busy()
    S.ballX=enabled and math.min(14,S.ballX+1)or math.max(-18,S.ballX-1);if not enabled then S.ball=nil end
    return result
  end
  Ui.draw=function(...)
    local result=draw(...)
    if S.ballX>-18 and game._hnsBattleVisuals then
      local row=game._hnsBattleVisuals.visuals.row();local a=row.ballPrompt
      love.graphics.setColor(1,1,1,1);love.graphics.draw(U.image(a.file,a.width,a.height),S.ballX-16,(Ui._st.double and 78 or 68)-16)
      local balls=S.balls(Ui._st);local id=S.ball or (Ui._st.session.modData or {}).hnsLastBall or balls[1]
      require('src.ui.game3.rse.bag_chrome').drawItemIcon(id,S.ballX-12,(Ui._st.double and 78 or 68)-12)
    end
    if S.quickWindow()and H.value('ITEM_BATTLE_LR_RUN',Intro._st.session)==0 then
      local kind=H.value('ITEM_BATTLE_RUN_TYPE',Intro._st.session)
      if kind==1 then U.text('L+R: RUN',170,96,nil,nil,'small')end
    end
    return result
  end
  local use=old.use or Items.use
  Items.use=function(st,ad,bag,s,id,...)
    local a,b,consumed,d,e=use(st,ad,bag,s,id,...)
    if consumed and H.battle(st)and Items.isBall(id)then s.modData=s.modData or {};s.modData.hnsLastBall=id end
    return a,b,consumed,d,e
  end
  game._hnsBattleSettings={begin=begin,pushTimed=pushTimed,anim=anim,update=update,use=use,settings=S}
end
