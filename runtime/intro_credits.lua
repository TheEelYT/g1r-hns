-- Source expansion_intro.c sequence, between copyright and Game Freak.
return function(U,assets)
  local Audio=require('src.core.game3.audio')
  local C=require('src.core.game3.constants').of('emerald')
  local Pal=require('src.core.game3.pal_fade')
  local Credits={};local Scene={};Scene.__index=Scene
  function Credits.new()
    local self=setmetatable({state='in',counter=0,blend=31,eggX=300,eggTick=0,poryX=-32,poryY=115,poryTick=0,poryState='fly',ticks=0,pal=Pal.new()},Scene)
    self.pal:beginFade(1,0,16,0,Pal.BLACK)
    return self
  end
  local function se(name)Audio.playSe(C:require('songs',name))end
  function Scene:frame(skip)
    if self.state=='done'then return true end
    self.ticks=self.ticks+1;self.blend=math.max(0,self.blend-1)
    if self.state=='in'then
      if not self.pal:fadeActive()then self.state='wait'end
    elseif self.state=='wait'then
      if self.counter==208 or skip then
        self.state='out';self.pal:beginFade(Pal.ALL,0,0,16,Pal.BLACK)
      else self.counter=self.counter+1 end
    elseif not self.pal:fadeActive()then self.state='done';return true end
    -- Run sprite callbacks, then animations, then UpdatePaletteFade.
    if self.eggX>172 then
      self.eggX=self.eggX-1
      if self.eggTick%16==0 and math.floor(self.eggTick/16)>2 then se('SE_BIKE_HOP')end
      self.eggTick=self.eggTick+1
      if self.eggX==172 then self.eggDizzyTick=0 end
    else self.eggDizzyTick=self.eggDizzyTick+1 end
    if self.poryState=='fly'then
      if self.poryTick>=99 then
        self.poryX=self.poryX+6;self.poryY=self.poryY+(self.poryTick%32>=16 and -1 or 1)
        if self.poryX>=140 then self.poryState='hit';self.poryTick=0;se('SE_M_DOUBLE_SLAP')end
      end
      self.poryTick=self.poryTick+1
    elseif self.poryState=='hit'then
      self.poryX=self.poryX-2
      -- Source Sin2 is the integer degree lookup, divided by 128.
      local angle=(180+self.poryTick*4)%360
      local v=assets.sineDegrees[angle%180+1]*(angle>=180 and -1 or 1)
      self.poryBounce=v<0 and math.ceil(v/128)or math.floor(v/128)
      if self.poryTick%8==0 then self.shiny=self.poryTick%16==0 end
      if self.poryTick>=48 then self.poryState='up';self.poryUpTick=0 end
      self.poryTick=self.poryTick+1
    else self.poryUpTick=self.poryUpTick+1 end
    self.pal:updateFade()
    return false
  end
  local function draw(name,x,y,frame,h,shade)
    local a=assets[name];love.graphics.setColor(shade or 1,shade or 1,shade or 1,1)
    love.graphics.draw(U.image(a.file,a.width,a.height),love.graphics.newQuad(0,(frame or 0)*(h or a.height),a.width,h or a.height,a.width,a.height),x,y)
  end
  function Scene:draw()
    local fade=1-((self.pal.fade or {}).y or 0)/16
    love.graphics.setColor(0,0,0,1);love.graphics.rectangle('fill',0,0,240,160)
    draw('powered_by',0,0,0,nil,fade)
    draw('rhh_credits',0,0,0,nil,(1-math.min(16,self.blend)/16)*(self.state=='out'and fade or 1))
    local egg=self.eggX>172 and ({2,1,0,1,2,3,4,3})[math.floor(self.eggTick/4)%8+1]or ({5,6,7,6})[math.floor((self.eggDizzyTick or 0)/12)%4+1]
    local frame=self.poryState=='fly'and 0 or self.poryState=='up'and self.poryUpTick>=20 and 2 or 1
    draw(self.shiny and 'porygon_shiny'or 'porygon',self.poryX-32,self.poryY+(self.poryBounce or 0)-32,frame,64,self.state=='out'and fade or 1)
    draw('dizzy_egg',self.eggX-16,138-16,egg,32,self.state=='out'and fade or 1)
    love.graphics.setColor(1,1,1,1)
  end
  Credits.Scene=Scene;return Credits
end
