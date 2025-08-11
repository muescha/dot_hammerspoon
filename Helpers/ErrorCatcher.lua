------------------------------------------------------------
-- 🚨 Global Error Catcher for Hammerspoon (with Help of ChatGPT) 🚨
-- This script catches runtime errors in Hammerspoon and displays them in a user-friendly way.
------------------------------------------------------------
----- Created by muescha.
----- DateTime: 03.08.25
------------------------------------------------------------

fileInfo()

-- Keep original traceback for later use
debug._traceback = debug._traceback or debug.traceback

-- Config (adjust cooldownSeconds later to 180 for 3 minutes)
local longDurationSec = 5.0       -- long alert for first/after-cooldown occurrences
local repeatDurationSec = 2.0    -- short alert for repeated occurrences during cooldown
local cooldownSeconds = 30       -- show long alert again after this cooldown

-- Store per-message state
-- map: message(string) -> { lastShownAt = seconds, count = number }
local shownErrorMessages = {}

local nowFn = hs and hs.timer and hs.timer.secondsSinceEpoch or os.time

-- Our replacement traceback to show console & alert with dedup and cooldown
debug.traceback = function(message, level)
    local msg = tostring(message or "unknown error")

    local trace = debug._traceback(message, (level or 1) + 1)
    local fullMsg = "\n\n💥 Hammerspoon Error 💥\n\nMessage:\n" ..
            msg .. "\n\nTrace:\n" ..
            trace .. "\n\n" ..
            "Please check the Hammerspoon console for more details.\n\n"

    print(fullMsg)

    local now = (hs and hs.timer and hs.timer.secondsSinceEpoch) and hs.timer.secondsSinceEpoch() or os.time()
    local rec = shownErrorMessages and shownErrorMessages[msg] or nil
    local showLong = false

    if not shownErrorMessages then shownErrorMessages = {} end

    if not rec then
        rec = { lastShownAt = 0, count = 0 }
        shownErrorMessages[msg] = rec
        showLong = true
    else
        showLong = (now - (tonumber(rec.lastShownAt) or 0)) >= (cooldownSeconds or 30)
    end

    rec.count = (rec.count or 0) + 1

    pcall(function()
        if showLong then
            -- First time or after cooldown: long alert + open console
            hs.alert.show(fullMsg, longDurationSec)
            hs.openConsole()
        else
            local last = tonumber(rec.lastShownAt) or 0
            local elapsedSec = math.max(0, math.floor(now - last))
            hs.alert.show("Repeated error (" .. tostring(rec.count) .. " - last " .. tostring(elapsedSec) .. "s ago): \n\n" .. msg, repeatDurationSec)
        end
        rec.lastShownAt = now
    end)

    return fullMsg
end

-- Hook into every Lua function call so runtime errors trigger traceback
debug.sethook(function()
    -- No-op; ensures traceback override works without doing additional work here
end, "c")

------------------------------------------------------------
-- Utility: reset de-duplication/cooldown (optional, e.g., via hotkey while debugging)
------------------------------------------------------------
function resetErrorCatcherShown()
    shownErrorMessages = {}
end

------------------------------------------------------------
-- End of error catcher header
------------------------------------------------------------
