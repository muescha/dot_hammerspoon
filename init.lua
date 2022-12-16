hs.notify.show("Hammerspoon", "Starting Hammerspoon: ", hs.screen.mainScreen():name())
require("Helpers.Base")

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
require('Functions.IinaGlobalControl')
require('Functions.MacZoom')
require('Functions.MaximizeApp')
require('Functions.ResizeChildWindows')
require('Functions.Umlauts')
require('Functions.Wifi')
require('Functions.WindowManager')
require('Functions.FuzzyWindowSearch')

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

-- Setup Complete

hs.loadSpoon('FadeLogo'):start()


-- Disable window animation = 0
-- normal is = 0.3

hs.window.animationDuration = 0.1




