---
--- Created by muescha.
--- DateTime: 05.08.22 12:02
---

fileInfo()

hs.hotkey.bind(hyper, "i", keyInfo("Open youtube in IINA"), function()

    local _,url = hs.osascript.applescript('tell application "Google Chrome" to return URL of active tab of front window')

    --https://github.com/search?l=lua&p=2&q=iina+open&type=Code
--    https://github.com/andweeb/.hammerspoon/blob/ae01cbda0136d9192bd80b17ca03795af63c08b2/ki-entities/entity/iina.lua

    --open 'iina://open?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D0b0x3C_BTT8'
    --url = 'https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D0b0x3C_BTT8'

    isMatch = url:match('^https://www.youtube.com')

    if isMatch then

        --if host == "open" || host == "weblink" {
        --more options here: https://github.com/0111b/iina/blob/512e9e218f51389d2c7afeda59239b457f9492d2/iina/AppDelegate.swift

        cmd = "iina://open?url="..url
        hs.urlevent.openURL(cmd)
    end


end )