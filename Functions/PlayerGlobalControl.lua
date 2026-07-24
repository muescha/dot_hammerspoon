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
---      -> [x] ARD Audiothek
---      -> [x] ARD Mediathek:
---      -> [x] WDR
---             TODO: onlye some Controls working on: https://www1.wdr.de/lokalzeit/fernsehen/koeln/video-studiogespraech-linda-rennings-gruenderin-heimatlos-in-koeln-hik-und-koelsche-linda-100.html
---      -> [x] spotify
---      -> Spiegel
---      -> Netflix
---      -> Facebook https://www.facebook.com/watch/?v=816103793764263
---      -> twitter (Example: https://twitter.com/jnybgr/status/1688423139330469888?s=12&t=UKgH_3wb-W7rBipFV7CKXg)
---      -> Loom https://www.loom.com/share/8771f24615e04735a00de927bb6fde99?t=277
---      -> https://podcasts.google.com/ (TODO)
---      -> https://www.linkedin.com/learning/small-talk-und-netzwerken-2-unterschatzte-karriere-booster/gutes-small-talk-thema-wie-findet-man-das?autoSkip=true&resume=false
---   -> TODO: add qualitiy selector for YT
---         Audio Player:
---         - Soundcloud
---
--- reduce Chromoim like apps to Chrome - and Safari like to WebKit
--- add fullscreen shortcut


fileInfo()

local cache = {}

local bundleIdIINA = "com.colliderli.iina"
local bundleIdChrome = "com.google.Chrome"
local browserGoogleChrome = "Google Chrome"
local browserGoogleDevTools = "Google DevTools"
local browserJavaScriptRunner = browserGoogleChrome

local actions = enumString {
    "start",
    "pause",
    "speedReset",
    "speedInc",
    "speedDec",
    "moveForward",
    "moveBackward",
    "maxQuality",
    "maxSpeed"
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

local PlayerActions = {
    actions = {}
}

function PlayerActions.setActions(actions)
    PlayerActions.actions = actions
end

function PlayerActions.getActions(bundleId, domain)
    local targetActions = PlayerActions.actions[bundleId]
    if domain then
        return targetActions and targetActions[domain] or nil
    end
    return targetActions
end

function PlayerActions.hasActions(bundleId)
    return PlayerActions.getActions(bundleId) ~= nil
end

local PlayerTarget = {
    bundleId = bundleIdChrome,
    window = nil
}

function PlayerTarget.saveWindow(win)
    PlayerTarget.window = win
    PlayerTarget.bundleId = win:application():bundleID()
end

function PlayerTarget.getWindow()
    return PlayerTarget.window
end

function PlayerTarget.getBundleId()
    return PlayerTarget.bundleId
end

function PlayerTarget.isChrome()
    return PlayerTarget.bundleId == bundleIdChrome
end

function PlayerTarget.getReceiverApp()
    local savedWindow = PlayerTarget.getWindow()
    if savedWindow then
        -- TODO: activate the window - place over others - but go back to current app
        -- TODO: check if savedWindow still exists - otherwise null it or use the current
        return savedWindow:application()
    end

    return hs.application.applicationsForBundleID(PlayerTarget.getBundleId())[1]
end

function PlayerTarget.getActions(domain)
    return PlayerActions.getActions(PlayerTarget.getBundleId(), domain)
end

-- Java Script Actions

local function doCache(cacheKey, f)
    debugInfo("Cache Size:", helper.table.count(cache))
    --for key, _ in pairs(cache) do
    --    print(key)
    --end
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

local function runActionCode(code, callback)
    local wrapper = path() .. "PlayerGlobalControl-BrowserWrapper.js"
    local params = { code = code, application = browserGoogleChrome, path = wrapper, browser = browserJavaScriptRunner, debug = false }

    if browserJavaScriptRunner == browserGoogleDevTools then
        params.path = nil
    end

    runJavaScriptInBrowser(params, callback)
end

local function logActionCodeResult(ok, output, message)
    debugInfo("runActionCode -      ok: ", ok)
    debugInfo("runActionCode -  Output: ", output)
    debugInfo("runActionCode - Message: ", message)
end

local function runActionCodeDebug(code, callback)
    assert(callback, "runActionCodeDebug requires callback")
    runActionCode(code, function(ok, output, message)
        logActionCodeResult(ok, output, message)
        callback(ok, output, message)
    end)
end

--
function GenericAction(action, defaultParams)
    local templatePath = path()

    return function(memory, callback)
        assert(callback, "GenericAction requires callback")
        local params = helper.table.assigned(memory, defaultParams)
        debugInfo("Params: ", params)
        local code = getActionCode(templatePath, action, params)

        local handleResult = function(ok, output, message)
            if not ok then
                return false, message
            end

            if params.property == nil then
                if output == nil then
                    return ok, {}
                end
                return ok, { [(memory.domain or '') .. '-' .. action..'-'.. params.action] = output}
            end

            local calc = params.calc or function(v) return v end

            -- TODO add nil check for output
            local result = { [params.property] = calc(output)}
            return ok, result
        end

        runActionCodeDebug(code, function(ok, output, message)
            callback(handleResult(ok, output, message))
        end)
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
    local params = (command == nil) and {} or { action = command }
    return GenericAction("ActionGenericVideo", params)
end

function MemoryCalc(params)
    return function(memory, callback) -- MemoryCalc
        assert(callback, "MemoryCalc requires callback")
        local allParams = helper.table.assigned(memory, params)
        debugInfo("MemoryCalc")
        debugInfo("Params: ", allParams)
        debugFunction(allParams.calc)
        local output = allParams.calc(allParams[allParams.property])
        local result = { [allParams.property] = output}
        callback(true, result)
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

---@param modifier table @available modifiers or empty table
---@param key string @key
---@return void
---
local function doKey(modifier, key)
    debugInfo("--> doKey(", modifier, ',"', key, '")')

    local receiverApp = PlayerTarget.getReceiverApp()

    if receiverApp then
        hs.eventtap.keyStroke(modifier, key, 0, receiverApp)
    end
end

local function Key(modifier, key)
    return function(_, callback)
        doKey(modifier, key)
        callback(true, {})
    end
end

local function copyCommandQueue(command)
    return type(command) == 'table' and { table.unpack(command) } or { command }
end

local function failCommand(callback, message, details)
    debugInfo(message, details)
    callback(false, details or message)
end

PlayerActions.setActions({
    [bundleIdIINA] = {
        pause = Key({}, "p"),
        speedReset = Key({}, "0"),
        -- speedInc = { {}, "=" }, -- +
        -- speedDec = { {}, "-" },
        speedInc = Key({}, "]"), -- 2,0
        speedDec = Key({}, "["), -- 0,5
        moveForward = Key({}, "right"),
        moveBackward = Key({}, "left"),
        info = "IINA Player"
    },
    [bundleIdChrome] = {
        ["generic.video"] = {
            selector = "",
            start = {
                ActionClick({ selector = ".ytp-large-play-button" }),
                ActionGenericVideo("play")
            },
            pause = ActionGenericVideo("doPause"),
            speedReset = ActionGenericVideo(),
            speedInc = ActionGenericVideo(),
            speedDec = ActionGenericVideo(),
            moveForward = ActionGenericVideo(),
            moveBackward = ActionGenericVideo(),
            maxQuality = {},
            maxSpeed = ActionGenericVideo(),
            info = "Generic Video"
        },
        ["youtube.com"] = {
            selector = "",
            start = {
                ActionClick({ selector = ".ytp-large-play-button" })
            },
            pause = ActionGenericVideo("doPause"),
            speedReset = ActionGenericVideo(),
            speedInc = ActionGenericVideo(),
            speedDec = ActionGenericVideo(),
            moveForward = ActionGenericVideo(),
            moveBackward = ActionGenericVideo(),
            maxQuality = {},
            maxSpeed = ActionGenericVideo(),
            info = "Generic YouTube"
        },
        ["youtube.com-old"] = {
            selector = "#movie_player",
            start = {
                ActionClick({ selector = ".ytp-large-play-button" })
            },
            pause = Key({}, "k"),
            -- document.querySelector('.ytp-large-play-button').click()
            -- not working:
            --pause = {
            --    ActionClick({ selector = ".ytp-large-play-button" })
            --},

            speedReset = actionSpeedReset(3),
            speedInc = Key({ "shift" }, "."), -- '>'
            speedDec = Key({ "shift" }, ","), -- '<'
            moveForward = Key({}, "right"),
            moveBackward = Key({}, "left"),
            maxQuality = {
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
            pause = Key({}, "k"),
            speedReset = actionSpeedReset(3),
            speedInc = Key({}, "."), -- '>'
            speedDec = Key({}, ","), -- '<'
            moveForward = Key({}, "right"),
            moveBackward = Key({}, "left"),
            info = "Twitch Player (Speed only on Videos)"
        },
        ["udemy.com"] = {
            --selector = "[class*='app--body-container--']",
            --selector = "[data-purpose='curriculum-item-viewer-content']",
            start = {
                ActionClick({ selector = "[data-purpose='go-to-next-button']" })
            },
            selector = "video.vjs-tech",
            pause = Key({}, "SPACE"),
            speedReset = actionSpeedReset(2),
            speedInc = Key({ "shift" }, "right"),
            speedDec = Key({ "shift" }, "left"),
            moveForward = Key({}, "right"),
            moveBackward = Key({}, "left"),
            info = "Udemy Player"
        },
        ["tvnow.de"] = {
            start = {},
            pause = Key({}, "SPACE"),
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = Key({}, "right"),
            moveBackward = Key({}, "left"),
            info = "TVnow Player (no speed controls)"

        },
        ["spiegel.de-old"] = {
            --defaultFunctionParams = {
            --    speedItems = { '0.5x', '1x', '1.25x', '1.5x', '2x' },
            --    speedItemsDefault = '1x',
            --},
            start = {},
            pause = Key({}, "SPACE"),
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
                }),
                ActionGetProperty({
                    selector=".jw-settings-submenu-playbackRates button.jw-settings-content-item:nth-child({{ child-index }})",
                    property="aria-label"
                }),
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
                }),
                ActionGetProperty({
                    selector=".jw-settings-submenu-playbackRates button.jw-settings-content-item:nth-child({{ child-index }})",
                    property="aria-label"
                }),
            },
            moveForward = Key({}, "right"),
            moveBackward = Key({}, "left"),
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
            moveForward = Key({}, "l"),
            moveBackward = Key({}, "j"),
            info = "wdr.de Player"
        },
        ["joyn.de"] = {
            start = {},
            pause = Key({}, "SPACE"),
            speedReset = {},
            speedInc = {},
            speedDec = {},
            moveForward = Key({}, "right"),
            moveBackward = Key({}, "left"),
            info = "Joyn Player (no speed controls)"
        },
        ["spotify.com"] = {
            start = {},
            pause = Key({}, "SPACE"),
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
            moveForward = Key({ "cmd", "shift"}, "right"),
            moveBackward = Key({ "cmd", "shift" }, "left"),
            info = "Spotify Player"
        },
    }
})

