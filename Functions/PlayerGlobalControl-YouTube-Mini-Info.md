# YouTube Mini Player (`yt-mini.html`)

A minimal, distraction-free YouTube player: just the video in an `<iframe>`,
no feed, no comments, no suggestions. Hosted at
`http://cc.pixil.de/yt-mini.html`, controlled via query parameters.

## URL parameters

| Param | Meaning | Example |
|-------|---------|---------|
| `v`   | YouTube video ID (11 characters) | `v=FVsMsCFtlOs` |
| `t`   | Start time in seconds, `s` suffix allowed | `t=277` or `t=277s` |

Usage:

```
http://cc.pixil.de/yt-mini.html?v=FVsMsCFtlOs&t=277s
```

### Validation

- `v` must match the pattern `^[A-Za-z0-9_-]{11}$`.
- `t` has an optional trailing `s` stripped (`.replace(/s$/i, '')`)
  and must then be an integer `0 … 604800` (max. 7 days).
- Invalid values -> error message in the body, no player.

## Behavior of `mini.js`

1. Reads `v` and `t` from the URL, validates them.
2. Builds a YouTube embed `<iframe>`:
   `https://www.youtube.com/embed/<id>` with
   `start`, `autoplay=1`, `playsinline=1`, `rel=0`, `enablejsapi=1`, `origin`.
3. After `load`, starts the `infoDelivery` stream via
   `postMessage({event:'listening', id:1, channel:'widget'})`.
4. From the `infoDelivery` messages:
   - **Tab title** = `HH:MM:SS - Title — Channel` (duration + `videoData`).
   - **Live `t=`**: The current playback position is continuously written into
     the browser's own address bar as `t=<sec>s` via `history.replaceState`
     (only on an actual whole-second change, since `infoDelivery` fires ~4×/sec).
     This keeps the URL always current for copying/reloading/jumping back.

## Toggle bookmarklet (YouTube ⇄ Mini)

A single bookmark for both directions. It detects from the hostname whether you
are on YouTube or in the mini player, carries `location.search` (i.e. `v`, `t`,
…) over 1:1 and swaps only the origin + path. On YouTube it additionally sets
the current `<video>` position as `t`.

**One-liner (paste into the bookmark):**

```javascript
javascript:(function(){var yt=location.hostname.indexOf('youtube.com')>-1;var url=new URL(yt?'http://cc.pixil.de/yt-mini.html':'https://www.youtube.com/watch');url.search=location.search;if(yt){var v=document.querySelector('video');if(v&&v.currentTime>1)url.searchParams.set('t',Math.floor(v.currentTime)+'s');}location.href=url.href;})();
```

**Readable version (without comments — `//` does not survive minification into one line):**

```javascript
javascript:(function () {
  var yt = location.hostname.indexOf('youtube.com') > -1;

  var url = new URL(
    yt
      ? 'http://cc.pixil.de/yt-mini.html'
      : 'https://www.youtube.com/watch'
  );

  url.search = location.search;

  if (yt) {
    var v = document.querySelector('video');
    if (v && v.currentTime > 1) {
      url.searchParams.set('t', Math.floor(v.currentTime) + 's');
    }
  }

  location.href = url.href;
})();
```

| Where you click | Direction | Timestamp |
|-----------------|-----------|-----------|
| `youtube.com/watch?v=…` | → Mini | current `<video>` position (otherwise URL `t`) |
| `cc.pixil.de/yt-mini.html?v=…` | → YouTube | `t` from the mini URL (kept live via `replaceState`) |

Note: `youtu.be` short links don't need special handling — YouTube redirects
them to `youtube.com/watch` anyway.

## Interplay with `PlayerGlobalControl`

The mini player uses the same YouTube IFrame postMessage API
(`enablejsapi=1`, `infoDelivery`) as the Hammerspoon remote control in
[`PlayerGlobalControl-ActionGenericVideo.js`](./PlayerGlobalControl-ActionGenericVideo.js).
The embedded player can therefore be controlled the same way via `command`
messages (`playVideo`, `pauseVideo`, `seekTo`, `setPlaybackRate`, …).
