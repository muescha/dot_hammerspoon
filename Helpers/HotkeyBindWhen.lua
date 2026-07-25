-- https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys

-- https://stackoverflow.com/questions/63795560/how-can-i-prevent-hammerspoon-hotkeys-from-overriding-hotkeys-in-other-applicati

local logger = hs.logger.new("HotkeyBindWhen")

---@class hs.hotkey.conditions

---@class hs.hotkey
---@field conditions hs.hotkey.conditions

---@alias HotkeyCondition fun(currentAppName: string, currentTab: string): boolean
---@alias AppTabPair { [1]: string, [2]: string }
---@type hs.hotkey.conditions
hs.hotkey.conditions = hs.hotkey.conditions or {}
local hotkeyConditions = hs.hotkey.conditions

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
    for _, pair in ipairs(listFromVarargs(...)) do
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
    for _, pair in ipairs(listFromVarargs(...)) do
        local appName, tabPattern = table.unpack(pair)
        table.insert(conditions, hotkeyConditions.inAppAndTab(appName, tabPattern))
    end
    return hotkeyConditions.noneOf(table.unpack(conditions))
end

-- hs.hotkey.bindWhen(AppCondition, modifier, key, message, function)
-- hs.hotkey.when(AppCondition).bind(modifier, key, message, function)
-- hs.hotkey.when(AppCondition).block(modifier, key, message, debugMessage)

-- local conditions = hs.hotkey.conditions

-- AppCondition :=
--   conditions.allApps
--   conditions.inApps(appName, ...)
--   conditions.inApps(apps)
--   conditions.notInApps(appName, ...)
--   conditions.notInApps(apps)
--   conditions.inAppAndTab(appName, tabPattern)
--   conditions.inAppsAndTabs({appName, tabPattern}, ...)
--   conditions.inAppsAndTabs(appTabPairs)
--   conditions.notInAppAndTab(appName, tabPattern)
--   conditions.notInAppsAndTabs({appName, tabPattern}, ...)
--   conditions.notInAppsAndTabs(appTabPairs)
--   conditions.anyOf(condition, ...)
--   conditions.noneOf(condition, ...)

-- `apps` := table of app names, for example {"Google Chrome", "code"}
-- `appTabPairs` := table of {appName, tabPattern} pairs

-- hs.hotkey.when(conditions.inApps("Google Chrome", "code")).bind(modifier, key, message, myFunction)
-- hs.hotkey.when(conditions.inApps({"Google Chrome", "code"})).bind(modifier, key, message, myFunction)

-- hs.hotkey.when(conditions.notInApps("Google Chrome")).bind(modifier, key, message, myFunction)
-- hs.hotkey.when(conditions.notInApps("Google Chrome", "whatsapp")).bind(modifier, key, message, myFunction)

-- hs.hotkey.when(conditions.inApps("Google Chrome", "IntelliJ IDEA")).bind({"cmd"}, "n", "info", myFunction)
-- hs.hotkey.when(conditions.notInApps("Google Chrome", "IntelliJ IDEA")).bind({"cmd"}, "n", "info", myFunction)

-- hs.hotkey.when(conditions.inAppAndTab("MailMate", "essages%)$")).bind({"cmd"}, "n", "info", myFunction)
-- hs.hotkey.when(conditions.inAppsAndTabs({"MailMate", "essages%)$"}, {"WhatsApp", "pattern"})).bind({"cmd"}, "n", "info", myFunction)
-- hs.hotkey.when(conditions.anyOf(conditions.inAppAndTab("MailMate", "essages%)$"), conditions.inAppAndTab("WhatsApp", "pattern"))).bind({"cmd"}, "n", "info", myFunction)

-- local appTabPairs = {{"MailMate", "essages%)$"}, {"WhatsApp", "pattern"}}
-- hs.hotkey.when(conditions.inAppsAndTabs(appTabPairs)).bind({"cmd"}, "n", "info", myFunction)

-- hs.hotkey.when(conditions.notInAppAndTab("MailMate", "essages%)$")).bind({"cmd"}, "n", "info", myFunction)
-- hs.hotkey.when(conditions.notInAppsAndTabs({"MailMate", "essages%)$"}, {"WhatsApp", "pattern"})).bind({"cmd"}, "n", "info", myFunction)
-- hs.hotkey.when(conditions.notInAppsAndTabs(appTabPairs)).bind({"cmd"}, "n", "info", myFunction)
-- hs.hotkey.when(conditions.allApps).bind({"cmd"}, "n", nil, myFunction)
-- hs.hotkey.when(conditions.inApps("MailMate")).block({"cmd"}, "W", "block cmd+w", "blocked cmd+w in MailMate")

---@param shouldHandleHotkey HotkeyCondition
---@param modifier table|string
---@param key string|number
---@param message string|nil
---@param callback function
---@class hs.hotkey
---@field bindWhen fun(shouldHandleHotkey: HotkeyCondition, modifier: table|string, key: string|number, message: string|nil, callback: function)
function hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, callback)

    -- in case someone forget to set the message to nil
    if not callback then
        callback = message
        message = nil
    end
    local hotkeyHandler
    hotkeyHandler = hs.hotkey.bind(modifier, key, message, function()
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

        if shouldHandle then
            --hs.alert.show("execute on: " .. currentApp)
            --logger.i("execute on: " .. currentApp)
            callback()
        else
            --hs.alert.show("no function at: " .. currentApp)
            --logger.i("no function at: " .. currentApp)
            hotkeyDisableSilent(hotkeyHandler)
            hs.eventtap.keyStroke(modifier, key)
            hotkeyEnableSilent(hotkeyHandler)
        end
    end)
end

---@class hs.hotkey.whenBuilder
---@field bind fun(modifier: table|string, key: string|number, message: string|nil, callback: function)
---@field block fun(modifier: table|string, key: string|number, message: string|nil, debugMessage: string|nil)

---@param shouldHandleHotkey HotkeyCondition
---@return hs.hotkey.whenBuilder
---@class hs.hotkey
---@field when fun(shouldHandleHotkey: HotkeyCondition): hs.hotkey.whenBuilder
function hs.hotkey.when(shouldHandleHotkey)
    return {
        bind = function(modifier, key, message, callback)
            hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, callback)
        end,
        block = function(modifier, key, message, debugMessage)
            hs.hotkey.blockWhen(shouldHandleHotkey, modifier, key, message, debugMessage)
        end
    }
end

---@param shouldHandleHotkey HotkeyCondition
---@param modifier table|string
---@param key string|number
---@param message string|nil
---@param debugMessage string|nil
---@class hs.hotkey
---@field blockWhen fun(shouldHandleHotkey: HotkeyCondition, modifier: table|string, key: string|number, message: string|nil, debugMessage: string|nil)
function hs.hotkey.blockWhen(shouldHandleHotkey, modifier, key, message, debugMessage)
    local noop = function()
        if debugMessage then
            debugInfo(debugMessage)
        end
    end

    hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, noop)
end
