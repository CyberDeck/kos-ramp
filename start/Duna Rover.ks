// This lands a rover type vessel on Duna.
// Does not work with RemoteTech because SAS control is used.
// Decouplers tagged with "entry" will be decoupled when entering the atmosphere
// Decouplers/Fairings tagged with "descend" will deploy during descend.
// Decouplers, Antennas, Solar Panels tagged with "landed" will deploy after touchdown.

runoncepath("lib/lib_ui.ks").
runoncepath("lib/lib_parts.ks").
runoncepath("lib/lib_staging.ks").

declare function srfRetro {
  unlock steering.
  rcs on.
  sas on.
  set navmode to "SURFACE".
  wait 1.
  set sasmode to "RETROGRADE".
}

if ship:body:name = "Duna" {

if ship:status = "ORBITING" {
  srfRetro().
  set navmode to "ORBIT".
  wait 10.
  set thr to 1.
  lock throttle to thr.
  local t is time:seconds.
  local lock dt to time:seconds - t.
  wait until orbit:periapsis < 10000 or dt > 60.
  set thr to 0.
  wait 1.
}

if ship:status = "SUB_ORBITAL" {
  srfRetro().
  wait 1.
  set warp to 5.
  wait until ship:altitude < body:atm:height.
  set warp to 0.
  wait 1.
  partsRetractAntennas().
  partsRetractSolarPanels().
  partsDoEvent("ModuleDecouple", "decouple", "entry").
  wait 1.
}

if ship:status = "FLYING" {
  srfRetro().
  // don't make me wait for so long...
  set warpMode to "PHYSICS".
  wait 1.
  set warp to 3.
  wait until alt:radar < 6000.
  set warp to 0.
  wait 1.
  // deploy whatever fairings we have
  partsDeployFairings("descend").
  wait 1.
  set warp to 3.
  wait until alt:radar < 2000.
  set warp to 0.
  chutes on.
  wait until alt:radar < 1000.
  // jettison base plate with heat shields and deorbit engines
  partsDoEvent("ModuleDecouple", "decouple", "descend").
  wait until alt:radar < 100.
  lights on.
  brakes on.

  when alt:radar < 5 or ship:verticalspeed > -0.1 or ship:status <> "FLYING" then {
    set sasmode to "". // stability assist
  }

  local pid is pidloop(0.1, 0.016, 0.016).
  set pid:setpoint to -6.
  when alt:radar < 15 then set pid:setpoint to -2.

  local thr is 0.3.
  lock throttle to thr.
  until ship:status <> "FLYING" {
    stagingCheck().
    set thr to min(1, thr + pid:update(time:seconds, ship:verticalspeed)).
    wait 0.
  }

  local t is thr.
  set thr to 0.
  rcs off.

  wait 10.
  set thr to t.
  wait 0.1.
  partsDoEvent("ModuleDecouple", "decouple", "landed").

  wait 10.
  unlock all.
  partsExtendAntennas("landed").
  partsExtendSolarPanels("landed").
  wait 5.
  reboot.
}

}
