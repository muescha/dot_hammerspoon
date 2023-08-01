---
--- Created by muescha.
--- DateTime: 24.08.22 10:00
---
--- Current Apps / Sites
---   -> IINA
---   -> Chrome for Player in:
---      -> [x] YouTube
---      -> [x] RTL+
---      -> [x] WDR
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


-- Java Script Actions

local function doCache(cacheKey, f)

    local code = cache[cacheKey]

    if code ~= nil then
        debugInfo("Cache: found - reusing javascript")
        return code
    end

    debugInfo("Cache: not found - generate javascript")
    code = f()
    cache[cacheKey] = code
    return code
end

local function getCacheKey(path, params)
    return "cache-key-'"..path.."'-params:"..hs.inspect(params, {newline="",indent=""})
end

local function getActionCode(templatePath, action, params)
    local templateBaseName = "PlayerGlobalControl-"

    local jsPath = templatePath .. templateBaseName..action..".js"
    local cacheKey = getCacheKey(jsPath, params)
    local generate = function()
            debugInfo("Filename: ", jsPath)
            debugInfo("params: ", params)
            return readFileTemplate(jsPath, params)
    end
    return doCache(cacheKey, generate)
end

local function runActionCode(code)
    local wrapper = path() .. "PlayerGlobalControl-BrowserWrapper.js"
    return runJavaScriptInBrowser(code, "Google Chrome", wrapper)
end

local function runActionCodeDebug(code)
    local error, output, message = runActionCode(code)
    debugInfo("runActionCode -   Error: ", error)
    debugInfo("runActionCode -  Output: ", output)
    debugInfo("runActionCode - Message: ", message)
    return error, output, message
end

--
function GenericAction(action, defaultParams)
    local templatePath = path()

    return function(memory)
        local params = helper.table.assigned(memory, defaultParams)
        debugInfo("Params: ", params)
        local code = getActionCode(templatePath, action, params)
        local ok, output = runActionCodeDebug(code)

        if params.property == nil then return ok, output end

        local calc = params.calc or function(v) return v end

        local result = { [params.property] = calc(output)}
        return ok, result
    end
end

function ActionSelect(params)
    return GenericAction("ActionSelect", params)
end

function ActionClick(params)
    return GenericAction("ActionClick", params)
end


function ActionGetProperty(params)
    return GenericAction("ActionGetProperty", params)
end

function ActionGetChildIndex(params)
    return GenericAction("ActionGetChildIndex", params)
end

function MemoryCalc(params)
    return function(memory) -- MemoryCalc
        local allParams = helper.table.assigned(memory, params)
        debugInfo("Params: ", allParams)
        local output = allParams.calc(allParams[allParams.property])
        local result = { [allParams.property] = output}
        return true, result
    end
end

