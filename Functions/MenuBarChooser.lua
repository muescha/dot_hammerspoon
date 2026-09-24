local axuielement = require("hs.axuielement")
local canvas = require("hs.canvas")

local chooser = nil
local scanTimer = nil
local progressHud = nil
local debugLoggedElementCount = 0

local SCAN_CONFIG = {
    intervalSeconds = 0.002,
    showChooserDuringScan = true,
    deferChooserItemsUntilScanComplete = false,
    choiceSortMode = "queryScore", -- discovery | score | queryScore
    negativeAppCacheTtlSeconds = 180
}

local CHOOSER_LAYOUT = {
    widthPercent = 60,
    maxWidth = 1400,
    rows = 20,
    hudOverlayOnChooser = false,
    hudPlacement = "searchRight", -- above | searchRight
    hudHeight = 48,
    hudGap = 8,
    topMarginLandscape = 120
}

local ICON_CONFIG = {
    snapshotMode = "off", -- off | all
    snapshotPadding = 2,
    snapshotSize = 18,
    snapshotWideAspectLimit = 2.2,
    snapshotCornerRadius = 4
}

local DEBUG = {
    verboseAxDumps = false,
    cacheLogs = false,
    scanSummaryLogs = false,
    discoveredItemLogs = false,
    axTreeLogs = false,
    iconLogs = false
}

local PERF_CONFIG = {
    enabled = true,
    slowAppThresholdMs = 20,
    slowItemThresholdMs = 10,
    maxSlowEntries = 10,
    semanticTraceThresholdMs = 20,
    semanticTraceMaxLabels = 12,
    metadataTraceThresholdMs = 1,
    metadataTraceValueMaxLength = 80,
    logToFile = true,
    logDir = hs.configdir .. "/Logs",
    logFileName = "MenuBarChooser.log"
}

local SEMANTIC_NAME_INFER_EXCLUDED_APPS = {
    ["com.apple.TextInputMenuAgent"] = true,
    TextInputMenuAgent = true
}

local function newTTLCache(defaultTTLSeconds)
    local store = {}

    local function now()
        return os.time()
    end

    return {
        get = function(_, key)
            local entry = store[key]
            if not entry then
                return nil
            end
            if entry.expiresAt and entry.expiresAt <= now() then
                store[key] = nil
                return nil
            end
            return entry.value
        end,
        set = function(_, key, value, ttlSeconds)
            local ttl = ttlSeconds
            if ttl == nil then
                ttl = defaultTTLSeconds
            end
            store[key] = {
                value = value,
                expiresAt = ttl and (now() + ttl) or nil
            }
            return value
        end,
        delete = function(_, key)
            store[key] = nil
        end,
        clear = function(_)
            store = {}
        end
    }
end

local negativeAppCache = newTTLCache(SCAN_CONFIG.negativeAppCacheTtlSeconds)
local NEGATIVE_APP_CACHE_MISS = "__no_menu_extras__"

local function debugLog(flag, message, ...)
    if flag then
        hs.printf(message, ...)
    end
end

local function logCache(message, ...)
    debugLog(DEBUG.cacheLogs, message, ...)
end

local function logScan(message, ...)
    debugLog(DEBUG.scanSummaryLogs, message, ...)
end

local function logDiscoveredItem(message, ...)
    debugLog(DEBUG.discoveredItemLogs, message, ...)
end

local function logIcon(message, ...)
    debugLog(DEBUG.iconLogs, message, ...)
end

local function perfNow()
    return hs.timer.secondsSinceEpoch()
end

local function perfElapsedMs(startedAt)
    return (perfNow() - startedAt) * 1000
end

local function newPerfStats()
    if not PERF_CONFIG.enabled then
        return nil
    end

    return {
        startedAt = perfNow(),
        phases = {},
        slowApps = {},
        slowItems = {}
    }
end

local function perfAdd(perf, phaseName, elapsedMs)
    if not perf then
        return
    end

    perf.phases[phaseName] = (perf.phases[phaseName] or 0) + elapsedMs
end

local function perfCount(perf, counterName, amount)
    if not perf then
        return
    end

    perf[counterName] = (perf[counterName] or 0) + (amount or 1)
end

local function perfRecordSlowEntry(entries, thresholdMs, entry)
    if entry.elapsedMs < thresholdMs then
        return
    end

    table.insert(entries, entry)
end

local function perfRecordSlowApp(perf, app, phaseName, elapsedMs)
    if not perf then
        return
    end

    perfRecordSlowEntry(perf.slowApps, PERF_CONFIG.slowAppThresholdMs, {
        appName = app:name() or app:bundleID() or "<unknown>",
        bundleID = app:bundleID() or "",
        phaseName = phaseName,
        elapsedMs = elapsedMs
    })
end

local function perfRecordSlowItem(perf, app, label, phaseName, elapsedMs)
    if not perf then
        return
    end

    perfRecordSlowEntry(perf.slowItems, PERF_CONFIG.slowItemThresholdMs, {
        appName = app:name() or app:bundleID() or "<unknown>",
        label = label or "-",
        phaseName = phaseName,
        elapsedMs = elapsedMs
    })
end

