# YouTube postMessage Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the non-functional `YT.Player`-based `YouTubeIframeAdapter` with a `YouTubePostMessageAdapter` that controls embedded YouTube players purely via `postMessage`, so Hammerspoon can drive them like native `<video>`/`<audio>` tags on any site.

**Architecture:** Hammerspoon injects `PlayerGlobalControl-ActionGenericVideo.js` into Chrome via JXA `activeTab.execute()`, which runs in an **isolated world** (DOM shared, JS globals not, and globals do not persist between calls). The adapter therefore never touches `window.YT`; it (a) sends commands with `iframe.contentWindow.postMessage({event:"command",...})`, and (b) installs a persistent `message` listener that caches YouTube `infoDelivery` state into `document.documentElement.dataset` (the DOM persists across calls), which the synchronous getter methods read.

**Tech Stack:** Vanilla browser JavaScript (injected string), Chrome JXA (`osascript -l JavaScript`) for verification. No JS test framework exists in this repo — verification runs the real injected file against a live `yt-mini.html` tab.

## Global Constraints

- Target file: `Functions/PlayerGlobalControl-ActionGenericVideo.js` (single injected script; the `{{ action }}` placeholder is templated by Lua before injection).
- Runtime is an **isolated world**: never rely on `window.YT`, `globalThis` persistence, or injected `<script>` tags (CSP blocks them). Persist only through the DOM (`dataset`).
- The adapter MUST keep the existing per-adapter interface consumed by `MediaController`: `getMediaType`, `isPaused`, `play`, `pause`, `getPlaybackRate`, `setPlaybackRate`, `getDefaultPlaybackRate`, `resetPlaybackRate`, `getMaxPlaybackRate`, `setMaxPlaybackRate`, `getCurrentTime`, `setCurrentTime`, `skipAd`, `getPlayer`.
- `static detect()` MUST return either `null` or `{ mediaAdapter, status }` (existing contract used by `findMediaAdapter`).
- `NativeMediaAdapter`, `MediaController`, `log`, `findMediaAdapter`, and the bottom driver stay unchanged except where a step says otherwise.
- `PlayerGlobalControl.lua` is NOT modified.
- Dataset keys (fixed): listener guard `data-pgc-yt` (`dataset.pgcYt`), state cache `data-pgc-yt-state` (`dataset.pgcYtState`).
- YouTube `playerState`: `-1` unstarted · `0` ended · `1` playing · `2` paused · `3` buffering · `5` cued.

---

## File Structure

- **Modify:** `Functions/PlayerGlobalControl-ActionGenericVideo.js`
  - Remove: `runInPageContext` helper (only used by the old adapter).
  - Remove: entire `YouTubeIframeAdapter` class (~lines 331–2048).
  - Add: `YouTubePostMessageAdapter` class.
  - Change: the `adapters` array to reference `YouTubePostMessageAdapter`.
- **Create (temporary, not committed):** `/tmp/yt-verify.sh` — a verification runner used during implementation. Delete after Task 2.

---

## Verification Runner (used by every task)

Create this helper first; it injects the **real** file exactly like Hammerspoon (reads the file, substitutes `{{ action }}`, runs it in the `yt-mini.html` tab) and can also read the cached state.

- [ ] **Setup Step: Write the verification runner**

Create `/tmp/yt-verify.sh`:

