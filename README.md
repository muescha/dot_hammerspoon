# Hammerspoon 

This are my collection of my Hammerspoon Scripts

### [MailMateFocus](/Functions/MailMateFocus.lua)

I don't like it when MailMate switches the focus to Chrome when I click on a link. This script changes the focus back to MailMate if it detects a click in MailMate before the focus switches to Chrome. You can modify the behavior of the script by enabling "enable_cmdClick" to only observe cmd+click events.

### [MailMateDisableCmdW](/Functions/MailMateDisableCmdW.lua)

This disable the shortcut `cmd+w` at the main screen of MailMate so it not closes the MailMate main window.This disables the shortcut cmd+w on the main screen of MailMate so that it does not close the MailMate main window.

### [MacZoom](/Functions/MacZoom.lua)

Enable the original MacZoom to my hyper key it's an better shortcut for my hand. i have set my hyper key to the `fn` key and to the `cmd_right` key.Enabling the original MacZoom to my Hyper key would be a better shortcut for my hand. I have set my Hyper key to the fn key and the cmd_right key.   

### [AppBorders](/Functions/AppBorders.lua)

Draw a red border around the current active app.

### [ChromeNewWindow](/Functions/ChromeNewWindow.lua)

Opens a New Chrome Window with the same size. You need to adjust the menu command to your current language. (PR is welcome for a language independent solution - maybe search the all the menu for shortcut `cmd`+`N` like in [KSheet](/Spoons/KSheet.spoon/init.lua)?)

### [MacZoom](/Functions/MacZoom.lua)

Map the shortkeys of accessibility features to zoom all or part of your screen from `{ "cmd", "alt" }` + `0` `-` `=` to `hyper` + `0` `-` `=` 



### [Umlauts.lua](/Functions/Umlauts.lua)

- Mapping german umlauts to `opt`+`key` are in:
```lua
local umlauts = {
    -- note: leave the space before ä Ä - otherwise it not work
    { 'a', ' ä', ' Ä' },
    { 'o', 'ö', 'Ö' },
    { 'u', 'ü', 'Ü' },
    { 'e', '€', '€' },
}

```

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
bindHotkey(exclude("Google Chrome","WhatsApp"), modifier, key, function)

bindHotkey(to("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, myFunction)
bindHotkey(exclude("Google Chrome","IntelliJ IDEA"), {"cmd"}, "n", nil, myFunction)

bindHotkey(toAppAndTab("MailMate","essages%)$"), {"cmd"}, "n", nil, myFunction)
bindHotkey(excludeAppAndTab("MailMate","^%d Tabs"), {"cmd"}, "n", nil, myFunction)

```

for patterns see:
https://www.lua.org/manual/5.1/manual.html#5.4.1

### HotKeySheet.spoon

replacement for `hs.hotkey.showHotkeys`

if you add a scriptname to the description then it is grouped by scriptname. Example: `MaximizeApp: Maximize App`

![ScreenShot HotKeySheet](./assets/readme/HotKeySheet.png)


### DebugFunction

- [debugFunction](/Helpers/DebugFunction.lua) show source code of a function in console

for example:
```lua
debugFunction(hs.hotkey.getHotkeys)
```

console output:

```text
2022-11-19 11:28:29: Source: @/Applications/Hammerspoon.app/Contents/Resources/extensions/hs/hotkey.lua:357-370

function hotkey.getHotkeys()
  local t={}
  for _,hks in pairs(hotkeys) do
    for i=#hks,1,-1 do
      if hks[i].enabled and hks[i]~=helpHotkey then
        t[#t+1] = hks[i]
        break
      end
    end
  end
  tsort(t,function(a,b)if#a.idx==#b.idx then return a.idx<b.idx else return #a.idx<#b.idx end end)
  if helpHotkey then tinsert(t,1,helpHotkey) end
  return t
end
```