# Spec: YouTube control via postMessage (generic, without `window.YT`)

Date: 2026-07-21
Affects: `Functions/PlayerGlobalControl-ActionGenericVideo.js`, called from `Functions/PlayerGlobalControl.lua`

## Goal

Remote-control embedded YouTube players (`<iframe src=".../embed/...">`) on **any**
website — just like native `<video>`/`<audio>` tags. Concrete test case:
`http://cc.pixil.de/yt-mini.html?v=Ti3Kt1WlZUM&t=71`. The solution must be generic
(not tied to an editable test page).

## Root cause (why the previous approach cannot work)

The old `YouTubeIframeAdapter` loads the YouTube IFrame API and creates a `YT.Player`.
In this setup that is fundamentally impossible:

1. **Isolated world.** Hammerspoon runs JS via
   `Application('Google Chrome').activeTab.execute({javascript})` (JXA). Like an extension
   content script, that runs in an *isolated world*: the **DOM is shared**, but the
   **JS globals are not** — `window.YT` stays `undefined`.
2. **Globals don't persist.** Each `execute` call starts a **fresh** isolated world. This
   makes the old adapter's entire `globalThis[globalStateKey]` state machinery ineffective.
3. **CSP blocks the bridge.** The usual workaround (inject a `<script>` tag that runs in the
   *main world*) is blocked on the test page by the CSP
   `script-src 'self' https://www.youtube.com`.

Conclusion: `YT.Player` is unreachable via this path.

## Proven approach: direct `postMessage`

A YouTube embed with `enablejsapi=1` is really just a **postMessage protocol** (`YT.Player`
does nothing else internally). Reachable from the isolated world:

- get the `<iframe>` element from the DOM (DOM is shared),
- `iframe.contentWindow.postMessage(JSON.stringify({event:"command", func, args}), "*")`.

No `window.YT`, no script injection, no CSP problem.

### Verified live (via the exact Hammerspoon path, JXA)

| Capability | Result |
|---|---|
| detect iframe | ✅ |
| `window.YT` in isolated world | ❌ `undefined` |
| JS globals across calls | ❌ disappear |
| `addEventListener` listeners across calls | ✅ survive, keep firing |
| DOM/`dataset` as state cache | ✅ persistent |
| add `enablejsapi=1` via reload | ✅ |
| read state via `infoDelivery` | ✅ `{currentTime, playbackRate, playerState, duration}` |
| commands `seekTo`/`setPlaybackRate`/`play`/`pause` | ✅ all take effect |

State observed after the test: `{currentTime:245, playbackRate:2, playerState:2, duration:979}`.

## Architecture

The existing skeleton stays: `MediaController` + a list of adapters detected via `detect()`.
The per-adapter interface is unchanged
(`getMediaType`, `isPaused`, `play`, `pause`, `getPlaybackRate`, `setPlaybackRate`,
`getCurrentTime`, `setCurrentTime`, `getMaxPlaybackRate`, `resetPlaybackRate`, `skipAd`).

- **`NativeMediaAdapter`** (real `<video>`/`<audio>`): **unchanged**.
- **`YouTubePostMessageAdapter`** (new): **fully replaces** `YouTubeIframeAdapter`.

Removed entirely (was only diagnostic infrastructure for the now-resolved `window.YT` problem):
YT.Player creation, IFrame API loading/polling/timeout, `globalThis` state, context probes,
`normalizeDebugValue`, `runInPageContext`.

### `YouTubePostMessageAdapter`

**`static detect()`** (idempotent, satisfies the existing contract `{ mediaAdapter, status }`)

1. Find `iframe[src*="youtube.com/embed/"], iframe[src*="youtube-nocookie.com/embed/"]`.
   None → `null` (next adapter).
