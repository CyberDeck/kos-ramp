/////////////////////////////////////////////////////////////////////////////
// Universal boot script for RAMP system.
/////////////////////////////////////////////////////////////////////////////
// Copy all scripts to local volume; run mission script. This is suitable for
// single-CPU vessels that will be operating out of comms range.
//
// To customize the mission, edit <ship name>.ks in 0:/start folder before
// launch; it will be persisted onto the craft you launch, suitable for
// archive-free operation.
//
// Nevertheless, every time this boots, it will try to copy the files again,
// IF possible.
// It expects the RAMP scripts files to be saved in 0:/ramp folder.
/////////////////////////////////////////////////////////////////////////////

local l is lexicon().

ON AG10 {
  l:add("abort", true).
  writejson(l, "1:/status.json").
  reboot.
}

// Print informational message.
function bootConsole {
  parameter msg.

  print "T+" + round(time:seconds) + " boot: " + msg.
}

// Print error message and shutdown CPU.
function bootError {
  parameter msg.

  print "T+" + round(time:seconds) + " boot: " + msg.
  hudtext(msg, 10, 4, 36, RED, false).
  shutdown.
}

function bootWarning {
  parameter msg.

  print "T+" + round(time:seconds) + " boot: " + msg.
  hudtext(msg, 10, 4, 24, YELLOW, false).
}

//Print system info; wait for all parts to load
CLEARSCREEN.
bootConsole("RAMP @ " + core:element:name).
bootConsole("kOS " + core:version).
bootConsole(round(core:volume:freespace/1024, 1) + "/" + round(core:volume:capacity/1024) + " kB free").
WAIT 1.

//Set up volumes
SET HD TO CORE:VOLUME.
SET ARC TO 0.
SET StartupLocalFile TO path(core:volume) + "/startup.ksm".
SET Failsafe TO false.

bootConsole("Attemping to connect to KSC...").
IF HOMECONNECTION:ISCONNECTED {
  bootConsole("Connected to KSC, updating...").
  SET ARC TO VOLUME(0).
  SWITCH TO ARC.

  IF EXISTS("ramp") {
    CD ("ramp").
  } ELSE IF EXISTS("kos-ramp") {
    CD ("kos-ramp").
  }

  SET copyFilesOk TO False.
  RUN copyfiles.
  IF NOT copyFilesOK SET Failsafe TO True.
} ELSE {
  bootConsole("No connection to KSC detected.").
  IF EXISTS(StartupLocalFile) {
    bootConsole("Local startup, proceeding.").
  } ELSE {
    bootConsole("RAMP not detected; extend antennas...").
    IF Career():CANDOACTIONS {
      FOR P IN SHIP:PARTS {
        IF P:MODULES:CONTAINS("ModuleDeployableAntenna") {
          LOCAL M IS P:GETMODULE("ModuleDeployableAntenna").
          FOR A IN M:ALLACTIONNAMES() {
            IF A:CONTAINS("Extend") { M:DOACTION(A,True). }
          }.
        }
      }.
      bootError("Please reboot when KSC is connected.").
    } ELSE {
      bootError("Cannot contact KSC. Add antennas?").
    }
  }
}

LOCAL StartupOk is FALSE.
LOCAL Aborted is FALSE.
if exists("1:/status.json") set l to readjson("1:/status.json").
if l:haskey("abort") {
  set Aborted to True.
}

bootConsole("Looking for remote start script...").
IF HOMECONNECTION:ISCONNECTED {
  LOCAL StartupScript is PATH("0:/start/" + SHIP:NAME).
  IF EXISTS(StartupScript) {
    bootConsole("Copying remote start script").
    SWITCH TO HD.
    compile StartupScript to StartupLocalFile.
    StartupOK ON.
  } ELSE {
    PRINT "No startup script found. Run initialize".
  }
} ELSE {
  SWITCH TO HD.
  IF EXISTS(StartupLocalFile) {
    bootConsole("Using local storage.").
    StartupOk ON.
  } ELSE {
    bootError("Cannot find scripts").
  }
}

IF Failsafe {
  bootWarning("Failsafe mode: run from archive.").
  SWITCH TO ARCHIVE.
} ELSE {
  SWITCH TO HD.
}

print("startupok: " + startupok).
print("aborted: " + aborted).

IF StartupOk and not Aborted {
  RUNPATH(StartupLocalFile).
} ELSE {
  if Aborted bootConsole("ABORTED, NOT RUNNING BOOT SCRIPT").
  bootWarning("Need user input.").
  CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
}