local function perfTopEntries(entries)
    table.sort(entries, function(a, b)
        return a.elapsedMs > b.elapsedMs
    end)

    local topEntries = {}
    local limit = math.min(#entries, PERF_CONFIG.maxSlowEntries)
    for index = 1, limit do
        table.insert(topEntries, entries[index])
    end
    return topEntries
end

local function perfFormatPhases(phases)
    local names = {}
    for name, _ in pairs(phases) do
        table.insert(names, name)
    end
    table.sort(names)

    local parts = {}
    for _, name in ipairs(names) do
        table.insert(parts, string.format("%s=%.1fms", name, phases[name]))
    end
    return table.concat(parts, " ")
end

local function perfLogFilePath()
    return PERF_CONFIG.logDir .. "/" .. PERF_CONFIG.logFileName
end

local function perfWriteLogLine(line, mode)
    if not PERF_CONFIG.enabled or not PERF_CONFIG.logToFile then
        return
    end

    local ok, err = pcall(function()
        hs.fs.mkdir(PERF_CONFIG.logDir)
        local file = assert(io.open(perfLogFilePath(), mode or "a"))
        file:write(os.date("%Y-%m-%d %H:%M:%S"), " ", line, "\n")
        file:close()
    end)

    if not ok then
        hs.printf("[MenuBarChooser][perf] failed to write log file: %s", tostring(err))
    end
end

local function perfResetLogFile()
    if not PERF_CONFIG.enabled or not PERF_CONFIG.logToFile then
        return
    end

    local ok, err = pcall(function()
        hs.fs.mkdir(PERF_CONFIG.logDir)
        local file = assert(io.open(perfLogFilePath(), "w"))
        file:close()
    end)

    if not ok then
        hs.printf("[MenuBarChooser][perf] failed to reset log file: %s", tostring(err))
    end
end

local function perfLog(message, ...)
    local line = string.format(message, ...)
    hs.printf("%s", line)
    perfWriteLogLine(line)
end

local function perfLogSummary(perf, scannedCount, foundAppsCount, foundItemsCount)
    if not perf then
        return
    end

    local totalMs = perfElapsedMs(perf.startedAt)
    perfLog(
            "[MenuBarChooser][perf] total=%.1fms apps=%d matchedApps=%d items=%d phases: %s",
            totalMs,
            scannedCount,
            foundAppsCount,
            foundItemsCount,
            perfFormatPhases(perf.phases)
    )

    local slowApps = perfTopEntries(perf.slowApps)
    for index, entry in ipairs(slowApps) do
        perfLog(
                "[MenuBarChooser][perf] slow app #%d %.1fms phase=%s app=%s bundle=%s",
                index,
                entry.elapsedMs,
                entry.phaseName,
                entry.appName,
                entry.bundleID
        )
    end

    local slowItems = perfTopEntries(perf.slowItems)
    for index, entry in ipairs(slowItems) do
        perfLog(
                "[MenuBarChooser][perf] slow item #%d %.1fms phase=%s app=%s item=%s",
                index,
                entry.elapsedMs,
                entry.phaseName,
                entry.appName,
                entry.label
        )
    end
end

perfResetLogFile()

local function safeApplicationPath(app)
    local ok, path = pcall(function()
        return app:path()
    end)
    if ok then
        return path
    end
    return nil
end

local function appCacheKey(app)
    return app:bundleID() or safeApplicationPath(app) or app:name()
end

local function appIdentity(app)
    return {
        bundleID = app:bundleID() or "",
        appName = app:name() or ""
    }
end

local function shouldSkipNegativeAppCache(app)
    local identity = appIdentity(app)

    return identity.bundleID == "com.apple.controlcenter"
            or identity.bundleID == "com.apple.systemuiserver"
            or identity.bundleID == "com.apple.TextInputMenuAgent"
            or identity.appName == "Kontrollzentrum"
            or identity.appName == "Control Center"
            or identity.appName == "SystemUIServer"
            or identity.appName == "TextInputMenuAgent"
end

-- Legacy / exploratory debug helpers
local function printChildren(application, children, recursive)
    if not DEBUG.axTreeLogs then
        return
    end

    for _, child in ipairs(children) do
        debugElement(child,"child")
        print(application:name())
        print(child.AXRoleDescription)
        debugMenuItem(application, child, "child")
        local role = child:attributeValue("AXRole")
        local subrole = child:attributeValue("AXSubrole")

        if role == "AXMenuBarItem" and subrole == "AXMenuExtra" then
            print("Found NSAccessibilityMenuExtrasMenuBar for application:", application:name())
            --return child
        end

        if recursive then
            local childs = child:attributeValue("AXChildren")
            debugTable(childs)
            if childs then
                printChildren(application, childs)
            end
        end
    end
end

local function findMenuExtrasMenuBarForApplication(app)
    local bundleID = app:bundleID()
    if bundleID == "com.apple.WebKit.WebContent" then
        return nil
    end

    local cacheKey = appCacheKey(app)
    local canUseNegativeCache = cacheKey and not shouldSkipNegativeAppCache(app)
    if canUseNegativeCache then
        local cachedValue = negativeAppCache:get(cacheKey)
        if cachedValue == NEGATIVE_APP_CACHE_MISS then
            logCache("[MenuBarChooser][cache] HIT negative %s", cacheKey)
            return nil
        end
        logCache("[MenuBarChooser][cache] MISS %s", cacheKey)
    end

    local appElement = axuielement.applicationElement(app)
    --debugElement(appElement,"appElement")
    if appElement then
        -- Get the menu bar element
        local menuBar = appElement:attributeValue("AXExtrasMenuBar")
        --debugElement(menuBar,"menuBar")
        if menuBar then
            if canUseNegativeCache then
                negativeAppCache:delete(cacheKey)
                logCache("[MenuBarChooser][cache] DELETE negative %s", cacheKey)
            end
            return menuBar
            --local children = menuBar:attributeValue("AXChildren")
            --debugTable(children, "children")
            --if children then
            --    --printChildren(application, children)
            --end
            --return children
        end
    end

    if canUseNegativeCache then
        negativeAppCache:set(cacheKey, NEGATIVE_APP_CACHE_MISS)
        logCache("[MenuBarChooser][cache] STORE negative %s", cacheKey)
    end

    return nil
end

local function printMenuItems(menuItems)
    -- Iterate over bigTable and run the method for each item
    for _, menu in ipairs(menuItems) do
        for _, item in ipairs(menu.children) do
            debugMenuItem(menu.app, item)
        end
    end
end


local FuzzyMatcher = require("Helpers.FuzzyMatcher")

local function stopScanTimer()
    if scanTimer then
        scanTimer:stop()
        scanTimer = nil
    end
end

local function hideProgressHud()
    if progressHud then
        progressHud:hide()
        progressHud:delete()
        progressHud = nil
    end
end

local function chooserWidthPercentForScreen(screenFrame)
    local cappedPercent = (CHOOSER_LAYOUT.maxWidth / screenFrame.w) * 100
    return math.min(CHOOSER_LAYOUT.widthPercent, cappedPercent)
end

local function chooserWidthForScreen(screenFrame)
    return math.min(
            math.floor(screenFrame.w * (CHOOSER_LAYOUT.widthPercent / 100)),
            CHOOSER_LAYOUT.maxWidth
    )
end

local function chooserHeight()
    return 88 + (CHOOSER_LAYOUT.rows * 22)
end

local function chooserYForScreen(screenFrame, currentChooserHeight)
    if screenFrame.h > screenFrame.w then
        return math.floor(screenFrame.y + (screenFrame.h - currentChooserHeight) / 2)
    end

    return math.floor(screenFrame.y + CHOOSER_LAYOUT.topMarginLandscape)
end

local function chooserFrameForScreen(screenFrame)
    local width = chooserWidthForScreen(screenFrame)
    local height = chooserHeight()

    return {
        x = math.floor(screenFrame.x + (screenFrame.w - width) / 2),
        y = chooserYForScreen(screenFrame, height),
        w = width,
        h = height
    }
end

local function progressHudFrame()
    local screenFrame = hs.screen.mainScreen():frame()
    local chooserFrame = chooserFrameForScreen(screenFrame)
    local hudHeight = CHOOSER_LAYOUT.hudHeight

    if CHOOSER_LAYOUT.hudPlacement == "searchRight" then
        local inset = 18
        local width = math.floor((chooserFrame.w / 2) - inset)
        return {
            x = math.floor(chooserFrame.x + chooserFrame.w - width - inset),
            y = math.floor(chooserFrame.y + 14),
            w = width,
            h = hudHeight
        }
    end

    local y = chooserFrame.y - hudHeight - CHOOSER_LAYOUT.hudGap
    if y < screenFrame.y + 8 then
        y = chooserFrame.y + chooserFrame.h + CHOOSER_LAYOUT.hudGap
    end

    return {
        x = chooserFrame.x,
        y = math.floor(y),
        w = chooserFrame.w,
        h = hudHeight
    }
end

local function ensureProgressHud()
    if progressHud then
        return progressHud
    end

    local frame = progressHudFrame()
    local innerWidth = frame.w - 24
    local barY = frame.h - 8

    progressHud = canvas.new(frame)
    progressHud:level(hs.canvas.windowLevels.overlay)
    progressHud[1] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 10, yRadius = 10 },
        fillColor = { alpha = 0.94, white = 0.96 },
        strokeColor = { alpha = 0.18, white = 0.42 },
        strokeWidth = 1
    }
    progressHud[2] = {
        type = "rectangle",
        action = "fill",
        fillColor = { alpha = 0, white = 1 },
        frame = { x = 0, y = 0, w = 0, h = 0 }
    }
    progressHud[3] = {
        type = "text",
        text = "",
        textSize = 1,
        textColor = { white = 0, alpha = 0 },
        frame = { x = 0, y = 0, w = 0, h = 0 }
    }
    progressHud[4] = {
        type = "rectangle",
        action = "fill",
        fillColor = { alpha = 0, white = 1 },
        frame = { x = 0, y = 0, w = 0, h = 0 }
    }
    progressHud[5] = {
        type = "text",
        text = "",
        textSize = 15,
        textColor = { white = 0.10, alpha = 1 },
        frame = { x = 10, y = 4, w = innerWidth - 64, h = 18 }
    }
    progressHud[6] = {
        type = "text",
        text = "0%",
        textSize = 12,
        textColor = { white = 0.36, alpha = 1 },
        frame = { x = frame.w - 54, y = 6, w = 44, h = 16 }
    }
    progressHud[7] = {
        type = "rectangle",
        action = "fill",
        fillColor = { alpha = 0, white = 1 },
        frame = { x = 0, y = 0, w = 0, h = 0 }
    }
    progressHud[8] = {
        type = "text",
        text = "",
        textSize = 1,
        textColor = { white = 0, alpha = 0 },
        frame = { x = 0, y = 0, w = 0, h = 0 }
    }
    progressHud[9] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
        fillColor = { white = 0.72, alpha = 0.20 },
        frame = { x = 10, y = barY, w = frame.w - 20, h = 4 }
    }
    progressHud[10] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
        fillColor = { red = 0.24, green = 0.48, blue = 0.98, alpha = 0.92 },
        frame = { x = 10, y = barY, w = 0, h = 4 }
    }
    progressHud[11] = {
        type = "text",
        text = "",
        textSize = 12,
        textColor = { white = 0.42, alpha = 1 },
        frame = { x = 10, y = 23, w = innerWidth, h = 14 }
    }
    progressHud:show()
    return progressHud