```bash
#!/bin/zsh
# Usage:
#   yt-verify.sh action <ACTION>   -> inject the real file with {{ action }}=<ACTION>, print return value
#   yt-verify.sh state             -> print document.documentElement.dataset.pgcYtState
#   yt-verify.sh open              -> (re)open a single fresh yt-mini test tab
YTFILE="$HOME/.hammerspoon/Functions/PlayerGlobalControl-ActionGenericVideo.js"
TESTURL="http://cc.pixil.de/yt-mini.html?v=Ti3Kt1WlZUM&t=71"

case "$1" in
  open)
    osascript -l JavaScript -e '
      const c=Application("Google Chrome");
      for(let w=0;w<c.windows.length;w++){const win=c.windows[w];
        for(let i=win.tabs.length-1;i>=0;i--){let u;try{u=win.tabs[i].url();}catch(e){continue;}
          if(u&&u.indexOf("yt-mini.html")!==-1)win.tabs[i].close();}}
      const win=c.windows[0];const t=c.Tab({url:"'"$TESTURL"'"});
      win.tabs.push(t);win.activeTabIndex=win.tabs.length;c.activate();"opened";'
    ;;
  action)
    ACTION="$2"
    # Substitute the template placeholder into a temp file, then read that file
    # verbatim in JXA (avoids all shell/JS template-literal escaping issues).
    sed "s/{{ action }}/$ACTION/g" "$YTFILE" > /tmp/yt-inject.js
    osascript -l JavaScript -e '
      function run(){
        const data=$.NSString.stringWithContentsOfFileEncodingError("/tmp/yt-inject.js",4,null);
        const code=ObjC.unwrap(data);
        const c=Application("Google Chrome");
        for(let w=0;w<c.windows.length;w++){const win=c.windows[w];const tabs=win.tabs;
          for(let i=0;i<tabs.length;i++){let u;try{u=tabs[i].url();}catch(e){continue;}
            if(u&&u.indexOf("yt-mini.html")!==-1)return tabs[i].execute({javascript:code});}}
        return "TAB-NOT-FOUND";}
      run();'
    ;;
  state)
    osascript -l JavaScript -e '
      const c=Application("Google Chrome");
      for(let w=0;w<c.windows.length;w++){const win=c.windows[w];const tabs=win.tabs;
        for(let i=0;i<tabs.length;i++){let u;try{u=tabs[i].url();}catch(e){continue;}
          if(u&&u.indexOf("yt-mini.html")!==-1)
            return tabs[i].execute({javascript:`document.documentElement.dataset.pgcYtState||"NONE"`});}}
      "TAB-NOT-FOUND";'
    ;;
esac
```

Then:

```bash
chmod +x /tmp/yt-verify.sh
/tmp/yt-verify.sh open
```

Expected: prints `opened`, and a single fresh `yt-mini.html` tab is visible in Chrome. Requires Chrome → View → Developer → "Allow JavaScript from Apple Events" enabled (the existing PlayerGlobalControl already needs this).

---

### Task 1: Detection, warmup, and state cache infrastructure

Replaces the old adapter's detection/state machinery with the postMessage listener + DOM cache and a warmup overlay. After this task the adapter is **detected** and **warms up**; control methods arrive in Task 2.

**Files:**
- Modify: `Functions/PlayerGlobalControl-ActionGenericVideo.js` (remove `runInPageContext` ~lines 15–38; remove `YouTubeIframeAdapter` class ~lines 331–2048; add `YouTubePostMessageAdapter`; update `adapters` array ~lines 2050–2053)

**Interfaces:**
- Consumes: `log(value)` (existing top-level helper); `MediaController` (unchanged); `findMediaAdapter` contract `detect() -> null | { mediaAdapter, status }`.
- Produces: class `YouTubePostMessageAdapter` with statics `iframeSelector`, `readState()`, `writeState(obj)`, `mergeState(patch)`, `installListener()`, `sendListening(iframe)`, `showOverlay(iframe, message, isError?)`, `removeOverlay(iframe)`, `detect()`, and instance methods `getPlayer()`, `getMediaType()` (returns `"YOUTUBE_IFRAME"`). Constructor: `new YouTubePostMessageAdapter(iframe)`.

- [ ] **Step 1: Remove the obsolete `runInPageContext` helper**

Delete the whole `function runInPageContext(code) { ... }` block (currently lines ~15–38, the CSP-blocked script-injection helper). Leave the `log` function above it intact.

- [ ] **Step 2: Delete the old `YouTubeIframeAdapter` class**

Delete the entire `class YouTubeIframeAdapter { ... }` (currently ~lines 331–2048), from its `class` keyword through its closing `}`. Do not touch `NativeMediaAdapter` (above it) or the `const adapters = [...]` block (below it).

- [ ] **Step 3: Add the `YouTubePostMessageAdapter` class**

Insert this class where `YouTubeIframeAdapter` was (between `NativeMediaAdapter` and `const adapters`):

