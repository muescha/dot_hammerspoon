local axuielement = require("hs.axuielement")
local canvas = require("hs.canvas")

local chooser = nil
local scanTimer = nil
local progressHud = nil
local debugLoggedElementCount = 0

local SCAN_CONFIG = {
    intervalSeconds = 0.002,
    showChooserDuringScan = true,
    deferChooserItemsUntilScanComplete = true,
    negativeAppCacheTtlSeconds = 180
}

local CHOOSER_LAYOUT = {
    widthPercent = 60,
    maxWidth = 1400,
    rows = 20,
    hudOverlayOnChooser = true,
    topMarginLandscape = 120
}

local ICON_CONFIG = {
    snapshotMode = "all", -- off | all
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

local function appCacheKey(app)
    return app:bundleID() or app:path() or app:name()
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
    return chooserFrameForScreen(hs.screen.mainScreen():frame())
end

local function ensureProgressHud()
    if progressHud then
        return progressHud
    end

    local frame = progressHudFrame()
    local innerWidth = frame.w - 48
    local barY = 76
    local outerFillAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.985
    local outerStrokeAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.14
    local searchFillAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.98
    local searchStrokeAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.10
    local placeholderAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 1
    local rowFillAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.88
    local rowStrokeAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.12
    local detailFillAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.80
    local detailStrokeAlpha = CHOOSER_LAYOUT.hudOverlayOnChooser and 0 or 0.10
    local rowInset = 14
    local rowWidth = frame.w - (rowInset * 2)

    progressHud = canvas.new(frame)
    progressHud:level(CHOOSER_LAYOUT.hudOverlayOnChooser and hs.canvas.windowLevels.overlay or hs.canvas.windowLevels.modalPanel)
    progressHud[1] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 16, yRadius = 16 },
        fillColor = { alpha = outerFillAlpha, white = 0.94 },
        strokeColor = { alpha = outerStrokeAlpha, white = 0.45 },
        strokeWidth = 1
    }
    progressHud[2] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 10, yRadius = 10 },
        fillColor = { alpha = searchFillAlpha, white = 0.985 },
        strokeColor = { alpha = searchStrokeAlpha, white = 0.45 },
        strokeWidth = 1,
        frame = { x = 20, y = 18, w = frame.w - 40, h = 44 }
    }
    progressHud[3] = {
        type = "text",
        text = "Menu-Bar-Items werden geladen ...",
        textSize = 20,
        textColor = { white = 0.48, alpha = placeholderAlpha },
        frame = { x = 34, y = 28, w = innerWidth - 20, h = 22 }
    }
    progressHud[4] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
        fillColor = { white = 0.97, alpha = rowFillAlpha },
        strokeColor = { white = 0.62, alpha = rowStrokeAlpha },
        strokeWidth = 1,
        frame = { x = rowInset, y = 96, w = rowWidth, h = 40 }
    }
    progressHud[5] = {
        type = "text",
        text = "",
        textSize = 26,
        textColor = { white = 0.10, alpha = 1 },
        frame = { x = 28, y = 100, w = innerWidth - 110, h = 30 }
    }
    progressHud[6] = {
        type = "text",
        text = "0%",
        textSize = 17,
        textColor = { white = 0.36, alpha = 1 },
        frame = { x = frame.w - 96, y = 104, w = 64, h = 24 }
    }
    progressHud[7] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 8, yRadius = 8 },
        fillColor = { white = 0.965, alpha = detailFillAlpha },
        strokeColor = { white = 0.62, alpha = detailStrokeAlpha },
        strokeWidth = 1,
        frame = { x = rowInset, y = 128, w = rowWidth, h = 64 }
    }
    progressHud[8] = {
        type = "text",
        text = "",
        textSize = 19,
        textColor = { white = 0.30, alpha = 1 },
        frame = { x = 28, y = 156, w = innerWidth - 12, h = 40 }
    }
    progressHud[9] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
        fillColor = { white = 0.72, alpha = 0.20 },
        frame = { x = 20, y = barY, w = frame.w - 40, h = 10 }
    }
    progressHud[10] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
        fillColor = { red = 0.24, green = 0.48, blue = 0.98, alpha = 0.92 },
        frame = { x = 20, y = barY, w = 0, h = 10 }
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

