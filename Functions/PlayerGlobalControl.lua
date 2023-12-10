---
--- Created by muescha.
--- DateTime: 24.08.22 10:00
---
--- Current Apps / Sites
---   -> IINA
---   -> Chrome for Player in:
---      -> Generic HTML Video
---      -> [x] YouTube
---      -> [x] RTL+
---      -> [x] WDR
---             TODO: onlye some Controls working on: https://www1.wdr.de/lokalzeit/fernsehen/koeln/video-studiogespraech-linda-rennings-gruenderin-heimatlos-in-koeln-hik-und-koelsche-linda-100.html
---      -> [x] spotify
---      -> Spiegel
---      -> Netflix
---      -> twitter (Example: https://twitter.com/jnybgr/status/1688423139330469888?s=12&t=UKgH_3wb-W7rBipFV7CKXg)
---      -> Loom https://www.loom.com/share/8771f24615e04735a00de927bb6fde99?t=277
---      -> https://podcasts.google.com/ (TODO)
---      -> https://www.linkedin.com/learning/small-talk-und-netzwerken-2-unterschatzte-karriere-booster/gutes-small-talk-thema-wie-findet-man-das?autoSkip=true&resume=false
---   -> TODO: add qualitiy selector for YT
--- reduce Chromoim like apps to Chrome - and Safari like to WebKit
--- add fullscreen shortcut


fileInfo()

local cache = {}

local bundleIdIINA = "com.colliderli.iina"
local bundleIdChrome = "com.google.Chrome"

local actions = enumString {
    "start",
    "pause",
    "speedReset",
    "speedInc",
    "speedDec",
    "moveForward",
    "moveBackward",
    "maxQuality"
}


-- maybe direct solution via javascript is here:
--   https://github.com/igrigorik/videospeed/blob/master/inject.js
-- since i don't know the current speed:


-- just tune down to minimum (7 keyStrokes from max 2x speed)
-- and then up to 1
function actionSpeedReset(count)
    local reset = {}
    table.insert(reset, actions.pause)

    for _=1,count+4 do
        table.insert(reset, actions.speedDec)
    end
    for _=1,count do
        table.insert(reset, actions.speedInc)
    end

    table.insert(reset, actions.pause)
    return reset
end

--local currentBundleId = bundleIdIINA
local savedBundleId = bundleIdChrome

---@type hs.window
local savedWindow = nil
local savedDomain = nil

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
    local ok, output, message = runActionCode(code)
    debugInfo("runActionCode -      ok: ", ok)
    debugInfo("runActionCode -  Output: ", output)
    debugInfo("runActionCode - Message: ", message)
    return ok, output, message
end

--
function GenericAction(action, defaultParams)
    local templatePath = path()

    return function(memory)
        local params = helper.table.assigned(memory, defaultParams)
        debugInfo("Params: ", params)
        local code = getActionCode(templatePath, action, params)
        local ok, output, message = runActionCodeDebug(code)

        if params.property == nil then
            if output == nil then
                return ok, {}
            end
            return ok, { [(memory.domain or '') .. '-' .. action..'-'.. params.action] = output}
        end

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

function ActionPatch(params)
    return GenericAction("ActionPatch", params)
end

function ActionGenericVideo(command)
    return ActionJavascript("ActionGenericVideo", command)
end

function ActionYoutubeVideo(command)
    return ActionJavascript("ActionYoutubeVideo", command)
end

function ActionJavascript(template, command)
    local params = (command == nil) and {} or { action = command }
    return GenericAction(template, params)
end

function MemoryCalc(params)
    return function(memory) -- MemoryCalc
        local allParams = helper.table.assigned(memory, params)
        debugInfo("MemoryCalc")
        debugInfo("Params: ", allParams)
        debugFunction(allParams.calc)
        local output = allParams.calc(allParams[allParams.property])
        local result = { [allParams.property] = output}
        return true, result
    end
end

function MemoryCalcCheck(params)
    return MemoryCalc({
            calc = function(value)
                if params.min ~= nil then
                    value = math.max(params.min, value)
                end
                if params.max ~= nil then
                    value = math.min(params.max, value)
                end
                return value
            end,
            property = params.property
        })
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
        ["generic.video"] = {
            selector = "",
            start = {},
            pause = ActionGenericVideo("doPause"),
            speedReset = ActionGenericVideo(),
            speedInc = ActionGenericVideo(),
            speedDec = ActionGenericVideo(),
            moveForward = ActionGenericVideo(),
            moveBackward = ActionGenericVideo(),
            maxQuality = {},
            info = "Generic Video"
        },
        ["youtube.com"] = {
            selector = "#movie_player",
            start = {
                ActionClick({ selector = ".ytp-large-play-button" })
            },
            pause = { {}, "k" },
            -- document.querySelector('.ytp-large-play-button').click()
            -- not working: 
            --pause = {
            --    ActionClick({ selector = ".ytp-large-play-button" })
            --},

            speedReset = actionSpeedReset(3),
            speedInc = { { "shift" }, "." }, -- '>'
            speedDec = { { "shift" }, "," }, -- '<'
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            maxQuality = ActionYoutubeVideo("getQuality"),
            maxQuality1 = {
                ActionClick({ selector="button.ytp-settings-button"}),
                ActionPatch({
                    selector=".ytp-settings-menu .ytp-panel-menu .ytp-menuitem",
                    childSelector=".ytp-menuitem-label"
                }),
                ActionClick({ selector=".ytp-settings-menu .ytp-panel-menu .ytp-menuitem[data-content-inner-text='Qualität']"}),
                ActionPatch({
                    selector=".ytp-quality-menu .ytp-menuitem",
                    childSelector=".ytp-menuitem-label"
                }),
                ActionClick({ selector=".ytp-menuitem[data-content-inner-text='1080p HD'"}),
            },
            info = "YouTube Player"
        },
        ["twitch.tv"] = {
            selector = ".persistent-player",
            start = {},
            pause = { {}, "k" },
            speedReset = actionSpeedReset(3),
            speedInc = { {}, "." }, -- '>'
            speedDec = { {}, "," }, -- '<'
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "Twitch Player"
        },
        ["udemy.com"] = {
            --selector = "[class*='app--body-container--']",
            --selector = "[data-purpose='curriculum-item-viewer-content']",
            start = {
                ActionClick({ selector = "[data-purpose='go-to-next-button']" })
            },
            selector = "video.vjs-tech",
            pause = { {}, "SPACE" },
            speedReset = actionSpeedReset(2),
            speedInc = { { "shift" }, "right" },
            speedDec = { { "shift" }, "left" },
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "Udemy Player"
        },
        ["tvnow.de"] = {
            start = {},
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
            start = {},
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
            start = {},
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
        -- https://www.ardmediathek.de/video/lokalzeit-aus-koeln/lokalzeit-aus-koeln-oder-25-08-2023/wdr/Y3JpZDovL3dkci5kZS9CZWl0cmFnLWU3NjI3YTM4LTI4YTUtNDlkNi04NGZkLTNhZmYxMWI1ZTY1Ng
        ["ardmediathek.de"] = {

            selector = ".ardplayer-viewport",
            start = {},
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
            info = "ardmediathek.de Player"
        },
        ["joyn.de"] = {
            start = {},
            pause = { {}, "SPACE" },
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = { {}, "right" },
            moveBackward = { {}, "left" },
            info = "Joyn Player (no speed controls)"
        },
        ["spotify.com"] = {
            start = {},
            pause = { {}, "SPACE" },
            speedReset = {
                ActionClick({
                    selector = "button[data-testid='control-button-playback-speed']"
                }),
                ActionPatch({
                    selector="#context-menu ul div li",
                    childSelector="button span"
                }),
                ActionClick({
                    selector = "#context-menu ul div li[data-content-inner-text='1x'] button"
                })
            },
            speedInc = {
                ActionClick({
                    selector = "button[data-testid='control-button-playback-speed']"
                }),
                ActionPatch({
                    selector="#context-menu ul div li",
                    childSelector="button span"
                }),
                ActionGetProperty({
                    selector="#context-menu ul div li:has( button[aria-checked='true'])",
                    property="data-element-index",
                    calc=function(value) return value+1 end,
                }),
                MemoryCalcCheck({
                    min=0,
                    max=30,
                    property="data-element-index"
                }),
                ActionClick({
                    selector = "#context-menu ul div li[data-element-index='{{ data-element-index }}'] button"
                })

            },
            speedDec = {
                ActionClick({
                    selector = "button[data-testid='control-button-playback-speed']"
                }),
                ActionPatch({
                    selector="#context-menu ul div li",
                    childSelector="button span"
                }),
                ActionGetProperty({
                    selector="#context-menu ul div li:has( button[aria-checked='true'])",
                    property="data-element-index",
                    calc=function(value) return value-1 end,
                }),
                MemoryCalcCheck({
                    min=0,
                    max=30,
                    property="data-element-index"
                }),
                ActionClick({
                    selector = "#context-menu ul div li[data-element-index='{{ data-element-index }}'] button"
                })

            },
            moveForward = { { "cmd", "shift"}, "right" },
            moveBackward = { { "cmd", "shift" }, "left" },
            info = "Spotify Player (no speed controls)"
        },
    }
}

