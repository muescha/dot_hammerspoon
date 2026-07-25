-- https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys

-- https://stackoverflow.com/questions/63795560/how-can-i-prevent-hammerspoon-hotkeys-from-overriding-hotkeys-in-other-applicati

local logger = hs.logger.new("HotkeyBindWhen")

---@class hs.hotkey.conditions

---@class hs.hotkey.target
---@field app fun(appName: string): HotkeyTarget
---@field appTab fun(appName: string, tabPattern: string): HotkeyTarget

---@class hs.hotkey
---@field conditions hs.hotkey.conditions
---@field target hs.hotkey.target

---@alias HotkeyCondition fun(currentAppName: string, currentTab: string): boolean
---@alias HotkeyTarget { kind: "app"|"appTab", app: string, tab: string|nil, withTab: function|nil }
---@alias HotkeyTargetSpec { app: string, tab: string|nil }
---@alias AppTabPair { [1]: string, [2]: string }
---@type hs.hotkey.conditions
hs.hotkey.conditions = hs.hotkey.conditions or {}
local hotkeyConditions = hs.hotkey.conditions

---@type hs.hotkey.target
hs.hotkey.target = hs.hotkey.target or {}
local hotkeyTarget = hs.hotkey.target

---@class hs.hotkey.target
---@field app fun(appName: string): HotkeyTarget
---@field appTab fun(appName: string, tabPattern: string): HotkeyTarget
function hotkeyTarget.appTab(appName, tabPattern)
    return {
        kind = "appTab",
        app = appName,
        tab = tabPattern
    }
end

function hotkeyTarget.app(appName)
    return {
        kind = "app",
        app = appName,
        withTab = function(tabPattern)
            return hotkeyTarget.appTab(appName, tabPattern)
        end
    }
end

local function conditionFromTarget(target)
    if target.kind == "app" then
        return hotkeyConditions.inApps(target.app)
    end

    if target.kind == "appTab" then
        return hotkeyConditions.inAppAndTab(target.app, target.tab)
    end

    error("Unknown hotkey target kind: " .. tostring(target.kind), 3)
end

local function conditionFromOne(conditionOrTarget)
    if type(conditionOrTarget) == "function" then
        return conditionOrTarget
    end

    if type(conditionOrTarget) == "string" then
        return conditionFromTarget(hotkeyTarget.app(conditionOrTarget))
    end

    if type(conditionOrTarget) == "table" and conditionOrTarget.kind then
        return conditionFromTarget(conditionOrTarget)
    end

    if type(conditionOrTarget) == "table" and conditionOrTarget.app then
        if conditionOrTarget.tab then
            return conditionFromTarget(hotkeyTarget.appTab(conditionOrTarget.app, conditionOrTarget.tab))
        end

        return conditionFromTarget(hotkeyTarget.app(conditionOrTarget.app))
    end

    error("Expected a hotkey condition or target, got "
            .. type(conditionOrTarget)
            .. ": "
            .. tostring(conditionOrTarget), 3)
end

local function conditionFrom(...)
    local args = { ... }
    if #args == 1 and type(args[1]) == "table" and not args[1].kind and not args[1].app then
        args = args[1]
    end

    if #args == 0 then
        error("Expected at least one hotkey condition or target", 3)
    end

    if #args == 1 then
        return conditionFromOne(args[1])
    end

    local conditions = {}
    for _, conditionOrTarget in ipairs(args) do
        table.insert(conditions, conditionFromOne(conditionOrTarget))
    end

    return hotkeyConditions.anyOf(table.unpack(conditions))
end

-- Helper Function

local function listToSet (list)
    local set = {}
    for _, l in ipairs(list) do
        set[l] = true
    end
    return set
end

local function listFromVarargs(...)
    local args = { ... }
    if #args == 1 and type(args[1]) == 'table' then
        return args[1]
    end
    return args
end

local function appTabPairsFromVarargs(...)
    local args = { ... }
    if #args == 1 and type(args[1]) == 'table' then
        local first = args[1][1]
        if type(first) == 'table' then
            return args[1]
        end
        return args
    end
    return args
end

--- app condition curry functions

local function conditionInApp(set, app)
    return set[app]
