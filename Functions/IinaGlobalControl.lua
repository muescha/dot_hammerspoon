---
--- Created by muescha.
--- DateTime: 24.08.22 10:00
---

fileInfo()

local bundleIdIINA = "com.colliderli.iina"
local bundleIdChrome = "com.google.Chrome"

local actions = enumString {
    "pause",
    "speedReset",
    "speedInc",
    "speedDec",
    "moveForward",
    "moveBackward"
}

--local currentBundleId = bundleIdIINA
local currentBundleId = bundleIdChrome

---@type hs.Application
local currentWindow = nil

local ControlKeys = {
    [bundleIdIINA] = {
        pause = { {}, "p" },
        speedReset = { {}, "0" },
        speedInc = { {}, "=" }, -- +
        speedDec = { {}, "-" },
        moveForward = { {}, "right" },
        moveBackward = { {}, "left" }
    },
    [bundleIdChrome] = {
        pause = { {}, "k" },

        -- maybe direct solution via javascript is here:
        --   https://github.com/igrigorik/videospeed/blob/master/inject.js
        -- since i don't know the current speed:
        -- just tune down to minimum (7 keyStrokes from max 2x speed)
        -- and then up to 1
        speedReset = {
            -- stop playing
            -- {}, "k",
            -- set to speed 0.25
            actions.speedDec,
            actions.speedDec,
            actions.speedDec,
            actions.speedDec,
            actions.speedDec,
            actions.speedDec,
            actions.speedDec,

            -- set to speed 1
            actions.speedInc,
            actions.speedInc,
            actions.speedInc,
            --{}, "k",

        },
        speedInc = { { "shift" }, "." }, -- '>'
        speedDec = { { "shift" }, "," }, -- '<'
        moveForward = { {}, "right" },
        moveBackward = { {}, "left" }
    }
}

-- reduce Chromoim like apps to Chrome - and Safari like to WebKit
-- Chrome Drivers:
--   youtube
--   wdr
--   spiegel
--   netflix
--  etc
local function doKey(modifier, key)
    debugInfo("--> doKey(", modifier, ',"', key, '")')

    local receiverApp
    -- use saved window
    if currentWindow then
        receiverApp = currentWindow:application()
        -- TODO: activate the window - place over others - but go back to current app
    else
        receiverApp = hs.application.applicationsForBundleID(currentBundleId)[1]
    end

    if receiverApp then
        hs.eventtap.keyStroke(modifier, key, 0, receiverApp)
    end
end


---@param appActions table @available actions for all apps
---@param actionQueue table @queue of actions
---@return void
---
local function doCommand(appActions, actionQueue)
    if #actionQueue == 0 then
        return
    end

    debugInfo("--> doCommand(", "appActions", ",", actionQueue, ")")

    local peek = actionQueue[1]

    if type(peek) == 'string' then

        -- unpack reference
        local action = table.remove(actionQueue, 1)
        local actionCommands = { table.unpack(appActions[action]) }
        doCommand(appActions, actionCommands)

    else

        local modifier = table.remove(actionQueue, 1)
        local key = table.remove(actionQueue, 1)

        doKey(modifier, key)

    end

    --debugInfo("again? actionQueue",actionQueue)
    --if actionQueue ~= nil and #actionQueue > 0 then
    --local nextAction = table.remove(actionQueue, 1)
    -- check remaining queue
    doCommand(appActions, actionQueue)
    --end
end

-- types
---@param sourceKey string
---@param action string
local function createHotkey(sourceKey, action, description)

    hs.hotkey.bind(hyper, sourceKey, description, function()

        local appActions = ControlKeys[currentBundleId]

        if appActions == nil then
            return
        end

        doCommand(appActions, { action })

    end)

end

local function setCurrentWindow()
    local win = hs.window.focusedWindow()
    local bundleID = win:application():bundleID()

    if ControlKeys[bundleID] == nil then
        return
    end

    currentWindow = win
    currentBundleId = bundleID

    debugInfo("changed currentBundleId to " .. currentBundleId)
end

-- Play / Pause
createHotkey("p", actions.pause, keyInfo("Pause Video"))

-- normal Speed 0
createHotkey("k", actions.speedReset, keyInfo("Reset Speed")) -- ?
--speed with +/-
createHotkey("l", actions.speedDec, keyInfo("Decrease Speed")) -- like yotube <
createHotkey(";", actions.speedInc, keyInfo("Increase Speed")) -- like yotube >

-- Rewind / Forward
createHotkey("'", actions.moveBackward, keyInfo("Jump Backward"))
createHotkey("\\", actions.moveForward, keyInfo("Jump Forward"))

hs.hotkey.bind(hyper, "o", keyInfo("Set active App"), setCurrentWindow)


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
