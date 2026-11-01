---
--- Created by muescha.
--- DateTime: 31.10.26
---
--- Window carousel: a list of windows placed side by side on one screen.
--- Concept: docs/2026-10-31-window-carousel-concept.md
---
--- No background tracking: closed windows and closed Chrome tabs are only
--- removed by `prune()`, which runs before every action and on `info()`.
---
--- Usage:
--- local carousel = require("Helpers.WindowCarousel").new({
---     screen = function() return hs.screen.find("5120x1440") end,
---     place = function(window, screen, unit) window:moveToScreen(screen); window:moveToUnit(unit) end,
---     keys = { add = "k", layout = "l", hide = "h", remove = "r", unload = "x" },
--- })
--- carousel:add(hs.window.focusedWindow())

---@class WindowCarouselKeys
---@field add string Key label for `add` in the info lines.
---@field layout string Key label for `show` in the info lines.
---@field hide string Key label for `hide` in the info lines.
---@field remove string Key label for `remove` in the info lines.
---@field unload string Key label for `unload` in the info lines.

---@class WindowCarouselOptions
---@field screen fun(): hs.screen|nil Returns the target screen.
---@field place fun(window: hs.window, screen: hs.screen, unit: hs.geometry) Moves a window to a unit rect on the screen.
---@field keys WindowCarouselKeys Key labels for the info lines.
---@field reserved? number Unit width kept free while there are at most `maxSmall` windows. Defaults to `1/6`.
---@field maxSmall? number Max windows that leave `reserved` free. Defaults to `5`.
---@field barWidth? number Characters of an info bar. Defaults to `36`.
---@field hiddenHeight? number Unit height of the windows after `hide`, placed at the bottom. Defaults to `1/3`.

---@class WindowCarouselEntry
---@field window hs.window
---@field tabId string|nil Chrome tab id remembered on `add`.

---@class WindowCarousel
---@field screen fun(): hs.screen|nil
---@field place fun(window: hs.window, screen: hs.screen, unit: hs.geometry)
---@field keys WindowCarouselKeys
---@field reserved number
---@field maxSmall number
---@field barWidth number
---@field hiddenHeight number
---@field height number Current unit height: `1` after `show`, `hiddenHeight` after `hide`.
---@field entries WindowCarouselEntry[]
local WindowCarousel = {}
WindowCarousel.__index = WindowCarousel

local chromeBundleID = "com.google.Chrome"
local unloadDelay = 0.3

---@param options WindowCarouselOptions
---@return WindowCarousel
function WindowCarousel.new(options)
    return setmetatable({
        screen = options.screen,
        place = options.place,
        keys = options.keys,
        reserved = options.reserved or (1 / 6),
        maxSmall = options.maxSmall or 5,
        barWidth = options.barWidth or 36,
        hiddenHeight = options.hiddenHeight or (1 / 3),
        height = 1,
        entries = {},
    }, WindowCarousel)
end

-- Chrome ----------------------------------------------------------------------

---@param window hs.window
---@return boolean
local function isChrome(window)
    local app = window:application()
    return app ~= nil and app:bundleID() == chromeBundleID
end

---Id of the active tab of Chrome's front window (= the focused window).
---@return string|nil
local function chromeActiveTabId()
    local ok, id = hs.osascript.applescript(
        'tell application id "' .. chromeBundleID .. '" to return id of active tab of front window')
    return ok and tostring(id) or nil
end

---Set of all Chrome tab ids, or nil when Chrome is not running or the query failed.
---@return table<string, boolean>|nil
local function chromeAllTabIds()
    if hs.application.get(chromeBundleID) == nil then
        return nil
    end

    local ok, windows = hs.osascript.applescript(
        'tell application id "' .. chromeBundleID .. '" to return id of every tab of every window')
    if not ok or type(windows) ~= "table" then
        return nil
    end

    local ids = {}
    for _, tabs in ipairs(windows) do
        for _, id in ipairs(type(tabs) == "table" and tabs or { tabs }) do
            ids[tostring(id)] = true
        end
    end
    return ids
end

-- List ------------------------------------------------------------------------

---@param window hs.window
---@return boolean
local function isAlive(window)
    local ok, role = pcall(function() return window:role() end)
    return ok and role ~= nil and role ~= ""
end

---@param window hs.window|nil
---@return number|nil
function WindowCarousel:indexOf(window)
    if window == nil then
        return nil
    end

    for i, entry in ipairs(self.entries) do
        if entry.window:id() == window:id() then
            return i
        end
    end
    return nil
end

