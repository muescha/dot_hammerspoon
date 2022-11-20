---
--- Created by muescha.
--- DateTime: 24.08.22 10:00
---

print("init IinaGlobalControl")

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

local currentBundleId = bundleIdIINA
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
        -- https://github.com/igrigorik/videospeed/blob/master/inject.js
        speedReset = {
            -- stop playing
            {}, "k",
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
        local receiverApp = hs.application.applicationsForBundleID(currentBundleId)[1]
    end

    if receiverApp then
        hs.eventtap.keyStroke(modifier, key, 0, receiverApp)
    end
end

local function doCommand(appActions, action, actionQueue)
    debugInfo("--> doCommand(", "appActions", ",", action, ",", actionQueue, ")")
    --debugInfo("actionQueue: ", actionQueue)
    --debugInfo("appActions: ", appActions)
    --debugInfo("action: ", action)
    local actionCommands
    if action == nil then
        actionCommands = actionQueue
        actionQueue = nil
    else
        actionCommands = { table.unpack(appActions[action]) }
    end
    --debugInfo('#actionCommands: ', #actionCommands)
    if #actionCommands == 0 then
        debugInfo('exit')
        return
    end

    local peek = actionCommands[1]

    if type(peek) == 'string' then
        local nextAction = table.remove(actionCommands, 1)
        doCommand(appActions, nextAction, actionCommands)
    else
        local modifier = table.remove(actionCommands, 1)
        local key = table.remove(actionCommands, 1)

        doKey(modifier, key)

        -- check if more in queue
        if #actionCommands > 0 then
            local nextAction = table.remove(actionCommands, 1)
            doCommand(appActions, nextAction, actionCommands)
        end
    end

    -- check remaining queue
    if actionQueue ~= nil and #actionQueue > 0 then
        local nextAction = table.remove(actionQueue, 1)
        doCommand(appActions, nextAction, actionQueue)
    end
end

local function createHotkey(sourcekey, action)


    hs.hotkey.bind(hyper, sourcekey, function()


        --debugInfo(ControlKeys)
        --debugTable(ControlKeys)
        --debugTable(actions)

        local appActions = ControlKeys[currentBundleId]

        if appActions == nil then
            return
        end

        --debugInfo("action: ", action)
        --debugInfo("currentBundleId: ", currentBundleId)
        --debugInfo("current window: ", currentWindow)

        doCommand(appActions, action)

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
createHotkey("p", actions.pause)

-- normal Speed 0
createHotkey("0", actions.speedReset)
--speed with +/-
createHotkey("-", actions.speedDec)
createHotkey("=", actions.speedInc)

-- Rewind / Forward
createHotkey("'", actions.moveBackward)
createHotkey("\\", actions.moveForward)

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
