---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 28.01.23 23:50
---

fileInfo()

-- Create a variable to keep track of the last focused app
local lastFocusedAppBundleID = nil

-- Define a variable to store the MailMate bundle ID
local mailmateBundleID = "com.freron.MailMate"

-- Define a variable to store the Chrome bundle ID
local chromeBundleID = "com.google.Chrome"

-- Define a function to store the current focused app bundle ID
local function storeFocusedAppBundleID()
    if hs.application.frontmostApplication():bundleID() ~= chromeBundleID then
        lastFocusedAppBundleID = hs.application.frontmostApplication():bundleID()
    end
    --lastFocusedAppBundleID = hs.application.frontmostApplication():bundleID()
    debugInfo("lastFocusedAppBundleID ",lastFocusedAppBundleID)
end

-- Define a function to check if the last focused app was MailMate and the current app is Chrome
local function checkAppsAndActivateMailMate()
    debugInfo("lets check")
    debugInfo("lastFocusedAppBundleID ",lastFocusedAppBundleID)
    debugInfo("hs.application.frontmostApplication():bundleID() ",hs.application.frontmostApplication():bundleID())
    debugInfo("mailmateBundleID ", mailmateBundleID)
    debugInfo("chromeBundleID ", chromeBundleID)
    if lastFocusedAppBundleID
            and lastFocusedAppBundleID == mailmateBundleID
            and hs.application.frontmostApplication():bundleID() == chromeBundleID then
        debugInfo("go back")
        hs.application.get(mailmateBundleID):activate()
    end
end

-- Set up a mouse event watcher to activate MailMate if the cmd key was pressed while clicking a link
hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    debugInfo("event:getFlags() ",event:getFlags())
    if event:getFlags()["cmd"] then
        debugInfo("cmd is hold")
        --checkAppsAndActivateMailMate()
        hs.timer.doAfter(0.5, checkAppsAndActivateMailMate)
    end
    return false
end):start()

-- Set up an event watcher to store the focused app bundle ID when it changes
hs.application.watcher.new(storeFocusedAppBundleID):start()
