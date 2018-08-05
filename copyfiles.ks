/////////////////////////////////////////////////////////////////////////////
// Copies RAMP files to core.
/////////////////////////////////////////////////////////////////////////////
// Copy all scripts to local volume
/////////////////////////////////////////////////////////////////////////////
@lazyglobal off.

runoncepath("lib/lib_staging").

LOCAL includeList IS LIST().

includeList:add("lib_ui").
includeList:add("lib_parts").
includeList:add("lib_util").

IF ship:STATUS = "PRELAUNCH" OR ship:STATUS = "LANDED" {
  includeList:add("launch.ks").
  IF(KUniverse:ORIGINEDITOR = "SPH" OR Ship:Name:TOUPPER:Contains("SSTO")) {
    includeList:add("launch_ssto").
    includeList:add("fly").
  } ELSE {
    includeList:add("launch_asc").
    includeList:add("lib_staging").
    includeList:add("lib_warp").
    includeList:add("circ.ks").
    includeList:add("node.ks").
  }
} ELSE IF Ship:STATUS = "LANDED" AND Ship:Name:TOUPPER:Contains("ROVER") {
  includeList:add("rover").
  includeList:add("lib_terrain").
} ELSE IF ship:STATUS = "SUB_ORBITAL" OR ship:STATUS = "ORBITING" OR ship:STATUS = "ESCAPING" {
  includeList:add("node").
  includeList:add("warp").
  includeList:add("lib_staging").
  includeList:add("transfer").
  includeList:add("circ").
  includeList:add("rendezvous").
  includeList:add("dock").
  includeList:add("approach").
}

DECLARE FUNCTION includeFile {
  PARAMETER fileName.

  FOR f IN includeList {
    if(fileName:CONTAINS(f)) {
      //PRINT("Copying " + fileName).
      RETURN True.
    }
  }

  RETURN False.
}

LOCAL copyFiles IS LIST().
LOCAL libs IS LIST().
LOCAL fls IS LIST().

LIST FILES IN fls.
LOCAL fSize IS 0.
FOR f IN fls {
  IF f:NAME:ENDSWITH(".ks") {
    DELETEPATH("1:" + f:NAME).
    DELETEPATH("1:" + f:NAME:REPLACE(".ks", ".ksm")).
    IF includeFile(f:NAME) {
      SET fSize to fSize + f:SIZE.
      copyFiles:ADD(f:NAME).
    }
  }
}
CD("lib").
LIST FILES IN libs.
FOR f IN libs {
  IF f:NAME:ENDSWITH(".ks") {
    DELETEPATH("1:/lib/" + f:NAME).
    DELETEPATH("1:/lib/" + f:NAME:REPLACE(".ks", ".ksm")).
    IF includeFile("lib/" + f:NAME) {
      SET fSize to fSize + f:SIZE.
      copyFiles:ADD("lib/" + f:NAME).
    }
  }
}
CD("..").
IF NOT (DEFINED copyFilesOK) GLOBAL copyFilesOK IS True.
IF core:volume:freespace > fSize {
  SET copyFilesOk TO True.
  IF NOT EXISTS("1:/lib") CREATEDIR("1:/lib").
  FOR f IN copyFiles {
    IF NOT COPYPATH("0:/" + f, "1:/" + f) { SET copyFilesOk TO False. }.
  }
} ELSE {
  print("Core volume too small.").
  print("Need " + (fSize - core:volume:freespace) + " more bytes.").
}
