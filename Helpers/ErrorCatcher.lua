-- lua
-- 🚨 Global Error Catcher for Hammerspoon (with Help of ChatGPT) 🚨
-- This script catches runtime errors in Hammerspoon and displays them in a user-friendly way.
------------------------------------------------------------
----- Created by muescha.
----- DateTime: 03.08.25
------------------------------------------------------------

fileInfo()

-- Keep original traceback for later use
debug._traceback = debug._traceback or debug.traceback

local longDurationSec = 5.0       -- long alert for first/after-cooldown occurrences
local repeatDurationSec = 2.0    -- short alert for repeated occurrences during cooldown
local cooldownSeconds = 30       -- show long alert again after this cooldown

-- Store per-message state
-- map: message(string) -> { lastShownAt = seconds, count = number, lastMessage = string }
local errorHistory = {}

-- Our replacement traceback to show console & alert with dedup and cooldown
debug.traceback = function(errorMessage, level)
    local msg = tostring(errorMessage or "unknown error")

    local msgHeader  = "\n\n💥 Hammerspoon Error 💥"
    local msgBody    = "Error:\n" .. msg
    local msgStackTrace = "Trace:\n" .. debug._traceback(errorMessage, (level or 1) + 1)
    local msgFooter  = "Please check the Hammerspoon console for more details.\nSee `printErrorHistory()` and `resetErrorHistory()`\n"

    local message = table.concat({ msgHeader, msgBody, msgStackTrace, msgFooter, }, "\n\n")

    print(message)

    local now = hs.timer.secondsSinceEpoch()
    local lastError = errorHistory and errorHistory[msg] or nil
    local showLong = false

    if not errorHistory then errorHistory = {} end

    if not lastError then
        lastError = { lastShownAt = 0, count = 0, lastMessage = nil }
        errorHistory[msg] = lastError
        showLong = true
    else
        showLong = (now - (tonumber(lastError.lastShownAt) or 0)) >= (cooldownSeconds or 30)
    end

    lastError.count = (lastError.count or 0) + 1
    lastError.lastMessage = message

    pcall(function()
        if showLong then
            hs.alert.show(message, longDurationSec)
            hs.openConsole()
        else
            local last = tonumber(lastError.lastShownAt) or 0
            local elapsedSec = math.max(0, math.floor(now - last))
            hs.alert.show("Repeated error (" .. tostring(lastError.count) .. " - last " .. tostring(elapsedSec) .. "s ago): \n\n" .. msg, repeatDurationSec)
        end
        lastError.lastShownAt = now
    end)

    return msgBody
end

-- Hook into every Lua function call so runtime errors trigger traceback
debug.sethook(function()
    -- No-op; ensures traceback override works without doing additional work here
end, "c")

------------------------------------------------------------
-- Utility: print error history to console
------------------------------------------------------------

local function sortErrorHistory()
    local errorHistorySorted = {}
    for key, value in pairs(errorHistory) do
        value.error = key
        table.insert(errorHistorySorted, value )
    end
    table.sort(errorHistorySorted, function(a, b)
        return (tonumber(a.lastShownAt) or 0) > (tonumber(b.lastShownAt) or 0)
    end)
    return errorHistorySorted
end

function printErrorHistory()
    local function fmtDate(ts)
        ts = tonumber(ts) or 0
        return os.date("%Y-%m-%d %H:%M:%S", math.floor(ts))
    end

    if not errorHistory or next(errorHistory) == nil then
        print("\n===== ErrorCatcher History =====")
        print("No stored errors.")
        hs.openConsole()
        return
    end

    local errorHistorySorted = sortErrorHistory()

    print("\n===== ErrorCatcher History • " .. tostring(#errorHistorySorted) .. " unique error(s) =====")
    for index, error in ipairs(errorHistorySorted) do
        local last = tonumber(error.lastShownAt) or 0
        local lastDate = fmtDate(last)
        local count = tostring(error.count or 0)
        local now = hs.timer.secondsSinceEpoch()
        local ago = tostring(math.max(0, math.floor(now - last)))
        local info = string.format("[%d] • %sx • last: %s (%ss ago)", index, count, lastDate, ago )
        print(info)
        print(error.lastMessage)
        print("----------------------------------------")
    end

    hs.openConsole()
end

------------------------------------------------------------
-- Utility: reset de-duplication/cooldown (optional, e.g., via hotkey while debugging)
------------------------------------------------------------
function resetErrorHistory()
    errorHistory = {}
end
