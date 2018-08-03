// we plan to get into an orbit below and well behind our target

parameter targetAngle is 5. // this gives the target enough time to pass us

local lock a to vectorangle(ship:up:vector, target:up:vector).

local a0 is a.
wait 1.
local a1 is a.

set targetAngle to max(targetAngle, 5). // sanity check
local lock decreasing to a1 < a0.
local lock inWindow to a1 <= targetAngle and a1 >= targetAngle - 5.
local lock nearing to a1 <= targetAngle*2.

// wait until angle is decreasing and in our window...
set warp to 5.
until decreasing and inWindow {
  if decreasing {
    if warp > 3 set warp to 3.
    if nearing and warp > 2 set warp to 2.
  }

  wait 1.
  set a0 to a1.
  set a1 to a.
}

set warp to 0.

