### set receiver to Video Controls

i have IINA Controls - i lake to attach dem also to a Chrome Youtube Tab as a receiver

- Select Source
  - IINA
  - Chrome Tab (a specific tab!)
  - MPV
  - QuickTime
  - VLC


### Use Hyperkey to start some apps

https://github.com/dbalatero/HyperKey.spoon

### Try out VimMode.spoon

https://github.com/dbalatero/VimMode.spoon

### Read Later

https://github.com/dbalatero/dotfiles/blob/master/hammerspoon/read-later/init.lua

### Text Expander

https://github.com/dbalatero/dotfiles/blob/master/hammerspoon/text-expander.lua

### IPC

```lua
require('hs.ipc') -- commandline 'hs' -- if CLI is not working, try `hs.ipc.cliInstall('/opt/homebrew')`
```

### Code Style Seperate my spoons into separate gh repos

### Use MemoryBar sctipt for WatchDog for GPU


### Close chrome tab after seconds

many times i close a tab and then think: i would read it - so i reopen it.
close with a delay which i can cancel

### Display with starters

-- https://nethumlamahewage.medium.com/setting-up-a-global-leader-key-for-macos-using-hammerspoon-f0330f8a7a4a

```lua
hs.loadSpoon("RecursiveBinder")

spoon.RecursiveBinder.escapeKey = {{}, 'escape'}  -- Press escape to abort

local singleKey = spoon.RecursiveBinder.singleKey

local keyMap = {
  [singleKey('c', 'chrome')] = function() hs.application.launchOrFocus("Chrome") end,
  [singleKey('t', 'terminal')] = function() hs.application.launchOrFocus("Terminal") end,
  [singleKey('d', 'domain+')] = {
    [singleKey('g', 'github')] = function() hs.urlevent.openURL("github.com") end,
    [singleKey('y', 'youtube')] = function() hs.urlevent.openURL("youtube.com") end
  }
}

spoon.RecursiveBinder.helperFormat = {
  atScreenEdge = 0,  -- 0-center, 1-top, 3-btm
  textStyle = {  -- An hs.styledtext object
      font = {
          name = "Courier",
          size = 40
      }
  }
}

 hs.hotkey.bind({'option'}, 'space', spoon.RecursiveBinder.recursiveBind(keyMap))
```

### Keyboard shortcut to open a context menu

Some trials here:
[ContextMenu.lua](/Functions/ContextMenu.lua)



### Menu Chooser

https://github.com/brokensandals/MenuChooser.spoon

https://github.com/olivertaylor/dotfiles/blob/master/hammerspoon/init.lua#L135-L173
https://github.com/boomker/spacehammer/blob/main/Spoons/MenuChooserMod.spoon/init.lua

### App Launcher

https://github.com/midnightblue69/hammerspoon-config/blob/main/launcher.lua


### Check if menuitem is enabled

```lua
bindings:insert(hotkey.bind({"ctrl","cmd"}, "m", function() toggle_application_nolaunch("com.webex.meetingmanager") end))
mute_toggle = function()
  app = hs.window.find("Webex Meetings"):application()
  -- i found also markierung_aktiv["ticked"]
  if app:findMenuItem("Mute Me")['enabled'] then  -- <-- here is the check 
    print("mute me enabled, so mute")
    app:selectMenuItem("Mute Me")
  else
    print("mute me disabled, so unmute")
    app:selectMenuItem("Unmute Me")
  end
end
-- bindings:insert(hotkey.bind(mash, "m", mute_toggle))
```

source: https://github.com/trws/dotfiles/blob/master/hammerspoon/init.lua


### Remember KeyBindings

```lua

local bindings = {}
setmetatable(bindings, { __index = table })

bindings:insert(hotkey.bind(mash, "g", function() hs.hints.windowHints() end))

local enable_bindings = function()
  for k,v in pairs(bindings) do
    v:enable()
  end
end

local disable_bindings = function()
  for k,v in pairs(bindings) do
    v:disable()
  end
end

local screen_sharing_watcher = application.watcher.new(function(name, event, app)
  if(name == "Screen Sharing") then
    if(event == application.watcher.activated) then
      disable_bindings()
    elseif(event == application.watcher.deactivated) then
      enable_bindings()
    end
  end
end)

screen_sharing_watcher:start()
```

### Simple Event pub-sub

```lua
--
-- Simple global event pub-sub hub.
--

local registry = {}

return {
  emit = (function(eventName)
    local callbacks = registry[eventName]
    if callbacks == nil then
      return
    end
    for _, callback in ipairs(callbacks) do
      callback()
    end
  end),

  subscribe = (function(eventName, callback)
    local callbacks = registry[eventName]
    if callbacks == nil then
      callbacks = {}
      registry[eventName] = callbacks
    end
    callbacks[#callbacks + 1] = callback
  end),
}
```

