--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- Show a fading-and-zooming image in the center of the screen
--
-- By default the Hammerspoon logo is shown. Typical use is to show it as an indicator when your configuration finishes loading, by adding the following to the bottom of your `~/.hammerspoon/init.lua` file:
-- ```
--   hs.loadSpoon('FadeLogo'):start()
-- ```
-- Which looks like this: http://imgur.com/a/TbZOl
--
-- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FadeLogo.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/FadeLogo.spoon.zip)
---@class spoon.FadeLogo
local M = {}
spoon.FadeLogo = M

-- Hide and delete the canvas
function M:delete() end

-- Number of seconds over which to fade in the image. Defaults to 0.3.
M.fade_in_time = nil

-- Number of seconds over which to fade out the image. Defaults to 0.5.
M.fade_out_time = nil

-- Hide the image without zoom, fading it out over `fade_out_time` seconds
function M:hide() end

-- Image to display. Must be an `hs.image` object. Defaults to `hs.image.imageFromName(hs.image.systemImageNames.ApplicationIcon)` (the Hammerspoon app icon)
M.image = nil

-- Initial transparency of the image. Defaults to 1.0.
M.image_alpha = nil

-- `hs.geometry` object specifying the initial size of the image to display in the center of the screen. The image object will be resizes proportionally to fit in this size. Defaults to `hs.geometry.size(w=200, h=200)`
M.image_size = nil

-- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
M.logger = nil

-- Number of seconds to leave the image on the screen when `start()` is called.
M.run_time = nil

-- Display the image, fading it in over `fade_in_time` seconds
function M:show() end

-- Show the image, wait `run_time` seconds, and then zoom-and-fade it out.
function M:start() end

-- Do zoom-and-fade if `true`, otherwise do a regular fade
M.zoom = nil

-- Zoom-and-fade the image over `fade_out_time` seconds
function M:zoom_and_fade() end

-- Factor by which to scale the image at every iteration during the zoom-and-fade. Defaults to 1.1.
M.zoom_scale_factor = nil

-- Seconds between the zooming iterations
M.zoom_scale_timer = nil

