local axuielement = require("hs.axuielement")
local chooser = nil
local scanTimer = nil
local debugLoggedElementCount = 0

local function printChildren(application, children, recursive)
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

    if app:bundleID() == "com.apple.WebKit.WebContent" then
        return nil
    end

    local appElement = axuielement.applicationElement(app)
    --debugElement(appElement,"appElement")
    if appElement then
        -- Get the menu bar element
        local menuBar = appElement:attributeValue("AXExtrasMenuBar")
        --debugElement(menuBar,"menuBar")
        if menuBar then
            return menuBar
            --local children = menuBar:attributeValue("AXChildren")
            --debugTable(children, "children")
            --if children then
            --    --printChildren(application, children)
            --end
            --return children
        end
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

local function isGenericHostBundle(bundleID)
    return bundleID == "com.apple.TextInputMenuAgent"
            or bundleID == "com.apple.systemuiserver"
end

local function isGenericHostApp(app)
    local bundleID = app:bundleID() or ""
    local appName = app:name() or ""
    return isGenericHostBundle(bundleID)
            or appName == "TextInputMenuAgent"
            or appName == "SystemUIServer"
end

local function shouldDebugFullDump(app)
    return isControlCenterApp(app) or isGenericHostApp(app)
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

local function childLabel(element)
    return firstNonEmpty(
            safeAttributeValue(element, "AXTitle"),
            safeAttributeValue(element, "AXDescription"),
            safeAttributeValue(element, "AXValue"),
            safeAttributeValue(element, "AXRoleDescription"),
            safeAttributeValue(element, "AXRole"),
            "<unbenannt>"
    )
end

local function stripTrailingDots(value)
    local cleaned = cleanValue(value)
    if not cleaned then
        return nil
    end

    cleaned = cleaned:gsub("%s*[%.…]+$", "")
    return cleanValue(cleaned)
end

local function stripTrailingSeparators(value)
    local cleaned = cleanValue(value)
    if not cleaned then
        return nil
    end

    cleaned = cleaned:gsub("[%s%-%–%—%:%·]+$", "")
    return cleanValue(cleaned)
end

local function deriveGenericNameFromMenuLabel(label)
    local cleaned = stripTrailingDots(label)
    if not cleaned then
        return nil
    end

    local lower = string.lower(cleaned)

    if lower:match("^open%s+.+%s+settings$") then
        local subject = cleaned:match("^[Oo]pen%s+(.+)%s+[Ss]ettings$")
        return stripTrailingSeparators(subject)
    end

    if lower:match("^open%s+.+%s+preferences$") then
        local subject = cleaned:match("^[Oo]pen%s+(.+)%s+[Pp]references$")
        return stripTrailingSeparators(subject)
    end

    local germanNeedle = "einstellungen öffnen"
    local germanStart = lower:find(germanNeedle, 1, true)
    if germanStart and germanStart > 1 then
        local subject = cleaned:sub(1, germanStart - 1)
        return stripTrailingSeparators(subject)
    end

    return nil
end

local function collectChildMenuLabels(element, labels, depth, maxDepth)
    if not element or depth > maxDepth then
        return
    end

    local label = childLabel(element)
    if label then
        table.insert(labels, label)
    end

    local children = safeAttributeValue(element, "AXChildren")
    if not children or #children == 0 then
        return
    end

    for _, child in ipairs(children) do
        collectChildMenuLabels(child, labels, depth + 1, maxDepth)
    end
end

local function inferredGenericAppName(app, item)
    if not isGenericHostApp(app) then
        return nil
    end

    local labels = {}
    collectChildMenuLabels(item, labels, 1, 4)
    for index = #labels, 1, -1 do
        local label = labels[index]
        local genericName = deriveGenericNameFromMenuLabel(label)
        if genericName then
            return genericName
        end
    end

    return nil
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

local function logMenuTree(element, prefix, depth, maxDepth)
    if not element or depth > maxDepth then
        return
    end

    local role = cleanValue(safeAttributeValue(element, "AXRole")) or "-"
    local subrole = cleanValue(safeAttributeValue(element, "AXSubrole")) or "-"
    local label = childLabel(element)
    local value = cleanValue(safeAttributeValue(element, "AXValue"))
    local actions = joinedActionNames(sortActionNames(element:actionNames()))

    local info = string.format("%srole=%s subrole=%s label=%s actions=%s",
            prefix,
            role,
            subrole,
            label,
            actions)
    if value then
        info = info .. " value=" .. value
    end
    hs.printf("%s", info)

    local children = safeAttributeValue(element, "AXChildren")
    if children and #children > 0 then
        for index, child in ipairs(children) do
            logMenuTree(child, string.format("%s  [%d] ", prefix, index), depth + 1, maxDepth)
        end
    end
end

