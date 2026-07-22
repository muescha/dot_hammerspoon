# YouTube Mini Player (`yt-mini.html`)

Ein minimaler, ablenkungsfreier YouTube-Player: nur das Video im `<iframe>`,
kein Feed, keine Kommentare, keine Vorschläge. Gehostet unter
`http://cc.pixil.de/yt-mini.html`, gesteuert über Query-Parameter.

## URL-Parameter

| Param | Bedeutung | Beispiel |
|-------|-----------|----------|
| `v`   | YouTube-Video-ID (11 Zeichen) | `v=FVsMsCFtlOs` |
| `t`   | Startzeit in Sekunden, `s`-Suffix erlaubt | `t=277` oder `t=277s` |

Aufruf:

```
http://cc.pixil.de/yt-mini.html?v=FVsMsCFtlOs&t=277s
```

### Validierung

- `v` muss dem Muster `^[A-Za-z0-9_-]{11}$` entsprechen.
- `t` wird von einem optionalen `s` am Ende befreit (`.replace(/s$/i, '')`)
  und muss danach eine ganze Zahl `0 … 604800` (max. 7 Tage) sein.
- Ungültige Werte -> Fehlermeldung im Body, kein Player.

## Verhalten von `mini.js`

1. Liest `v` und `t` aus der URL, validiert sie.
2. Baut ein YouTube-Embed-`<iframe>`:
   `https://www.youtube.com/embed/<id>` mit
   `start`, `autoplay=1`, `playsinline=1`, `rel=0`, `enablejsapi=1`, `origin`.
3. Startet nach `load` den `infoDelivery`-Strom per
   `postMessage({event:'listening', id:1, channel:'widget'})`.
4. Aus den `infoDelivery`-Nachrichten:
   - **Tab-Titel** = `HH:MM:SS - Titel — Kanal` (Dauer + `videoData`).
   - **Live-`t=`**: Die aktuelle Abspielposition wird per
     `history.replaceState` laufend als `t=<sek>s` in die eigene Adresszeile
     geschrieben (nur bei echtem Sekundenwechsel, da `infoDelivery` ~4×/Sek.
     feuert). So ist die URL immer aktuell zum Kopieren/Reload/Zurückspringen.

## Toggle-Bookmarklet (YouTube ⇄ Mini)

Ein einziges Lesezeichen für beide Richtungen. Es erkennt am Hostnamen, ob man
auf YouTube oder im Mini-Player ist, übernimmt `location.search` (also `v`, `t`,
…) 1:1 und tauscht nur Origin+Pfad. Auf YouTube wird zusätzlich die aktuelle
`<video>`-Position als `t` gesetzt.

**Einzeiler (ins Lesezeichen einfügen):**

```javascript
javascript:(function(){var yt=location.hostname.indexOf('youtube.com')>-1;var url=new URL(yt?'http://cc.pixil.de/yt-mini.html':'https://www.youtube.com/watch');url.search=location.search;if(yt){var v=document.querySelector('video');if(v&&v.currentTime>1)url.searchParams.set('t',Math.floor(v.currentTime)+'s');}location.href=url.href;})();
```

**Lesbare Version (ohne Kommentare — `//` überlebt das Einzeilen nicht):**

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

| Wo du klickst | Richtung | Zeitmarke |
|---------------|----------|-----------|
| `youtube.com/watch?v=…` | → Mini | aktuelle `<video>`-Position (sonst URL-`t`) |
| `cc.pixil.de/yt-mini.html?v=…` | → YouTube | `t` aus der Mini-URL (läuft dank `replaceState` live mit) |

Hinweis: `youtu.be`-Kurzlinks müssen nicht behandelt werden — YouTube leitet
sie ohnehin auf `youtube.com/watch` um.

## Zusammenspiel mit `PlayerGlobalControl`

Der Mini-Player nutzt dieselbe YouTube-IFrame-postMessage-API
(`enablejsapi=1`, `infoDelivery`) wie die Hammerspoon-Fernsteuerung in
[`PlayerGlobalControl-ActionGenericVideo.js`](./PlayerGlobalControl-ActionGenericVideo.js).
Der eingebettete Player lässt sich also genauso per `command`-Nachrichten
(`playVideo`, `pauseVideo`, `seekTo`, `setPlaybackRate`, …) steuern.
