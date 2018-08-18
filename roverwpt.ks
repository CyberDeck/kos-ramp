@lazyglobal off.

Parameter MaxSpeed is 12.
Parameter WaypointTolerance is 50.

runoncepath("lib/lib_ui").
runoncepath("lib/lib_astar_route").

local WP is list().
global settings is lexicon().
settings:add("IPU", 2000).
settings:add("MinSlope", -15).
settings:add("MaxSlope", 20).

for w in allwaypoints(){
    if w:body = ship:body {
        WP:Add(w).
    }
}.
local SelectedIndex is uiTerminalList(WP).

astar_main("LATLNG", WP[SelectedIndex]:geoposition, false).

run rover_autosteer(route,WaypointTolerance,MaxSpeed).