end

local function addMenuItem(selectionMap, value)
    selectionMap.menuItemsCounter = selectionMap.menuItemsCounter + 1
    local key = tostring(selectionMap.menuItemsCounter)
    local menuItems = selectionMap.menuItems
    menuItems[key] = value
    return key
end

local function safeAttributeValue(item, attributeName)
    local ok, value = pcall(function()
        return item:attributeValue(attributeName)
    end)
    if ok then
        return value
    end
    return nil
end

local function cleanValue(value)
    if value == nil then
        return nil
    end

    if type(value) == "string" then
        local trimmed = value:match("^%s*(.-)%s*$")
        if trimmed == "" then
            return nil
        end
        return trimmed
    end

    if type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    end

    return nil
end

local function itemMetadataValue(item, attributeName)
    local shortcutValue = cleanValue(item[attributeName])
    if shortcutValue then
        return shortcutValue
    end

    return cleanValue(safeAttributeValue(item, attributeName))
end

local function firstNonEmptyAttributeValue(item, ...)
    for i = 1, select("#", ...) do
        local value = cleanValue(safeAttributeValue(item, select(i, ...)))
        if value then
            return value
        end
    end
    return nil
end

local function sortActionNames(names)
    if not names then
        return {}
    end
    table.sort(names, function(a, b)
        if a == "AXPress" then
            return true
        end
        if b == "AXPress" then
            return false
        end
        return a < b
    end)
    return names
end

