--- === ChromeTabLitePlayer ===
---
--- Toggle the active Chrome tab between YouTube and liteplayer, hands-free.
---
--- Same logic as the liteplayer bookmarklet, but triggered by hyper+g instead
--- of clicking a bookmark:
---   * on youtube.com/watch  -> liteplayer.pages.dev/watch (adds t= from the live
---                              <video> currentTime and d= from its duration)
---   * on liteplayer.pages.dev -> back to youtube.com/watch, setting t= to the
---                              current position read from the pgcYtState seed
---                              (the <video> is cross-origin here); d= just rides
---                              along, YouTube ignores it
---
--- The URL is only rewritten on youtube.com or liteplayer.pages.dev; on any other
--- page the hotkey does nothing (guards against an accidental hyper+g elsewhere).
---
--- Requires:
--- Chrome:
---   View > Developer > Allow JavaScript from Apple Events

fileInfo()

local module = {}

-- The bookmarklet body, run inside the active tab. Only single quotes inside, so
-- it lives safely in a JXA backtick template below. Keep in sync with
-- liteplayer/liteplayer-bookmarklet.md. Returns a status the Lua side alerts on.
local JXA = [[
(() => {
    const chrome = Application("Google Chrome");
    const windows = chrome.windows();
    if (windows.length === 0) { return "nowin"; }

    const tab = windows[0].activeTab();
    const src = `(function () {
        var host = location.hostname;
        var yt = host.indexOf('youtube.com') > -1;
        var lp = host.indexOf('liteplayer.pages.dev') > -1;
        if (!yt && !lp) { return 'skip'; }

        var url = new URL(
            yt ? 'https://liteplayer.pages.dev/watch' : 'https://www.youtube.com/watch'
        );
        url.search = location.search;

        if (yt) {
            var v = document.querySelector('video');
            if (v && v.currentTime > 1) {
                url.searchParams.set('t', Math.floor(v.currentTime) + 's');
            }
            if (v && isFinite(v.duration) && v.duration > 0) {
                url.searchParams.set('d', Math.floor(v.duration));
            }
        } else {
            // liteplayer -> YouTube: carry the current position back via t=.
            // The embedded <video> is cross-origin and unreadable here, so read
            // the live position from the pgcYtState seed (kept fresh by the
            // Hammerspoon adapter; otherwise extrapolated from the initial seed).
            // d= just rides along in the query -- YouTube ignores it.
            var pos = null;
            try {
                var s = JSON.parse(
                    document.documentElement.dataset.pgcYtState || 'null'
                );
                if (s && typeof s.currentTime === 'number') {
                    var el = (s.playerState === 1 && s.at)
                        ? (Date.now() - s.at) / 1000 * (s.playbackRate || 1)
                        : 0;
                    pos = Math.floor(s.currentTime + el);
                }
            } catch (e) {}
            if (pos !== null && pos > 0) {
                url.searchParams.set('t', pos + 's');
            }
        }

        location.href = url.href;
        return yt ? 'liteplayer' : 'youtube';
    })();`;

    try {
        return tab.execute({ javascript: src });
    } catch (e) {
        return "error:" + e.message;
    }
})();
]]

local function runJXA(script)
    local ok, result, err = hs.osascript.javascript(script)

    if not ok then
        hs.alert.show("liteplayer: Chrome JXA failed")
        print("[ChromeTabLitePlayer] Error: " .. hs.inspect(err))
        return nil
    end

    return result
end

function module.toggle()
    local result = runJXA(JXA)

    if result == "liteplayer" then
        hs.alert.show("→ liteplayer")
    elseif result == "youtube" then
        hs.alert.show("→ YouTube")
    elseif result == "skip" then
        hs.alert.show("liteplayer: not a YouTube / liteplayer tab")
    elseif result == "nowin" then
        hs.alert.show("liteplayer: no Chrome window")
    elseif type(result) == "string" and result:sub(1, 6) == "error:" then
        hs.alert.show("liteplayer: " .. result)
    end

    return result
end

hs.hotkey
    .when("Google Chrome")
    .bind(
        hyper,
        "g",
        keyInfo("Toggle YouTube ↔ liteplayer"),
        function()
            module.toggle()
        end
    )

return module
