--# selene: allow(unused_variable)
---@diagnostic disable: unused-local

-- A spoon that let you bind sequential bindings.
-- It also (optionally) shows a bar about current keys bindings.
--
-- [Click to download](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/RecursiveBinder.spoon.zip)
---@class spoon.RecursiveBinder
local M = {}
spoon.RecursiveBinder = M

-- key to abort, default to {keyNone, 'escape'}
M.escapeKey = nil

-- Number of entries each line of helper. Default to 5.
M.helperEntryEachLine = nil

-- Length of each entry in char. Default to 20.
M.helperEntryLengthInChar = nil

-- format of helper, the helper is just a hs.alert
-- default to {atScreenEdge=2,
--             strokeColor={ white = 0, alpha = 2 },
--             textFont='SF Mono'
--             textSize=20}
M.helperFormat = nil

-- The mapping used to display modifiers on helper.
-- Default to {
--  command = '⌘',
--  control = '⌃',
--  option = '⌥',
--  shift = '⇧',
-- }
function M.helperModifierMapping() end

-- Bind sequential keys by a nested keymap.
--
-- Parameters:
--  * keymap - A table that specifies the mapping.
--
-- Returns:
--  * A function to start. Bind it to a initial key binding.
--
-- Note:
-- Spec of keymap:
-- Every key is of format {{modifers}, key, (optional) description}
-- The first two element is what you usually pass into a hs.hotkey.bind() function.
--
-- Each value of key can be in two form:
-- 1. A function. Then pressing the key invokes the function
-- 2. A table. Then pressing the key bring to another layer of keybindings.
--    And the table have the same format of top table: keys to keys, value to table or function
function M.recursiveBind(keymap, ...) end

-- whether to show helper, can be true of false
function M.showBindHelper() end

-- this function simply return a table with empty modifiers also it translates capital letters to normal letter with shift modifer
--
-- Parameters:
--  * key - a letter
--  * name - the description to pass to the keys binding function
--
-- Returns:
--  * a table of modifiers and keys and names, ready to be used in keymap
--    to pass to RecursiveBinder.recursiveBind()
function M.singleKey(key, name, ...) end