```javascript
    class YouTubePostMessageAdapter {

        static iframeSelector =
            'iframe[src*="youtube.com/embed/"], '
            + 'iframe[src*="youtube-nocookie.com/embed/"]';

        static listenerFlag = "pgcYt";
        static stateKey = "pgcYtState";
        static overlayClass =
            "player-global-control-youtube-loading";

        constructor(iframe) {
            this.iframe = iframe;
        }

        static readState() {
            const raw =
                document.documentElement.dataset[this.stateKey];

            if (!raw) {
                return null;
            }

            try {
                return JSON.parse(raw);
            } catch (_) {
                return null;
            }
        }

        static writeState(next) {
            document.documentElement.dataset[this.stateKey] =
                JSON.stringify(next);
        }

        static mergeState(patch) {
            const prev = this.readState() || {};

            Object.assign(prev, patch, { at: Date.now() });
            this.writeState(prev);
        }

        static installListener() {
            if (
                document.documentElement.dataset[this.listenerFlag]
                === "1"
            ) {
                return;
            }

            window.addEventListener("message", event => {
                if (typeof event.data !== "string") {
                    return;
                }

                let message;

                try {
                    message = JSON.parse(event.data);
                } catch (_) {
                    return;
                }

                if (
                    !message
                    || message.event !== "infoDelivery"
                    || !message.info
                ) {
                    return;
                }

                const info = message.info;
                const patch = {};

                if (info.currentTime !== undefined) {
                    patch.currentTime = info.currentTime;
                }
                if (info.playbackRate !== undefined) {
                    patch.playbackRate = info.playbackRate;
                }
                if (info.playerState !== undefined) {
                    patch.playerState = info.playerState;
                }
                if (info.duration !== undefined) {
                    patch.duration = info.duration;
                }
                if (info.availablePlaybackRates !== undefined) {
                    patch.rates = info.availablePlaybackRates;
                }

                YouTubePostMessageAdapter.mergeState(patch);
            });

            document.documentElement.dataset[this.listenerFlag] =
                "1";
        }

        static sendListening(iframe) {
            iframe.contentWindow.postMessage(
                JSON.stringify({
                    event: "listening",
                    id: 1,
                    channel: "widget"
                }),
                "*"
            );
        }

        static showOverlay(iframe, message, isError = false) {
            const parent = iframe.parentElement;

            if (!parent) {
                return;
            }

            if (getComputedStyle(parent).position === "static") {
                parent.dataset.pgcYtPos =
                    parent.style.position || "";
                parent.style.position = "relative";
            }

            let overlay = parent.querySelector(
                ":scope > ." + this.overlayClass
            );

            if (!overlay) {
                overlay = document.createElement("div");
                overlay.className = this.overlayClass;

                Object.assign(overlay.style, {
                    position: "absolute",
                    inset: "0",
                    zIndex: "2147483647",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    padding: "24px",
                    boxSizing: "border-box",
                    background: "rgba(0, 0, 0, 0.78)",
                    color: "#ffffff",
                    fontFamily: "system-ui, sans-serif",
                    fontSize: "18px",
                    fontWeight: "600",
                    textAlign: "center",
                    pointerEvents: "none"
                });

                parent.appendChild(overlay);
            }

            overlay.textContent = message;
            overlay.style.background = isError
                ? "rgba(120, 0, 0, 0.88)"
                : "rgba(0, 0, 0, 0.78)";
        }

        static removeOverlay(iframe) {
            const parent = iframe.parentElement;

            if (!parent) {
                return;
            }

            const overlay = parent.querySelector(
                ":scope > ." + this.overlayClass
            );

            if (overlay) {
                overlay.remove();
            }

            if (
                Object.prototype.hasOwnProperty.call(
                    parent.dataset,
                    "pgcYtPos"
                )
            ) {
                parent.style.position = parent.dataset.pgcYtPos;
                delete parent.dataset.pgcYtPos;
            }
        }

        static detect() {
            const iframe = document.querySelector(
                this.iframeSelector
            );

            if (!iframe) {
                return null;
            }

            this.installListener();

            let url;

            try {
                url = new URL(iframe.src);
            } catch (_) {
                url = null;
            }

            if (
                url
                && url.searchParams.get("enablejsapi") !== "1"
            ) {
                url.searchParams.set("enablejsapi", "1");

                this.showOverlay(iframe, "YouTube connecting…");

                iframe.addEventListener(
                    "load",
                    () => this.sendListening(iframe),
                    { once: true }
                );

                iframe.src = url.toString();

                return {
                    mediaAdapter: null,
                    status: "YouTube connecting…"
                };
            }

            this.sendListening(iframe);

            if (this.readState()) {
                this.removeOverlay(iframe);

                return {
                    mediaAdapter:
                        new YouTubePostMessageAdapter(iframe),
                    status: "YouTube iframe player ready"
                };
            }

            this.showOverlay(iframe, "YouTube connecting…");

            return {
                mediaAdapter: null,
                status: "YouTube connecting…"
            };
        }

        getPlayer() {
            return this.iframe;
        }

        getMediaType() {
            return "YOUTUBE_IFRAME";
        }
    }
```

