-- https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys

-- https://stackoverflow.com/questions/63795560/how-can-i-prevent-hammerspoon-hotkeys-from-overriding-hotkeys-in-other-applicati

local logger = hs.logger.new("HotkeyBindWhen")
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

local function toTable(st)
    return type(st) == 'table' and st or { st }
end

local function normalizeArgs(st)
    if isTable(st) and isTable(st[1]) then
        return st[1]
    else
        return st
    end
end

--- app condition curry functions

local function conditionTo(set, app)
    return set[app]
end

local function conditionExclude(set, app)
    return not set[app]
end

local function curryCondition(condition, ...)
    local appSet = listToSet({ ... })
    local function curried(name)
        return condition(appSet, name)
    end
    return curried
end

--- app select options

function hotkeyConditions.allApps()
    return true
end

function hotkeyConditions.inApps(...)
    return curryCondition(conditionTo, ...)
end

function hotkeyConditions.notInApps(...)
    return curryCondition(conditionExclude, ...)
end

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
function hotkeyConditions.inAppAndTab(appName,tabPattern)
    local function condition(currentAppName, currentTab)
        --return currentAppName == appName and string.match(currentTab,tabPattern)
        return string.match(currentAppName, appName) and string.match(currentTab,tabPattern)
    end
    return condition
end

function hotkeyConditions.inAppsAndTabs(...)
    local conditions = {}
    for _, pair in ipairs({...}) do
        local appName, tabPattern = table.unpack(pair)
        table.insert(conditions, hotkeyConditions.inAppAndTab(appName, tabPattern))
    end
    return hotkeyConditions.anyOf(table.unpack(conditions))
end

-- for patterns see https://www.lua.org/manual/5.1/manual.html#5.4.1
function hotkeyConditions.notInAppAndTab(appName,tabPattern)
    local function condition(currentAppName, currentTab)
        --return not (currentAppName == appName and string.match(currentTab,tabPattern))
        return not (string.match(currentAppName, appName) and string.match(currentTab,tabPattern))
    end
    return condition
end

function hotkeyConditions.notInAppsAndTabs(...)
    local conditions = {}
    for _, pair in ipairs({...}) do
        local appName, tabPattern = table.unpack(pair)
        table.insert(conditions, hotkeyConditions.notInAppAndTab(appName, tabPattern))
    end
    return hotkeyConditions.noneOf(table.unpack(conditions))
end

-- hs.hotkey.bindWhen(AppCondition, modifier, key, function)

-- AppCondition := hotkeyConditions.inApps(apps) | hotkeyConditions.notInApps(apps)

-- `apps` := can be a list of parameters or a table

-- hs.hotkey.bindWhen(hotkeyConditions.inApps("Google Chrome","code"), modifier, key, message, function)
-- hs.hotkey.bindWhen(hotkeyConditions.inApps({"Google Chrome","code"}), modifier, key, message, function)

-- hs.hotkey.bindWhen(hotkeyConditions.notInApps("Google Chrome"), modifier, key, message, function)
-- hs.hotkey.bindWhen(hotkeyConditions.notInApps("Google Chrome","whatsapp"), modifier, key, message, function)

-- hs.hotkey.bindWhen(hotkeyConditions.inApps("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", "info", myFunction)
-- hs.hotkey.bindWhen(hotkeyConditions.notInApps("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", "info", myFunction)

-- hs.hotkey.bindWhen(hotkeyConditions.inAppAndTab("MailMate","essages%)$"), {"cmd"}, "n", "info", myFunction)
-- hs.hotkey.bindWhen(hotkeyConditions.inAppsAndTabs({"MailMate", "essages%)$"}, {"WhatsApp", "pattern"}), {"cmd"}, "n", "info", myFunction)
-- hs.hotkey.bindWhen(hotkeyConditions.anyOf(hotkeyConditions.inAppAndTab("MailMate", "essages%)$"), hotkeyConditions.inAppAndTab("WhatsApp", "pattern")), {"cmd"}, "n", "info", myFunction)

-- hs.hotkey.bindWhen(hotkeyConditions.notInAppAndTab("MailMate","essages%)$"), {"cmd"}, "n", "info", myFunction)
-- hs.hotkey.bindWhen(hotkeyConditions.notInAppsAndTabs({"MailMate","essages%)$"},{"WhatsApp", "pattern"}), {"cmd"}, "n", "info", myFunction)
-- hs.hotkey.bindWhen(hotkeyConditions.noneOf(hotkeyConditions.notInAppAndTab("MailMate","essages%)$",hotkeyConditions.notInAppAndTab("WhatsApp", "pattern")), {"cmd"}, "n", "info", myFunction)

-- local apps = {"Google Chrome","IntelliJ IDEA"}
-- hs.hotkey.bindWhen(hotkeyConditions.inApps(apps), {"cmd"}, "n", nil, myFunction)

-- AllApps:
--   hs.hotkey.bindWhen(hotkeyConditions.allApps, {"cmd"}, "n", nil, myFunction)

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

function hs.hotkey.when(shouldHandleHotkey)
    return {
        bind = function(modifier, key, message, callback)
            hs.hotkey.bindWhen(shouldHandleHotkey, modifier, key, message, callback)
        end
    }
end


-- Bind Hotkey only to one app

function bindHotkeyOnlyTo(appname, modifier, key, message, callback)
    hs.hotkey.bindWhen(hotkeyConditions.inApps(appname), modifier, key, message, callback)
end
