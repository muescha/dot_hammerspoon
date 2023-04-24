hs.notify.show("Hammerspoon", "Starting Hammerspoon: ", hs.screen.mainScreen():name())
require("Helpers.Base")
require("Helpers.Util")

-- Note: Setup this hyper Key with Karabiner ELements
hyper = { "shift", "ctrl", "alt", "cmd" }

-- disable hotkey info
hs.hotkey.alertDuration = 0

require('Functions.Reload')
require("Functions.ConfigConsole")

require('Functions.SetupLuaRocks')

-- need to start after LuaRocks path setup
require('Functions.StartDebug')

require("Helpers.Extensions.String")
require("Helpers.Extensions.Table")
require("Helpers.Extensions.WindowFilterEvents")

require("Helpers.Debug")
require("Helpers.DebugFunction")

require("Helpers.Enum")

require("Helpers.SendKeysOnlyInApp")
require("Helpers.HotkeyBindModal")
require("Helpers.HotkeyBindSafe")

hs.logger.defaultLogLevel = "info"
--hs.logger.defaultLogLevel = "verbose"

print("hs.logger.defaultLogLevel: " .. hs.logger.defaultLogLevel)

helper = {
    table = require('Helpers.Table'),
    window = require('Helpers.Window'),
}

hs.loadSpoon("EmmyLua")
hs.loadSpoon("hs_select_window")



require('Functions.ReloadWatcher')

require('Functions.AppBorders')
require('Functions.ChromeNewWindow')
require('Functions.ChromeTabToIina')
require('Functions.ChromeTabToNewWindow')
require('Functions.CheatSheet')
require('Functions.HighLight')
require('Functions.PlayerGlobalControl')
require('Functions.MacZoom')
require('Functions.MailMateFocus')
require('Functions.MailMateDisableCmdW')
require('Functions.MaximizeApp')
require('Functions.Notifications')
require('Functions.ResizeChildWindows')
require('Functions.Umlauts')
require('Functions.Wifi')
require('Functions.WindowManager')
require('Functions.WindowPlacer')
require('Functions.FuzzyWindowSearch')

require('Functions.AudioSwitcher') -- hyper-6
require('Functions.Caffeine')
require('Functions.MultiDisplayBlack') -- heper-4 and hyper-5

require('Functions.KeyMapping')

--require('Functions.WindowTimer') -- cmd+ctrl+E

    -- This shortcut can be changed


-- only for tests
--require('Functions.ContextMenu')
--require('Functions.Experimental')

-- Unused Scripts
-- require('Functions.PopupNotes') -- F3
-- require('Functions.Vimperator')


-- --> similar to pgrap and pkill
-- require('Functions.NetworkBar') -- show the current network speed
-- require('Functions.MemoryBar') -- show current used memory
-- require('Functions.NetworkDump') -- Dump all Wifi Events


-- Test Spoons :)
--hs.loadSpoon("DrawRect")
--hs.window.highlight.ui.isolateColor = {0.1, 0.1, 0.1, 0.85}

--hs.window.highlight.start()
--local highlight = require "hs.window.highlight"
--highlight.ui.overlay = true
--highlight.ui.overlayColor = {0, 0, 0, 0}
--highlight.ui.isolateColor = {0.1, 0.1, 0.1, 0.85}
-- highlight.ui.windowShownFlashColor = {1, 0.6, 0, 0.5}
-- highlight.ui.flashDuration = 0.3
-- highlight.ui.frameWidth = 10
-- highlight.ui.frameColor = {1, 0.6, 0, 0.5}
--highlight.start()
--highlight.toggleIsolate()


--local tabs = require "hs.tabs"

--hs.tabs.enableForApp("com.google.Chrome")

function karabinerCallback(eventName, params)
    print("Event: "..eventName)
    print(hs.inspect(params))
end

hs.urlevent.bind("karabiner", karabinerCallback)
-- Setup Complete

hs.loadSpoon('FadeLogo'):start()

--hs.spoons.use('SDCPasteboard', {
--    hotkeys = {
--        toggleChooser = {hyper, 'V'}
--    },
--    start = true
--})

-- Disable window animation = 0
-- normal is = 0.3

function sleep()
    --hs.caffeinate.systemSleep()
    testTimer = hs.timer.doAfter(2, function() hs.caffeinate.systemSleep() end)

end

hs.hotkey.bind({"shift", "alt", "command"}, "DELETE", keyInfo("goto sleep"), sleep)

hs.window.animationDuration = 0.1




