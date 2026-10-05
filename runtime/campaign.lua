-- Scoped native services for the first badge and its source ROOST TM.
return function(mod,world,game)
  local Q=world.campaign
  local Pokemon=require('src.core.game3.pokemon')
  local Items=require('src.core.game3.items_data')
  local FieldMoves=require('src.core.game3.field_moves')
  local Effects=require('src.core.game3.battle.effects')
  local Moves=require('src.core.game3.battle.moves')
  local C=require('src.core.game3.constants').of('emerald')
  local old=game._hnsCampaign or {}
  local function own()
    local s=require('src.core.game3.runtime').getSession()
    return s and world.maps[s.map]~=nil
  end
  local function isRoost(id)return (tonumber(id) or Items.toNumericId(id))==Q.roostItem end
  local baseTm=old.isTm or Items.isTm;local number=old.tmNumber or Items.tmNumber
  local from=old.moveFromTmItem or Pokemon.moveFromTmItem
  local can=old.canLearnTmItem or Pokemon.canLearnTmItem
  local badge=old.badgeFlag or FieldMoves.badgeFlag
  local constName=old.constName or Moves.constName
  local numForName=old.numForName or Moves.numForName
  -- Native name construction scans the original ROM count. Add this owned
  -- move explicitly without widening that scan into missing ROM rows.
  Moves.constName=function(id)if tonumber(id)==Q.roostMove then return 'HNS_ROOST' end;return constName(id) end
  Moves.numForName=function(name)if name=='HNS_ROOST' or name=='ROOST' then return Q.roostMove end;return numForName(name) end
  local eligible={}
  for _,name in ipairs(Q.roostSpecies) do eligible[C.species.byName['SPECIES_'..name]]=true end
  Items.isTm=function(id)if isRoost(id) then return true end;return baseTm(id) end
  Items.tmNumber=function(id)if isRoost(id) then return 51 end;return number(id) end
  Pokemon.moveFromTmItem=function(id)if isRoost(id) then return Q.roostMove end;return from(id) end
  Pokemon.canLearnTmItem=function(species,id)if isRoost(id) then return eligible[tonumber(species)]==true end;return can(species,id) end
  FieldMoves.badgeFlag=function(name)
    if own() then
      if name=='FLASH' then return C.flags.byName.FLAG_BADGE01_GET end
      if name=='CUT' then return C.flags.byName.FLAG_BADGE02_GET end
    end
    return badge(name)
  end
  local run=old.runForMove or Effects.runForMove
  local typeIds=require('src.core.game3.battle.types').ID
  local flying,normal=typeIds.FLYING,typeIds.NORMAL
  local resting=old.resting or {}
  Effects.runForMove=function(adapter,user,target,id,ctx)
    if tonumber(id)~=Q.roostMove then return run(adapter,user,target,id,ctx) end
    local before=adapter:hp(user)
    Effects.run('EXP_RECOVER_EFFECT',adapter,user,user,Moves.get(id),id,ctx)
    if adapter:hp(user)>before and (user.type1==flying or user.type2==flying) then
      resting[user]={user.type1,user.type2}
      if user.type1==flying and user.type2==flying then user.type1,user.type2=normal,normal
      elseif user.type1==flying then user.type1=user.type2
      else user.type2=user.type1 end
    end
    return true
  end
  if not old.events then
    local function restore()
      for user,types in pairs(resting) do user.type1,user.type2=types[1],types[2];resting[user]=nil end
    end
    mod.events:on('battle.turn_ended',restore);mod.events:on('battle.ended',restore)
  end
  game._hnsCampaign={isTm=baseTm,tmNumber=number,moveFromTmItem=from,canLearnTmItem=can,badgeFlag=badge,runForMove=run,resting=resting,events=true,constName=constName,numForName=numForName}
end
