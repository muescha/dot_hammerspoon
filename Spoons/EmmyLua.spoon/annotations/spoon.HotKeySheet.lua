--# selene: allow(unused_variable)
--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- Keybindings cheatsheet for current application
--
-- Download: https://github.com/muescha/dot_hammerspoon/tree/master/Spoons/HotKeySheet.spoon
---@class spoon.HotKeySheet
local M = {}
spoon.HotKeySheet = M

-- Binds hotkeys for HotKeySheet
--
-- Parameters:
--  * mapping - A table containing hotkey modifier/key details for the following items:
--   * show - Show the keybinding view
--   * hide - Hide the keybinding view
--   * toggle - Show if hidden, hide if shown
function M:bindHotkeys(mapping, ...) end

-- Hide the cheatsheet view.
function M:hide() end

-- Initialize the spoon
function M:init() end

-- Show current application's keybindings in a view.
function M:show() end

-- Alternatively show/hide the cheatsheet view.
function M:toggle() end

