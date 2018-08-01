/////////////////////////////////////////////////////////////////////////////
// Dock
/////////////////////////////////////////////////////////////////////////////
// Docks with the target.
//
// Chooses an arbitrary docking port on the vessel, then finds a compatible
// port on the target (or uses the selected port if a port is already
// selected).
//
// Once a port is chosen, moves the docking ports into alignment and then
// approaches at a slow speed.
/////////////////////////////////////////////////////////////////////////////

ON AG10 reboot.

runoncepath("lib/lib_ui").
runoncepath("lib/lib_dock").
runoncepath("lib/lib_parts").

run approach.
wait until target:position:mag < 150.

dockMatchVelocity(0).

//Save before dock!
wait until KUniverse:CanQuickSave().
KUniverse:QuickSaveTo("Before docking").

local DockingDone is False.
local MaxDistanceToApproach is 5000.
local TargetVessel is 0.
if hastarget and target:istype("Vessel") set TargetVessel to Target.
else if hastarget and target:istype("DockingPort") set TargetVessel to target:ship.

if not ship:status = "ORBITING" {
  uiError("Dock", "not in orbit.").
  DockingDone on.
} else if hastarget and TargetVessel:Distance >= MaxDistanceToApproach {
  uiError("Dock","Target too far, run rendezvous.").
  DockingDone on.
} else if hastarget and TargetVessel:Distance >= KUNIVERSE:DEFAULTLOADDISTANCE:ORBIT:UNPACK and Target:Distance < MaxDistanceToApproach {
  uiWarning("Dock", "Target too far, approaching.").
  run approach.
} else if not hastarget {
  uiError("Dock", "No target selected").
  DockingDone on.
}

global dock_myPort is dockChoosePorts().
global dock_hisPort is target.

if dock_myPort = 0 {
  if ship:partsnamed("GrapplingDevice"):length < 1 {
    uiError("Grab", "No Docking port or AGU on ship").
    GrabbingDone on.
  } else {
    global dock_myPort is ship:partsnamed("GrapplingDevice")[0].
    dock_myPort:GetModule("ModuleGrappleNode"):DoEvent("Control from here").
    local m is dock_myPort:GetModule("ModuleAnimateGeneric").
    if m:AllEventNames:Contains("Arm") m:DoEvent("Arm").
  }
}

// maybe we just had to approach, re-check distance
if hastarget and TargetVessel:Distance > MaxDistanceToApproach {
  uiError("Dock", "Target too far.").
  DockingDone on.
}

local needBack is true.
until DockingDone {
  if dock_myPort <> 0 {
    global dock_station is TargetVessel.
    uiBanner("Dock", "Dock with " + dock_station:name).
    dockPrepare(dock_myPort, target).

    until dockComplete(dock_myPort) or not hastarget or target <> dock_hisPort {
      local rawD is target:position - dock_myPort:position.
      local sense is ship:facing.

      local dockD is V(
        vdot(rawD, sense:starvector),
        vdot(rawD, sense:upvector),
        vdot(rawD, sense:vector)
      ).
      local rawV is dock_station:velocity:orbit - ship:velocity:orbit.
      local dockV is V(
        vdot(rawV, sense:starvector),
        vdot(rawV, sense:upvector),
        vdot(rawV, sense:vector)
      ).
      local needAlign is (abs(dockD:x) > abs(dockD:z)/10) or (abs(dockD:y) > abs(dockD:z)/10).

      if needBack and dockD:Z > 5 {
        set needBack to false.
      }

      if needBack {
        dockBack(dockD, dockV).
      } else if needAlign or dockD:Z > dock_start {
        dockAlign(dockD, dockV).
      } else {
        dockApproach(dockD, dockV, dock_myPort).
      }
      wait 0.
    }

    uiBanner("Dock", "Docking complete").
    dockFinish().
  } else {
    uiError("Dock", "No suitable docking port; try moving closer?").
  }
  DockingDone on.
}