2. Install the listener if not present (guard: `documentElement.dataset.pgcYt === "1"` —
   **not** `globalThis`, since that doesn't persist). The listener parses `message` events,
   filters `event === "infoDelivery"`, and writes state to `documentElement.dataset.pgcYtState` (JSON).
3. If `enablejsapi=1` is missing from `iframe.src` → register a `listening` handshake on
   `load`, then set `iframe.src` with `enablejsapi=1` (reload). Show warmup overlay "connecting…".
   Return `{ mediaAdapter: null, status: "YouTube connecting…" }`.
4. Otherwise: send the `listening` handshake. If the cache is already populated
   (`dataset.pgcYtState` present) → `{ mediaAdapter: new YouTubePostMessageAdapter(iframe), status: "ready" }`
   and remove the overlay. Cache empty → `{ mediaAdapter: null, status: "YouTube connecting…" }`.

**State cache** `documentElement.dataset.pgcYtState` = JSON
`{ currentTime, playbackRate, playerState, duration, rates, at }`. The listener merges each
`infoDelivery` (only overwriting fields that are present).

**Methods**

| Method | Implementation |
|---|---|
| `getMediaType()` | `"YOUTUBE_IFRAME"` (→ Lua treats domain as `generic.video`) |
| `isPaused()` | cache `playerState !== 1` (1 = playing) |
| `play()` / `pause()` | `postMessage` `playVideo` / `pauseVideo` |
| `getPlaybackRate()` | cache `playbackRate` (fallback `1`) |
| `setPlaybackRate(v)` | `postMessage setPlaybackRate` **and** optimistically set cache to `v` |
| `getDefaultPlaybackRate()` / `resetPlaybackRate()` | `1` / `setPlaybackRate(1)` |
| `getMaxPlaybackRate()` | last value from cache `rates`, else `2` |
| `getCurrentTime()` | cache `currentTime` (fallback `0`) |
| `setCurrentTime(v)` | `postMessage seekTo` with `[Math.max(0,v), true]`, optimistic cache |
| `skipAd()` | kept (`.ytp-skip-ad-button` click; usually a no-op for cross-origin embeds, harmless) |

### postMessage protocol (reference)

- Command: `iframe.contentWindow.postMessage(JSON.stringify({event:"command", func:"<name>", args:[…]}), "*")`
- Handshake: `iframe.contentWindow.postMessage(JSON.stringify({event:"listening", id:1, channel:"widget"}), "*")`
- Reply: `message` events where `JSON.parse(e.data).event === "infoDelivery"`,
  payload in `.info` (`currentTime`, `playbackRate`, `playerState`, `duration`,
  `availablePlaybackRates`).
- `playerState`: `-1` unstarted · `0` ended · `1` playing · `2` paused · `3` buffering · `5` cued.
- Preconditions: `enablejsapi=1` and a matching `origin` parameter (already set by `yt-mini.js`).

## Warmup behavior (cold start)

On first contact with a page the cache is empty. Behavior:

1. `detect()` installs the listener, adds `enablejsapi=1` if needed, sends the handshake, and
   shows an **overlay "YouTube connecting…"** (a div on the parent page over the iframe).
2. As soon as the first `infoDelivery` arrives (cache populated), the adapter is **ready**;
   the overlay is removed and controls work normally.

This fits the existing workflow: `hyper+O` (`setSavedWindow`) already triggers `isGeneric`
for an unknown domain — i.e. `detect()` — and thus kicks off setup + warmup before the first
control key is pressed. A possibly needed reload (`enablejsapi`) costs a one-time "warmup press".

## Lua side

`PlayerGlobalControl.lua` stays **unchanged**. For the unknown domain `cc.pixil.de` the
existing path runs: `getAppActions` → `isGeneric` → adapter detects the YT iframe →
`getMediaType()` returns a truthy value → the domain is treated as `generic.video`; the
`generic.video` ControlKeys call `ActionGenericVideo(...)`.

## YAGNI / later

- Additional providers (Vimeo etc.) via extra adapters — **not** part of this spec.
- Multiple simultaneous iframes — for now `querySelector` (first match).

## Test strategy

Verify via the real path (JXA), not via chrome-devtools (different world/instance):
a small runner finds the `yt-mini.html` tab by URL and calls `tab.execute({javascript})`.
Checks: iframe detected · `enablejsapi` added · state cache fills · `seekTo`/`setPlaybackRate`/
`play`/`pause` change the cache as expected.
