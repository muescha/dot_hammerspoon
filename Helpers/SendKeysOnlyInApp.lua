-- https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys

-- https://stackoverflow.com/questions/63795560/how-can-i-prevent-hammerspoon-hotkeys-from-overriding-hotkeys-in-other-applicati

local logger = hs.logger.new("SendKeysOnlyInApp")

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

function allApps()
    return true
end

function to(...)
    return curryCondition(conditionTo, ...)
end

function exclude(...)
    return curryCondition(conditionExclude, ...)
end

function any(...)
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

function none(...)
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
function toAppAndTab(appName,tabPattern)
    local function condition(currentAppName, currentTab)
        --return currentAppName == appName and string.match(currentTab,tabPattern)
        return string.match(currentAppName, appName) and string.match(currentTab,tabPattern)
    end
    return condition
end

function toAppsAndTabs(...)
    local conditions = {}
    for _, pair in ipairs({...}) do
        local appName, tabPattern = table.unpack(pair)
        table.insert(conditions, toAppAndTab(appName, tabPattern))
    end
    return any(table.unpack(conditions))
end

-- for patterns see https://www.lua.org/manual/5.1/manual.html#5.4.1
function excludeAppAndTab(appName,tabPattern)
    local function condition(currentAppName, currentTab)
        --return not (currentAppName == appName and string.match(currentTab,tabPattern))
        return not (string.match(currentAppName, appName) and string.match(currentTab,tabPattern))
    end
    return condition
end

function excludeAppsAndTabs(...)
    local conditions = {}
    for _, pair in ipairs({...}) do
        local appName, tabPattern = table.unpack(pair)
        table.insert(conditions, excludeAppAndTab(appName, tabPattern))
    end
    return none(table.unpack(conditions))
end

-- bindHotkey(AppCondition, modifier, key, function)

-- AppCondition := to(apps) | exclude(apps)

-- `apps` := can be a list of parameters or a table

-- bindHotkey(to("Google Chrome","code"), modifier, key, message, function)
-- bindHotkey(to({"Google Chrome","code"}), modifier, key, message, function)

-- bindHotkey(exclude("Google Chrome"), modifier, key, message, function)
-- bindHotkey(exclude("Google Chrome","whatsapp"), modifier, key, message, function)

-- bindHotkey(to("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", "info", myFunction)
-- bindHotkey(exclude("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", "info", myFunction)

-- bindHotkey(toAppAndTab("MailMate","essages%)$"), {"cmd"}, "n", "info", myFunction)
-- bindHotkey(toAppsAndTabs({"MailMate", "essages%)$"}, {"WhatsApp", "pattern"}), {"cmd"}, "n", "info", myFunction)
-- bindHotkey(any(toAppAndTab("MailMate", "essages%)$"), toAppAndTab("WhatsApp", "pattern")), {"cmd"}, "n", "info", myFunction)

-- bindHotkey(excludeAppAndTab("MailMate","essages%)$"), {"cmd"}, "n", "info", myFunction)
-- bindHotkey(excludeAppsAndTabs({"MailMate","essages%)$"},{"WhatsApp", "pattern"}), {"cmd"}, "n", "info", myFunction)
-- bindHotkey(none(excludeAppAndTab("MailMate","essages%)$",excludeAppAndTab("WhatsApp", "pattern")), {"cmd"}, "n", "info", myFunction)

-- local apps = {"Google Chrome","IntelliJ IDEA"}
-- bindHotkey(to(apps), {"cmd"}, "n", nil, myFunction)

-- AllApps:
--   bindHotkey(allApps, {"cmd"}, "n", nil, myFunction)

function bindHotkey(runWithAppCondition, modifier, key, message, callback)

    -- in case someone forget to set the message to nil
    if not callback then
        callback = message
        message = nil
    end
    local hotkeyHandler
    hotkeyHandler = hs.hotkey.bind(modifier, key, message, function()
        local currentApp = hs.application.frontmostApplication():name()
        local currentTab = hs.window.focusedWindow():title()
        if runWithAppCondition(currentApp, currentTab) then
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


-- Bind Hotkey only to one app

function bindHotkeyOnlyTo(appname, modifier, key, message, callback)

    -- in case someone forget to set the message to nil
    if not callback then
        callback = message
        message = nil
    end

    local hotkeyHandler
    hotkeyHandler = hs.hotkey.bind(modifier, key, message, function()

        local currentApp = hs.application.frontmostApplication():name()

        if (appname == currentApp) then
            callback()
        else
            hotkeyDisableSilent(hotkeyHandler)
            hs.eventtap.keyStroke(modifier, key)
            hotkeyEnableSilent(hotkeyHandler)
        end
    end)
end