local function firstNonEmpty(...)
    for i = 1, select("#", ...) do
        local value = cleanValue(select(i, ...))
        if value then
            return value
        end
    end
    return nil
end

local function appendDetail(parts, label, value)
    local cleaned = cleanValue(value)
    if cleaned then
        table.insert(parts, label .. "=" .. cleaned)
    end
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
    local children = safeAttributeValue(item, "AXChildren")
    if not children or #children == 0 then
        return
    end

    for _, child in ipairs(children) do
        if safeAttributeValue(child, "AXRole") == "AXMenu" then
            local menuItems = safeAttributeValue(child, "AXChildren")
            if menuItems and #menuItems > 0 then
                for index = #menuItems, 1, -1 do
                    local menuLabel = firstNonEmpty(
                            safeAttributeValue(menuItems[index], "AXTitle"),
                            safeAttributeValue(menuItems[index], "AXDescription"),
                            safeAttributeValue(menuItems[index], "AXValue")
                    )
                    local genericName = deriveGenericNameFromMenuLabel(menuLabel)
                    if genericName then
                        return genericName
                    end
                end
            end
        end
    end
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

    local identifier = cleanValue(firstNonEmpty(item.AXIdentifier, safeAttributeValue(item, "AXIdentifier")))
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

    local path = app:path()
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

local function itemMetadataValue(item, attributeName)
    return firstNonEmpty(item[attributeName], safeAttributeValue(item, attributeName))
end

local function collectMenuItemMetadata(item)
    local metadata = {
        identifier = itemMetadataValue(item, "AXIdentifier"),
        title = itemMetadataValue(item, "AXTitle"),
        valueDescription = itemMetadataValue(item, "AXValueDescription"),
        description = itemMetadataValue(item, "AXDescription"),
        help = itemMetadataValue(item, "AXHelp"),
        value = itemMetadataValue(item, "AXValue"),
        role = itemMetadataValue(item, "AXRole"),
        subrole = itemMetadataValue(item, "AXSubrole"),
        roleDescription = itemMetadataValue(item, "AXRoleDescription")
    }
    metadata.label = preferredLabelValue(metadata.description, metadata.title, metadata.valueDescription, metadata.help)
    metadata.derivedLabel = deriveGenericNameFromMenuLabel(metadata.label)
    return metadata
end

local function buildBaseMenuChoiceText(app, item, metadata)
    local isGenericHost = isGenericHostApp(app)
    local appName = fallbackDisplayAppName(app)
    local appText = metadata.label and (metadata.label ~= appName) and (appName .. ": " .. metadata.label) or appName

    if isGenericHost then
        appText = inferSemanticNameFromMenu(item) or appName
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

local function buildMenuChoiceDebugText(app, item, metadata, actionName)
    local detailParts = {}
    appendDetail(detailParts, "action", actionName)
    appendDetail(detailParts, "desc", item:actionDescription(actionName))
    appendDetail(detailParts, "id", metadata.identifier)
    appendDetail(detailParts, "title", metadata.title)
    appendDetail(detailParts, "valueDesc", metadata.valueDescription)
    appendDetail(detailParts, "value", metadata.value)
    appendDetail(detailParts, "role", metadata.role)
    appendDetail(detailParts, "subrole", metadata.subrole)
    appendDetail(detailParts, "roleDesc", metadata.roleDescription)
    appendDetail(detailParts, "help", metadata.help)
    appendDetail(detailParts, "bundle", app:bundleID())
    return table.concat(detailParts, " | ")
end

