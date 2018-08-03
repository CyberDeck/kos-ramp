/////////////////////////////////////////////////////////////////////////////
// Ascent phase of launch.
/////////////////////////////////////////////////////////////////////////////
// Ascend from a planet, performing a gravity turn and staging as necessary.
// Achieve circular orbit with desired apoapsis.
/////////////////////////////////////////////////////////////////////////////

// Final apoapsis (m altitude)
local function defaultApo {
	if body:atm:exists return body:atm:height + 10000.
	return min(15000, body:radius * 0.08).
}
parameter apo is 0.
if apo = 0 set apo to defaultApo().

// Heading during launch (90 for equatorial prograde orbit)
parameter hdglaunch is 90.

// Roll/rotation during launch
local function defaultRotation {
	// do not rotate the rocket 180° if we are already facing the proper way
	if abs(ship:facing:roll-180-hdglaunch) < 30 return 0.
	return 180. // needed for shuttles, should not harm rockets
}
parameter launchRoll is defaultRotation().

ON AG10 reboot.

runoncepath("lib/lib_parts").
runoncepath("lib/lib_ui").
runoncepath("lib/lib_util").
runoncepath("lib/lib_warp").
runoncepath("lib/lib_staging").

uiBanner("ascend", "Ascend to " + round(apo/1000) + "km; heading " + hdglaunch + "º").

// Starting/ending height of gravity turn
local launch_gt0 is body:atm:height * 0.007.
local launch_gt1 is max(body:atm:height * 0.7, body:radius * 0.02).

/////////////////////////////////////////////////////////////////////////////
// Steering function for continuous lock.
/////////////////////////////////////////////////////////////////////////////

function ascentSteering {
//	How far through our gravity turn are we? (0..1)
	local gtPct is min(1,max(0, (ship:altitude - launch_gt0) / (launch_gt1 - launch_gt0))).
//	Ideal gravity-turn azimuth (inclination) and facing at present altitude.
	local pitch is arccos(gtPct).

	return heading(hdglaunch, pitch) * r(0,0,launchRoll).
}

/////////////////////////////////////////////////////////////////////////////
// Throttle function for continuous lock.
/////////////////////////////////////////////////////////////////////////////

local maxQ is 0.3.
local pidMaxQ is PIDLOOP(0.05).
set pidMaxQ:setpoint to maxQ.
local thr is 1.
local controlQ is False.
function ascentThrottle {
	// reaching apoapsis
	local ApoPercent is ship:obt:apoapsis/apo.
	if ApoPercent > 0.95 {
		local ApoCompensation is (ApoPercent - 0.95) * 10.
		set thr to 1.05 - min(1, max(0, ApoCompensation)).
		return thr.
	}

	if ship:q > maxQ * 0.8 set controlQ to True.
	if(controlQ and ship:q < 0.2) set controlQ to False.

	if controlQ {
		set thr to thr + pidMaxQ:update(time:seconds, ship:q).
		set thr to max(0.1, min(thr, 1)).
		return thr.
	}
	
	set thr to 1.
	return thr.
}

/////////////////////////////////////////////////////////////////////////////
// Deploy fairings and panels at proper altitude; call in a loop.
/////////////////////////////////////////////////////////////////////////////

local deployed is false.
function ascentDeploy {
	if deployed return.
	if ship:altitude < ship:body:atm:height return.
	set deployed to true.
	if partsDeployFairings() {
		wait 0.
	}
	partsExtendSolarPanels().
	partsExtendAntennas().
}

/////////////////////////////////////////////////////////////////////////////
// Perform initial setup; trim ship for ascent.
/////////////////////////////////////////////////////////////////////////////

sas off.
bays off.
// panels off. - bug in kOS with OX-STAT: KSP-KOS/KOS#2213
partsRetractSolarPanels().
partsRetractAntennas().
radiators off.

lock steering to ascentSteering().
lock throttle to ascentThrottle().

/////////////////////////////////////////////////////////////////////////////
// Enter ascent loop.
/////////////////////////////////////////////////////////////////////////////

local warped to false.
until ship:obt:apoapsis >= apo or (ship:altitude > apo/2 and eta:apoapsis < 30) {
	stagingCheck().
	ascentDeploy().
	if not warped and altitude > min(ship:body:atm:height/10,1000) {
		set warped to true.
		physWarp(1).
	}
	wait 0.
}
unlock throttle.
set ship:control:pilotmainthrottle to 0.

/////////////////////////////////////////////////////////////////////////////
// Coast to apoapsis and hand off to circularization program.
/////////////////////////////////////////////////////////////////////////////

// Roll with top up
lock steering to heading (hdglaunch,0). //Horizon, ceiling up.
wait until utilIsShipFacing(heading(hdglaunch,0):vector).

// Warp to end of atmosphere
local AdjustmentThrottle is 0.
lock throttle to AdjustmentThrottle.
until ship:altitude > body:atm:height {
  if ship:obt:apoapsis < apo {
	set AdjustmentThrottle to ascentThrottle().
	stagingCheck().
	wait 0.
  } else {
	set AdjustmentThrottle to 0.
	wait 0.5.
  }
}
if warped resetWarp().
// Discard fairings and deploy panels, if they aren't yet.
ascentDeploy().
wait 1.

// Circularize
unlock all.
run circ.