end

local function conditionNotInApp(set, app)
    return not set[app]
end

local function curryCondition(condition, ...)
    local appSet = listToSet(listFromVarargs(...))
    local function curried(currentAppName)
        return condition(appSet, currentAppName)
    end
    return curried
end

--- app select options

---@class hs.hotkey.conditions
---@field allApps HotkeyCondition
function hotkeyConditions.allApps()
    return true
end

---@class hs.hotkey.conditions
---@field inApps fun(apps: table|string, ...: string): HotkeyCondition
function hotkeyConditions.inApps(...)
    return curryCondition(conditionInApp, ...)
end

---@class hs.hotkey.conditions
---@field notInApps fun(apps: table|string, ...: string): HotkeyCondition
function hotkeyConditions.notInApps(...)
    return curryCondition(conditionNotInApp, ...)
end

---@class hs.hotkey.conditions
---@field anyOf fun(condition: HotkeyCondition, ...: HotkeyCondition): HotkeyCondition
function hotkeyConditions.anyOf(...)
    local conditions = { ... }
    return function(currentAppName, currentTab)
        for _, cond in ipairs(conditions) do
            if cond(currentAppName, currentTab) then
                return true
            end
        end
        return false
    end
end

---@class hs.hotkey.conditions
---@field noneOf fun(condition: HotkeyCondition, ...: HotkeyCondition): HotkeyCondition
function hotkeyConditions.noneOf(...)
    local conditions = { ... }
    return function(currentAppName, currentTab)
        for _, cond in ipairs(conditions) do
            if cond(currentAppName, currentTab) then
                return false
            end
        end
        return true
    end
end

-- for patterns see https://www.lua.org/manual/5.1/manual.html#5.4.1
---@class hs.hotkey.conditions
---@field inAppAndTab fun(appName: string, tabPattern: string): HotkeyCondition
function hotkeyConditions.inAppAndTab(appName,tabPattern)
    local function condition(currentAppName, currentTab)
        --return currentAppName == appName and string.match(currentTab,tabPattern)
        return string.match(currentAppName, appName) and string.match(currentTab,tabPattern)
    end
    return condition
end

---@class hs.hotkey.conditions
---@field inAppsAndTabs fun(appTabPair: AppTabPair, ...: AppTabPair): HotkeyCondition
function hotkeyConditions.inAppsAndTabs(...)
    local conditions = {}
    for _, pair in ipairs(appTabPairsFromVarargs(...)) do
        local appName, tabPattern = table.unpack(pair)
        table.insert(conditions, hotkeyConditions.inAppAndTab(appName, tabPattern))
    end
    return hotkeyConditions.anyOf(table.unpack(conditions))
end

-- for patterns see https://www.lua.org/manual/5.1/manual.html#5.4.1
---@class hs.hotkey.conditions
---@field notInAppAndTab fun(appName: string, tabPattern: string): HotkeyCondition
function hotkeyConditions.notInAppAndTab(appName,tabPattern)
    local function condition(currentAppName, currentTab)
        --return not (currentAppName == appName and string.match(currentTab,tabPattern))
        return not (string.match(currentAppName, appName) and string.match(currentTab,tabPattern))
    end
    return condition
end

---@class hs.hotkey.conditions
---@field notInAppsAndTabs fun(appTabPair: AppTabPair, ...: AppTabPair): HotkeyCondition
function hotkeyConditions.notInAppsAndTabs(...)
    local conditions = {}
    for _, pair in ipairs(appTabPairsFromVarargs(...)) do
        local appName, tabPattern = table.unpack(pair)
        table.insert(conditions, hotkeyConditions.inAppAndTab(appName, tabPattern))
    end
    return hotkeyConditions.noneOf(table.unpack(conditions))
end

-- hs.hotkey.bindWhen(AppCondition, modifier, key, message, pressedfn, releasedfn, repeatfn)
-- hs.hotkey.when(AppCondition).bind(modifier, key, message, pressedfn, releasedfn, repeatfn)
-- hs.hotkey.when(AppCondition).block(modifier, key, message, debugMessage)
-- Blocked press and repeat events are passed through with hs.eventtap.keyStroke.
-- Blocked release events are ignored.