local function buildMenuChoice(app, item, actionName, selectionMap)
    local metadata = collectMenuItemMetadata(item)
    local baseText = buildBaseMenuChoiceText(app, item, metadata)
    local appText = buildMenuChoiceText(baseText, actionName)
    local appSubText = buildMenuChoiceSubText(app, metadata, baseText)
    local debugText = buildMenuChoiceDebugText(app, item, metadata, actionName)
    local appKey = addMenuItem(selectionMap, item)
    local appImage = preferredChoiceImage(app, item, appText)

    return {
        text = appText,
        subText = appSubText,
        image = appImage,
        element = {
            key = appKey,
            action = actionName
        },
        debugText = debugText
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

    for _, item in ipairs(children) do
        local names = item:actionNames()
        if not shouldSkipMenuItem(app, item, names) then
            local primaryActionName, sortedNames = choosePrimaryAction(names)
            if primaryActionName then
                local choice = buildMenuChoice(app, item, primaryActionName, selectionMap)
                table.insert(selectionMap.chooserItems, choice)
                addedChoices = addedChoices + 1
                logDiscoveredMenuItem(app, item, choice, sortedNames)
            end
        end
    end

    return addedChoices
end

local function applyChoices(selectionMap)
    FuzzyMatcher.setChoices(selectionMap.chooserItems, chooser, false, FuzzyMatcher.Sorter.asc)
end

local function updateProgressHud(scannedCount, totalCount, foundAppsCount, foundItemsCount, lastAppName, state)
    local hud = ensureProgressHud()
    local progress = 0
    if totalCount > 0 then
        progress = math.min(1, scannedCount / totalCount)
    end
    local currentFrame = hud:frame()
    local barWidth = math.floor((currentFrame.w - 40) * progress)

    hud[5].text = string.format(
            "%s  %d/%d",
            state,
            scannedCount,
            totalCount
    )
    hud[6].text = string.format("%d%%", math.floor(progress * 100))
    hud[8].text = string.format(
            "%d Apps mit Menueleiste   %d Eintraege\nZuletzt: %s",
            foundAppsCount,
            foundItemsCount,
            lastAppName or "-"
    )
    hud[10].frame = { x = 20, y = 76, w = barWidth, h = 10 }
end

function MenuBarChooser()
    stopScanTimer()
    hideProgressHud()
    debugLoggedElementCount = 0

    if chooser then
        chooser:delete()
        chooser = nil
    end

    local runningApplications = hs.application.runningApplications()
    local selectionMap = {
        chooserItems = {},
        menuItems = {},
        menuItemsCounter = 0
    }
    local scannedCount = 0
    local foundAppsCount = 0
    local foundItemsCount = 0
    local scanIndex = 1
    local lastStatusAppName = nil
    local scanComplete = false

    local chooserCallback = function(selection)
        if selection and selection.element and selection.element.key then
            local menuItem = selectionMap.menuItems[selection.element.key]
            if menuItem then
                local ok, result = pcall(function()
                    return menuItem:performAction(selection.element.action)
                end)
                if not ok or result == false then
                    hs.printf("MenuBarChooser action failed: %s", selection.debugText or selection.text or "<unknown>")
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
    updateProgressHud(0, #runningApplications, 0, 0, nil, "Suche startet...")
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
            lastStatusAppName = "fertig"
            updateProgressHud(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, lastStatusAppName, "Suche abgeschlossen")
            hideProgressHud()
            applyChoices(selectionMap)
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

        local children = findMenuExtrasMenuBarForApplication(app)
        local lastAppName = app:name()
        local foundItemsAtStart = foundItemsCount
        if children then
            local addedChoices = appendChoicesForApp(app, children, selectionMap)
            if addedChoices > 0 then
                foundAppsCount = foundAppsCount + 1
                foundItemsCount = foundItemsCount + addedChoices
                lastAppName = string.format("%s (+%d)", lastAppName, addedChoices)
            end
        end

        lastStatusAppName = lastAppName
        scanIndex = scanIndex + 1
        updateProgressHud(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, lastAppName, "Suche laeuft...")
        if foundItemsCount ~= foundItemsAtStart and not SCAN_CONFIG.deferChooserItemsUntilScanComplete then
            applyChoices(selectionMap)
        end
    end)
end

hs.hotkey.bind(hyper, "b", keyInfo("macOS MenuBar"), MenuBarChooser)
