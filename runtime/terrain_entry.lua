-- Source BattleIntroSlide1/2/3 BG1 register progression. Sprite orchestration
-- remains native; Modern scenery uses the source's separate entry tilemap.
return function(sine)
  local function cos(angle)
    angle=angle+90
    local v=sine[angle%180+1]
    return math.floor(angle/180)%2==1 and -v or v
  end
  local function trunc(v)return v<0 and math.ceil(v)or math.floor(v)end
  return function(frame,kind,environment)
    local s={x=0,y=0,scan=240,top=80,bottom=81,alpha=16,visible=true}
    local state,delay,hold,remaining,blend,timer,angle,win=0,0,0,0,0,0,0,0x5051
    for _=1,math.max(0,frame)do
      s.x=s.x+(kind==3 and 8 or kind==2 and(environment=='SAND'or environment=='WATER')and 8 or 6)
      if kind==2 and environment=='WATER'then
        s.y=trunc(cos(angle)/512)-8
        angle=angle+(angle<180 and 4 or 6);if angle==360 then angle=0 end
      end
      if state==0 then
        delay=1;state=1;blend=kind==3 and 0x808 or kind==2 and 16 or 0
      elseif state==1 then
        delay=delay-1;if delay==0 then state=2 end
      elseif state==2 then
        win=(win-0xFF)%65536
        if math.floor(win/256)==48 then state=3;remaining=240;hold=32;timer=1 end
      elseif state==3 then
        if hold>0 then
          hold=hold-1
          if kind==2 and hold==0 then s.alpha=15 end
        elseif kind==1 then
          s.y=math.max(environment=='LONG_GRASS'and -80 or -56,s.y-(environment=='LONG_GRASS'and 2 or 1))
        else
          if blend%(kind==2 and 32 or 16)>0 then
            timer=timer-1
            if timer==0 then blend=blend+255;timer=kind==2 and 4 or 6 end
          end
        end
        if math.floor(win/256)>0 then win=(win-0x3FC)%65536 end
        if remaining>0 then remaining=remaining-2 end
        s.scan=remaining
        if remaining==0 then state=4;s.visible=false end
      else
        s.x=0;s.y=0;s.visible=false
      end
      if kind~=1 and state~=4 then s.alpha=math.min(16,blend%32)end
    end
    s.top=math.floor(win/256);s.bottom=win%256
    return s
  end
end
