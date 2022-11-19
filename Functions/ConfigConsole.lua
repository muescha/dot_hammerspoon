-- Configure console

hs.console.darkMode(false)
hs.console.consoleFont({ name = "Fira Code", size = 18 })
-- Alpha == transparency. 0 = fully transparent, 1 = fully opaque
hs.console.alpha(0.9)

local colors = hs.drawing.color.definedCollections
--hs.console.outputBackgroundColor(colors.hammerspoon.white)
--hs.console.inputBackgroundColor(colors.hammerspoon.white)
--hs.console.consoleCommandColor(colors.hammerspoon.black)
--hs.console.consoleResultColor(colors.x11.lightgreen)
--hs.console.consolePrintColor(colors.x11.black)

-- hs.hotkey.setLogLevel("warning")
