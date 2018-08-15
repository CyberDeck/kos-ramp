// This lands a rover type vessel in vacuum.
// Does not work with RemoteTech because SAS control is used.
// Decouplers/Fairings tagged with "descend" will deploy during descend.
// Decouplers, Antennas, Solar Panels tagged with "landed" will deploy after touchdown.

runoncepath("lib/lib_ui.ks").
runoncepath("lib/lib_parts.ks").
runoncepath("lib/lib_staging.ks").

sas off.
lock steering to srfretrograde.
wait 10.

if ship:status = "ORBITING" {
  lock throttle to 1.
  local t is time:seconds.
  local lock dt to time:seconds - t.
  wait until orbit:periapsis < 1000 or dt > 60.
  lock throttle to 0.
  wait 1.
}

if ship:altitude > 20000 {
  set warp to 5.
  wait until ship:altitude < 20000.
  set warp to 0.
  wait 1.
}

// kill horizontal velocity
sas off.
lock steering to angleaxis(-90, vcrs(up:forevector, velocity:surface)) * up:forevector.
wait 10.
until ship:groundspeed < 20 {
  lock throttle to 1.
  stagingCheck().
  wait 0.
}
lock throttle to 0.

lock steering to srfretrograde.
wait 10.

lock trueRadar to alt:radar - 300.
lock g to constant:g * body:mass / body:radius^2.
lock maxDecel to (ship:availablethrust / ship:mass) - g.
lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).
lock impactTime to trueRadar / abs(ship:verticalspeed).

brakes on.
gear on.


partsRetractAntennas("landed").
partsRetractSolarPanels("landed").

set warp to 2.
wait until trueRadar < stopDist * 5 or alt:radar < 10000.
set warp to 1.
wait until trueRadar < stopDist * 1.3 or alt:radar < 7000.

set warp to 0.
wait until trueRadar < stopDist.


lights on.
lock throttle to 1.
until ship:verticalspeed > -10 {
  stagingCheck().
  wait 0.
}
lock throttle to 0.
wait 0.2.
partsDoEvent("ModuleDecouple", "decouple", "descend").
stage.
wait 0.2.

when alt:radar < 10 or ship:verticalspeed > -0.1 then {
  lock steering to up.
}

local pid is pidloop(0.1, 0.016, 0.016).
set pid:setpoint to -10.
when alt:radar < 20 then set pid:setpoint to -6.
when alt:radar < 10 then set pid:setpoint to -2.

print("a " + ship:status).

local thr is 0.3.
lock throttle to thr.
until ship:status = "LANDED" {
  stagingCheck().
  set thr to min(1, thr + pid:update(time:seconds, ship:verticalspeed)).
  wait 0.
}

print("b " + ship:status).

set thr to 0.
rcs off.
unlock all.

wait 10.
set thr to 0.2.
wait 0.1.
partsDoEvent("ModuleDecouple", "decouple", "landed").

wait 10.
lights off.
partsExtendAntennas("landed").
partsExtendSolarPanels("landed").
wait 5.
reboot.

