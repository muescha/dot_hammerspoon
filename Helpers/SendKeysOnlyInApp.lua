-- https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys

-- https://stackoverflow.com/questions/63795560/how-can-i-prevent-hammerspoon-hotkeys-from-overriding-hotkeys-in-other-applicati

local logger = hs.logger.new("SendKeysOnlyInApp")

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

--- app select pure functions

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

function allTypes()
    return true
end

function to(...)
    return curryCondition(conditionTo, ...)
end

function exclude(...)
    return curryCondition(conditionExclude, ...)
end



--function hs_hotkey_bind_exclude(excludeApp, ...)
--    local appName = hs.application.frontmostApplication():name()
--end

-- bindHotkey(to, "google chrome", modifier, key, function)
-- bindHotkey(only, "google chrome", modifier, key, function)
-- bindHotkey(notTo, "google chrome", modifier, key, function)
-- bindHotkey(exclude, "google chrome", modifier, key, function)

-- bindHotkey(to("google chrome"), modifier, key, function)

-- bindHotkey(modifier, key, function)
-- bindHotkey(to("chrome","code"), modifier, key, function)
-- bindHotkey(to({"chrome","code"}), modifier, key, function)
-- bindHotkey(exclude("google chrome"), modifier, key, function)
-- bindHotkey(exclude("chrome","whatsapp"), modifier, key, function)


-- runWithAppCondition = to | exclude

-- bindHotkey(to("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, function()
-- bindHotkey(exclude("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, function()
-- local apps = {"Google Chrome","IntelliJ IDEA"}
-- bindHotkey(to(apps), {"cmd"}, "n", nil, function()
-- bindHotkey(all, {"cmd"}, "n", nil, function()

function bindHotkey(runWithAppCondition, modifier, key, message, callback)

    -- in case someone forget to set the message to nil
    if not callback then
        callback = message
        message = nil
    end

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

--bindHotkey(to,"Google Chrome", {"cmd"}, "n", nil, function()
--bindHotkey(exclude,"IntelliJ IDEA", {"cmd"}, "n", nil, function()

-- selectAppCondition = conditionTo | conditionExclude
function bindHotkeyOld(selectAppCondition, apps, modifier, key, message, callback, ...)
    hotkeyHandler = hs.hotkey.bind(modifier, key, message, function()

        local currentApp = hs.application.frontmostApplication():name()
        local appSet = Set(toTable(apps))

        if selectAppCondition(appSet, currentApp) then
            callback()
        else
            hotkeyHandler:disable()
            hs.eventtap.keyStroke(modifier, key)
            hotkeyHandler:enable()
        end
    end)
end
