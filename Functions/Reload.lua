---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 20.07.22 08:44
---

print("Init Reload")
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "r", "Reload", function()
    hs.notify.show("Hammerspoon", "", "Reload Config")
    hs.reload()
    hs.console.clearConsole()
end)