-- https://www.ardaudiothek.de/sendung/legion/12015417/
PlayerActions.actions[bundleIdChrome]["ardaudiothek.de"] = helper.table.assigned(PlayerActions.actions[bundleIdChrome]["wdr.de"], {
        selector = ".ardplayer-viewport",
        info = "ardaudiothek.de Player"
    })

-- https://www.ardmediathek.de/video/lokalzeit-aus-koeln/lokalzeit-aus-koeln-oder-25-08-2023/wdr/Y3JpZDovL3dkci5kZS9CZWl0cmFnLWU3NjI3YTM4LTI4YTUtNDlkNi04NGZkLTNhZmYxMWI1ZTY1Ng
PlayerActions.actions[bundleIdChrome]["ardmediathek.de"] = helper.table.assigned(PlayerActions.actions[bundleIdChrome]["wdr.de"], {
        selector = ".ardplayer-viewport",
        info = "ardmediathek.de Player"
    })

-- https://www.arte.tv/de/
-- https://www.zdf.de/dokus

function getChromeUrl()
    --local _,url = hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')
    --_, title, _ = hs.osascript.javascript("Application('Google Chrome').windows[0].activeTab().title()")
    --_, url, _ = hs.osascript.javascript("Application('Google Chrome').windows[0].activeTab().url()")
    local ok, url, err = hs.osascript.javascript("Application('Google Chrome').windows[0].activeTab().url()")
    if not ok then
        debugInfo("getChromeUrl: AppleScript-JS call failed: ", err)
        return nil
    end
    if type(url) ~= "string" or url == "" then
        debugInfo("getChromeUrl: no URL for active tab (window missing or internal page).")
        return nil
    end
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
    if not url then
        debugInfo("getChromeUrlDomain: url is nil")
        return nil
    end
    local parts = hs.http.urlParts(url)
    if not parts or not parts.host then
        debugInfo("getChromeUrlDomain: no host parsed (likely non-http(s) url). parts=", parts)
        return nil
    end
    local host = parts.host
    debugInfo("current host: ", host)
    --local domain = url:match("[%w%.]*%.(%w+%.%w+)")
    local domain = tld(host)
    debugInfo("current domain: ", domain)
    return domain
