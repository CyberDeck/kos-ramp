/////////////////////////////////////////////////////////////////////////////
// Copies RAMP files to core.
/////////////////////////////////////////////////////////////////////////////
// Copy all scripts to local volume
/////////////////////////////////////////////////////////////////////////////

LIST FILES IN fls.
LOCAL fSize is 0.
FOR f IN fls {
  IF f:NAME:ENDSWITH(".ks") {
    SET fSize to fSize + f:SIZE.
    DELETEPATH("1:" + f:NAME).
    DELETEPAHT("1:" + f:NAME:REPLACE(".ks", ".ksm").
  }
}
IF core:volume:freespace > fSize {
  SET copyFilesOk TO True.
  FOR f IN fls {
    IF f:NAME:ENDSWITH(".ks") {
      IF NOT COPYPATH(f, HD) { SET copyFilesOk TO False. }.
    }
  }
} ELSE {
  print("Core volume too small.").
  print("Need " + (fSize - core:volume:freespace) + " more bytes.").
}
