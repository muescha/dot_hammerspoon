-- https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys

-- https://stackoverflow.com/questions/63795560/how-can-i-prevent-hammerspoon-hotkeys-from-overriding-hotkeys-in-other-applicati

local logger = hs.logger.new("SendKeysOnlyInApp")

-- Helper Function

local function Set (list)
    local set = {}
    for _, l in ipairs(list) do
        set[l] = true
    end
    return set
end

local function isTable(t)
    return type(t) == 'table'
end

local function toTable(st)
    return isTable(st) and st or { st }
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
    local appSet = Set(normalizeArgs({ ... }))
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

-- bindHotkey(AppCondition, modifier, key, function)

-- AppCondition := to(apps) | exclude(apps)

-- `apps` := can be a list of parameters or a table

-- bindHotkey(to("Google Chrome","code"), modifier, key, function)
-- bindHotkey(to({"Google Chrome","code"}), modifier, key, function)

-- bindHotkey(exclude("Google Chrome"), modifier, key, function)
-- bindHotkey(exclude("Google Chrome","whatsapp"), modifier, key, function)

-- bindHotkey(to("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, myFunction)
-- bindHotkey(exclude("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, myFunction)

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
        if runWithAppCondition(currentApp) then
            --hs.alert.show("execute on: " .. currentApp)
            --logger.i("execute on: " .. currentApp)
            callback()
        else
            --hs.alert.show("no function at: " .. currentApp)
            --logger.i("no function at: " .. currentApp)
            hotkeyHandler:disable()
            hs.eventtap.keyStroke(modifier, key)
            hotkeyHandler:enable()
        end
    end)
end


-- Bind Hotkey only to one app

function bindHotkeyOnlyTo(appname, modifier, key, message, callback, ...)
    local hotkeyHandler
    hotkeyHandler = hs.hotkey.bind(modifier, key, message, function()

        local currentApp = hs.application.frontmostApplication():name()

        if (appname == currentApp) then
            callback()
        else
            hotkeyHandler:disable()
            hs.eventtap.keyStroke(modifier, key)
            hotkeyHandler:enable()
        end
    end)
end