end

local functionMemory = {}

---@param actionFunction function @function to be called
---@return void
---
local function doFunction(actionFunction, callback)
    assert(callback, "doFunction requires callback")

    debugInfo("--> doFunction(", getFunctionSignature(actionFunction), ")")
    debugInfo("Memory: ", functionMemory)
    debugInfo("debugFunction(actionFunction)")
    debugFunction(actionFunction)

    local done = function(ok, result)
        local win = hs.window.focusedWindow()
        hs.alert.show(hs.inspect(result), { atScreenEdge = 1}, win)

        if ok then
            helper.table.assign(functionMemory, result)
            debugInfo("Memory: ", functionMemory)
        else
            failCommand(callback, "doFunction: action failed: ", result)
            return
        end

        callback(ok, result)
    end

    actionFunction(functionMemory, done)
end


---@param appActions table @available actions for all apps
---@param actionQueue table @queue of actions
---@return void
---
local function doCommand(appActions, actionQueue, callback)
    assert(callback, "doCommand requires callback")

    if #actionQueue == 0 then
        callback(true)
        return
    end

    debugInfo("--> doCommand(", "appActions", ",", actionQueue, ")")

    local command = table.remove(actionQueue, 1)

    local function continueQueue(ok, message)
        if not ok then
            failCommand(callback, "Command queue failed: ", message)
            return
        end

        doCommand(appActions, actionQueue, callback)
    end

    if type(command) == 'string' then

        local actionCommands = appActions[command]
        if actionCommands == nil then
            failCommand(callback, "No command defined for action: " .. command)
            return
        end

        doCommand(appActions, copyCommandQueue(actionCommands), continueQueue)

    elseif type(command) == 'function' then
        doFunction(command, continueQueue)

    else
        failCommand(callback, "Unknown command: " .. tostring(command))
    end

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
    if selector==nil or selector=="" then return end
    doFunction(ActionSelect({ selector=selector }), function() end)
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
    if win == nil then debugInfo("checkSwitch: no focused window available") return end
    local app = win:application()
    if app == nil then debugInfo("checkSwitch: focused window has no application") return end
    local bundleId = app:bundleID()

    local returnSwitchBacks = { win }

    --if bundleIdChrome ~= bundleId then debugInfo("checkSwitch: current app no Chrome") return end
    if not PlayerTarget.isChrome() then debugInfo("checkSwitch: saved window is not chrome") return end
    local savedWindow = PlayerTarget.getWindow()
    if savedWindow==nil then debugInfo("checkSwitch: no window saved") return end
    if savedWindow:application()==nil then debugInfo("checkSwitch: savedWindow has no Application") return end
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

