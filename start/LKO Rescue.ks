runoncepath("lib/lib_ui").
runoncepath("lib/lib_parts").
runoncepath("lib/lib_warp").

declare function waitForLaunch {
  // usually we want to get into an orbit below and behind our target
  // a negative angle means we want to be ahead of the target, in a higher orbit
  parameter targetAngle is 5. // this gives the target enough time to pass us
  
  local lock a to vectorangle(ship:up:vector, target:up:vector).
  
  local a0 is a.
  wait 1.
  local a1 is a.
  
  local lock decreasing to a1 < a0.
  local lock inWindow to a1 <= abs(targetAngle) and a1 >= abs(targetAngle) - 5.
  local lock nearing to a1 <= abs(targetAngle*2).
  local lock approaching to targetAngle > 0 and decreasing or targetAngle < 0 and not decreasing.
  
  // wait until angle is decreasing and in our window...
  set warp to 5.
  until approaching and inWindow {
    if approaching {
      if warp > 4 set warp to 4.
      if nearing and warp > 3 set warp to 3.
    }
  
    wait 1.
    set a0 to a1.
    set a1 to a.
  }
  
  set warp to 0.
}

if (ship:status = "PRELAUNCH" or ship:status = "LANDED") and (not hastarget or not target:typename = "Vessel") {
  uiBanner("Rescue", "Select a target vessel").
  wait until hastarget and target:typename = "Vessel".
}

if ship:status = "PRELAUNCH" or ship:status = "LANDED" {
  local ap is ship:body:atm:height + 10000.
  // make sure our orbits are at enogh altitude difference, too close and the hohmann transfer will be tricky
  if abs(ap - target:orbit:periapsis) < 20000 {
    set ap to target:orbit:apoapsis + 20000.
    set ap to round(ap/1000) * 1000.
  }

  if target:orbit:periapsis < 250000 {
    local window is 5.
    if ap > target:orbit:apoapsis set window to 50. // launch well ahead of target
    waitForLaunch(window).
  }

  lights off.
  run launch_asc(ap).
  reboot.
}

if hastarget and ship:status = "ORBITING" {
  run rendezvous.
  lights on.
  run dock.
}

if not hastarget and ship:status = "ORBITING" {
  ship:modulesnamed("ModuleGrappleNode")[0]:doevent("Control from here").
  rcs on.
  sas off.
  lock steering to retrograde.
  wait 10.
  set thr to 1.
  lock throttle to thr.
  local t is time:seconds.
  local lock dt to time:seconds - t.
  wait until orbit:periapsis < 15000 or dt > 60.
  set thr to 0.
  wait 1.
  stage.
  wait 1.
  stage.
  wait 1.
  chutes on.
  rcs on.
  lock steering to R(0,0,0) * -velocity:surface.
  wait 1.
  set warp to 3.
  wait until ship:altitude < body:atm:height.
  set warp to 0.
  wait 1.
  for m in ship:modulesnamed("ModuleDeployableAntenna") {
    for e in m:allEventNames() {
      if e:matchesPattern("Retract") m:doevent(e).
    }
  }
  for m in ship:modulesnamed("ModuleDeployableSolarPanel") {
    for e in m:allEventNames() {
      if e:matchesPattern("Retract") m:doevent(e).
    }
  }
  wait 1.
  set warpMode to "PHYSICS".
  wait 1.
  set warp to 3.
  wait until alt:radar < 12000.
  rcs off.
  sas off.
  unlock steering.
  wait until alt:radar < 50.
  set warp to 0.
}

