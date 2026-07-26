-- https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys

-- https://stackoverflow.com/questions/63795560/how-can-i-prevent-hammerspoon-hotkeys-from-overriding-hotkeys-in-other-applicati

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
---@alias HotkeyTargetInput HotkeyCondition|HotkeyTarget|HotkeyTargetSpec|string
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
        return function(currentAppName)
            return string.match(currentAppName, target.app) ~= nil
        end
    end

    if target.kind == "appTab" then
        return function(currentAppName, currentTab)
            return string.match(currentAppName, target.app) ~= nil
                    and string.match(currentTab, target.tab) ~= nil
        end
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

local function conditionsFrom(...)
    local args = { ... }
    if #args == 1 and type(args[1]) == "table" and not args[1].kind and not args[1].app then
        args = args[1]
    end

    if #args == 0 then
        error("Expected at least one hotkey condition or target", 3)
    end

    local conditions = {}
    for _, conditionOrTarget in ipairs(args) do
        table.insert(conditions, conditionFromOne(conditionOrTarget))
    end

    return conditions
end

local function conditionFrom(...)
    local conditions = conditionsFrom(...)

    if #conditions == 1 then
        return conditions[1]
    end

    return hotkeyConditions.anyOf(table.unpack(conditions))
end

--- condition combinators

---@class hs.hotkey.conditions
---@field allApps HotkeyCondition
function hotkeyConditions.allApps()
    return true
end

---@class hs.hotkey.conditions
---@field anyOf fun(conditionOrTarget: HotkeyTargetInput, ...: HotkeyTargetInput): HotkeyCondition
function hotkeyConditions.anyOf(...)
    local conditions = conditionsFrom(...)
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
---@field noneOf fun(conditionOrTarget: HotkeyTargetInput, ...: HotkeyTargetInput): HotkeyCondition
function hotkeyConditions.noneOf(...)
    local conditions = conditionsFrom(...)
    return function(currentAppName, currentTab)
        for _, cond in ipairs(conditions) do
            if cond(currentAppName, currentTab) then
                return false
            end
        end
        return true
    end
end

-- hs.hotkey.bindWhen(HotkeyTargetInput, modifier, key, message, pressedfn, releasedfn, repeatfn)
-- hs.hotkey.when(HotkeyTargetInput, ...).bind(modifier, key, message, pressedfn, releasedfn, repeatfn)
-- hs.hotkey.when(HotkeyTargetInput, ...).block(modifier, key, message, debugMessage)
-- hs.hotkey.whenNot(HotkeyTargetInput, ...).bind(modifier, key, message, pressedfn, releasedfn, repeatfn)
-- hs.hotkey.whenNot(HotkeyTargetInput, ...).block(modifier, key, message, debugMessage)
-- Blocked press and repeat events are passed through with hs.eventtap.keyStroke.
-- Blocked release events are ignored.

-- local at = hs.hotkey.target
-- local conditions = hs.hotkey.conditions

-- HotkeyTargetInput :=
--   appName
--   { app = appName }
--   { app = appName, tab = tabPattern }
--   at.app(appName)
--   at.app(appName).withTab(tabPattern)
--   at.appTab(appName, tabPattern)
--   condition
--   { targetOrCondition, ... }

-- Condition combinators:
--   conditions.allApps
--   conditions.anyOf(targetOrCondition, ...)
--   conditions.noneOf(targetOrCondition, ...)

-- `appName` := app name pattern, for example "Google Chrome"
-- `tabPattern` := focused window title pattern, for example "essages%)$"
-- `targetOrCondition` := HotkeyTargetInput except nested lists

-- hs.hotkey.when("Google Chrome", "IntelliJ IDEA").bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when({ "Google Chrome", "IntelliJ IDEA" }).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when({ app = "MailMate", tab = "essages%)$" }).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(at.app("MailMate").withTab("essages%)$"), at.app("WhatsApp").withTab("WhatsApp")).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.anyOf("Google Chrome", "IntelliJ IDEA")).bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.whenNot("Google Chrome").bind({"cmd"}, "n", "info", pressedfn)
-- hs.hotkey.when(conditions.allApps).bind({"cmd"}, "n", nil, pressedfn)
-- hs.hotkey.when("MailMate").block({"cmd"}, "W", "block cmd+w", "blocked cmd+w in MailMate")

---@param shouldHandleHotkey HotkeyTargetInput
---@param modifier table|string
---@param key string|number
---@param message string|nil
---@param pressedfn function|nil
---@param releasedfn function|nil
---@param repeatfn function|nil
---@class hs.hotkey
---@field bindWhen fun(shouldHandleHotkey: HotkeyTargetInput, modifier: table|string, key: string|number, message: string|nil, pressedfn: function|nil, releasedfn: function|nil, repeatfn: function|nil)
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

    local function shouldHandleCurrentContext()
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

        local shouldHandleCurrentHotkey = shouldHandleHotkey(currentApp, currentTab)

        debugInfo("shouldHandleCurrentHotkey = shouldHandleHotkey(currentApp, currentTab)")
        debugInfo("shouldHandleCurrentHotkey: ", shouldHandleCurrentHotkey)

        return shouldHandleCurrentHotkey
    end

    local function passThroughKeystroke()
        hotkeyDisableSilent(hotkeyHandler)
        hs.eventtap.keyStroke(modifier, key)
        hotkeyEnableSilent(hotkeyHandler)
    end

    local function handleHotkeyEvent(callback, passThroughWhenBlocked)
        local shouldHandleCurrentHotkey = shouldHandleCurrentContext()

        if shouldHandleCurrentHotkey then
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

---@param ... HotkeyTargetInput
---@return hs.hotkey.whenBuilder
---@class hs.hotkey
---@field when fun(...: HotkeyTargetInput): hs.hotkey.whenBuilder
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

---@param ... HotkeyTargetInput
---@return hs.hotkey.whenBuilder
---@class hs.hotkey
---@field whenNot fun(...: HotkeyTargetInput): hs.hotkey.whenBuilder
function hs.hotkey.whenNot(...)
    return hs.hotkey.when(hotkeyConditions.noneOf(...))
end

---@param shouldHandleHotkey HotkeyTargetInput
---@param modifier table|string
---@param key string|number
---@param message string|nil
---@param debugMessage string|nil
---@class hs.hotkey
---@field blockWhen fun(shouldHandleHotkey: HotkeyTargetInput, modifier: table|string, key: string|number, message: string|nil, debugMessage: string|nil)
function hs.hotkey.blockWhen(shouldHandleHotkey, modifier, key, message, debugMessage)
    local noop = function()
        if debugMessage then
            debugInfo(debugMessage)
        end
    end

    hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, noop)
end
