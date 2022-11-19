---
--- Created by muescha.
--- DateTime: 24.08.22 10:00
---

print("init IinaGlobalControl")

local bundleIdIINA = "com.colliderli.iina"
local bundleIdChrome = "com.google.Chrome"

local action = enumString {
    "pause",
    "speedZero",
    "speedInc",
    "speedDec",
    "moveForward",
    "moveBackward"
}

local currentBundleId = bundleIdIINA
local currentApp = nil
local currentWindow = nil

local ControlKeys = {
    [bundleIdIINA] = {
        pause = { {}, "p" },
        speedZero = { {}, "0"},
        speedInc = { {}, "="}, -- +
        speedDec = { {}, "-"},
        moveForward = { {}, "right"},
        moveBackward = { {}, "left"}
    },
    [bundleIdChrome] = {
        pause = { {}, "k" },
        -- https://github.com/igrigorik/videospeed/blob/master/inject.js
        speedZero = nil,
        speedInc = { {"shift"}, "."}, -- '>'
        speedDec = { {"shift"}, ","}, -- '<'
        moveForward = { {}, "right"},
        moveBackward = { {}, "left"}
    }
}

-- reduce Chromoim like apps to Chrome - and Safari like to WebKit
-- Chrome Drivers:
--   youtube
--   wdr
--   spiegel
--   netflix
--  etc

local function doCommand(sourcekey, action)


    hs.hotkey.bind(hyper, sourcekey, function()

        debugInfo("action: " .. action)
        debugInfo("currentBundleId: " .. currentBundleId)

        if currentBundleId == nil then
            currentBundleId = bundleIdIINA
        end

        system = currentBundleId
        --system = bundleIdChrome
        debugInfo("system: " .. system)

        mods = ControlKeys[system][action]

        if mods == nil then return end

        modifier, key = table.unpack(ControlKeys[system][action])

        debugInfo("modifier: "..hs.inspect(modifier))
        debugInfo("key: "..key)

        local myApp = hs.application.applicationsForBundleID(currentBundleId)[1]

        if currentWindow then
            debugInfo("current window:")
            debugInfo(currentWindow)
            app = currentWindow:application()
            debugInfo(app)
            hs.eventtap.keyStroke(modifier, key, 0, app)
        else

            if myApp then
                hs.eventtap.keyStroke(modifier, key, 0, myApp)
                --hs.eventtap.keyStroke(modifier, key, 200, myApp)
            end

        end
    end)

end

local function setCurrentWindow()
    win = hs.window.focusedWindow()
    debugInfo(win)
    debugInfo(win:application():bundleID())
    currentWindow = win
    currentBundleId = win:application():bundleID()
end

-- Play / Pause
doCommand("p", action.pause)

-- normal Speed 0
doCommand("0", action.speedZero)
--speed with +/-
doCommand("-", action.speedDec)
doCommand("=", action.speedInc)

-- Rewind / Forward
doCommand("'", action.moveBackward)
doCommand("\\", action.moveForward)

hs.hotkey.bind(hyper, "o", setCurrentWindow)


--local function activateOrHide(bundleID)
--    return function()
--        local app = hs.application.get(bundleID)
--        if not app then
--            -- app hasn't yet running
--            return hs.application.open(bundleID)
--        end
--        -- if hs.window.focusedWindow():application():bundleID() == bundleID then
--        if app:isFrontmost() then
--            -- hs.alert.show("hide")
--            app:hide()
--        else
--            -- hs.alert.show("activate")
--            app:activate()
--        end
--    end
--end

-- activate tab in Brave - i think in Chrome would be the same
-- https://github.com/evantravers/hammerspoon-config/blob/master/brave.lua
--module.jump = function(url)
--    hs.osascript.javascript([[
--  (function() {
--    var brave = Application('Brave');
--    brave.activate();
--    for (win of brave.windows()) {
--      var tabIndex =
--        win.tabs().findIndex(tab => tab.url().match(/]] .. url .. [[/));
--      if (tabIndex != -1) {
--        win.activeTabIndex = (tabIndex + 1);
--        win.index = 1;
--      }
--    }
--  })();
--  ]])
--end
