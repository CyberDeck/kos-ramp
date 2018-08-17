@lazyglobal off.

Parameter MaxSpeed is 28.
Parameter WaypointTolerance is 5.

ON AG10 reboot.

runoncepath("lib/lib_ui").

local WP is list().

//Read the route files
for w in allwaypoints(){
    if w:body = ship:body {
        WP:Add(w).
    }
}.
local SelectedIndex is uiTerminalList(WP).
run rover_autosteer(WP[SelectedIndex]:geoposition,WaypointTolerance,MaxSpeed).
