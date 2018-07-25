// Library for staging logic and deltaV calculation
// ================================================
// Asparagus and designs that throw off empty tanks were considered.
// Note that engines attached to tanks that get empty will be staged
// (even if not technically flamed out - that is something that KER and MechJeb do not consider).

// logic: Stage if either availableThrust = 0 (separator-only, fairing-only stage)
// or all engines that are to be separated by staging flame out
// or all tanks (and boosters) to be separated that were not empty are empty now

// tag noauto: use "noauto" tag on any decoupler to instruct this library to never stage it
// note: can use multiple tags if separated by whitespace (e.g. "noauto otherTag") or other word-separators ("tag,noauto.anything;more").

// list of all consumed fuels (for deltaV; add e.g. Karbonite and/or MonoPropellant if using such mods)
IF NOT (defined stagingConsumed)
GLOBAL stagingConsumed IS LIST("SolidFuel", "LiquidFuel", "Oxidizer").

// list of fuels for empty-tank identification (for dual-fuel tanks use only one of the fuels)
// note: SolidFuel is in list for booster+tank combo, both need to be empty to stage
IF NOT (defined stagingTankFuels)
GLOBAL stagingTankFuels IS LIST("SolidFuel", "LiquidFuel"). //Oxidizer intentionally not included (would need extra logic)

// list of modules that identify decoupler
IF NOT (defined stagingDecouplerModules)
GLOBAL stagingDecouplerModules IS LIST("ModuleDecouple", "ModuleAnchoredDecoupler").

// Standard gravity for isp
// https://en.wikipedia.org/wiki/Specific_impulse
// https://en.wikipedia.org/wiki/Standard_gravity
IF NOT (defined isp_g0)
GLOBAL isp_g0 IS kerbin:mu/kerbin:radius^2. // exactly 9.81 in ksp 1.3.1, 9.80665 for Earth
// note that constant:G*kerbin:mass/kerbin:radius^2 yields 9.80964723..., correct value could be 9.82

// work variables for staging logic
GLOBAL stagingNumber   IS -1.     // stage:number when last calling stagingPrepare()
GLOBAL stagingMaxStage IS 0.      // stop staging if stage:number is lower or same as this
GLOBAL stagingResetMax IS true.   // reset stagingMaxStage to 0 if we passed it (search for next "noauto")
GLOBAL stagingEngines  IS LIST(). // list of engines that all need to flameout to stage
GLOBAL stagingTanks    IS LIST(). // list of tanks that all need to be empty to stage

// info for and from stageDeltaV
GLOBAL stageAvgIsp    IS 0.    // average isp in seconds
GLOBAL stageStdIsp    IS 0.    // average isp in N*s/kg (stageAvgIsp*isp_g0)
GLOBAL stageDryMass   IS 0.    // dry mass just before staging
GLOBAL stageBurnTime  IS 0.    // updated in stageDeltaV()

// return stage number where the part is decoupled (probably Part.separationIndex in ksp api)
FUNCTION stagingDecoupledIn {
  PARAMETER part.

  LOCAL FUNCTION partIsDecoupler {
    PARAMETER part.
    FOR m IN stagingDecouplerModules IF part:modules:contains(m) {
      IF part:tag:TOLOWER:matchesPattern("\bnoauto\b") and part:stage+1 >= stagingMaxStage
        SET stagingMaxStage TO part:stage+1.
      RETURN true.
    }
    RETURN false.
  }
  until partIsDecoupler(part) {
    IF NOT part:hasParent RETURN -1.
    SET part TO part:parent.
  }
  RETURN part:stage.
}

// to be called whenever current stage changes to prepare data for quicker test and other functions
FUNCTION stagingPrepare {
  wait until stage:ready.
  SET stagingNumber TO stage:number.
  IF stagingResetMax and stagingMaxStage >= stagingNumber SET stagingMaxStage TO 0.
  stagingEngines:clear().
  stagingTanks:clear().

  // prepare list of tanks that are to be decoupled and have some fuel
  LIST parts IN parts.
  FOR p IN parts {
    LOCAL amount IS 0.
    FOR r IN p:resources IF stagingTankFuels:contains(r:name)
      SET amount TO amount + r:amount.
    IF amount > 0.01 and stagingDecoupledIn(p) = stage:number-1
      stagingTanks:add(p).
  }

  // prepare list of engines that are to be decoupled by staging
  // and average isp for stageDeltaV()
  LIST engines IN engines.
  LOCAL thrust IS 0.
    LOCAL flow IS 0.
  FOR e IN engines IF e:ignition and e:isp > 0 {
    IF stagingDecoupledIn(e) = stage:number-1
      stagingEngines:add(e).

    LOCAL t IS e:availableThrust.
    SET thrust TO thrust + t.
    SET flow TO flow + t / e:isp. // thrust=isp*g0*dm/dt => flow = sum of thrust/isp
  }
  SET stageAvgIsp TO 0.
    IF flow > 0 SET stageAvgIsp TO thrust/flow.
  SET stageStdIsp TO stageAvgIsp * isp_g0.

  // prepare dry mass for stageDeltaV()
    LOCAL fuelMass IS 0.
    FOR r IN stage:resources IF stagingConsumed:contains(r:name)
    SET fuelMass TO fuelMass + r:amount*r:density.
  SET stageDryMass TO ship:mass-fuelMass.
}

// to be called repeatedly
FUNCTION stagingCheck {
  wait until stage:ready.
  IF stage:number <> stagingNumber
    stagingPrepare().
  IF stage:number <= stagingMaxStage
    RETURN.

  // need to stage because all engines are without fuel?
  LOCAL FUNCTION checkEngines {
    IF stagingEngines:empty RETURN false.
    FOR e IN stagingEngines IF NOT e:flameout
      RETURN false.
    RETURN true.
  }

  // need to stage because all tanks are empty?
  LOCAL FUNCTION checkTanks {
    IF stagingTanks:empty RETURN false.
    FOR t IN stagingTanks {
      LOCAL amount IS 0.
      FOR r IN t:resources IF stagingTankFuels:contains(r:name)
        SET amount TO amount + r:amount.
      IF amount > 0.01 RETURN false.
    }
    RETURN true.
  }

  // check staging conditions and return true if staged, false otherwise
  IF availableThrust = 0 OR checkEngines() OR checkTanks() {
    stage.
    // this is optional and unnecessary if twr does not change much,
    // but can prevent weird steering behaviour after staging
    steeringManager:resetPids().
    // prepare new data
    stagingPrepare().
    RETURN true.
  }
  RETURN false.
}

// delta-V remaining for current stage
// + stageBurnTime updated with burn time at full throttle
FUNCTION stageDeltaV {
  IF stageAvgIsp = 0 OR availableThrust = 0 {
    SET stageBurnTime TO 0.
    RETURN 0.
  }

  SET stageBurnTime TO stageStdIsp*(ship:mass-stageDryMass)/availableThrust.
  RETURN stageStdIsp*ln(ship:mass / stageDryMass).
}

// calculate burn time for maneuver needing provided deltaV
FUNCTION burnTimeForDv {
  PARAMETER dv.
  RETURN stageStdIsp*ship:mass*(1-constant:e^(-dv/stageStdIsp))/availableThrust.
}

// current thrust to weght ratio
FUNCTION thrustToWeight {
  RETURN availableThrust/(ship:mass*body:mu)*(body:radius+altitude)^2.
}
