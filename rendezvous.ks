/////////////////////////////////////////////////////////////////////////////
// Rendezvous with target
/////////////////////////////////////////////////////////////////////////////
// Maneuver close to another vessel orbiting the same body.
/////////////////////////////////////////////////////////////////////////////

@lazyglobal off.

runoncepath("lib/lib_ui").
runoncepath("lib/lib_util").

parameter maxOrbitsToTransfer is 5.

ON AG10 reboot.

if ship:body <> target:body {
  uiError("Rendezvous", "Target outside of SoI").
  wait 5.
  reboot.
}

local accel is uiAssertAccel("Rendezvous").
local approachT is utilClosestApproach(ship, target).
local approachX is (positionat(target, approachT) - positionat(ship, approachT)):mag.

print("target:position:mag " + target:position:mag).
print("approachX: " + approachX).

// Perform Hohmann transfer if necessary
if target:position:mag > 15000 and approachX > 15000 {
  local ri is abs(obt:inclination - target:obt:inclination).

  // Align if necessary
  if ri > 0.1 {
    uiBanner("Rendezvous", "Alignment burn").
    run node_inc.
    run node.
  }

  run node_hoh(maxOrbitsToTransfer).

  local strandedcount is 0.
  until HASNODE {
    set strandedcount to strandedcount + 1.
    uiBanner("Rendezvous", "Transfer to phasing orbit").
    run circ_alt(target:altitude * 1.666 * strandedcount).
    run node_hoh(maxOrbitsToTransfer).
  }

  uiBanner("Rendezvous", "Transfer injection burn").
  run node.

  uiBanner("Rendezvous", "Matching velocity at closest approach.").
  run node_vel_tgt.
  run node.
}

