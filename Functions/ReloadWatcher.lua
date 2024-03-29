---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 20.07.22 08:45
---

fileInfo()

--PATH = "/dotfiles/hammerspoon/.hammerspoon/"
PATH = "/.hammerspoon/"

-- Auto reload config
function reloadConfig(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
        if file:sub(-3) == ".js" then
            doReload = true
        end
    end
    if doReload then
        print("------------- ############## reload")
        hs.reload()
        hs.console.clearConsole()
    end
end
myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. PATH, reloadConfig):start()
--hs.notify.show("Hammerspoon", "Config Watcher", "Config reloaded")
