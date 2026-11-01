# Konzept: Fenster-Karussell im Hyper+W-Modal

**Erstellt:** 2026-10-31
**Status:** umgesetzt (2026-10-31), noch nicht im Alltag getestet
**Betrifft:** `Helpers/WindowCarousel.lua` (neu), `Functions/WindowPlacer.lua`

## Ziel

Eine Merkliste von Fenstern („Karussell“), die nebeneinander auf dem externen
Monitor (`screens.monitor_2`, Odyssey G95SC, Querformat) verteilt werden.
Bedienung über das bestehende Hyper+W-Modal.

Grundidee: **kein Hintergrund-Tracking.** Keine Listener, keine Timer. Alles passiert
nur, wenn eine Taste gedrückt oder das Modal geöffnet wird.

## Bedienung

Alle Tasten gehen mit und ohne Hyper und schließen das Modal danach (wie `1`–`f`).
Belegt sind im Modal bereits `1`–`8` und `a`–`f`.

| Taste | Merkhilfe | Aktion |
|-------|-----------|--------|
| `K` | **K**arussell | fokussiertes Fenster ans **Ende** der Liste setzen, Layout anwenden |
| `L` | **L**ayout | aufräumen, in voller Höhe neu platzieren, alle nach vorne holen |
| `H` | **H**ide | wie `L`, aber nur im unteren Drittel – Fenster dahinter bleiben erreichbar |
| `R` | **R**emove | fokussiertes Fenster aus der Liste nehmen (Fenster bleibt offen) |
| `X` | Close | `Cmd+W` an das fokussierte Fenster senden und aus der Liste nehmen |

Die Tasten stehen in `carousel_keys` in `Functions/WindowPlacer.lua` und lassen
sich dort umstellen. Hilfe-Anzeige und Bindings folgen automatisch.

### `K` – hinzufügen / ans Ende setzen

- Fenster ist **nicht** in der Liste → wird ans Ende angehängt.
- Fenster ist **schon** in der Liste → wird an seiner alten Position entfernt und
  ans Ende gesetzt (kein Duplikat, aber neue Reihenfolge).
- Bei Google Chrome wird zusätzlich die ID des aktiven Tabs gemerkt.
- Danach Layout anwenden (wie `L`), Fokus bleibt auf dem Fenster.

### `L` – Layout

1. Höhe zurück auf voll (beendet `H`).
2. Aufräumen: geschlossene Fenster und geschlossene, gemerkte Chrome-Tabs entfernen.
3. Alle Fenster der Liste neu platzieren.
4. Alle Fenster in Listen-Reihenfolge nach vorne holen (nacheinander `focus()`).
5. Fokus auf das letzte Fenster der Liste.

`L` ist der Ersatz für das automatische Tracking: Lücken durch geschlossene Fenster
und verdeckte Karussell-Fenster werden damit behoben.

### `H` – Hide

- Wie `L`, aber die Fenster bekommen nur `1/3` der Höhe und sitzen unten
  (`hiddenHeight`, Option der Klasse). Oben werden die Fenster dahinter frei.
- Die Höhe bleibt, bis `L` gedrückt wird: `K`, `R` und `X` platzieren im
  versteckten Zustand ebenfalls im unteren Drittel.
- Die Hilfe-Anzeige zeigt dann `(hidden)` hinter der Karussell-Zeile.

### `R` – raus aus der Liste

- Fenster ist in der Liste → wird entfernt, bleibt offen und an seiner aktuellen
  Position stehen.
- Danach Layout anwenden; Fokus auf das zuletzt hinzugefügte Fenster
  (= letzter Listeneintrag).
- Fenster ist **nicht** in der Liste → es passiert nichts, kein Hinweis.

### `X` – schließen

- Fenster ist in der Liste → aus der Liste nehmen, dann `Cmd+W` senden
  (`hs.eventtap.keyStroke({"cmd"}, "w")`), danach Layout anwenden wie bei `R`.
- Fenster ist **nicht** in der Liste → es passiert nichts (auch kein `Cmd+W`).
- In Browsern schließt `Cmd+W` nur den **aktiven Tab**. Hat das Fenster noch
  weitere Tabs, bleibt es offen – es ist dann trotzdem nicht mehr in der Liste.
- `Functions/DisableCmdW.lua` blockiert `Cmd+W` in MailMate, WhatsApp, Warp und
  ChatGPT. Ob der gesendete Tastendruck dort auch geblockt wird, muss ein Test
  zeigen. Geblockt wäre gewollt (Schutz bleibt), das Fenster ist dann nur aus der
  Liste raus.

### Andere WindowPlacer-Tasten

Wird ein Karussell-Fenster mit einer anderen WindowPlacer-Taste platziert
(`1`–`f` im Hyper+W-Modal oder `Hyper+1`, `2`, `3`, `4`, `8`), fliegt es aus der
Liste (`carousel:forget(window)`):

- Die restlichen Fenster werden neu platziert (Lücke schließt sich).
- Anders als bei `R` wird nichts nach vorne geholt und der Fokus bleibt auf dem
  gerade platzierten Fenster – sonst würde das Karussell es sofort verdecken.

## Merkliste