-- local conditions = hs.hotkey.conditions

-- AppCondition :=
--   conditions.allApps
--   conditions.inApps(appName, ...)
--   conditions.inApps(apps)
--   conditions.notInApps(appName, ...)
--   conditions.notInApps(apps)
--   conditions.inAppAndTab(appName, tabPattern)
--   conditions.inAppsAndTabs({appName, tabPattern}, ...)
--   conditions.inAppsAndTabs(appTabPair)
--   conditions.inAppsAndTabs(appTabPairs)
--   conditions.notInAppAndTab(appName, tabPattern)
--   conditions.notInAppsAndTabs({appName, tabPattern}, ...)
--   conditions.notInAppsAndTabs(appTabPair)
--   conditions.notInAppsAndTabs(appTabPairs)
--   conditions.anyOf(condition, ...)
--   conditions.noneOf(condition, ...)

-- `apps` := table of app names, for example {"Google Chrome", "code"}
-- `appTabPair` := {appName, tabPattern} pair, for example {"ChatGPT", "ChatGPT"}
-- `appTabPairs` := table of {appName, tabPattern} pairs

-- hs.hotkey.when(conditions.inApps("Google Chrome", "code")).bind(modifier, key, message, pressedfn)
-- hs.hotkey.when(conditions.inApps({"Google Chrome", "code"})).bind(modifier, key, message, pressedfn)

-- hs.hotkey.when(conditions.notInApps("Google Chrome")).bind(modifier, key, message, pressedfn)
-- hs.hotkey.when(conditions.notInApps("Google Chrome", "whatsapp")).bind(modifier, key, message, pressedfn)

-- hs.hotkey.when(conditions.inApps("Google Chrome", "IntelliJ IDEA")).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.notInApps("Google Chrome", "IntelliJ IDEA")).bind({"cmd"}, "n", "info", pressedfn)

-- hs.hotkey.when(conditions.inAppAndTab("MailMate", "essages%)$")).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.inAppsAndTabs({"MailMate", "essages%)$"}, {"WhatsApp", "pattern"})).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.anyOf(conditions.inAppAndTab("MailMate", "essages%)$"), conditions.inAppAndTab("WhatsApp", "pattern"))).bind({"cmd"}, "n", "info", pressedfn)

-- local appTabPair = {"ChatGPT", "ChatGPT"}
-- hs.hotkey.when(conditions.inAppsAndTabs(appTabPair)).bind({"cmd"}, "n", "info", pressedfn)

-- local appTabPairs = {{"MailMate", "essages%)$"}, {"WhatsApp", "pattern"}}
-- hs.hotkey.when(conditions.inAppsAndTabs(appTabPairs)).bind({"cmd"}, "n", "info", pressedfn)

-- hs.hotkey.when(conditions.notInAppAndTab("MailMate", "essages%)$")).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.notInAppsAndTabs({"MailMate", "essages%)$"}, {"WhatsApp", "pattern"})).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.notInAppsAndTabs(appTabPairs)).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.allApps).bind({"cmd"}, "n", nil, pressedfn)
-- hs.hotkey.when(conditions.inApps("MailMate")).block({"cmd"}, "W", "block cmd+w", "blocked cmd+w in MailMate")

