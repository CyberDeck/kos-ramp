/////////////////////////////////////////////////////////////////////////////
// Run node
/////////////////////////////////////////////////////////////////////////////
// Execute a maneuver node, warping if necessary to save time.
/////////////////////////////////////////////////////////////////////////////
// Example:
//   run node_peri(orbit:apoapsis). // create the node
//   run node. // execute the node
// Advanced:
//   function create_node { ... }
//   run node(create_node@). // create and execute the node using delegate
// Advanced 2:
//   run node({run node_create.}). // using anonymous function/delegate

parameter nodeCreator is false. // delegate to re-create node if needed
parameter burnTime is 0. // estimated burn time, lib_staging:burnTimeForDt used if zero

ON AG10 reboot.

runoncepath("lib/lib_ui").
runoncepath("lib/lib_util").
runoncepath("lib/lib_warp").
runoncepath("lib/lib_staging").

stagingPrepare().

// Configuration constants; these are pre-set for automated missions; if you
// have a ship that turns poorly, you may need to decrease these and perform
// manual corrections.
if not (defined node_bestFacing)
global node_bestFacing is 5.   // ~5  degrees error (10 degree cone)
if not (defined node_okFacing)
global node_okFacing   is 20.  // ~20 degrees error (40 degree cone)

local sstate is sas. // save SAS state
local rstate is rcs. // save RCS state

// quo vadis?
if not hasNode {
	if nodeCreator:istype("delegate") nodeCreator().
	if not hasNode uiFatal("Node", "No node to execute").
}
local nn is nextnode.

// keep ship pointed at node
sas off.
lock steerDir to lookdirup(nn:deltav, positionAt(ship,time:seconds+nn:eta)-body:position).
lock steering to steerDir.

// estimate burn direction & duration
local resetBurnTime is burnTime = 0.
if resetBurnTime set burnTime to burnTimeForDv(nn:deltav:mag).
local dt is burnTime/2.

local function faceManeuverNode {
	// If have time, wait to ship almost align with maneuver node.
	// If have little time, wait at least to ship face in general direction of node
	// This prevents backwards burns, but still allows steering via engine thrust.
	// If ship is not rotating for some reason, will proceed anyway. (Maybe only torque source is engine gimbal?)
	wait 0.
	local facingWarped to false.
	until utilIsShipFacing(steerDir,node_bestFacing,0.5)
		or nn:eta <= dt and utilIsShipFacing(steerDir,node_okFacing,5)
		or ship:angularvel:mag < 0.0001 and rcs = true
	{
		if ship:angularvel:mag < 0.01 rcs on.
		stagingCheck().
		if not facingWarped { set facingWarped to true. physWarp(1). }
		wait 0.
	}
	resetWarp().
}

local function recreateManeuverNode {
	// recreate node if warped more than 10 minutes and we have node creator delegate
	unlock steering. // release references before deleting nodes
	unlock steerDir.
	set nn to false.
	utilRemoveNodes().
	nodeCreator().
	wait 0.
	set nn to nextnode.
	if resetBurnTime set burnTime to burnTimeForDv(nn:deltav:mag).
	set dt to burnTime/2.
	sas off.
	lock steerDir to lookdirup(nn:deltav, positionAt(ship,time:seconds+nn:eta)-body:position).
	lock steering to steerDir.
}

faceManeuverNode().
if(nn:eta - dt - 60 > 600 and nodeCreator:istype("delegate")) {
	warpSeconds2(nn:eta - dt - 60).
	wait until nn:eta - dt - 60 < 60.
	resetWarp().
	recreateManeuverNode().
	faceManeuverNode().
}

warpSeconds2(nn:eta - dt - 10).
wait until nn:eta - dt < 10.
resetWarp().

stagingPrepare().

local dv0 is nn:deltav.
local dvMin is dv0:mag.
local minThrottle is 0.
local maxThrottle is 0.
lock throttle to min(maxThrottle,max(minThrottle,min(dvMin,nn:deltav:mag)*ship:mass/max(1,availableThrust))).
lock steerDir to lookdirup(nn:deltav,ship:position-body:position).

local almostThere to 0.
local choked to 0.
local warned to false.

if nn:eta-dt > 5 {
	physWarp(1).
	wait until nn:eta-dt <= 2.
	resetWarp().
}
wait until nn:eta-dt <= 1.
until dvMin < 0.05
{
	stagingCheck().
	wait 0. //Let a physics tick run each loop.

	local dv is nn:deltav:mag.
	if dv < dvMin set dvMin to dv.

	if ship:availablethrust > 0 {
		if utilIsShipFacing(steerDir,node_okFacing,2) {
			set minThrottle to 0.01.
			set maxThrottle to 1.
		} else {
			// we are not facing correctly! cut back thrust to 10% so gimbaled
			// engine will push us back on course
			set minThrottle to 0.1.
			set maxThrottle to 0.1.
			rcs on.
	 	}
		if vdot(dv0, nn:deltaV) < 0 break.	// overshot (node deltaV is pointing opposite from initial)
		if dv > dvMin + 0.1 break.		// burn DV increases (off target due to wobbles)
		if dv <= 0.2 {				// burn DV gets too small for main engines to cope with
			if almostThere = 0 set almostThere to time:seconds.
			if time:seconds-almostThere > 5 break.
			if dv <= 0.05 break.
		}
		set choked to 0.
	} else {
		if choked = 0 set choked to time:seconds.
		if not warned and time:seconds-choked > 3 {
			set warned to true.
			uiWarn("Node", "No acceleration").
		}
		if time:seconds-choked > 30 {
			uiFatal("Node", "No acceleration").
			break.
		}
	}
}

set ship:control:pilotMainThrottle to 0.
unlock throttle.

// Make fine adjustments using RCS (for up to 15 seconds)
if nn:deltaV:mag > 0.1 utilRCSCancelVelocity({return nn:deltaV.},0.1,15).
else wait 1.

// Fault if remaining dv > 5% of initial AND mag is > 0.1 m/s
if nn:deltaV:mag > dv0:mag * 0.05 and nn:deltaV:mag > 0.1 {
  uiFatal("Node", "BURN FAULT " + round(nn:deltaV:mag, 1) + " m/s").
} else if nn:deltaV:mag > 0.1 {
  uiWarning("Node", "BURN FAULT " + round(nn:deltaV:mag, 1) + " m/s").
}

remove nn.
// Release all controls to be safe.
unlock all.
set ship:control:pilotMainThrottle to 0.
set ship:control:neutralize to true.
set sas to sstate.
set rcs to rstate.
