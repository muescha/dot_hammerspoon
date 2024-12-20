local axuielement = require("hs.axuielement")

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


local function getMenuItemsForAllApps()

    local runningApplications = hs.application.runningApplications()

    local allMenuItems = {}

    for _, app in ipairs(runningApplications) do
        local children = findMenuExtrasMenuBarForApplication(app)
        if children then
            table.insert(allMenuItems, { app = app, children = children })
        end
    end
    --debugTable(allMenuItems)
    --printMenuItems(allMenuItems)
    return allMenuItems
end

local FuzzyMatcher = require("Helpers.FuzzyMatcher")

local function getSelection(appItems)

    local selection = {}

    local menuItemsCounter = 0
    local menuItems = {}

    local function addMenuItem(value)
        menuItemsCounter = menuItemsCounter + 1
        local key = tostring(menuItemsCounter)
        menuItems[key] = value
        return key
    end

    for _, menu in ipairs(appItems) do
        for _, item in ipairs(menu.children) do
            local names = item:actionNames()
            if names then
                for i, name in ipairs(names) do
                    if name == 'AXPress' then
                        local key = addMenuItem(item)
                        table.insert(selection,
                                {
                                    --text = hs.styledtext.new(p(menu.app:name())..":"..p(item.AXTitle) .. p(item.AXValue) .. p(item.AXDescription).. p(item.AXHelp)),
                                    text = defaultStr(menu.app:name())..":".. defaultStr(item.AXTitle) .. defaultStr(item.AXValue) .. defaultStr(item.AXDescription).. defaultStr(item.AXHelp),
                                    subText = defaultStr(item:actionDescription(name)),
                                    image = hs.image.imageFromAppBundle(menu.app:bundleID()),
                                    element = {
                                        key = key,
                                        action = name
                                    }
                                }
                        )
                    end
                end
            end
        end
    end
    return  { chooserItems = selection, menuItems = menuItems }
end

function MenuBarChooser()
    local appItems = getMenuItemsForAllApps()

    local selectionMap = getSelection(appItems)

    local chooserCallback = function(selection)
        if selection then
            local menuItem = selectionMap.menuItems[selection.element.key]
            menuItem:doAXPress()
        end
    end

    --for i = 1,#keys do
    --    table.insert(help, {
    --        --text = keys[i].msg,
    --        text = hs.styledtext.new(keys[i].msg),
    --        --subText = hs.styledtext.new('a little text')
    --        subText = 'a little text'
    --    })
    --end

    local choices = selectionMap.chooserItems

    chooser = hs.chooser.new(chooserCallback)
    --chooser:choices(choices)

    FuzzyMatcher.setChoices(choices, chooser, false, FuzzyMatcher.Sorter.asc)

    chooser:queryChangedCallback(function()
        FuzzyMatcher.setChoices(choices, chooser, false, FuzzyMatcher.Sorter.asc)
    end)

    --chooser:rows(#choices)
    chooser:rows(20)
    chooser:width(60)
    --chooser:bgDark(true)
    --chooser:fgColor(hs.drawing.color.x11.orange)
    --chooser:subTextColor(hs.drawing.color.x11.chocolate)
    chooser:show()
end

hs.hotkey.bind(hyper, "b", keyInfo("macOS MenuBar"), MenuBarChooser)
