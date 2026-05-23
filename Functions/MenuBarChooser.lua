local axuielement = require("hs.axuielement")
local canvas = require("hs.canvas")
local chooser = nil
local scanTimer = nil
local progressHud = nil
local debugLoggedElementCount = 0
local SCAN_INTERVAL_SECONDS = 0.002
local ENABLE_VERBOSE_AX_DUMPS = false
local DEBUG_CACHE_LOGS = false
local DEBUG_SCAN_SUMMARY_LOGS = false
local DEBUG_DISCOVERED_ITEM_LOGS = false
local DEBUG_AX_TREE_LOGS = false
local SHOW_CHOOSER_DURING_SCAN = true
local CHOOSER_WIDTH_PERCENT = 60
local CHOOSER_ROWS = 20
local HUD_OVERLAY_ON_CHOOSER = true
local DEFER_CHOOSER_ITEMS_UNTIL_SCAN_COMPLETE = true
local NEGATIVE_APP_CACHE_TTL_SECONDS = 180

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

local negativeAppCache = newTTLCache(NEGATIVE_APP_CACHE_TTL_SECONDS)
local NEGATIVE_APP_CACHE_MISS = "__no_menu_extras__"

local function debugLog(flag, message, ...)
    if flag then
        hs.printf(message, ...)
    end
end

local function logCache(message, ...)
    debugLog(DEBUG_CACHE_LOGS, message, ...)
end

local function logScan(message, ...)
    debugLog(DEBUG_SCAN_SUMMARY_LOGS, message, ...)
end

local function logDiscoveredItem(message, ...)
    debugLog(DEBUG_DISCOVERED_ITEM_LOGS, message, ...)
end

local function appCacheKey(app)
    return app:bundleID() or app:path() or app:name()
end

local function shouldSkipNegativeAppCache(app)
    local bundleID = app:bundleID() or ""
    local appName = app:name() or ""

    return bundleID == "com.apple.controlcenter"
            or bundleID == "com.apple.systemuiserver"
            or bundleID == "com.apple.TextInputMenuAgent"
            or appName == "Kontrollzentrum"
            or appName == "Control Center"
            or appName == "SystemUIServer"
            or appName == "TextInputMenuAgent"
end

local function printChildren(application, children, recursive)
    if not DEBUG_AX_TREE_LOGS then
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

local function progressHudFrame()
    local screenFrame = hs.screen.mainScreen():frame()
    local chooserWidth = math.floor(screenFrame.w * (CHOOSER_WIDTH_PERCENT / 100))
    local chooserX = math.floor(screenFrame.x + (screenFrame.w - chooserWidth) / 2)
    local chooserY = math.floor(screenFrame.y + 120)
    local chooserHeight = 88 + (CHOOSER_ROWS * 22)

    return {
        x = chooserX,
        y = chooserY,
        w = chooserWidth,
        h = chooserHeight
    }
end

local function ensureProgressHud()
    if progressHud then
        return progressHud
    end

    local frame = progressHudFrame()
    local innerWidth = frame.w - 48
    local barY = 76
    local outerFillAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.985
    local outerStrokeAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.14
    local searchFillAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.98
    local searchStrokeAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.10
    local placeholderAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 1
    local rowFillAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.88
    local rowStrokeAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.12
    local detailFillAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.80
    local detailStrokeAlpha = HUD_OVERLAY_ON_CHOOSER and 0 or 0.10
    local rowInset = 14
    local rowWidth = frame.w - (rowInset * 2)

    progressHud = canvas.new(frame)
    progressHud:level(HUD_OVERLAY_ON_CHOOSER and hs.canvas.windowLevels.overlay or hs.canvas.windowLevels.modalPanel)
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
    local bundleID = app:bundleID() or ""
    local appName = app:name() or ""
    return bundleID == "com.apple.controlcenter"
            or appName == "Kontrollzentrum"
            or appName == "Control Center"
end

local function isGenericHostApp(app)
    local bundleID = app:bundleID() or ""
    local appName = app:name() or ""
    return bundleID == "com.apple.TextInputMenuAgent"
            or bundleID == "com.apple.systemuiserver"
            or appName == "TextInputMenuAgent"
            or appName == "SystemUIServer"
end

local function shouldDebugFullDump(app)
    return ENABLE_VERBOSE_AX_DUMPS and isControlCenterApp(app)
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
    local bundleID = app:bundleID() or ""
    local appName = app:name() or ""
    if bundleID == "com.apple.TextInputMenuAgent" or appName == "TextInputMenuAgent" then
        return "Tastatur"
    end
    if bundleID == "com.apple.systemuiserver" or appName == "SystemUIServer" then
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