---@param shouldHandleHotkey HotkeyCondition|HotkeyTarget
---@param modifier table|string
---@param key string|number
---@param message string|nil
---@param pressedfn function|nil
---@param releasedfn function|nil
---@param repeatfn function|nil
---@class hs.hotkey
---@field bindWhen fun(shouldHandleHotkey: HotkeyCondition|HotkeyTarget, modifier: table|string, key: string|number, message: string|nil, pressedfn: function|nil, releasedfn: function|nil, repeatfn: function|nil)
function hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, pressedfn, releasedfn, repeatfn)
    shouldHandleHotkey = conditionFrom(shouldHandleHotkey)

    -- in case someone forget to set the message to nil
    if type(message) == "function" then
        repeatfn = releasedfn
        releasedfn = pressedfn
        pressedfn = message
        message = nil
    end

    if not pressedfn and not releasedfn and not repeatfn then
        error("At least one of pressedfn, releasedfn or repeatfn must be a function", 2)
    end

    local hotkeyHandler

    local function shouldHandle()
        -- guard: frontmostApplication may be nil briefly
        local frontmost = hs.application.frontmostApplication()
        local currentApp = frontmost and frontmost:name() or ""
        debugInfo("currentApp = hs.application.frontmostApplication():name()")
        debugInfo("currentApp: ", currentApp)

        -- guard: focusedWindow may be nil (e.g., Desktop focus or no windows)
        local focusedWindow = hs.window.focusedWindow()
        debugInfo("focusedWindow = hs.window.focusedWindow():")
        debugInfo("focusedWindow: ", focusedWindow)

        local currentTab
        if focusedWindow and focusedWindow.title then
            currentTab = focusedWindow:title()
        else
            currentTab = ""
        end
        debugInfo("currentTab=focusedWindow:title()")
        debugInfo("currentTab: ", currentTab)

        local shouldHandle = shouldHandleHotkey(currentApp, currentTab)

        debugInfo("shouldHandle = shouldHandleHotkey(currentApp, currentTab)")
        debugInfo("shouldHandle: ", shouldHandle)

        return shouldHandle
    end

    local function passThroughKeystroke()
        hotkeyDisableSilent(hotkeyHandler)
        hs.eventtap.keyStroke(modifier, key)
        hotkeyEnableSilent(hotkeyHandler)
    end

    local function handleHotkeyEvent(callback, passThroughWhenBlocked)
        local shouldHandle = shouldHandle()

        if shouldHandle then
            --hs.alert.show("execute on: " .. currentApp)
            --logger.i("execute on: " .. currentApp)
            if callback then
                callback()
            end
        elseif passThroughWhenBlocked then
            passThroughKeystroke()
        else
            --hs.alert.show("no function at: " .. currentApp)
            --logger.i("no function at: " .. currentApp)
        end
    end

    local function optionalHandlerFor(callback, passThroughWhenBlocked)
        if not callback then
            return nil
        end

        return function()
            handleHotkeyEvent(callback, passThroughWhenBlocked)
        end
    end

    local function requiredHandlerFor(callback, passThroughWhenBlocked)
        return function()
            handleHotkeyEvent(callback, passThroughWhenBlocked)
        end
    end

    hotkeyHandler = hs.hotkey.bind(
            modifier,
            key,
            message,
            requiredHandlerFor(pressedfn, true),
            optionalHandlerFor(releasedfn, false),
            optionalHandlerFor(repeatfn, true)
    )
end

---@class hs.hotkey.whenBuilder
---@field bind fun(modifier: table|string, key: string|number, message: string|nil, pressedfn: function|nil, releasedfn: function|nil, repeatfn: function|nil)
---@field block fun(modifier: table|string, key: string|number, message: string|nil, debugMessage: string|nil)

---@param ... HotkeyCondition|HotkeyTarget|HotkeyTargetSpec|string
---@return hs.hotkey.whenBuilder
---@class hs.hotkey
---@field when fun(...: HotkeyCondition|HotkeyTarget|HotkeyTargetSpec|string): hs.hotkey.whenBuilder
function hs.hotkey.when(...)
    local shouldHandleHotkey = conditionFrom(...)

    return {
        bind = function(modifier, key, message, pressedfn, releasedfn, repeatfn)
            hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, pressedfn, releasedfn, repeatfn)
        end,
        block = function(modifier, key, message, debugMessage)
            hs.hotkey.blockWhen(shouldHandleHotkey, modifier, key, message, debugMessage)
        end
    }
end

---@param shouldHandleHotkey HotkeyCondition|HotkeyTarget
---@param modifier table|string
---@param key string|number
---@param message string|nil
---@param debugMessage string|nil
---@class hs.hotkey
---@field blockWhen fun(shouldHandleHotkey: HotkeyCondition|HotkeyTarget, modifier: table|string, key: string|number, message: string|nil, debugMessage: string|nil)
function hs.hotkey.blockWhen(shouldHandleHotkey, modifier, key, message, debugMessage)
    local noop = function()
        if debugMessage then
            debugInfo(debugMessage)
        end
    end

    hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, noop)
end