- [ ] **Step 4: Point the `adapters` array at the new class**

Change the `adapters` array (near the bottom) from:

```javascript
    const adapters = [
        NativeMediaAdapter,
        YouTubeIframeAdapter
    ];
```

to:

```javascript
    const adapters = [
        NativeMediaAdapter,
        YouTubePostMessageAdapter
    ];
```

- [ ] **Step 5: Verify no dangling references to removed code**

Run:

```bash
grep -n "YouTubeIframeAdapter\|runInPageContext" ~/.hammerspoon/Functions/PlayerGlobalControl-ActionGenericVideo.js
```

Expected: **no output** (both identifiers fully removed).

- [ ] **Step 6: Verify detection + warmup + enablejsapi reload on a fresh tab**

```bash
/tmp/yt-verify.sh open
/tmp/yt-verify.sh action isGeneric
```

Expected: first call after a fresh open returns `YouTube connecting…` (enablejsapi was missing → reload triggered), and a dark "YouTube connecting…" overlay appears over the video. Then:

```bash
/tmp/yt-verify.sh action isGeneric
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(2); "waited"' >/dev/null
/tmp/yt-verify.sh state
```

Expected: `state` prints JSON containing `currentTime`, `playbackRate`, `duration` (the listener caught `infoDelivery`), e.g. `{"currentTime":71,"playbackRate":1,"playerState":-1,"duration":978,"at":...}`.

- [ ] **Step 7: Verify a warm detect returns the ready adapter**

```bash
/tmp/yt-verify.sh action isGeneric
```

Expected: returns `YOUTUBE_IFRAME` (cache present → `detect()` returned a real `mediaAdapter`, `MediaController.isGeneric()` → `getMediaType()`), and the overlay is gone.

- [ ] **Step 8: Commit**

