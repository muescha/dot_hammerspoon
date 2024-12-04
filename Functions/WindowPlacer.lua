---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 26.01.23 02:12
---

--- done with ChatGPT :)
--- can you write me an hammerspoon lua script where i can place a window on
--- main screen on macbook and the other one on halfscreen (top and bottom)
--- of my portrait mode external monitor.
---
--- can it done more generic for the external monitor, so that it find out by
--- self if a monitor external, and if it is in portrait mode it should place
--- on top or bottom and if it is in landscape mode it should be placed on left and right

fileInfo()

local units = require("hs.geometry").rect

debugTable(hs.screen.allScreens())

local function to_unit(values, rotate)
    if rotate then
        return units(values[1], 0, values[2], 1 )
    else
        return units(0, values[1], 1, values[2] )
    end
end

local layout_setup = {
    ["1"] = {  0, 1/3, "+==1==+-----+-----+"},
    ["2"] = {1/3, 1/3, "+-----+==2==+-----+"},
    ["3"] = {2/3, 1/3, "+-----+-----+==3==+"},
    ["4"] = {  0,   1, "+========4========+"},
    ["5"] = {  0, 2/3, "+=====5=====+-----+"},
    ["6"] = {1/3, 2/3, "+-----+=====6=====+"},
    ["7"] = {  0, 1/2, "+=====7==+--------+"},
    ["8"] = {1/2, 1/2, "+--------+==8=====+"},
}
local layout_keys = {
    maximize = "4",
    top = "7",
    bottom = "8",
    udemy = "6"
}

-- TODO make this as config
local screens = {
    internal = "Built%-in",
    monitor_1 = 'Thunderbolt',
    monitor_2 = '5120x1440'
}

local layout = { ["portrait"] = {}, ["landscape"] = {}}
local layout_info = "Layout: "

local sortedLayoutSetupIterator = helper.table.sortByKeyIterator(layout_setup)
for i, v in sortedLayoutSetupIterator do
    layout["portrait"][i] = to_unit(v, false)
    layout["landscape"][i] = to_unit(v, true)
    layout_info = layout_info .. "\n key "..i..": " .. v[3]:gsub("-"," "):gsub("+"," ")
end

local function windowMoveToKey(screenId, key)
    local screen = hs.screen.find(screenId)
    if screen == nil then hs.alert.show('No screen available for keyword: ' .. screenId) return end
    local window = hs.window.focusedWindow()
    local direction = (screen:rotate()==0) and "landscape" or "portrait"
    local newUnit = layout[direction][key]

    window:moveToScreen(screen)
    window:moveToUnit(newUnit)
end

debugInfo(layout_info)

local function startFn()
    local window = hs.window.frontmostWindow()
    hs.alert.show(layout_info, { textFont = "Menlo"}, window, 'do-not-close')
end

local function exitFn ()
    hs.alert.closeAll()
end

local hkbm = hotkeybindmodal(hyper, "w", keyInfo("place on Big Monitor "), startFn, exitFn)

for key, _ in pairs(layout_setup) do

    local move = function()
        windowMoveToKey(screens.monitor_2, key)
        hkbm:exit()
    end

    hkbm:bind({}, key, move)
    hkbm:bind(hyper, key, move)
end

hs.hotkey.bind(hyper, "3", keyInfo("place on main screen"), function()
    windowMoveToKey(screens.internal,layout_keys.maximize)
end)

hs.hotkey.bind(hyper, "4", keyInfo("place fullscreen on monitor"), function()
    windowMoveToKey(screens.monitor_1,layout_keys.maximize)
end)

hs.hotkey.bind(hyper, "8", keyInfo("place 2/3 on monitor (Udemy Mode)"), function()
    windowMoveToKey(screens.monitor_1,layout_keys.udemy)
end)

hs.hotkey.bind(hyper, "1", keyInfo("place on one half of monitor"), function()
    windowMoveToKey(screens.monitor_1,layout_keys.top)
end)

hs.hotkey.bind(hyper, "2", keyInfo("place on other half of monitor"), function()
    windowMoveToKey(screens.monitor_1,layout_keys.bottom)
end)