---Remove entries whose window or remembered Chrome tab is gone.
function WindowCarousel:prune()
    local tabIds
    for _, entry in ipairs(self.entries) do
        if entry.tabId then
            tabIds = chromeAllTabIds()
            break
        end
    end

    local alive = {}
    for _, entry in ipairs(self.entries) do
        local tabGone = entry.tabId and tabIds and not tabIds[entry.tabId]
        if isAlive(entry.window) and not tabGone then
            alive[#alive + 1] = entry
        end
    end
    self.entries = alive
end

-- Layout ----------------------------------------------------------------------

---Unit width used for `count` windows.
---@param count number
---@return number
function WindowCarousel:areaWidth(count)
    return count <= self.maxSmall and (1 - self.reserved) or 1
end

---Place all windows with the current height, bring them to the front in list
---order and focus the last one.
---@param raise? boolean Bring to front and focus. Defaults to `true`.
function WindowCarousel:layout(raise)
    self:prune()

    local count = #self.entries
    if count == 0 then
        return
    end

    local screen = self.screen()
    if screen == nil then
        hs.alert.show("No screen available for the window carousel")
        return
    end

    local landscape = screen:rotate() == 0
    local size = self:areaWidth(count) / count
    local top = 1 - self.height

    for i, entry in ipairs(self.entries) do
        local start = (i - 1) * size
        local unit = landscape
            and hs.geometry.rect(start, top, size, self.height)
            or hs.geometry.rect(top, start, self.height, size)
        self.place(entry.window, screen, unit)
    end

    if raise == false then
        return
    end

    for _, entry in ipairs(self.entries) do
        entry.window:focus()
    end
end

-- Actions ---------------------------------------------------------------------

---Lay out with full height.
function WindowCarousel:show()
    self.height = 1
    self:layout()
end

---Lay out with `hiddenHeight` at the bottom, so windows behind stay reachable.
function WindowCarousel:hide()
    self.height = self.hiddenHeight
    self:layout()
end

---Add the window at the end of the list (or move it there) and lay out.
---@param window hs.window|nil
function WindowCarousel:add(window)
    if window == nil then
        return
    end

    self:prune()

    local index = self:indexOf(window)
    if index then
        table.remove(self.entries, index)
    end

    self.entries[#self.entries + 1] = {
        window = window,
        tabId = isChrome(window) and chromeActiveTabId() or nil,
    }

    self:layout()
end

---Take the window out of the list (it stays open) and lay out.
---@param window hs.window|nil
---@return boolean removed
function WindowCarousel:remove(window)
    self:prune()

    local index = self:indexOf(window)
    if index == nil then
        return false
    end

    table.remove(self.entries, index)
    self:layout()
    return true
end

---Take the window out of the list because it is placed elsewhere: the rest is
---placed again, but nothing is brought to front and the focus stays.
---@param window hs.window|nil
function WindowCarousel:forget(window)
    local index = self:indexOf(window)
    if index == nil then
        return
    end

    table.remove(self.entries, index)
    self:layout(false)
end

---Take the window out of the list, send Cmd+W to it and lay out.
---@param window hs.window|nil
function WindowCarousel:unload(window)
    self:prune()

    local index = self:indexOf(window)
    if window == nil or index == nil then
        return
    end

    table.remove(self.entries, index)
    window:focus()
    hs.eventtap.keyStroke({ "cmd" }, "w")

    hs.timer.doAfter(unloadDelay, function()
        self:layout()
    end)
end

-- Info ------------------------------------------------------------------------

---Text bar of `count` columns; `markers[i]` is drawn in the middle of column i.
---@param count number
---@param markers? table<number, string>
---@return string
function WindowCarousel:bar(count, markers)
    if count == 0 then
        return "–"
    end

    markers = markers or {}
    local reservedChars = math.floor(self.barWidth * self.reserved + 0.5)
    local areaChars = count <= self.maxSmall and (self.barWidth - reservedChars) or self.barWidth

    local parts = {}
    for i = 1, count do
        local from = math.floor((i - 1) * areaChars / count + 0.5)
        local to = math.floor(i * areaChars / count + 0.5)
        local inner = math.max(to - from - 2, 1)
        local marker = markers[i]
        local fill
        if marker then
            local left = math.floor((inner - 1) / 2)
            fill = ("─"):rep(left) .. marker .. ("─"):rep(inner - 1 - left)
        else
            fill = ("─"):rep(inner)
        end
        parts[#parts + 1] = "╞" .. fill .. "╡"
    end

    local text = table.concat(parts)
    if count <= self.maxSmall then
        local pad = math.max(reservedChars - 3, 0)
        local left = math.floor(pad / 2)
        text = text .. (" "):rep(left) .. "·c·" .. (" "):rep(pad - left)
    end
    return text
end

---Info lines for the modal help, relative to the focused window.
---@param window hs.window|nil
---@return string
function WindowCarousel:info(window)
    self:prune()

    local count = #self.entries
    local index = self:indexOf(window)
    local addCount = index and count or count + 1

    local function line(label, text)
        return ("%-11s %s"):format(label, text)
    end

    local function all(marker)
        local markers = {}
        for i = 1, count do
            markers[i] = marker
        end
        return markers
    end

    local function removeText(key)
        return index and self:bar(count, { [index] = key }) or "–"
    end

    local state = (count > 0 and self.height < 1) and "  (hidden)" or ""

    return table.concat({
        line("Carousel:", self:bar(count, index and { [index] = "●" } or nil) .. state),
        line("key " .. self.keys.add .. ":", self:bar(addCount, { [addCount] = self.keys.add })),
        line("key " .. self.keys.layout .. ":", self:bar(count, all("↻"))),
        line("key " .. self.keys.hide .. ":", self:bar(count, all("▁"))),
        line("key " .. self.keys.remove .. ":", removeText(self.keys.remove)),
        line("key " .. self.keys.unload .. ":", removeText(self.keys.unload) .. (index and "  (Cmd+W)" or "")),
    }, "\n")
end

return WindowCarousel