local ControlKeys = {
    [bundleIdIINA] = {
        pause = { {}, "p" },
        speedReset = { {}, "0" },
        speedInc = { {}, "=" }, -- +
        speedDec = { {}, "-" },
        moveForward = { {}, "right" },
        moveBackward = { {}, "left" },
        info = "IINA Player"
    },
    [bundleIdChrome] = {
        ["youtube.com"] = {
            selector = "#movie_player",
            pause = { {}, "k" },
            speedReset = actionSpeedReset3Inc,
            speedInc = { { "shift" }, "." }, -- '>'
            speedDec = { { "shift" }, "," }, -- '<'
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "YouTube Player"
        },
        ["twitch.tv"] = {
            selector = ".persistent-player",
            pause = { {}, "k" },
            speedReset = actionSpeedReset3Inc,
            speedInc = { {}, "." }, -- '>'
            speedDec = { {}, "," }, -- '<'
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "Twitch Player"
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
            moveBackward = { {}, "left" },
            info = "Udemy Player"
        },
        ["tvnow.de"] = {
            pause = { {}, "SPACE" },
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "TVnow Player (no speed controls)"

        },
        ["spiegel.de"] = {
            --defaultFunctionParams = {
            --    speedItems = { '0.5x', '1x', '1.25x', '1.5x', '2x' },
            --    speedItemsDefault = '1x',
            --},
            pause = { {}, "SPACE" },
            speedReset ={
                --ActionClick, { selector="div[aria-label='Einstellungen']"},
                --ActionClick, { selector="div[name='playbackRates']"},
                ActionClick({ selector = "button.jw-settings-content-item[aria-label='1x']" })
                --ActionClick, { selector=".jw-settings-close"},
            },
            speedInc = {
                ActionGetChildIndex({
                    selector=".jw-settings-submenu-playbackRates button.jw-settings-content-item.jw-settings-item-active",
                    property="child-index",
                }),
                MemoryCalc({
                    calc=function(value) return value+1+1 end,
                    property="child-index",
                }),
                ActionClick({
                    selector=".jw-settings-submenu-playbackRates button.jw-settings-content-item:nth-child({{ child-index }})",
                })
            },
            speedDec = {
                ActionGetChildIndex({
                    selector=".jw-settings-submenu-playbackRates button.jw-settings-content-item.jw-settings-item-active",
                    property="child-index",
                    --calc=function(value) return value-1+1 end,
                }),
                MemoryCalc({
                    calc=function(value) return value-1+1 end,
                    property="child-index",
                }),
                ActionClick({
                    selector=".jw-settings-submenu-playbackRates button.jw-settings-content-item:nth-child({{ child-index }})",
                })
            },
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "Spiegel.de Player"
        },
        -- https://exporte.wdr.de/player/current/v-6.5.0/ardplayer-wdr.js?t=19569
        ["wdr.de"] = {

            selector = "#videoPlayer",
            pause = ActionClick({ selector=".ardplayer-button-playpause" }),
            speedReset = {
                ActionClick({ selector="button.ardplayer-button-settings"}),
                ActionClick({ selector=".ardplayer-bottom-sheet-container div[aria-label='Geschwindigkeit'] span.ardplayer-option[data-index='3']"}),
                ActionClick({ timeout=500, selector=".ardplayer-bottom-sheet-close-button.ardplayer-icon-close"}),
            },
            speedInc = {
                ActionClick({ selector="button.ardplayer-button-settings"}),
                ActionGetProperty({
                    selector=".ardplayer-bottom-sheet-container div[aria-label='Geschwindigkeit'] span.ardplayer-option.ardplayer-option-active",
                    property="data-index"
                }),
                MemoryCalc({
                    calc=function(value) return value+1 end,
                    property="data-index"
                }),
                ActionClick({ selector=".ardplayer-bottom-sheet-container div[aria-label='Geschwindigkeit'] span.ardplayer-option[data-index='{{ data-index }}']"}),
                ActionClick({ timeout=500, selector=".ardplayer-bottom-sheet-close-button.ardplayer-icon-close"}),
            },
            speedDec = {
                ActionClick({ selector="button.ardplayer-button-settings"}),
                ActionGetProperty({
                    selector=".ardplayer-bottom-sheet-container div[aria-label='Geschwindigkeit'] span.ardplayer-option.ardplayer-option-active",
                    property="data-index"
                }),
                MemoryCalc({
                    calc=function(value) return value-1 end,
                    property="data-index"
                }),
                ActionClick({ selector=".ardplayer-bottom-sheet-container div[aria-label='Geschwindigkeit'] span.ardplayer-option[data-index='{{ data-index }}']"}),
                ActionClick({ timeout=500, selector=".ardplayer-bottom-sheet-close-button.ardplayer-icon-close"}),
            },
            moveForward = { {}, "l" },
            moveBackward = { {}, "j" },
            info = "wdr.de Player"
        },
        ["joyn.de"] = {
            pause = { {}, "SPACE" },
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "Joyn Player (no speed controls)"
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

---@param modifier table @available modifiers or empty table
---@param key string @key
---@return void
---
local function doKey(modifier, key)
    debugInfo("--> doKey(", modifier, ',"', key, '")')

    local receiverApp

    if currentWindow then
        receiverApp = currentWindow:application()
        -- TODO: activate the window - place over others - but go back to current app
        -- TODO: check if currentWindow still exists - otherwise null it or use the current
    else
        receiverApp = hs.application.applicationsForBundleID(currentBundleId)[1]
    end

    if receiverApp then
        hs.eventtap.keyStroke(modifier, key, 0, receiverApp)
    end
end

local functionMemory = {}

---@param function function @function to be called
---@param params table @params for the function
---@return void
---
local function doFunction(actionFunction)

    debugInfo("--> doFunction(", getFunctionName(actionFunction), ',"', actionParameter, '")')
    debugFunction(actionFunction)

    local ok, result = actionFunction(functionMemory)
    --debugInfo(ok, result, type(result))
    helper.table.assign(functionMemory, result)
    --debugTable("functionMemory")
    --debugTable(functionMemory)
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
        --local actionCommands = { table.unpack(appActions[action]) }
        local actionCommands = appActions[action]
        if type(actionCommands) == 'function' then
            actionCommands = { actionCommands }
        else
            actionCommands = { table.unpack(appActions[action]) }
        end
        doCommand(appActions, actionCommands)

    elseif type(peek) == 'function' then
        -- function type
        local actionFunction = table.remove(actionQueue, 1)

        doFunction(actionFunction)

    else -- table?

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
    ActionSelect({ selector=selector })
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

    if appActions == nil then
        debugInfo("no player actions defined for current domain.")
        return
    end

    debugInfo("changed currentBundleId to: " .. currentBundleId)
    debugInfo("Detected: "..appActions.info)
    hs.alert.show("Detected: "..appActions.info)

    selectPlayer(appActions.selector)
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