```bash
cd ~/.hammerspoon
git add Functions/PlayerGlobalControl-ActionGenericVideo.js
git commit -m "PlayerGlobalControl: replace YT.Player adapter with postMessage detection/warmup

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Control methods (play/pause, speed, seek, max)

Adds the command methods that the `MediaController` actions call, completing the adapter.

**Files:**
- Modify: `Functions/PlayerGlobalControl-ActionGenericVideo.js` (add instance methods to `YouTubePostMessageAdapter`, after `getMediaType()`)

**Interfaces:**
- Consumes: `YouTubePostMessageAdapter.readState()`, `mergeState(patch)` (from Task 1); `this.iframe` (constructor field).
- Produces: instance methods `postCommand(func, args?)`, `isPaused()`, `play()`, `pause()`, `getPlaybackRate()`, `setPlaybackRate(v)`, `getDefaultPlaybackRate()`, `resetPlaybackRate()`, `getMaxPlaybackRate()`, `setMaxPlaybackRate()`, `getCurrentTime()`, `setCurrentTime(v)`, `skipAd()` — matching the `NativeMediaAdapter` interface consumed by `MediaController`.

- [ ] **Step 1: Add the control methods**

Insert these methods inside `YouTubePostMessageAdapter`, immediately after `getMediaType()`:

```javascript
        postCommand(func, args = []) {
            this.iframe.contentWindow.postMessage(
                JSON.stringify({
                    event: "command",
                    func: func,
                    args: args
                }),
                "*"
            );
        }

        isPaused() {
            const state =
                YouTubePostMessageAdapter.readState();

            return !state || state.playerState !== 1;
        }

        play() {
            return this.postCommand("playVideo");
        }

        pause() {
            return this.postCommand("pauseVideo");
        }

        getPlaybackRate() {
            const state =
                YouTubePostMessageAdapter.readState();

            return (state && state.playbackRate) || 1;
        }

        setPlaybackRate(value) {
            this.postCommand("setPlaybackRate", [value]);
            YouTubePostMessageAdapter.mergeState({
                playbackRate: value
            });
        }

        getDefaultPlaybackRate() {
            return 1;
        }

        resetPlaybackRate() {
            this.setPlaybackRate(
                this.getDefaultPlaybackRate()
            );
        }

        getMaxPlaybackRate() {
            const state =
                YouTubePostMessageAdapter.readState();
            const rates = state && state.rates;

            return (rates && rates.length)
                ? rates[rates.length - 1]
                : 2;
        }

        setMaxPlaybackRate() {
            this.setPlaybackRate(
                this.getMaxPlaybackRate()
            );
        }

        getCurrentTime() {
            const state =
                YouTubePostMessageAdapter.readState();

            return (state && state.currentTime) || 0;
        }

        setCurrentTime(value) {
            const target = Math.max(0, value);

            this.postCommand("seekTo", [target, true]);
            YouTubePostMessageAdapter.mergeState({
                currentTime: target
            });
        }

        skipAd() {
            const skipButton = document.querySelector(
                "button.ytp-skip-ad-button"
            );

            if (skipButton) {
                skipButton.click();
                return true;
            }

            return false;
        }
```

- [ ] **Step 2: Prime the tab and confirm the adapter is warm**

```bash
/tmp/yt-verify.sh open
/tmp/yt-verify.sh action isGeneric   # warmup (may reload for enablejsapi)
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(2); "w"' >/dev/null
/tmp/yt-verify.sh action isGeneric   # should return YOUTUBE_IFRAME
```

Expected: second `isGeneric` returns `YOUTUBE_IFRAME`.

- [ ] **Step 3: Verify speed control (`maxSpeed`) changes the cached rate**

```bash
/tmp/yt-verify.sh action maxSpeed
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(1); "w"' >/dev/null
/tmp/yt-verify.sh state
```

Expected: `maxSpeed` returns a value (e.g. `2` or `2 & skipButton clicked`); `state` shows `"playbackRate":2`.

- [ ] **Step 4: Verify seek (`moveForward`) advances the cached time**

```bash
/tmp/yt-verify.sh state          # note currentTime BEFORE
/tmp/yt-verify.sh action moveForward
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(1); "w"' >/dev/null
/tmp/yt-verify.sh state          # currentTime AFTER
```

Expected: `moveForward` returns a formatted string like `00:01:11 + 8 = 00:01:19`; `currentTime` in `state` increased.

- [ ] **Step 5: Verify pause/play toggle (`doPause`) flips playerState**

Because YouTube blocks unmuted autoplay without a user gesture, first mute+play so the video actually runs, then toggle:

```bash
osascript -l JavaScript -e '
  const c=Application("Google Chrome");
  for(let w=0;w<c.windows.length;w++){const win=c.windows[w];const tabs=win.tabs;
    for(let i=0;i<tabs.length;i++){let u;try{u=tabs[i].url();}catch(e){continue;}
      if(u&&u.indexOf("yt-mini.html")!==-1){
        tabs[i].execute({javascript:`(function(){var f=document.querySelector('"'"'iframe[src*="/embed/"]'"'"');function c(fn){f.contentWindow.postMessage(JSON.stringify({event:"command",func:fn,args:[]}),"*");}c("mute");c("playVideo");return "played";})()`});}}}' >/dev/null
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(2.5); "w"' >/dev/null
/tmp/yt-verify.sh state          # expect playerState:1 (playing)
/tmp/yt-verify.sh action doPause
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(1.5); "w"' >/dev/null
/tmp/yt-verify.sh state          # expect playerState:2 (paused)
```

Expected: state goes from `"playerState":1` to `"playerState":2`; `doPause` returned `true`.

- [ ] **Step 6: Verify speed decrease + reset**

```bash
/tmp/yt-verify.sh action speedDec
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(1); "w"' >/dev/null
/tmp/yt-verify.sh state          # playbackRate lower than before
/tmp/yt-verify.sh action speedReset
osascript -l JavaScript -e '$.NSThread.sleepForTimeInterval(1); "w"' >/dev/null
/tmp/yt-verify.sh state          # playbackRate:1
```

Expected: `speedDec` lowers `playbackRate`; `speedReset` returns it to `1`.

- [ ] **Step 7: Commit**

```bash
cd ~/.hammerspoon
git add Functions/PlayerGlobalControl-ActionGenericVideo.js
git commit -m "PlayerGlobalControl: add postMessage control methods for YouTube adapter

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 8: Clean up the verification runner**

