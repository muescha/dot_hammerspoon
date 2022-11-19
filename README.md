# Hammerspoon 

This are my collection of my Hammerspoon Scripts

### Umlauts

- Mapping german umlauts to `opt`+`key` are in [Umlauts.lua](/Functions/Umlauts.lua).

### EmmyLua.spoon

- i added Timestamps to speed up and skip unchanged files
- interesting when you use IntelliJ IDEA to show complettions
- NOTE: load this spoon before other an reload watcher to avoid reloads while this spoon writes the annotation files

### BindHotkey only to some apps

If you like to have hotkeys only in some apps or exclude some apps from your global hotkeys, then the helper `bindHotkey` help you.

#### Syntax

`bindHotkey(AppCondition, modifier, key, function)`

- where `AppCondition` := `to(apps)` | `exclude(apps)`

- and where `apps` := can be a list of parameters or a table

Examples:

```lua
bindHotkey(to("Google Chrome","code"), modifier, key, function)
bindHotkey(to({"Google Chrome","code"}), modifier, key, function)

bindHotkey(exclude("Google Chrome"), modifier, key, function)
bindHotkey(exclude("Google Chrome","whatsapp"), modifier, key, function)

bindHotkey(to("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, myFunction)
bindHotkey(exclude("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, myFunction)


```

### DebugFunction

- [debugFunction](/Helpers/DebugFunction.lua) show source code of a function in console