local function inspectAttachedMenu(app, item, choice)
    if not isGenericHostApp(app) then
        return
    end

    local children = safeAttributeValue(item, "AXChildren")
    if not children or #children == 0 then
        hs.printf("[MenuBarChooser][Inspector] %s has no AXChildren", choice.text)
        return
    end

    hs.printf("[MenuBarChooser][Inspector] %s AXChildren=%d", choice.text, #children)
    for index, child in ipairs(children) do
        logMenuTree(child, string.format("[MenuBarChooser][Inspector] child[%d] ", index), 1, 3)
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
    local labelDerivedName = deriveGenericNameFromMenuLabel(label)
    local inferredAppName = inferredGenericAppName(app, item)
    local isGenericHost = isGenericHostApp(app)
    local appName = labelDerivedName or inferredAppName or fallbackDisplayAppName(app)
    local rawAppName = app:name()
    local appText = label and (label ~= appName) and (appName .. ": " .. label) or appName
    if isGenericHost or labelDerivedName then
        appText = appName
    end
    if isControlCenterApp(app) and value then
        appText = appText .. " - " .. value
    end

    local summaryParts = {}
    if rawAppName and rawAppName ~= appName and not isGenericHost then
        table.insert(summaryParts, rawAppName)
    end
    if not isGenericHost and label and label ~= appText and not labelDerivedName then
        appendSummaryDetail(summaryParts, label)
    elseif not isGenericHost and label and label ~= appText and labelDerivedName ~= appName then
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
    hs.printf("[MenuBarChooser][%03d] %s", debugLoggedElementCount, choice.text)
    hs.printf("[MenuBarChooser][%03d] actions=%s", debugLoggedElementCount, joinedActionNames(names))
    hs.printf("[MenuBarChooser][%03d] %s", debugLoggedElementCount, choice.subText)

    if shouldDebugFullDump(app) then
        hs.printf("[MenuBarChooser][%03d] full AX dump follows", debugLoggedElementCount)
        debugElement(item, string.format("MenuBarChooser %s", choice.text))
        inspectAttachedMenu(app, item, choice)
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

local function buildStatusChoice(scannedCount, totalCount, foundAppsCount, foundItemsCount, lastAppName, state)
    local statusText = string.format("%s %d/%d Apps", state, scannedCount, totalCount)
    local statusSubText = string.format("%d Apps, %d Eintraege, zuletzt: %s",
            foundAppsCount,
            foundItemsCount,
            lastAppName or "-")

    return {
        text = "  " .. statusText,
        subText = statusSubText,
        valid = false,
        isStatus = true
    }
end

local function applyChoices(selectionMap, statusChoice)
    local choices = {}

    if statusChoice then
        table.insert(choices, statusChoice)
    end

    for _, choice in ipairs(selectionMap.chooserItems) do
        table.insert(choices, choice)
    end

    FuzzyMatcher.setChoices(choices, chooser, false, FuzzyMatcher.Sorter.asc)
end

function MenuBarChooser()
    stopScanTimer()
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
    chooser:placeholderText("Menu-Bar-Items werden geladen ...")
    chooser:hideCallback(function()
        stopScanTimer()
    end)

    applyChoices(selectionMap, buildStatusChoice(0, #runningApplications, 0, 0, nil, "Suche startet..."))

    chooser:queryChangedCallback(function()
        local state = scanTimer and "Suche laeuft..." or "Suche abgeschlossen"
        applyChoices(selectionMap, buildStatusChoice(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, lastStatusAppName, state))
    end)

    --chooser:rows(#choices)
    chooser:rows(20)
    chooser:width(60)
    --chooser:bgDark(true)
    --chooser:fgColor(hs.drawing.color.x11.orange)
    --chooser:subTextColor(hs.drawing.color.x11.chocolate)
    chooser:show()
    hs.printf("[MenuBarChooser] scan started, apps=%d", #runningApplications)

    scanTimer = hs.timer.doEvery(0.01, function()
        local app = runningApplications[scanIndex]

        if not chooser or not chooser:isVisible() then
            stopScanTimer()
            return
        end

        if not app then
            stopScanTimer()
            lastStatusAppName = "fertig"
            chooser:placeholderText(string.format("%d Menu-Bar-Eintraege geladen", foundItemsCount))
            applyChoices(selectionMap, buildStatusChoice(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, lastStatusAppName, "Suche abgeschlossen"))
            hs.printf("[MenuBarChooser] scan finished, apps=%d, matchedApps=%d, items=%d",
                    scannedCount,
                    foundAppsCount,
                    foundItemsCount)
            return
        end

        scannedCount = scannedCount + 1

        local children = findMenuExtrasMenuBarForApplication(app)
        local lastAppName = app:name()
        if children then
            local addedChoices = appendChoicesForApp(app, children, selectionMap)
            if addedChoices > 0 then
                foundAppsCount = foundAppsCount + 1
                foundItemsCount = foundItemsCount + addedChoices
                lastAppName = string.format("%s (+%d)", lastAppName, addedChoices)
            end
        end

        lastStatusAppName = lastAppName
        chooser:placeholderText(string.format("Suche laeuft ... %d/%d Apps", scannedCount, #runningApplications))
        applyChoices(selectionMap, buildStatusChoice(scannedCount, #runningApplications, foundAppsCount, foundItemsCount, lastAppName, "Suche laeuft..."))

        scanIndex = scanIndex + 1
    end)
end

hs.hotkey.bind(hyper, "b", keyInfo("macOS MenuBar"), MenuBarChooser)
