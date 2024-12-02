---
--- Created by muescha.
--- DateTime: 05.08.22 12:02
---

fileInfo()

hs.hotkey.bind(hyper, "i", keyInfo("Chrome: Goto first Audio"), function()
    debugInfo("INFO: this script is not working :(")

    -- https://stackoverflow.com/questions/40356873/is-it-possible-to-detect-whether-a-browser-tab-is-playing-audio-or-not

    local jsScript = [[
        (function() {
            let audibleTabId = null;
            chrome.tabs.query({}, function(tabs) {
              for (let tab of tabs) {
                if (tab.audible) {
                  audibleTabId = tab.id;
                  chrome.tabs.update(audibleTabId, { active: true });
                  chrome.windows.update(tab.windowId, { focused: true });
                  break;
                }
              }
            });
            return audibleTabId ? "Switched to the first audible tab." : "No audible tabs found.";
          })();
    ]]

    local escapedJsScript = jsScript:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")

    local appleScriptx = string.format([[
      tell application "Google Chrome"
        set jsResult to execute front window's active tab javascript "%s"
      end tell
      return jsResult
    ]], escapedJsScript)


    local appleScript = [[
        tell application "Google Chrome"
            set audibleTab to missing value
            repeat with w in windows
                repeat with t in tabs of w
                    if (audible of t) is true then
                        set audibleTab to t
                        set audibleWindow to w
                        exit repeat
                    end if
                end repeat
                if audibleTab is not missing value then exit repeat
            end repeat

            if audibleTab is not missing value then
                set active tab index of audibleWindow to (index of audibleTab)
                set index of audibleWindow to 1
                return true
            else
                return false
            end if
        end tell
    ]]

    local success,result = hs.osascript.applescript(appleScript)

    debugInfo(success)
    debugInfo(result)

end )