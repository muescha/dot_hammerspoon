--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- Allow arbitrary actions when transitioning between SSIDs
--
-- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WiFiTransitions.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WiFiTransitions.spoon.zip)
---@class spoon.WiFiTransitions
local M = {}
spoon.WiFiTransitions = M

-- Table containing a list of actions to execute for SSID transitions. Transitions to a "no network" state (`nil` SSID) are ignored unless you set `WiFiTransitions.actOnNilTransitions`. Each action is itself a table with the following keys:
--  * to - if given, pattern to match against the new SSID. Defaults to match any network.
--  * from - if given, pattern to match against the previous SSID. Defaults to match any network.
--  * fn - function to execute if there is a match. Can also be a list of functions, which will be executed in sequence. Each function will receive the following arguments:
--    * event - always "SSIDChange"
--    * interface - name of the interface on which the SSID changed
--    * old_ssid - previous SSID name
--    * new_ssid - new SSID name
--  * cmd - shell command to execute if there is a match. Can also be a list of commands, which will be executed in sequence using `hs.execute`. If `fn` is given, `cmd` is ignored.
M.actions = nil

-- Whether to evaluate `WiFiTransitions.actions` if the "to" network is no network (`nil`). Defaults to `false` to maintain backward compatibility; if unset, note that `from` transitions may not execute as expected.
M.actOnNilTransitions = nil

-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
M.logger = nil

-- Process the rules and execute any actions corresponding to the specified transition.
--
-- Parameters:
--  * new_ssid - new SSID name
--  * prev_ssid - previous SSID name. Defaults to `nil`
--  * interface - interface where the transition occurred. Defaults to `nil`
--
-- Notes:
--  * This method is called internally by the `hs.wifi.watcher` object when WiFi transitions happen. It does not get any system information nor does it set any Spoon state information, so it can also be used to "trigger" transitions manually, either for testing or if the automated processing fails for any reason.
function M:processTransition(new_ssid, prev_ssid, interface, ...) end

-- Start the WiFi watcher
--
-- Parameters:
--  * None
--
-- Returns:
--  * The WiFiTransitions spoon object
function M:start() end