https://github.com/mikejakobsen/2017/blob/master/roles/dotfiles/files/.hammerspoon/events.lua


### MailMate related


```lua
isMailMateMailViewer = (function(window)
  local title = window:title()
  
  return title == 'No mailbox selected' or
     -- mailmate includes this text when a mailbox is selected (not when a mail is open
     string.find(title, '%(%d+ messages?%)')
end)
```

### Network Chooser


```lua
-- Audio Chooser

local audioChooser = hs.chooser
    .new(function(choice)
        if not choice then return end
        local idx = choice["idx"]
        local name = choice["text"]
        dev = hs.audiodevice.allOutputDevices()[idx]
        if not dev:setDefaultOutputDevice() then
            hs.alert.show("Unable to enable audio output device " .. name)
        -- else
            -- hs.alert.show("Audio output device is now: " .. name)
        end
    end)
    :choices(function()
        local audiochoices = {}
        for i,v in ipairs(hs.audiodevice.allOutputDevices()) do
            if v:name() ~= "DELL U2419HC" and v:name() ~= "W2442" then
                table.insert(audiochoices, {text = v:name(), idx = i})
            end
        end
        return audiochoices
    end)

hs.hotkey.bind(hyper, "a", function() audioChooser:refreshChoicesCallback():show() end)

```

other one:
https://github.com/allen-mack/dotfiles/blob/main/.hammerspoon/audioOutput.lua
```lua
-- f10 -> Select the audio output device.
hs.hotkey.bind({}, "f10", function()
  audioOutput.selectAudioOutput()
end)
```

### Window Switcher with chooser 

hs.window.switcher.ui.showThumbnails = true

switcher = hs.window.switcher.new()

-- code for thumnails see here https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/window/window_switcher.lua#L53
--hs.window.switcher.ui.showTitles = true
--hs.window.switcher.ui.showThumbnails = false
--hs.window.switcher.ui.thumbnailSize = 128
--hs.window.switcher.ui.showSelectedThumbnail = false
-- bind to hotkeys; WARNING: at least one modifier key is required!


-- hs.hotkey.bind('alt','tab','Next window',function()switcher:next()end)
-- hs.hotkey.bind('alt-shift','tab','Prev window',function()switcher:previous()end)



### Fix Error


```lua
2022-08-28 14:42:24: *** ERROR: /Users/muescha/.hammerspoon/Functions/AppBorders.lua:18: attempt to index a nil value
stack traceback:
	/Users/muescha/.hammerspoon/Functions/AppBorders.lua:18: in function 'initBorder'
	/Users/muescha/.hammerspoon/Functions/AppBorders.lua:40: in main chunk
	[C]: in function 'rawrequire'
	...poon.app/Contents/Resources/extensions/hs/_coresetup.lua:662: in function 'require'
	/Users/muescha/.hammerspoon/init.lua:43: in main chunk
	[C]: in function 'xpcall'
	...poon.app/Contents/Resources/extensions/hs/_coresetup.lua:723: in function 'hs._coresetup.setup'
	(...tail calls...)

```

on Startup:
```lua
2022-10-24 08:34:27: Init ReloadWatcher
2022-10-24 08:34:27: -- Loading extension: pathwatcher
2022-10-24 08:34:27: Init AppBorders
2022-10-24 08:34:27:          AppBorders: Init
2022-10-24 08:34:27: -- Loading extension: window
2022-10-24 08:34:29: *** ERROR: /Users/muescha/.hammerspoon/Functions/AppBorders.lua:18: attempt to index a nil value
stack traceback:
/Users/muescha/.hammerspoon/Functions/AppBorders.lua:18: in function 'initBorder'
/Users/muescha/.hammerspoon/Functions/AppBorders.lua:40: in main chunk
[C]: in function 'rawrequire'
...poon.app/Contents/Resources/extensions/hs/_coresetup.lua:662: in function 'require'
/Users/muescha/.hammerspoon/init.lua:43: in main chunk
[C]: in function 'xpcall'
...poon.app/Contents/Resources/extensions/hs/_coresetup.lua:723: in function 'hs._coresetup.setup'
(...tail calls...)
2022-10-24 08:34:53: -- Lazy extension loading enabled
2022-10-24 08:34:53: -- Loading ~/.hammerspoon/init.lua
```

#### Ideas for myHammerspoon setup

