---
--- Created by muescha.
--- DateTime: 05.08.22 12:02
---

fileInfo()

-- chrome://media-internals

-- load YT api embed
-- https://stackoverflow.com/questions/41368785/youtube-iframe-embed-stopvideo-not-a-function/41368919

-- Youtube
-- iframe.contentWindow.postMessage('{"event":"command","func":"pauseVideo","args":""}',"*");

-- https://player.vimeo.com/
-- iframe.contentWindow.postMessage('{"method":"pause"}', "*");

function stopMediaInTabs()
    local jsFileName = path() .. filename() .. "-yt-only-count.js"
    --local jsFileName = path() .. filename() .. "-count.js"
    --local jsFileName = path() .. filename() .. ".js"
    debugInfo(jsFileName)
    local ok, urls = hs.osascript.javascriptFromFile(jsFileName)
    debugInfo(ok)
    debugInfo(urls)
end

hs.hotkey.bind(hyper, "i", keyInfo("Chrome: mute all audio/video"), stopMediaInTabs)