local function joinedActionNames(names)
    if not names or #names == 0 then
        return "-"
    end
    return table.concat(names, ", ")
end

local function isControlCenterApp(app)
    local identity = appIdentity(app)
    return identity.bundleID == "com.apple.controlcenter"
            or identity.appName == "Kontrollzentrum"
            or identity.appName == "Control Center"
end

local function isGenericHostApp(app)
    local identity = appIdentity(app)
    return identity.bundleID == "com.apple.TextInputMenuAgent"
            or identity.bundleID == "com.apple.systemuiserver"
            or identity.appName == "TextInputMenuAgent"
            or identity.appName == "SystemUIServer"
end

local function shouldInferSemanticName(app)
    local identity = appIdentity(app)
    if SEMANTIC_NAME_INFER_EXCLUDED_APPS[identity.bundleID]
            or SEMANTIC_NAME_INFER_EXCLUDED_APPS[identity.appName] then
        return false
    end

    return isGenericHostApp(app)
end

local function shouldDebugFullDump(app)
    return DEBUG.verboseAxDumps and isControlCenterApp(app)
end

local function choosePrimaryAction(names)
    local sortedNames = sortActionNames(names)
    return sortedNames[1], sortedNames
end

local function isGenericDescription(value)
    local cleaned = cleanValue(value)
    if not cleaned then
        return true
    end

    local normalized = string.lower(cleaned)
    return normalized == "statusmenü"
            or normalized == "status menu"
            or normalized == "menu extra"
end

local function isWeakLabelValue(value)
    local cleaned = cleanValue(value)
    if not cleaned then
        return true
    end

    local normalized = string.lower(cleaned)
    if isGenericDescription(cleaned) then
        return true
    end

    if normalized == "<none>" or normalized == "= <none>" then
        return true
    end

    return false
end

local function preferredLabelValue(...)
    for i = 1, select("#", ...) do
        local value = cleanValue(select(i, ...))
        if value and not isWeakLabelValue(value) then
            return value
        end
    end
    return nil
end

local function appendSummaryDetail(parts, value)
    local cleaned = cleanValue(value)
    if cleaned and not isGenericDescription(cleaned) then
        table.insert(parts, cleaned)
    end
end

local function stripTrailingDots(value)
    local cleaned = cleanValue(value)
    if not cleaned then
        return nil
    end

    cleaned = cleaned:gsub("%s*[%.…]+$", "")
    return cleanValue(cleaned)
end

local function deriveGenericNameFromMenuLabel(label)
    local cleaned = stripTrailingDots(label)
    if not cleaned then
        return nil
    end

    local subject = cleaned:match("^[Oo]pen%s+(.+)%s+[Ss]ettings$")
            or cleaned:match("^[Oo]pen%s+(.+)%s+[Pp]references$")
    if not subject then
        local lower = string.lower(cleaned)
        local germanStart = lower:find("einstellungen öffnen", 1, true)
        if germanStart and germanStart > 1 then
            subject = cleaned:sub(1, germanStart - 1)
        end
    end
    if not subject then
        return nil
    end

    subject = subject:gsub("[%s%-%–%—%:%·]+$", "")
    return cleanValue(subject)
end

local function fallbackDisplayAppName(app)
    local identity = appIdentity(app)
    if identity.bundleID == "com.apple.TextInputMenuAgent" or identity.appName == "TextInputMenuAgent" then
        return "Tastatur"
    end
    if identity.bundleID == "com.apple.systemuiserver" or identity.appName == "SystemUIServer" then
        return "Systemstatus"
    end
    return app:name()
end

local function inferSemanticNameFromMenu(item)
    local trace = {
        menus = 0,
        menuItems = 0,
        labels = {}
    }

    local children = safeAttributeValue(item, "AXChildren")
    if not children or #children == 0 then
        return nil, trace
    end

    for _, child in ipairs(children) do
        if safeAttributeValue(child, "AXRole") == "AXMenu" then
            trace.menus = trace.menus + 1
            local menuItems = safeAttributeValue(child, "AXChildren")
            if menuItems and #menuItems > 0 then
                trace.menuItems = trace.menuItems + #menuItems
                for index = #menuItems, 1, -1 do
                    local menuLabel = firstNonEmptyAttributeValue(menuItems[index], "AXTitle", "AXDescription", "AXValue")
                    if #trace.labels < PERF_CONFIG.semanticTraceMaxLabels then
                        table.insert(trace.labels, string.format("#%d=%s", index, menuLabel or "<empty>"))
                    end
                    local genericName = deriveGenericNameFromMenuLabel(menuLabel)
                    if genericName then
                        trace.matched = genericName
                        return genericName, trace
                    end
                end
            end
        end
    end

    return nil, trace
end

