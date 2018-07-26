@lazyglobal off.
/////////////////////////////////////////////////////
// Launch.ks just try to decide if is better to use
// launch_asc.ks or launch_ssto.ks
/////////////////////////////////////////////////////
parameter Apo is 0.
parameter hdg is 90.

ON AG10 reboot.

if KUniverse:ORIGINEDITOR = "SPH" or Ship:Name:Contains("SSTO") {
    runpath("launch_ssto",apo,hdg).
} else {
  runpath("launch_asc",apo,hdg).
}
