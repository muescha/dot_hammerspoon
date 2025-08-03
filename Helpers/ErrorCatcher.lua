------------------------------------------------------------
-- 🚨 Global Error Catcher for Hammerspoon (with Help of ChatGPT) 🚨
-- This script catches runtime errors in Hammerspoon and displays them in a user-friendly way.
------------------------------------------------------------
----- Created by muescha.
----- DateTime: 03.08.25
------------------------------------------------------------

-- Keep original traceback for later use
debug._traceback = debug._traceback or debug.traceback

-- Our replacement traceback to show console & alert
debug.traceback = function(message, level)
    -- Build full error message
    local trace = debug._traceback(message, (level or 1) + 1)
    local fullMsg = "\n\n💥 Hammerspoon Error 💥\n\nMessage:\n" ..
            tostring(message) .. "\n\nTrace:\n" ..
            trace .. "\n\n" ..
            "Please check the Hammerspoon console for more details.\n\n"

    -- Log in console
    print(fullMsg)

    -- Show short on‑screen alert
    --hs.alert.show("💥 Hammerspoon Error!\n" .. tostring(message), 3)
    hs.alert.show(fullMsg, 15)

    -- Bring up console
    hs.openConsole()

    return fullMsg
end

-- Hook into every Lua function call so runtime errors trigger traceback
debug.sethook(function()
    -- This hook doesn't do the printing, it just ensures traceback override works
    -- You can also trigger hs.openConsole() here if you want for *every* call
end, "c")

------------------------------------------------------------
-- End of error catcher header
------------------------------------------------------------