local function perfLogSemanticTrace(app, itemLabel, elapsedMs, trace)
    if not trace or elapsedMs < PERF_CONFIG.semanticTraceThresholdMs then
        return
    end

    local labels = table.concat(trace.labels or {}, " | ")
    if trace.menuItems and trace.menuItems > #(trace.labels or {}) then
        labels = labels .. string.format(" | ... +%d more", trace.menuItems - #trace.labels)
    end

    perfLog(
            "[MenuBarChooser][perf] semantic trace %.1fms app=%s bundle=%s item=%s menus=%d menuItems=%d matched=%s labels=%s",
            elapsedMs,
            app:name() or app:bundleID() or "<unknown>",
            app:bundleID() or "",
            itemLabel or "-",
            trace.menus or 0,
            trace.menuItems or 0,
            trace.matched or "-",
            labels ~= "" and labels or "-"
    )
end

local function isZeroSizedFrame(item)
    local frame = safeAttributeValue(item, "AXFrame")
    if type(frame) ~= "table" then
        return false
    end

    return (frame.w or 0) == 0 or (frame.h or 0) == 0
end

local function shouldSkipMenuItem(app, item, names)
    if not names or #names == 0 then
        return true
    end

    if not isControlCenterApp(app) then
        return false
    end

    local identifier = itemMetadataValue(item, "AXIdentifier")
    local enabled = safeAttributeValue(item, "AXEnabled")

    if identifier then
        return false
    end

    if enabled == false then
        return true
    end

    if isZeroSizedFrame(item) then
        return true
    end

    return false
end

local function screenContainingFrame(frame)
    if type(frame) ~= "table" then
        return nil
    end

    local centerX = (frame.x or 0) + ((frame.w or 0) / 2)
    local centerY = (frame.y or 0) + ((frame.h or 0) / 2)

    for _, screen in ipairs(hs.screen.allScreens()) do
        local fullFrame = screen:fullFrame()
        if centerX >= fullFrame.x and centerX <= (fullFrame.x + fullFrame.w)
                and centerY >= fullFrame.y and centerY <= (fullFrame.y + fullFrame.h) then
            return screen, fullFrame
        end
    end

    return nil
end

local backgroundColorForSnapshotImage

local function shouldUseSnapshotForApp(app)
    return ICON_CONFIG.snapshotMode ~= "off" and (isControlCenterApp(app) or isGenericHostApp(app))
end

local function snapshotRectForMenuBarFrame(frame, screenFrame)
    local padding = ICON_CONFIG.snapshotPadding

    return {
        x = math.max(0, math.floor((frame.x or 0) - screenFrame.x - padding)),
        y = math.max(0, math.floor((frame.y or 0) - screenFrame.y - padding)),
        w = math.floor((frame.w or 0) + (padding * 2)),
        h = math.floor((frame.h or 0) + (padding * 2))
    }
end

local function menuBarSnapshotImageForItem(item, debugLabel)
    local frame = safeAttributeValue(item, "AXFrame")
    if type(frame) ~= "table" or (frame.w or 0) <= 0 or (frame.h or 0) <= 0 then
        logIcon("[MenuBarChooser][icon] snapshot skipped %s reason=invalid-frame", debugLabel or "-")
        return nil
    end

    -- Skip wide textual menu bar items like the clock/date because they don't produce a usable icon.
    if (frame.w or 0) > ((frame.h or 0) * ICON_CONFIG.snapshotWideAspectLimit) then
        logIcon(
                "[MenuBarChooser][icon] snapshot skipped %s reason=wide-frame frame=%dx%d",
                debugLabel or "-",
                math.floor(frame.w or 0),
                math.floor(frame.h or 0)
        )
        return nil
    end

    local screen, screenFrame = screenContainingFrame(frame)
    if not screen then
        logIcon("[MenuBarChooser][icon] snapshot skipped %s reason=no-screen", debugLabel or "-")
        return nil
    end

    local snapshotRect = snapshotRectForMenuBarFrame(frame, screenFrame)
    local snapshot = screen:snapshot(snapshotRect)
    if not snapshot then
        logIcon("[MenuBarChooser][icon] snapshot failed %s rect=%dx%d", debugLabel or "-", snapshotRect.w, snapshotRect.h)
        return nil
    end

    local sizedSnapshot = snapshot:setSize({ w = ICON_CONFIG.snapshotSize, h = ICON_CONFIG.snapshotSize }, false)
    local snapshotSize = sizedSnapshot:size()
    local rawSnapshotSize = snapshot:size()
    logIcon(
            "[MenuBarChooser][icon] snapshot ok %s frame=%dx%d rect=%dx%d raw=%dx%d sized=%dx%d",
            debugLabel or "-",
            math.floor(frame.w or 0),
            math.floor(frame.h or 0),
            snapshotRect.w,
            snapshotRect.h,
            math.floor(rawSnapshotSize.w or 0),
            math.floor(rawSnapshotSize.h or 0),
            math.floor(snapshotSize.w or 0),
            math.floor(snapshotSize.h or 0)
    )
    return {
        image = sizedSnapshot,
        backgroundColor = backgroundColorForSnapshotImage(snapshot)
    }
end

local function averageColorForImagePoints(image, points)
    local redSum = 0
    local greenSum = 0
    local blueSum = 0
    local alphaSum = 0
    local measuredCount = 0

    for _, point in ipairs(points) do
        local color = image:colorAt(point)
        if color then
            redSum = redSum + (color.red or color.white or 0)
            greenSum = greenSum + (color.green or color.white or 0)
            blueSum = blueSum + (color.blue or color.white or 0)
            alphaSum = alphaSum + (color.alpha or 1)
            measuredCount = measuredCount + 1
        end
    end

    if measuredCount == 0 then
        return { white = 1, alpha = 1 }
    end

    return {
        red = redSum / measuredCount,
        green = greenSum / measuredCount,
        blue = blueSum / measuredCount,
        alpha = alphaSum / measuredCount
    }
end

backgroundColorForSnapshotImage = function(image)
    local size = image:size()
    local samplePoints = {
        { x = 1, y = 1 },
        { x = math.max(1, math.floor(size.w / 2)), y = 1 },
        { x = math.max(1, math.floor(size.w - 2)), y = 1 },
        { x = 1, y = math.max(1, math.floor(size.h - 2)) },
        { x = math.max(1, math.floor(size.w - 2)), y = math.max(1, math.floor(size.h - 2)) }
    }
    return averageColorForImagePoints(image, samplePoints)
end

local function roundedChoiceImage(image, backgroundColor)
    local iconCanvas = canvas.new({ x = 0, y = 0, w = ICON_CONFIG.snapshotSize, h = ICON_CONFIG.snapshotSize })
    iconCanvas[1] = {
        type = "rectangle",
        action = "clip",
        roundedRectRadii = { xRadius = ICON_CONFIG.snapshotCornerRadius, yRadius = ICON_CONFIG.snapshotCornerRadius },
        frame = { x = 0, y = 0, w = ICON_CONFIG.snapshotSize, h = ICON_CONFIG.snapshotSize }
    }
    iconCanvas[2] = {
        type = "rectangle",
        action = "fill",
        fillColor = backgroundColor,
        frame = { x = 0, y = 0, w = ICON_CONFIG.snapshotSize, h = ICON_CONFIG.snapshotSize }
    }
    iconCanvas[3] = {
        type = "image",
        image = image,
        frame = { x = 0, y = 0, w = ICON_CONFIG.snapshotSize, h = ICON_CONFIG.snapshotSize },
        imageScaling = "scaleProportionally"
    }

    local roundedImage = iconCanvas:imageFromCanvas()
    iconCanvas:delete()
    return roundedImage
end

local function snapshotChoiceImageForHostApp(app, item, debugLabel)
    if not shouldUseSnapshotForApp(app) then
        return nil
    end

    local snapshotInfo = menuBarSnapshotImageForItem(item, debugLabel)
    if snapshotInfo then
        logIcon("[MenuBarChooser][icon] using snapshot %s", debugLabel or "-")
        return roundedChoiceImage(snapshotInfo.image, snapshotInfo.backgroundColor)
    end

    return nil
end

local function fallbackChoiceImageForApp(app, debugLabel)
    local bundleID = app:bundleID()
    if bundleID then
        logIcon("[MenuBarChooser][icon] using bundle fallback %s bundle=%s", debugLabel or "-", bundleID)
        return hs.image.imageFromAppBundle(bundleID)
    end

    local path = safeApplicationPath(app)
    if path then
        logIcon("[MenuBarChooser][icon] using file fallback %s path=%s", debugLabel or "-", path)
        return hs.image.iconForFile(path)
    end

    logIcon("[MenuBarChooser][icon] no image %s", debugLabel or "-")
    return nil
end

local function preferredChoiceImage(app, item, debugLabel)
    return snapshotChoiceImageForHostApp(app, item, debugLabel) or fallbackChoiceImageForApp(app, debugLabel)
end

local function perfFormatMetadataTraceValue(value)
    local cleaned = cleanValue(value)
    if not cleaned then
        return "<empty>"
    end

    cleaned = cleaned:gsub("%s+", " ")
    if #cleaned > PERF_CONFIG.metadataTraceValueMaxLength then
        cleaned = cleaned:sub(1, PERF_CONFIG.metadataTraceValueMaxLength - 1) .. "…"
    end
    return cleaned
end

local function perfLogMetadataTrace(app, itemLabel, elapsedMs, trace)
    if not trace or elapsedMs < PERF_CONFIG.metadataTraceThresholdMs then
        return
    end

    local parts = {}
    for _, entry in ipairs(trace) do
        table.insert(parts, string.format(
                "%s=%.1fms:%s",
                entry.name,
                entry.elapsedMs,
                perfFormatMetadataTraceValue(entry.value)
        ))
    end

    perfLog(
            "[MenuBarChooser][perf] metadata trace %.1fms app=%s bundle=%s item=%s fields: %s",
            elapsedMs,
            app:name() or app:bundleID() or "<unknown>",
            app:bundleID() or "",
            itemLabel or "-",
            table.concat(parts, " | ")
    )
end

local function collectMenuItemMetadata(item)
    local trace = {}
    local function readMetadata(name, attributeName)
        local startedAt = perfNow()
        local value = itemMetadataValue(item, attributeName)
        table.insert(trace, {
            name = name,
            attributeName = attributeName,
            value = value,
            elapsedMs = perfElapsedMs(startedAt)
        })
        return value
    end

    local metadata = {
        identifier = readMetadata("identifier", "AXIdentifier"),
        description = readMetadata("description", "AXDescription"),
        value = readMetadata("value", "AXValue")
    }

    metadata.label = preferredLabelValue(metadata.description)
    if not metadata.label then
        metadata.title = readMetadata("title", "AXTitle")
        metadata.label = preferredLabelValue(metadata.title)
    end
    if not metadata.label then
        metadata.valueDescription = readMetadata("valueDescription", "AXValueDescription")
        metadata.label = preferredLabelValue(metadata.valueDescription)
    end
    if not metadata.label then
        metadata.help = readMetadata("help", "AXHelp")
        metadata.label = preferredLabelValue(metadata.help)
    end

    metadata.derivedLabel = deriveGenericNameFromMenuLabel(metadata.label)
    return metadata, trace
end

local function collectMenuItemMetadataDebug(item)
    local metadata = collectMenuItemMetadata(item)
    metadata.role = itemMetadataValue(item, "AXRole")
    metadata.subrole = itemMetadataValue(item, "AXSubrole")
    metadata.roleDescription = itemMetadataValue(item, "AXRoleDescription")
    return metadata
end

local function buildBaseMenuChoiceText(app, item, metadata, perf)
    local isGenericHost = isGenericHostApp(app)
    local appName = fallbackDisplayAppName(app)
    local appText = metadata.label and (metadata.label ~= appName) and (appName .. ": " .. metadata.label) or appName

    if shouldInferSemanticName(app) then
        local inferStartedAt = perfNow()
        local inferredName, semanticTrace = inferSemanticNameFromMenu(item)
        local inferElapsedMs = perfElapsedMs(inferStartedAt)
        perfAdd(perf, "inferSemanticName", inferElapsedMs)
        perfRecordSlowItem(perf, app, metadata.label or appName, "inferSemanticName", inferElapsedMs)
        perfLogSemanticTrace(app, metadata.label or appName, inferElapsedMs, semanticTrace)
        appText = inferredName or appName
    elseif metadata.derivedLabel then
        appText = metadata.derivedLabel
    end

    if isControlCenterApp(app) and metadata.value then
        appText = appText .. " - " .. metadata.value
    end

    return appText
end

local function buildMenuChoiceText(baseText, actionName)
    local appText = baseText
    if actionName ~= "AXPress" then
        appText = appText .. " [" .. actionName .. "]"
    end

    return appText
end

local function buildMenuChoiceSubText(app, metadata, appText)
    local isGenericHost = isGenericHostApp(app)
    local appName = fallbackDisplayAppName(app)
    local rawAppName = app:name()
    local summaryParts = {}

    if rawAppName and rawAppName ~= appName and not isGenericHost then
        table.insert(summaryParts, rawAppName)
    end
    if not isGenericHost and metadata.label and metadata.label ~= appText and not metadata.derivedLabel then
        appendSummaryDetail(summaryParts, metadata.label)
    elseif not isGenericHost and metadata.label and metadata.label ~= appText and metadata.derivedLabel ~= appText then
        appendSummaryDetail(summaryParts, metadata.label)
    end
    if metadata.identifier and isControlCenterApp(app) then
        table.insert(summaryParts, metadata.identifier)
    else
        appendSummaryDetail(summaryParts, metadata.value)
    end
    if #summaryParts == 0 then
        appendSummaryDetail(summaryParts, metadata.help)
    end
    if #summaryParts == 0 then
        appendSummaryDetail(summaryParts, metadata.valueDescription)
    end

    return table.concat(summaryParts, " | ")
end

local function buildMenuChoice(app, item, actionName, selectionMap)
    local perf = selectionMap.perf
    local metadataStartedAt = perfNow()
    local metadata, metadataTrace = collectMenuItemMetadata(item)
    local metadataElapsedMs = perfElapsedMs(metadataStartedAt)
    perfAdd(perf, "metadata", metadataElapsedMs)
    perfRecordSlowItem(perf, app, metadata.label or metadata.title or metadata.identifier, "metadata", metadataElapsedMs)
    perfLogMetadataTrace(app, metadata.label or metadata.title or metadata.identifier, metadataElapsedMs, metadataTrace)

    local labelStartedAt = perfNow()
    local baseText = buildBaseMenuChoiceText(app, item, metadata, perf)
    local appText = buildMenuChoiceText(baseText, actionName)
    local appSubText = buildMenuChoiceSubText(app, metadata, baseText)
    local labelElapsedMs = perfElapsedMs(labelStartedAt)
    perfAdd(perf, "labels", labelElapsedMs)
    perfRecordSlowItem(perf, app, appText, "labels", labelElapsedMs)

    local appKey = addMenuItem(selectionMap, item)
    local imageStartedAt = perfNow()
    local appImage = preferredChoiceImage(app, item, appText)
    local imageElapsedMs = perfElapsedMs(imageStartedAt)
    perfAdd(perf, "images", imageElapsedMs)
    perfRecordSlowItem(perf, app, appText, "images", imageElapsedMs)

    return {
        text = appText,
        subText = appSubText,
        image = appImage,
        element = {
            key = appKey,
            action = actionName
        }
    }
end

local function logDiscoveredMenuItem(app, item, choice, names)
    debugLoggedElementCount = debugLoggedElementCount + 1
    logDiscoveredItem("[MenuBarChooser][%03d] %s", debugLoggedElementCount, choice.text)
    logDiscoveredItem("[MenuBarChooser][%03d] actions=%s", debugLoggedElementCount, joinedActionNames(names))
    logDiscoveredItem("[MenuBarChooser][%03d] %s", debugLoggedElementCount, choice.subText)

    if shouldDebugFullDump(app) then
        logDiscoveredItem("[MenuBarChooser][%03d] full AX dump follows", debugLoggedElementCount)
        debugElement(item, string.format("MenuBarChooser %s", choice.text))
    end
end

local function appendChoicesForApp(app, children, selectionMap)
    local addedChoices = 0
    local perf = selectionMap.perf

    for _, item in ipairs(children) do
        local actionNamesStartedAt = perfNow()
        local names = item:actionNames()
        local actionNamesElapsedMs = perfElapsedMs(actionNamesStartedAt)
        perfAdd(perf, "actionNames", actionNamesElapsedMs)
        perfRecordSlowItem(perf, app, nil, "actionNames", actionNamesElapsedMs)

        local skipStartedAt = perfNow()
        local shouldSkip = shouldSkipMenuItem(app, item, names)
        local skipElapsedMs = perfElapsedMs(skipStartedAt)
        perfAdd(perf, "skipChecks", skipElapsedMs)
        perfRecordSlowItem(perf, app, nil, "skipChecks", skipElapsedMs)

        if not shouldSkip then
            local primaryActionName, sortedNames = choosePrimaryAction(names)
            if primaryActionName then
                local choice = buildMenuChoice(app, item, primaryActionName, selectionMap)
                table.insert(selectionMap.chooserItems, choice)
                addedChoices = addedChoices + 1
                perfCount(perf, "builtChoices")
                local logStartedAt = perfNow()
                logDiscoveredMenuItem(app, item, choice, sortedNames)
                local logElapsedMs = perfElapsedMs(logStartedAt)
                perfAdd(perf, "logDiscoveredMenuItem", logElapsedMs)
                perfRecordSlowItem(perf, app, choice.text, "logDiscoveredMenuItem", logElapsedMs)
            end
        end
    end

    return addedChoices
end

local function applyChoices(selectionMap)
    local startedAt = perfNow()
    local sorter = nil
    local query = chooser:query() or ""
    if SCAN_CONFIG.choiceSortMode == "score"
            or (SCAN_CONFIG.choiceSortMode == "queryScore" and #query > 0) then
        sorter = FuzzyMatcher.Sorter.byScore
    end
    FuzzyMatcher.setChoices(selectionMap.chooserItems, chooser, false, sorter)
    perfAdd(selectionMap.perf, "applyChoices", perfElapsedMs(startedAt))
end

local function updateProgressHud(scannedCount, totalCount, foundAppsCount, foundItemsCount, lastAppName, lastBundleID, state)
    local hud = ensureProgressHud()
    local progress = 0
    if totalCount > 0 then
        progress = math.min(1, scannedCount / totalCount)
    end
    local currentFrame = hud:frame()
    local barX = 10
    local barY = currentFrame.h - 8
    local barWidth = math.floor((currentFrame.w - (barX * 2)) * progress)
    local currentIdentity = lastBundleID or lastAppName or "-"

    hud[5].text = string.format(
            "Search: %d Apps - %d",
            totalCount,
            scannedCount
    )
    hud[6].text = string.format("%d%%", math.floor(progress * 100))
    hud[11].text = currentIdentity
    hud[8].text = string.format(
            "%d Apps mit Menueleiste   %d Eintraege\nZuletzt: %s",
            foundAppsCount,
            foundItemsCount,
            lastAppName or "-"
    )
    hud[10].frame = { x = barX, y = barY, w = barWidth, h = 4 }
end

function MenuBarChooser()
    stopScanTimer()
    hideProgressHud()
    debugLoggedElementCount = 0
    local perf = newPerfStats()

    if chooser then
        chooser:delete()
        chooser = nil
    end

    local runningApplicationsStartedAt = perfNow()
    local runningApplications = hs.application.runningApplications()
    perfAdd(perf, "runningApplications", perfElapsedMs(runningApplicationsStartedAt))

    local selectionMap = {
        chooserItems = {},
        menuItems = {},
        menuItemsCounter = 0,
        perf = perf
    }
    local scannedCount = 0
    local foundAppsCount = 0
    local foundItemsCount = 0
    local scanIndex = 1
    local scanComplete = false

    local chooserCallback = function(selection)
        if selection and selection.element and selection.element.key then
            local menuItem = selectionMap.menuItems[selection.element.key]
            if menuItem then
                local ok, result, actionError = pcall(function()
                    return menuItem:performAction(selection.element.action)
                end)
                if result == false then
                    hs.printf(
                            "MenuBarChooser action returned false: text=%s subText=%s action=%s",
                            selection.text or "<unknown>",
                            selection.subText or "-",
                            selection.element.action or "-"
                    )
                elseif not ok or result == nil then
                    local debugStartedAt = perfNow()
                    local metadata = collectMenuItemMetadataDebug(menuItem)
                    local actionDescription = nil
                    pcall(function()
                        actionDescription = menuItem:actionDescription(selection.element.action)
                    end)
                    perfAdd(selectionMap.perf, "debugText", perfElapsedMs(debugStartedAt))
                    hs.printf(
                            "MenuBarChooser action failed: text=%s subText=%s action=%s result=%s error=%s actionDescription=%s metadata=%s",
                            selection.text or "<unknown>",
                            selection.subText or "-",
                            selection.element.action or "-",
                            tostring(result),
                            actionError or "-",
                            actionDescription or "-",
                            hs.inspect(metadata)
                    )
                    debugElement(menuItem, selection.text or "MenuBarChooser selection")
                    hs.alert.show("Aktion fehlgeschlagen: " .. (selection.text or selection.element.action), 1.5)
                end
            end
        end
    end

    chooser = hs.chooser.new(chooserCallback)
    chooser:hideCallback(function()
        stopScanTimer()
        hideProgressHud()
    end)

    if not SCAN_CONFIG.deferChooserItemsUntilScanComplete then
        applyChoices(selectionMap)
    end

    chooser:queryChangedCallback(function()
        if scanComplete or not SCAN_CONFIG.deferChooserItemsUntilScanComplete then
            applyChoices(selectionMap)
        end
    end)

    --chooser:rows(#choices)
    local chooserScreenFrame = hs.screen.mainScreen():frame()
    local chooserFrame = chooserFrameForScreen(chooserScreenFrame)
    chooser:rows(CHOOSER_LAYOUT.rows)
    chooser:width(chooserWidthPercentForScreen(chooserScreenFrame))
    --chooser:bgDark(true)
    --chooser:fgColor(hs.drawing.color.x11.orange)
    --chooser:subTextColor(hs.drawing.color.x11.chocolate)
    local chooserTopLeft = hs.geometry.point(chooserFrame.x, chooserFrame.y)
    if SCAN_CONFIG.showChooserDuringScan then
        chooser:show(chooserTopLeft)
    end
    updateProgressHud(0, #runningApplications, 0, 0, nil, nil, "Suche startet...")
    logScan("[MenuBarChooser] scan started, apps=%d", #runningApplications)

    scanTimer = hs.timer.doEvery(SCAN_CONFIG.intervalSeconds, function()
        if not chooser then
            stopScanTimer()
            return
        end
        if SCAN_CONFIG.showChooserDuringScan and not chooser:isVisible() then
            stopScanTimer()
            hideProgressHud()
            return
        end

        local app = runningApplications[scanIndex]
        if not app then
            stopScanTimer()
            scanComplete = true
            updateProgressHud(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, "fertig", nil, "Suche abgeschlossen")
            hideProgressHud()
            applyChoices(selectionMap)
            perfLogSummary(perf, scannedCount, foundAppsCount, foundItemsCount)
            if not SCAN_CONFIG.showChooserDuringScan then
                chooser:show(chooserTopLeft)
            end
            logScan("[MenuBarChooser] scan finished, apps=%d, matchedApps=%d, items=%d",
                    scannedCount,
                    foundAppsCount,
                    foundItemsCount)
            return
        end

        scannedCount = scannedCount + 1
        local lastAppName = app:name()
        local lastBundleID = app:bundleID()
        local foundItemsAtStart = foundItemsCount
        updateProgressHud(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, lastAppName, lastBundleID, "Lese App...")

        local findStartedAt = perfNow()
        local children = findMenuExtrasMenuBarForApplication(app)
        local findElapsedMs = perfElapsedMs(findStartedAt)
        perfAdd(perf, "findMenuExtras", findElapsedMs)
        perfRecordSlowApp(perf, app, "findMenuExtras", findElapsedMs)

        if children then
            local appendStartedAt = perfNow()
            local addedChoices = appendChoicesForApp(app, children, selectionMap)
            local appendElapsedMs = perfElapsedMs(appendStartedAt)
            perfAdd(perf, "appendChoicesForApp", appendElapsedMs)
            perfRecordSlowApp(perf, app, "appendChoicesForApp", appendElapsedMs)

            if addedChoices > 0 then
                foundAppsCount = foundAppsCount + 1
                foundItemsCount = foundItemsCount + addedChoices
                lastAppName = string.format("%s (+%d)", lastAppName, addedChoices)
            end
        end

        scanIndex = scanIndex + 1
        updateProgressHud(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, lastAppName, lastBundleID, "Suche laeuft...")
        if foundItemsCount ~= foundItemsAtStart and not SCAN_CONFIG.deferChooserItemsUntilScanComplete then
            applyChoices(selectionMap)
        end
    end)
end

hs.hotkey.bind(hyper, "b", keyInfo("macOS MenuBar"), MenuBarChooser)