local function getGenericVideoActions(domain, callback)
    functionMemory['domain'] = domain

    doFunction(ActionGenericVideo("isGeneric"), function(ok)
        if ok and functionMemory[domain..'-ActionGenericVideo-isGeneric'] then
            local genericDomain = "generic.video"
            local appActions = PlayerTarget.getActions(genericDomain)
            functionMemory['domain'] = genericDomain
            callback(appActions, genericDomain)
        else
            callback(nil, domain)
        end
    end)
end


local function getAppActions(callback)
    assert(callback, "getAppActions requires callback")

    local appActions

    local domain

    if PlayerTarget.isChrome() then
        domain = getChromeUrlDomain()
        if domain == nil then
            debugInfo("No domain detected for current Chrome tab (likely internal/blank page).")
            callback(nil, nil)
            return
        end
        appActions = PlayerTarget.getActions(domain)
        if appActions == nil then
            getGenericVideoActions(domain, callback)
            return
        end
        functionMemory['domain'] = domain
    else
        appActions = PlayerTarget.getActions()
    end

    callback(appActions, domain)
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

        functionMemory = {}
        debugInfo("")
        debugInfo("-----------------------------")
        debugInfo("HotKey")
        debugInfo("-----------------------------")
        debugInfo("hyper: ", hyper)
        debugInfo("sourceKey: ", sourceKey)
        debugInfo("description: ", keyInfo(description))
        debugInfo("Key: ", hyper,  " + '", sourceKey, "' => ", keyInfo(description))
        debugInfo("Action ", action)
        debugInfo("-----------------------------")
        debugInfo("step: reset functionMemory")
        print("collectgarbage(count)")
        print(collectgarbage("count"))
        --         collectgarbage("collect")

        local switchBackToWindow = checkSwitch()

        getAppActions(function(appActions, domain)
            if appActions == nil then
                debugInfo("exit - no commands found for domain " .. tostring(domain))
                checkSwitchBack(switchBackToWindow)
                return
            end

            helper.table.assign(functionMemory, { action = action })
            doCommand(appActions, { action }, function(ok, message)
                checkSwitchBack(switchBackToWindow)

                if not ok then
                    local msg = "HotKey action failed: " .. action .. "\n" .. tostring(message)
                    debugInfo(msg)
                    hs.alert.show(msg)
                    return
                end

                print("collectgarbage(count)")
                print(collectgarbage("count"))
                debugInfo("-----------------------------")
                debugInfo("HotKey: End")
                debugInfo("-----------------------------")
            end)
        end)

    end)

