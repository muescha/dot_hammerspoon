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

    if hs.application.frontmostApplication():bundleID() ~= mailmateBundleID then
        debugInfo(scriptInfo, 'not in mailmate --> exit')
        return false
    end
    if not hs.eventtap.checkKeyboardModifiers()['cmd'] then
        debugInfo(scriptInfo, 'no modifier `cmd` --> exit')
        return false
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

-- Set up a mouse event watcher to activate MailMate if the cmd key was pressed while clicking a link
MailMateFocus_EventTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, checkCmdClickInMailmateAndActivateMailmate):start()