local function buildMenuChoice(app, item, actionName, selectionMap)
    local identifier = firstNonEmpty(item.AXIdentifier, safeAttributeValue(item, "AXIdentifier"))
    local title = firstNonEmpty(item.AXTitle, safeAttributeValue(item, "AXTitle"))
    local valueDescription = firstNonEmpty(item.AXValueDescription, safeAttributeValue(item, "AXValueDescription"))
    local description = firstNonEmpty(item.AXDescription, safeAttributeValue(item, "AXDescription"))
    local help = firstNonEmpty(item.AXHelp, safeAttributeValue(item, "AXHelp"))
    local value = firstNonEmpty(item.AXValue, safeAttributeValue(item, "AXValue"))
    local role = firstNonEmpty(item.AXRole, safeAttributeValue(item, "AXRole"))
    local subrole = firstNonEmpty(item.AXSubrole, safeAttributeValue(item, "AXSubrole"))
    local roleDescription = firstNonEmpty(item.AXRoleDescription, safeAttributeValue(item, "AXRoleDescription"))
    local label = preferredLabelValue(description, title, valueDescription, help)
    local derivedLabel = deriveGenericNameFromMenuLabel(label)
    local isGenericHost = isGenericHostApp(app)
    local appName = fallbackDisplayAppName(app)
    local rawAppName = app:name()
    local appText = label and (label ~= appName) and (appName .. ": " .. label) or appName
    if isGenericHost then
        appText = inferSemanticNameFromMenu(item) or appName
    else
        if derivedLabel then
            appText = derivedLabel
        end
    end
    if isControlCenterApp(app) and value then
        appText = appText .. " - " .. value
    end

    local summaryParts = {}
    if rawAppName and rawAppName ~= appName and not isGenericHost then
        table.insert(summaryParts, rawAppName)
    end
    if not isGenericHost and label and label ~= appText and not derivedLabel then
        appendSummaryDetail(summaryParts, label)
    elseif not isGenericHost and label and label ~= appText and derivedLabel ~= appText then
        appendSummaryDetail(summaryParts, label)
    end
    if identifier and isControlCenterApp(app) then
        table.insert(summaryParts, identifier)
    else
        appendSummaryDetail(summaryParts, value)
    end
    if #summaryParts == 0 then
        appendSummaryDetail(summaryParts, help)
    end
    if #summaryParts == 0 then
        appendSummaryDetail(summaryParts, valueDescription)
    end
    local appSubText = table.concat(summaryParts, " | ")

    if actionName ~= "AXPress" then
        appText = appText .. " [" .. actionName .. "]"
    end

    local detailParts = {}
    appendDetail(detailParts, "action", actionName)
    appendDetail(detailParts, "desc", item:actionDescription(actionName))
    appendDetail(detailParts, "id", identifier)
    appendDetail(detailParts, "title", title)
    appendDetail(detailParts, "valueDesc", valueDescription)
    appendDetail(detailParts, "value", value)
    appendDetail(detailParts, "role", role)
    appendDetail(detailParts, "subrole", subrole)
    appendDetail(detailParts, "roleDesc", roleDescription)
    appendDetail(detailParts, "help", help)
    appendDetail(detailParts, "bundle", app:bundleID())
    local debugText = table.concat(detailParts, " | ")

    local appKey = addMenuItem(selectionMap, item)
    local bundleID = app:bundleID()
    local appImage = nil
    if bundleID then
        appImage = hs.image.imageFromAppBundle(bundleID)
    else
        local path = app:path()
        if path then
            appImage = hs.image.iconForFile(path)
        end
    end

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

    if not DEFER_CHOOSER_ITEMS_UNTIL_SCAN_COMPLETE then
        applyChoices(selectionMap)
    end

    chooser:queryChangedCallback(function()
        if scanComplete or not DEFER_CHOOSER_ITEMS_UNTIL_SCAN_COMPLETE then
            applyChoices(selectionMap)
        end
    end)

    --chooser:rows(#choices)
    chooser:rows(CHOOSER_ROWS)
    chooser:width(CHOOSER_WIDTH_PERCENT)
    --chooser:bgDark(true)
    --chooser:fgColor(hs.drawing.color.x11.orange)
    --chooser:subTextColor(hs.drawing.color.x11.chocolate)
    if SHOW_CHOOSER_DURING_SCAN then
        chooser:show()
    end
    updateProgressHud(0, #runningApplications, 0, 0, nil, "Suche startet...")
    logScan("[MenuBarChooser] scan started, apps=%d", #runningApplications)

    scanTimer = hs.timer.doEvery(SCAN_INTERVAL_SECONDS, function()
        if not chooser then
            stopScanTimer()
            return
        end
        if SHOW_CHOOSER_DURING_SCAN and not chooser:isVisible() then
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
            if not SHOW_CHOOSER_DURING_SCAN then
                chooser:show()
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
        if foundItemsCount ~= foundItemsAtStart and not DEFER_CHOOSER_ITEMS_UNTIL_SCAN_COMPLETE then
            applyChoices(selectionMap)
        end
    end)
end

hs.hotkey.bind(hyper, "b", keyInfo("macOS MenuBar"), MenuBarChooser)
