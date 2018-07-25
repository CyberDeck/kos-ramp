@lazyglobal off.

runoncepath("lib/lib_ui").

ON AG10 reboot.

local AllTargets is List().
local ValidTargets is List().
local Names is List().
list targets in AllTargets.

for Tgt in AllTargets {
    if Tgt:Body = Ship:Body and Tgt:Type = "Rover" {
        ValidTargets:Add(Tgt).
        Names:Add(Tgt:name).
    }
}

local SelectedIndex is uiTerminalList(Names).
run rover_autosteer(ValidTargets[SelectedIndex],30).