```bash
rm -f /tmp/yt-verify.sh /tmp/yt-inject.js
```

---

### Task 3: End-to-end check through Hammerspoon hotkeys

Confirms the real user path (hotkeys via `PlayerGlobalControl.lua`), not just direct injection.

**Files:** none (manual verification; reload Hammerspoon config).

- [ ] **Step 1: Reload Hammerspoon and drive the real hotkeys**

```bash
osascript -e 'tell application "Hammerspoon" to reload config' 2>/dev/null || \
  echo "Reload Hammerspoon config manually (Hammerspoon menu → Reload Config)."
```

Then, with the `yt-mini.html` tab focused:
1. Press `hyper+O` (Set active App) → expect the "Detected: Generic Video" alert (isGeneric path) and, on first contact, a brief "YouTube connecting…" overlay.
2. Press `hyper+9` (Max Speed) → video speeds up; on-screen alert shows the rate.
3. Press `hyper+P` (Pause) → toggles play/pause.
4. Press `hyper+\` (Jump Forward) / `hyper+'` (Jump Backward) → time jumps.
5. Press `hyper+K` (Reset Speed) → back to 1×.

Expected: each hotkey visibly controls the embedded YouTube video. (`hyper` and the exact keys are defined at the bottom of `PlayerGlobalControl.lua`.)

- [ ] **Step 2: Confirm no regression on native video**

Open any page with a plain `<video>` tag (e.g. a direct `.mp4`), press `hyper+O`, then `hyper+9`/`hyper+P`. Expected: `NativeMediaAdapter` still controls it (unchanged behavior).

---

## Self-Review

**Spec coverage:**
- Root cause / isolated-world constraint → encoded in Global Constraints; adapter uses only DOM + postMessage. ✅
- `YouTubePostMessageAdapter` replaces `YouTubeIframeAdapter` → Task 1 Steps 2–4. ✅
- State cache in `dataset` → Task 1 Step 3 (`readState/writeState/mergeState/installListener`). ✅
- `detect()` contract + warmup overlay + enablejsapi reload → Task 1 Step 3; verified Steps 6–7. ✅
- All interface methods → `getMediaType/getPlayer` (Task 1), controls (Task 2 Step 1). ✅
- Removed diagnostic machinery (`runInPageContext`, context probes, YT.Player, globalThis) → Task 1 Steps 1–2, verified Step 5. ✅
- Lua unchanged; `isGeneric` → `generic.video` path → Task 3. ✅
- postMessage protocol (command/listening/infoDelivery, playerState codes) → Global Constraints + Task 1/2 code. ✅
- YAGNI (no Vimeo, single iframe via `querySelector`) → respected in code. ✅

**Placeholder scan:** No TBD/TODO; all code blocks complete; every verification step has an exact command and expected output. ✅

**Type consistency:** `readState/writeState/mergeState`, `listenerFlag`/`stateKey`, `postCommand(func, args)`, `sendListening(iframe)`, `showOverlay/removeOverlay(iframe,...)` used consistently between Task 1 and Task 2. Dataset keys `pgcYt`/`pgcYtState`/`pgcYtPos` consistent throughout. ✅
