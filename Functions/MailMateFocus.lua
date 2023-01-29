---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 28.01.23 23:50
---

local scriptInfo = fileInfo()

-- Define a variable to store the MailMate bundle ID
local mailmateBundleID = "com.freron.MailMate"

-- Define a variable to store the Chrome bundle ID
local chromeBundleID = "com.google.Chrome"

-- Define a function to check if the current app is MailMate and the cmd key was pressed while clicking a link
local function checkCmdClickInMailmateAndActivateMailmate()

    -- Setup the click behaviour:
    -- -> use normal click to come back: false
    -- -> use cmd+click to come back: true
    local enable_cmdClick = true

    if hs.application.frontmostApplication():bundleID() ~= mailmateBundleID then
        --debugInfo(scriptInfo, 'not in MailMate --> exit')
        return false
    end

    if enable_cmdClick then
        if not hs.eventtap.checkKeyboardModifiers()['cmd'] then
            debugInfo(scriptInfo, 'no modifier `cmd` --> exit')
            return false
        end
    else
        local mousePos = hs.mouse.getAbsolutePosition()
        --debugInfo(scriptInfo,'mousePos ',mousePos)
        local focusedWindow = hs.window.focusedWindow()
        --debugInfo(scriptInfo,'focusedWindow ',focusedWindow)
        local frame = focusedWindow:frame()
        --debugInfo(scriptInfo,'frame ',frame)
        if mousePos.x < frame.x or mousePos.y < frame.y or
                mousePos.x > frame.x + frame.w or mousePos.y > frame.y + frame.h then
            -- Click occurred outside the window
            debugInfo(scriptInfo, "Click outside MailMate window --> exit")
            return false
        else
            -- Click occurred inside the MailMate window
            --debugInfo(scriptInfo, "Click inside MailMate window")
        end
    end

    hs.timer.doAfter(0.5, function()
        if hs.application.frontmostApplication():bundleID() == chromeBundleID then
            debugInfo(scriptInfo, 'we are now in Chrome --> switch back')
            hs.application.get(mailmateBundleID):activate()
        else
            debugInfo(scriptInfo, 'no app change --> exit')
        end
    end)
    return false
end

-- it need to be a global variable so this is not garbage collected
MailMateFocus_EventTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, checkCmdClickInMailmateAndActivateMailmate):start()
