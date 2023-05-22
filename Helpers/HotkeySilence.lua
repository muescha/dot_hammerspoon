---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 22.05.23 15:04
---

--- Usage:
---     hotkeySilence(
---         function()
---             doSomething()
---         end
---     )
---
--- for example:
---     hotkeySilence(function()  hotkeyHandler:disable() end)

function hotkeySilence(fn)
    local previousLogLevel = hs.hotkey.getLogLevel()
    hs.hotkey.setLogLevel(0)
    fn()
    hs.hotkey.setLogLevel(previousLogLevel)
end

--- Usage:
---
---     hotkeyDisableSilent(hotkeyHandler)

function hotkeyDisableSilent(hotkeyHandler)
     hotkeySilence(
        function()
            hotkeyHandler:disable()
        end
    )
end

--- Usage:
---
---     hotkeyEnableSilent(hotkeyHandler)


function hotkeyEnableSilent(hotkeyHandler)
    hotkeySilence(
            function()
                hotkeyHandler:enable()
            end
    )
end