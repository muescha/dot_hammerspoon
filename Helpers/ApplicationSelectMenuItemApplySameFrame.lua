---lua
-- Applies the previous window frame after triggering a menu item that opens/moves a window.
-- Usage: windowApplyFrameAfterMenu({ "German name", "English name" }, { timeout=3, interval=0.05, alertPrefix="..." })
-- - menuItemNames: array of possible localized menu titles
-- - options (optional):
--     timeout  (seconds, default 3)
--     interval (seconds, default 0.05)
--     alertPrefix (string, optional)
-- Returns: true on trigger, false on early failure
function applicationSelectMenuItemApplySameFrame(menuItemNames, options)
    options = options or {}
    local timeout  = options.timeout or 3
    local interval = options.interval or 0.05
    local alertPrefix = options.alertPrefix or ""

    local function alert(msg)
        if alertPrefix ~= "" then
            hs.alert.show(alertPrefix .. ": " .. msg)
        else
            hs.alert.show(msg)
        end
    end

    local app = hs.application.frontmostApplication()
    if not app then
        alert("No active application found.")
        return false
    end

    local winBefore = hs.window.focusedWindow()
    if not winBefore then
        alert("No active window found.")
        return false
    end

    local frameBefore = winBefore:frame()
    local appPid = app:pid()

    -- Try all provided (localized) menu item names
    local triggered = false
    for _, name in ipairs(menuItemNames) do
        if app:selectMenuItem(name) then
            triggered = true
            break
        end
    end
    if not triggered then
        alert("Menu item not available.")
        return false
    end

    -- Wait until a window of the same app is focused, then restore the frame
    hs.timer.waitUntil(
        function()
            local win = hs.window.focusedWindow()
            return win ~= nil
                and win:application() ~= nil
                and win:application():pid() == appPid
        end,
        function()
            local win = hs.window.focusedWindow()
            if not win then
                alert("New window not found.")
                return
            end
            local ok, err = pcall(function()
                win:setFrame(frameBefore)
            end)
            if not ok then
                alert("Failed to set window frame: " .. tostring(err))
            end
        end,
        interval,
        timeout
    )

    return true
end
