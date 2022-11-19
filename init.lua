hs.notify.show("Hammerspoon", "Starting Hammerspoon: ",hs.screen.mainScreen():name())

-- Note: Setup this hyper Key with Karabiner ELements
hyper = {"shift","ctrl", "alt", "cmd"}

require("Helpers.Extensions.String")
require("Helpers.Extensions.Table")
require("Helpers.Extensions.WindowFilterEvents")

require("Helpers.Debug")
require("Helpers.DebugFunction")

require("Helpers.Enum")

require("Helpers.SendKeysOnlyInApp")

print(hs.inspect(hs.spoons.list()))
print(hs.logger.defaultLogLevel)
hs.logger.defaultLogLevel = "info"
--hs.logger.defaultLogLevel = "verbose"
helper = {
  --app = require('Helpers.App'),
  --clipboard = require('Helpers.Clipboard'),
  --custom = require('config.custom.Helpers.Custom'),
  --is = require('Helpers.Is'),
  --misc = require('Helpers.Misc.Index'),
  --str = require('Helpers.String'),
  table = require('Helpers.Table'),
  window = require('Helpers.Window'),
  --Alfred = require('Apps.Alfred'),
  --Chrome = require('Apps.Chrome'),
  --Code = require('Apps.Code'),
  --Discord = require('Apps.Discord'),
  --iTerm = require('Apps.iTerm'),
  --Slack = require('Apps.Slack'),
  --TablePlus = require('Apps.TablePlus'),
}

hs.loadSpoon("EmmyLua")
hs.loadSpoon("hs_select_window")

-- Test Spoons :)
--hs.loadSpoon("DrawRect")

-- ## Init Functions

--require('Functions.Vimperator')

require('Functions.Reload')
require('Functions.ReloadWatcher')

require('Functions.AppBorders')
require('Functions.ChromeNewWindow')
require('Functions.ChromeTabToIina')
require('Functions.ChromeTabToNewWindow')
require('Functions.CheatSheet')
require('Functions.HighLight')
require('Functions.IinaGlobalControl')
require('Functions.MaximizeApp')
-- require('Functions.PopupNotes') -- F3
require('Functions.ResizeChildWindows')
require('Functions.Umlauts')
require('Functions.Wifi')
require('Functions.WindowManager')
require('Functions.FuzzyWindowSearch')


-- --> similar to pgrap and pkill
-- require('Functions.MemoryBar')


--require('Functions.NetworkDump')
--require('Functions.NetworkBar')






--- Second Screen

-- Source: https://nethumlamahewage.medium.com/setting-up-a-global-leader-key-for-macos-using-hammerspoon-f0330f8a7a4a

--hs.loadSpoon("RecursiveBinder")
--
--spoon.RecursiveBinder.escapeKey = {{}, 'escape'}  -- Press escape to abort
--
--local singleKey = spoon.RecursiveBinder.singleKey
--
--local keyMap = {
--  [singleKey('c', 'chrome')] = function() hs.application.launchOrFocus("Chrome") end,
--  [singleKey('t', 'terminal')] = function() hs.application.launchOrFocus("Terminal") end,
--  [singleKey('d', 'domain+')] = {
--    [singleKey('g', 'github')] = function() hs.urlevent.openURL("github.com") end,
--    [singleKey('y', 'youtube')] = function() hs.urlevent.openURL("youtube.com") end
--  }
--}

--spoon.RecursiveBinder.helperFormat = {
--  atScreenEdge = 0,  -- 0-center, 1-top, 3-btm
--  textStyle = {  -- An hs.styledtext object
--      font = {
--          name = "Courier",
--          size = 40
--      }
--  }
--}

-- hs.hotkey.bind({'option'}, 'space', spoon.RecursiveBinder.recursiveBind(keyMap))

------









--[[
hs.hotkey.bind({"shift"}, "F10", function() 
  local ax = hs.axuielement
  local systemElement = ax.systemWideElement()
  local currentElement = systemElement:attributeValue("AXFocusedUIElement")

  -- local value = currentElement:attributeValue("AXValue")
  -- local textLength = currentElement:attributeValue("AXNumberOfCharacters")
  --hs.alert.show("->"..hs.inspect(currentElement:attributeNames()))
  debugElement(currentElement)
  
  local child = currentElement:attributeValue("AXSelectedChildren")

  debugElement(child)
  -- print(hs.inspect(currentElement:attributeNames()))
  local position = currentElement:attributeValue("AXPosition")

  local point = hs.mouse.getAbsolutePosition() 

  print("Mouse : " .. hs.inspect(point))

  hs.alert.show(" at ".. position.x .. ":".. position.y .. " or ".. point.x ..":"..point.y)

  
  local point = position
  local clickState = hs.eventtap.event.properties.mouseEventClickState
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types["rightMouseDown"], point):setProperty(clickState, 1):post()
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types["rightMouseUp"], point):setProperty(clickState, 1):post() 
end)
--]]

print(hs.inspect(hs.spoons.list()))


local showHotkeys = hs.hotkey.showHotkeys(hyper,'k')

-- showHotkeys['msg'] = 'abc'
debugTable(showHotkeys['_hk'])
debugInfo(showHotkeys['_hk'])
debugTable(showHotkeys)

hs.loadSpoon('FadeLogo'):start()

--debugTable(hs.window.filter.events)

--hs.notify.show("Hammerspoon","Config loaded: ",hs.screen.mainScreen():name())