function getChromeUrl()
    --local _,url = hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')
    --_, title, _ = hs.osascript.javascript("Application('Google Chrome').windows[0].activeTab().title()")
    _, url, _ = hs.osascript.javascript("Application('Google Chrome').windows[0].activeTab().url()")
    return url
end

local function host(url)
    return (url.."/"):match("://(.-)/")
end

local function tld(domain)
    if domain == nil then return nil end
    local parts = hs.fnutils.split(domain, '%.')
    if #parts == 1 then return domain end
    return parts[#parts -1]..".".. parts[#parts]
end

function getChromeUrlDomain()
    local url = getChromeUrl()
    debugInfo("current url: ", url)
    local host = hs.http.urlParts(url).host
    debugInfo("current host: ", host)
    --local domain = url:match("[%w%.]*%.(%w+%.%w+)")
    local domain = tld(host)
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

    if savedWindow then
        receiverApp = savedWindow:application()
        -- TODO: activate the window - place over others - but go back to current app
        -- TODO: check if savedWindow still exists - otherwise null it or use the current
    else
        receiverApp = hs.application.applicationsForBundleID(savedBundleId)[1]
    end

    if receiverApp then
        hs.eventtap.keyStroke(modifier, key, 0, receiverApp)
    end
end

local functionMemory = {}

---@param actionFunction function @function to be called
---@return void
---
local function doFunction(actionFunction)

    debugInfo("--> doFunction(", getFunctionName(actionFunction), ',"', actionParameter, '")')
    debugFunction(actionFunction)

    local ok, result = actionFunction(functionMemory)
    --debugInfo(ok, result, type(result))
    helper.table.assign(functionMemory, result)
    debugInfo("Memory: ", functionMemory)
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
        if actionCommands == nil then
            debugInfo("No command defined for action: " .. action)
        else
            if type(actionCommands) == 'function' then
                actionCommands = { actionCommands }
            else
                actionCommands = { table.unpack(actionCommands) }
            end
            doCommand(appActions, actionCommands)
        end

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
-- savedWindow:focusTab(1)
-- local _,tabIndex = hs.osascript.applescript('tell application "Google Chrome" to return active tab index of front window')

local function checkSwitch()

    local win = hs.window.focusedWindow()
    local bundleID = win:application():bundleID()

    local returnSwitchBacks = { win }

    --if bundleIdChrome ~= bundleID then debugInfo("checkSwitch: current app no Chrome") return end
    if bundleIdChrome ~= savedBundleId then debugInfo("checkSwitch: saved window is not chrome") return end
    if savedWindow==nil then debugInfo("checkSwitch: no window saved") return end
    if win == savedWindow then debugInfo("checkSwitch: current app focused is same window as saved") return end

    local savedWindowFocused = savedWindow:application():focusedWindow()

    if savedWindowFocused == savedWindow then debugInfo("checkSwitch: saved app focused is the same window as saved") return end
    debugInfo("checkSwitch: saved app focused is NOT the same window as saved")

    if win ~= savedWindowFocused then
        debugInfo("checkSwitch: add currentWinFocused to return table")
        table.insert(returnSwitchBacks, 1, savedWindowFocused)
    end

    debugInfo("checkSwitch: switch to ", savedWindow)
    savedWindow:focus()
    hs.timer.usleep(10000)
    --savedWindow:raise()

    return returnSwitchBacks
end

local function checkSwitchBack(switchBacks)
    if switchBacks then
        for _, win in pairs(switchBacks) do
            debugInfo("checkSwitch: switch back to", win)
            win:focus()
        end
    end
end


local function getAppActions()

    local appActions

    if savedBundleId == bundleIdChrome then
        --local domain = savedDomain or getChromeUrlDomain()
        local domain = getChromeUrlDomain()
        appActions = ControlKeys[savedBundleId][domain]
        if appActions == nil then
            --local generic = ControlKeys[savedBundleId]["genieric.video"]
            functionMemory['domain'] = domain
            doFunction(ActionGenericVideo("isGeneric"))
            if functionMemory[domain..'-ActionGenericVideo-isGeneric'] then
                domain = "generic.video"
                appActions = ControlKeys[savedBundleId][domain]
            else
                return
            end
        end
        functionMemory['domain'] = domain
    else
        appActions = ControlKeys[savedBundleId]
    end

    return appActions
end

local hotkeyInfo = {}

-- types
---@param sourceKey string
---@param action string
local function createHotkey(sourceKey, action, description)

    hotkeyInfo[action] = {
        sourceKey = sourceKey,
        action = action,
        description = description
    }

    hs.hotkey.bind(hyper, sourceKey, keyInfo(description), function()

        local switchBackToWindow = checkSwitch()

        local appActions = getAppActions()

        if appActions == nil then
            debugInfo("exit - no commands found")
            return
        end

        helper.table.assign(functionMemory, { action = action })
        doCommand(appActions, { action })

        checkSwitchBack(switchBackToWindow)
    end)

end

local function setSavedWindow()
    local win = hs.window.focusedWindow()
    local bundleID = win:application():bundleID()

    if ControlKeys[bundleID] == nil then
        if savedWindow then
            local msg = "focus saved window"
            debugInfo(msg)
            hs.alert.show(msg)

            savedWindow:focus()
        end
        return
    end

    savedWindow = win
    savedBundleId = bundleID
    if savedBundleId == bundleIdChrome then
        savedDomain = getChromeUrlDomain()
    else
        savedDomain = nil
    end

    local appActions = getAppActions()

    if appActions == nil then
        local msg = "no player actions defined for current domain: " .. savedDomain
        debugInfo(msg)
        hs.alert.show(msg)
        return
    end

    local enabledInfo = getEnabledInfo(appActions)

    debugInfo("changed savedBundleId to: " .. savedBundleId)

    local infoText = "Detected: "..appActions.info
            .."\n\n"..enabledInfo

    debugInfo("\n\n".. infoText)
    hs.alert.show(infoText, { textFont = "Menlo"}, win)

    selectPlayer(appActions.selector)
end

function getEnabledInfo(appActions)
    local enabledInfo = ""
    local icon = ""

    local sortedActionsIterator = helper.table.sortByKeyIterator(actions)
    local format = "✧%s %s %-12s %s\n"
    for k, v in sortedActionsIterator do

        if appActions[v] == nil or type(appActions[v]) == 'table' and #appActions[v] == 0 then
            icon = "🔴"
        else
            icon = "🟢"
        end

        local info = string.format(format, hotkeyInfo[v].sourceKey  ,icon ,v, hotkeyInfo[v].description)
        enabledInfo = enabledInfo .. info
    end
    return enabledInfo
end

-- Start
createHotkey("u", actions.start, "Start (next) Video")

-- Play / Pause
createHotkey("p", actions.pause, "Pause Video")

-- normal Speed 0
createHotkey("k", actions.speedReset, "Reset Speed")
--speed with +/-
createHotkey("l", actions.speedDec, "Decrease Speed")
createHotkey(";", actions.speedInc, "Increase Speed")

-- Rewind / Forward
createHotkey("'", actions.moveBackward, "Jump Backward")
createHotkey("\\", actions.moveForward, "Jump Forward")

createHotkey("j", actions.maxQuality, "Max Quality")

hs.hotkey.bind(hyper, "o", keyInfo("Set active App"), setSavedWindow)