[x] new tab window on Chrome should be at same place like before (no offeset) 
[x] "remote control" for youtube on a chrome tab when other app is active
[x] "remote control" for IINA when other app is active

```lua
  local myApp = hs.application.applicationsForBundleID('com.apple.finder')[1]
  hs.eventtap.keyStroke({"cmd"}, "2", 200, myApp)
```

- open in IINA should be placed on area 3 

- when there is a bad or no WIFI connection: red blinking border around screens

- zoom animation into mouse circle (scale / area on geometry -> start with window frame down to the mouse circle rect)
[x] mouse circe follow mouse movement

### WIFI
- select WIFI with keyboard
  - https://www.hammerspoon.org/docs/hs.wifi.html#interfaces
- switch wifi on/of
  - https://www.hammerspoon.org/docs/hs.wifi.html#setPower
- [done] disable commad-w for: whatsapp / Telegram via System Environment 


### Interesting setups

https://github.com/FryJay/MenuHammer

https://github.com/jasonrudolph/ControlEscape.spoon

strictShortcut - only  on some apps execute shortcut otherwise passthrough

https://github.com/roeybiran/.hammerspoon/blob/main/Spoons/NotificationCenter.spoon/init.lua

https://github.com/roeybiran/.hammerspoon/blob/main/rb/util.lua#L47


https://github.com/roeybiran/.hammerspoon/tree/main/Spoons

https://kalis.me/setup-hyper-key-hammerspoon-macos/
-> hier auch hyperkey F18: https://github.com/hetima/hammerspoon-hyperex

brew install iina

screen annotating tool for Hammerspoon
https://github.com/szymonkaliski/hhann


Log of Window / App in History files:

- https://github.com/pathologicalhandwaving/dotdotdot/blob/master/.hammerspoon/log.lua

use sqlite 3 in Hammerspoon:

- https://github.com/pathologicalhandwaving/dotdotdot/blob/master/.hammerspoon/dash.lua


use FN as meta key - fixed version of FnMate

- https://github.com/vogler/dotfiles/blob/master/macos/.hammerspoon/init.lua


show AutoInstall for Spoons:

- https://github.com/sidharthv96/hammerspoon-config/blob/master/init.lua


Wifi Watcher for inactivity:

- https://stackoverflow.com/questions/39474726/how-to-check-if-user-is-connected-via-wifi-or-lan-through-hammerspoon


TP-Link neue MacAdresse suchen

- subType=pcSub; Authorization=Basic YWRtaW46TGlua1N5c1JvdXRlckFk; TPLoginTimes=1

Many Spoons:
https://github.com/roeybiran/.hammerspoon

AppQuitter
AppSpoonsManager
DownloadsWatcher
NotificationCenter
old overview here: https://github.com/roeybiran/.hammerspoon/tree/cb88fa5b0bc49a918c1aad81220e45f05c60ecc8


some other resources:

https://github.com/elliotwaite/hammerspoon-config


better inspect:
https://github.com/kikito/inspect.lua



example
https://github.com/braddevelop/hellfred
explanation: https://hackernoon.com/hellfred-or-how-i-learned-to-automate-macos-and-become-hellishly-productive

interessante utils functions
https://github.com/AdamWagner/stackline


find items with bonjour and control them (like Hue controller?)
https://github.com/evantravers/hammerspoon-config/blob/master/Spoons/ElgatoKey.spoon/init.lua


https://github.com/cmsj/hammerspoon-config/blob/master/hueMotionSensor.lua


-- Network connectivity watcher:function
-- https://gist.github.com/keithrbennett/103f57dfeb0c9346ee817825659fbf5a



other Spoons:
- check Camera and Mic with an icon in menubar
  - https://github.com/von/WatcherWatcher.spoon


add debug helper:

- https://github.com/von/homestuff/blob/main/home/dot_hammerspoon/config/console.lua

more settings examples:

- https://github.com/megalithic/dotfiles/tree/main/config/hammerspoon
- https://github.com/von/homestuff/tree/main/home/dot_hammerspoon
- spoons: 

KI :)
- https://github.com/andweeb/Ki/blob/master/docs/markdown/index.md

### Use ASCII Icons

https://web.archive.org/web/20161114153605/http://xqt2.com/asciiIcons.html

```lua
ampOffIcon = [[ASCII:
.....1a.....x....AC.y.......zE
..............................
......4.......................
1..........aA..........CE.....
e.2......4.3...........h......
..............................
..............................
.......................h......
e.2......6.3..........t..q....
5..........c..........s.......
......6..................q....
......................s..t....
...x.5c....y.......z..........
]]

local caffeine = hs.menubar.new()
caffeine:setIcon(ampOnIcon)

```