- Nur im Arbeitsspeicher. Nach einem Hammerspoon-Reload ist sie leer.
- Reihenfolge der Liste = Reihenfolge von links nach rechts auf dem Monitor.
- Eintrag: `{ window = hs.window, tabId = <nur bei Chrome> }`.

## Aufräumen (nur bei Bedarf)

Wird ausgeführt beim Öffnen des Modals und vor jedem `K`, `L`, `H`, `R`, `X`. Ein
Eintrag wird entfernt, wenn

1. das **Fenster** nicht mehr existiert (`hs.window.get(id) == nil`), oder
2. der gemerkte **Chrome-Tab** nicht mehr existiert – eine einzige
   AppleScript-Abfrage aller Tab-IDs, nur wenn mindestens ein Tab gemerkt ist.

Beim Öffnen des Modals wird nur die Liste bereinigt, nicht neu platziert – damit die
Hilfe-Anzeige stimmt.

Tab-Details:

- Beim `K` auf ein Chrome-Fenster: `id of active tab of front window` (das
  fokussierte Fenster ist in dem Moment `front window`). Chrome-Tab-IDs sind
  stabil, solange der Tab lebt.
- Erneutes `K` auf dasselbe Fenster merkt den dann aktiven Tab.
- Tab in ein anderes Fenster gezogen: der Tab lebt noch → Eintrag bleibt.
- Andere Apps (Safari hat keine stabilen Tab-IDs, Nicht-Browser): nur
  Fenster-Prüfung.

## Aufteilung

Gleich breite Spalten, jeweils volle Höhe.

| Anzahl | Fläche |
|--------|--------|
| 1–5 Fenster | `0` bis `5/6` – die Breite von `c` (rechtes Sechstel) bleibt frei |
| ab 6 Fenstern | `0` bis `1` – volle Breite |

Spalte `i` von `n` (0-basiert) bei Flächenbreite `W`:
`start = i * W / n`, `size = W / n`.

## Dynamische Hilfe-Anzeige

Beim Öffnen von Hyper+W wird der Karussell-Block jedes Mal neu berechnet und unter
die bestehenden Layout-Zeilen gehängt. **Keine Zahlen** in den Balken, damit es nicht
mit den Tasten `1`, `2`, `3` … verwechselt wird. Nur Balken, keine Fenstertitel.

````text
Carousel:   ╞────────╡╞───●────╡╞────────╡ ·c·
key k:      ╞────────╡╞────────╡╞───k────╡ ·c·
key l:      ╞───↻────╡╞───↻────╡╞───↻────╡ ·c·
key h:      ╞───▁────╡╞───▁────╡╞───▁────╡ ·c·
key r:      ╞────────╡╞───r────╡╞────────╡ ·c·
key x:      ╞────────╡╞───x────╡╞────────╡ ·c·    (Cmd+W)
````

- Tasten werden als Kleinbuchstaben angezeigt.
- `Carousel`: aktueller Stand; `●` markiert das fokussierte Fenster, falls es in
  der Liste ist. Nach `H` steht `(hidden)` dahinter.
- `key k`: Ergebnis nach `k` – das fokussierte Fenster (`k`) steht immer rechts
  außen. Beim Sprung von 5 auf 6 sieht man, dass der `c`-Bereich mitbenutzt wird.
- `key l`: aktuelle Aufteilung, jede Spalte mit `↻` (neu platzieren).
- `key h`: aktuelle Aufteilung, jede Spalte mit `▁` (unteres Drittel).
- `key r` / `key x`: aktuelle Aufteilung, die Spalte, die wegkommt, ist mit `r`
  bzw. `x` markiert; ist das fokussierte Fenster nicht in der Liste, steht dort
  nur `–`.
- Leere Liste: `Carousel: –`, die `K`-Zeile zeigt eine einzelne Spalte.
- Die Balken sind eine Text-Näherung (Menlo, feste Breite, z. B. 36 Zeichen, davon
  6 für `c`); bei 4 oder 5 Spalten nicht pixelgenau gleich breit.

## Aufbau: Klasse `WindowCarousel`

Eigene Datei `Helpers/WindowCarousel.lua`, Klasse per Metatable. Kennt keine
Hotkeys und kein Modal.

````lua
local carousel = WindowCarousel.new({
    screen      = function() return hs.screen.find(screens.monitor_2) end,
    reserved    = 1/6,   -- Breite von "c", frei bis maxSmall Fenster
    maxSmall    = 5,
    place       = function(window, screen, unit) ... end, -- windowMoveToUnit + retry
})

carousel:add(window)       -- K
carousel:show()            -- L, volle Höhe
carousel:hide()            -- H, unteres Drittel
carousel:remove(window)    -- R, gibt true zurück wenn es drin war
carousel:unload(window)    -- X
carousel:forget(window)    -- andere WindowPlacer-Taste: raus, ohne nach vorne
carousel:prune()           -- Aufräumen
carousel:info(window)      -- Zeilen für die Hilfe-Anzeige
````

`WindowPlacer.lua` erzeugt das Objekt, bindet die fünf Tasten ins Modal, ruft in
`startFn` `carousel:prune()` auf und hängt `carousel:info(focusedWindow)` an
`createLayoutInfo(layout_setup)` an.
