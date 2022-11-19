--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- With this script you will be able to move the window in halves and in corners using your keyboard and mainly using arrows. You would also be able to resize them by thirds, quarters, or halves.
--
-- Official homepage for more info and documentation: [https://github.com/miromannino/miro-windows-manager](https://github.com/miromannino/miro-windows-manager)
--
-- Download: [https://github.com/miromannino/miro-windows-manager/raw/master/MiroWindowsManager.spoon.zip](https://github.com/miromannino/miro-windows-manager/raw/master/MiroWindowsManager.spoon.zip)
---@class spoon.MiroWindowsManager
local M = {}
spoon.MiroWindowsManager = M

-- The screen's size using `hs.grid.setGrid()`
-- This parameter is used at the spoon's `:init()`
M.GRID = nil

-- The sizes that the window can have in full-screen.
-- The sizes are expressed as dividend of the entire screen's size.
-- For example `{1, 4/3, 2}` means that it can be 1/1 (hence full screen), 3/4 and 1/2 of the total screen's size
M.fullScreenSizes = nil

-- The sizes that the window can have.
-- The sizes are expressed as dividend of the entire screen's size.
-- For example `{2, 3, 3/2}` means that it can be 1/2, 1/3 and 2/3 of the total screen's size
M.sizes = nil

-- Binds hotkeys for Miro's Windows Manager
-- Parameters:
--  * mapping - A table containing hotkey details for the following items:
--   * up: for the up action (usually {hyper, "up"})
--   * right: for the right action (usually {hyper, "right"})
--   * down: for the down action (usually {hyper, "down"})
--   * left: for the left action (usually {hyper, "left"})
--   * fullscreen: for the full-screen action (e.g. {hyper, "f"})
--
-- A configuration example can be:
-- ```
-- local hyper = {"ctrl", "alt", "cmd"}
-- spoon.MiroWindowsManager:bindHotkeys({
--   up = {hyper, "up"},
--   right = {hyper, "right"},
--   down = {hyper, "down"},
--   left = {hyper, "left"},
--   fullscreen = {hyper, "f"}
-- })
-- ```
function M:bindHotkeys() end