end

local function toggleBrowserJavaScriptRunner()
    if browserJavaScriptRunner == browserGoogleChrome then
        browserJavaScriptRunner = browserGoogleDevTools
    else
        browserJavaScriptRunner = browserGoogleChrome
    end

    debugInfo("Player browser JavaScript runner: ", browserJavaScriptRunner)
    hs.alert.show("Player JS: " .. browserJavaScriptRunner)
end

local function getEnabledInfo(appActions)
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

local function setSavedWindow()
    debugInfo("devtoolscheck: Start")
    local devtoolscheck = helper.chrome.devtools.debugFrontmostChromeDetection()
    debugInfo("devtoolscheck: Result:")
    debugTable(devtoolscheck)
    debugInfo("devtoolscheck: End")
    local win = hs.window.focusedWindow()
    if win == nil then
        debugInfo("setSavedWindow: no focused window available")
        return
    end
    local app = win:application()
    if app == nil then
        debugInfo("setSavedWindow: focused window has no application")
        return
    end
    local bundleId = app:bundleID()
    local title = app:title()

    debugInfo("Cache Size:", helper.table.count(cache))
    debugInfo("reset cache")
    cache = {}

    if not PlayerActions.hasActions(bundleId) then
        local savedWindow = PlayerTarget.getWindow()
        if savedWindow then
            local msg = "setSavedWindow: focus saved window"
            debugInfo(msg)
            hs.alert.show(msg)

            savedWindow:focus()
        else
            local msg = "setSavedWindow: no player controls defined for App " .. title .. " ('" .. bundleId .. "')"
            debugInfo(msg)
            hs.alert.show(msg)
        end
        return
    end

    PlayerTarget.saveWindow(win)

    getAppActions(function(appActions, domain)
        if appActions == nil then
            local msg = "setSavedWindow: no player actions defined for current domain: " .. (domain or "(none)")
            debugInfo(msg)
            hs.alert.show(msg)
            return
        end

        local enabledInfo = getEnabledInfo(appActions)

        debugInfo("setSavedWindow: changed savedBundleId to: " .. PlayerTarget.getBundleId())

        local infoText = "Detected: "..appActions.info
                .."\n\n"..enabledInfo

        debugInfo("\n\n".. infoText)
        hs.alert.show(infoText, { textFont = "Menlo"}, win)

        selectPlayer(appActions.selector)
    end)
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
createHotkey("9", actions.maxSpeed, "Max Speed")

hs.hotkey.bind(hyper, "o", keyInfo("Set active App"), setSavedWindow)
hs.hotkey.bind(hyper, "z", keyInfo("Toggle Player JS Runner"), toggleBrowserJavaScriptRunner)
