-- Source SetStepAnimHandleAlternation / SeekSpriteAnim / ContinueAnim timing.
local M={}
function M.tick(a)
  if a.poseDelay>0 then a.poseDelay=a.poseDelay-1
  else a.poseIndex=(a.poseIndex+1)%4;a.poseDelay=a.poseDuration-1 end
end
function M.begin(a,spec,fast)
  a.poseIndex=a.poseIndex or 0
  local pos=spec.animPositions
  if a.poseIndex==pos[1]then a.poseIndex=pos[4]
  elseif a.poseIndex==pos[2]then a.poseIndex=pos[3]end
  a.poseDuration=fast and spec.runPoseDuration or spec.walkPoseDuration
  a.poseDelay=a.poseDuration
  M.tick(a)
end
function M.frame(a,spec)return spec.poseImages[(a.poseIndex or 0)+1]end
return M
