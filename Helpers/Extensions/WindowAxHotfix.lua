
--- Created by muescha.
--- DateTime: 15.10.24
---
--- See: https://github.com/Hammerspoon/hammerspoon/issues/3224#issuecomment-2155567633
--- https://github.com/Hammerspoon/hammerspoon/issues/3277



local function axHotfix(win, infoText)
    if not win then win = hs.window.frontmostWindow() end
    if not infoText then infoText = "?" end

    local axApp = hs.axuielement.applicationElement(win:application())
    local wasEnhanced = axApp.AXEnhancedUserInterface
    axApp.AXEnhancedUserInterface = false
    print(" enable hotfix: " .. infoText)

    return function()
        hs.timer.doAfter(hs.window.animationDuration * 2, function()
            print("disable hotfix: " .. infoText)
            axApp.AXEnhancedUserInterface = wasEnhanced
        end)
    end
end

local function withAxHotfix(fn, position, infoText)
    if not position then position = 1 end
    return function(...)
        local revert = axHotfix(select(position, ...), infoText)
        fn(...)
        revert()
    end
end

local windowMT = hs.getObjectMetatable("hs.window")
windowMT.setFrame = withAxHotfix(windowMT.setFrame,1, "setFrame")

-- no need for maximize because maximize use setFrame internal
--windowMT.maximize = withAxHotfix(windowMT.maximize,1, "maximize")