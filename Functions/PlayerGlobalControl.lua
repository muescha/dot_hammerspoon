---
--- Created by muescha.
--- DateTime: 24.08.22 10:00
---
--- Current Apps / Sites
---   -> IINA
---   -> Chrome for Player in:
---      -> [x] YouTube
---      -> [x] RTL+
---      -> WDR
---      -> Spiegel
---      -> Netflix
---      -> https://podcasts.google.com/ (TODO)
--- reduce Chromoim like apps to Chrome - and Safari like to WebKit
--- add fullscreen shortcut


fileInfo()

local cache = {}

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


-- maybe direct solution via javascript is here:
--   https://github.com/igrigorik/videospeed/blob/master/inject.js
-- since i don't know the current speed:
-- just tune down to minimum (7 keyStrokes from max 2x speed)
-- and then up to 1
local actionSpeedReset3Inc = {
    -- stop playing
    actions.pause,

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

    -- continue playing
    actions.pause,

}
local actionSpeedReset2Inc = {
    -- stop playing
    actions.pause,

    -- set to speed 0.5
    actions.speedDec,
    actions.speedDec,
    actions.speedDec,
    actions.speedDec,
    actions.speedDec,
    actions.speedDec,

    -- set to speed 1
    actions.speedInc,
    actions.speedInc,

    -- continue playing
    actions.pause,

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
        ["youtube.com"] = {
            selector = "#movie_player",
            pause = { {}, "k" },
            speedReset = actionSpeedReset3Inc,
            speedInc = { { "shift" }, "." }, -- '>'
            speedDec = { { "shift" }, "," }, -- '<'
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" }
        },
        ["twitch.tv"] = {
            selector = ".persistent-player",
            pause = { {}, "k" },
            speedReset = actionSpeedReset3Inc,
            speedInc = { {}, "." }, -- '>'
            speedDec = { {}, "," }, -- '<'
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" }
        },
        ["udemy.com"] = {
            --selector = "[class*='app--body-container--']",
            --selector = "[data-purpose='curriculum-item-viewer-content']",
            selector = "video.vjs-tech",
            pause = { {}, "SPACE" },
            speedReset = actionSpeedReset2Inc,
            speedInc = { { "shift" }, "right" },
            speedDec = { { "shift" }, "left" },
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" }
        },
        ["tvnow.de"] = {
            pause = { {}, "SPACE" },
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" }

        },
        ["spiegel.de"] = {
            pause = { {}, "SPACE" },
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" }
        },
        ["joyn.de"] = {
            pause = { {}, "SPACE" },
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" }

        },
    }
}

function getChromeUrl()
    local _,url = hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')
    return url
end

function getChromeUrlDomain()
    local url = getChromeUrl()
    local domain = url:match("[%w%.]*%.(%w+%.%w+)")
    debugInfo("current domain: ", domain)
    return domain
end

local function doKey(modifier, key)
    debugInfo("--> doKey(", modifier, ',"', key, '")')

    local receiverApp

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

    doCommand(appActions, actionQueue)

end

-- TODO add error message if no javascript is activated
-- TODO inform how to activate javascript in Chrome
-- https://sites.google.com/a/chromium.org/dev/developers/applescript?visit_id=638164618181850548-1888693479&p=applescript&rd=1
local function testforScriptEnabled()
    local wasSuccessful,  jsout, error = hs.osascript.javascript("Application('Google Chrome').windows[0].activeTab.execute({javascript:'true'})")
    debugInfo("wasSuccessful: ",wasSuccessful)
    debugInfo("error: ", error)
    debugTable(error)
    debugInfo("jsout: ", jsout)
end

local function selectPlayer(selector)
    if selector==nil then return end
    local code = cache[selector]
    if code == nil then
        debugInfo("no cache - generate javascript")
        local jsPath = path() .. filename() .. 'ChromeSelect.js'
        debugInfo("Filename: ", jsPath)
        debugInfo("Selector: ", selector)
        code = readFileTemplate(jsPath, {selector=selector})
        cache[selector] = code
    end
    local error, output, message = runJavaScript(code)
    debugInfo(error, " - ", output, " - " , message)
end

-- TODO: when Chrome is not the current App, then also i need to switch to
--       the right tab to get the keyStrokes send to the right tab

-- fix for Chrome when current app is also Chrome
-- remember current window - activate player window to receive the actionCommands

-- when in same maybe use the current tab ---> first test: not work on Chrome :(
-- currentWindow:focusTab(1)
-- local _,tabIndex = hs.osascript.applescript('tell application "Google Chrome" to return active tab index of front window')

local function checkSwitch()

    local win = hs.window.focusedWindow()
    local bundleID = win:application():bundleID()

    -- TODO -> check the focused Window on the currentApp and then switch back

    if bundleIdChrome ~= bundleID then debugInfo("checkSwitch: no Chrome") return end
    if bundleIdChrome ~= currentBundleId then debugInfo("checkSwitch: saved no chrome") return end
    if currentWindow==nil then debugInfo("checkSwitch: no window saved") return end
    if win == currentWindow then debugInfo("checkSwitch: same window") return end

    debugInfo("checkSwitch: switch to", currentWindow)
    currentWindow:focus()
    hs.timer.usleep(10000)
    --currentWindow:raise()

    return win
end

local function getAppActions()

    local appActions

    if currentBundleId == bundleIdChrome then
        local domain = getChromeUrlDomain()
        appActions = ControlKeys[currentBundleId][domain]
    else
        appActions = ControlKeys[currentBundleId]
    end

    return appActions
end

-- types
---@param sourceKey string
---@param action string
local function createHotkey(sourceKey, action, description)

    hs.hotkey.bind(hyper, sourceKey, description, function()

        local switchBackToWindow = checkSwitch()

        local appActions = getAppActions()

        if appActions == nil then
            debugInfo("exit - no commands found")
            return
        end

        doCommand(appActions, { action })

        if switchBackToWindow then
            debugInfo("checkSwitch: switch back to", switchBackToWindow)
            switchBackToWindow:focus()
        end

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

    local appActions = getAppActions()
    selectPlayer(appActions.selector)

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
