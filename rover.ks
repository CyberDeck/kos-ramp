@lazyglobal off.

runoncepath("lib/lib_ui").

ON AG10 reboot.

set ship:type to "Rover".

local RoverOptions is lexicon(
    "D","Drive the rover",
    "F","Follow a route",
    "C","Convoy mode",
    "W","Waypoint mode").

local choice is uiTerminalMenu(RoverOptions).
if      choice = "D" run roverdrive.
else if choice = "F" run roverroute.
else if choice = "C" run roverconvoy.
else if choice = "W" run roverwpt.
