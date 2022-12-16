
--[[
    Try to find how i can simulate a mouse right click
    find the exact current position of the cursor
      - in Text
      - in Menu
    then simulate a right mouse click at this place
--]]

fileInfo()



function drawInfo(frame)
  global_border = hs.drawing.rectangle(frame)
  global_border:setStrokeColor({ ["red"] = 1, ["blue"] = 0, ["green"] = 0, ["alpha"] = 0.8 })
  global_border:setFill(false)
  global_border:setStrokeWidth(8)
  global_border:show()
end



hs.hotkey.bind({"shift"}, "F10", keyInfo("Test AX-Functions"),function()
  local ax = hs.axuielement
  local systemElement = ax.systemWideElement()
  local currentElement = systemElement:attributeValue("AXFocusedUIElement")

  -- local value = currentElement:attributeValue("AXValue")
  -- local textLength = currentElement:attributeValue("AXNumberOfCharacters")
  --hs.alert.show("->"..hs.inspect(currentElement:attributeNames()))
  debugElement(currentElement, "currentElement")

  local child = currentElement:attributeValue("AXSelectedChildren")

  debugElement(child, "child")
  -- print(hs.inspect(currentElement:attributeNames()))
  local position = currentElement:attributeValue("AXPosition")

  local point = hs.mouse.getAbsolutePosition()

  print("Position : " .. hs.inspect(position))
  print("Mouse    : " .. hs.inspect(point))

  hs.alert.show(" at ".. position.x .. ":".. position.y .. " \n or ".. point.x ..":"..point.y)

  frame = hs.geometry.new(position.x, position.y, point.x,point.y)
  drawInfo(frame)

  local point = position

  debugInfo(point)

  local clickState = hs.eventtap.event.properties.mouseEventClickState
  debugInfo(clickState)
  --hs.eventtap.event.newMouseEvent(hs.eventtap.event.types["rightMouseDown"], point):setProperty(clickState, 1):post()
  --hs.eventtap.event.newMouseEvent(hs.eventtap.event.types["rightMouseUp"], point):setProperty(clickState, 1):post()
  hs.eventtap.rightClick(point)
end)

-- right click examples
-- only need to get current point of cursor somehow
-- source: https://github.com/schilken/dot-hammerspoon/blob/master/papyrus-functions.lua

function deleteObject()
  local capp = hs.application.frontmostApplication()
  --  local tabList = hs.tabs.tabWindows(capp)
  --  print(inspect(tabList))
  local w = hs.window.frontmostWindow()
  local title = w:title()
  print("title:" .. title)
  if w:title():ends_with("Denkbrett") then
    local point = hs.mouse.getRelativePosition()
    hs.eventtap.rightClick(point)
    hs.timer.doAfter(1, function()
      hs.eventtap.keyStroke({}, "up")
      hs.eventtap.keyStroke({}, "return")
    end )
  end
end

function makeGroupFromBox()
  hs.eventtap.keyStroke({"cmd"}, "a")
  hs.eventtap.keyStroke({"cmd"}, "x")
  local point = hs.mouse.getRelativePosition()
  hs.eventtap.rightClick(point)
  hs.timer.doAfter(0.5, function()
    local newpoint = { x=point.x + 30, y=point.y + 15}
    hs.eventtap.leftClick(newpoint)
    hs.eventtap.keyStroke({}, "delete")
    hs.eventtap.keyStroke({}, "delete")
    hs.eventtap.keyStroke({}, "delete")
    hs.eventtap.keyStroke({}, "delete")
    hs.eventtap.keyStroke({}, "delete")
    hs.eventtap.keyStroke({}, "delete")
    hs.eventtap.keyStroke({"cmd"}, "v")
  end )
end

local axuielement = require("hs.axuielement")
local canvas      = require("hs.canvas")

-- see: https://github.com/Hammerspoon/hammerspoon/discussions/3266
hs.hotkey.bind(
        --{"cmd", "pagedown"},
        hyper, "s",
        keyInfo("test1 context menu"),
        function()
          local function getFocusedElementPosition()
            local systemElement = axuielement.systemWideElement()
            if not systemElement then return nil end
            local currentElement = systemElement:attributeValue("AXFocusedUIElement")
            if not currentElement then return nil end
            -- we don't want to get position for anything that isn't a text field
            -- axUtils => https://github.com/dbalatero/VimMode.spoon/blob/master/lib/utils/ax.lua
            --if not axUtils.isTextField(currentElement) then return nil end
            local position = currentElement:attributeValue('AXPosition')
            if not position then return nil end
            return {
              x = position.x,
              y = position.y
            }
          end
          local currentApp = hs.application.frontmostApplication()
          local axApp = axuielement.applicationElement(currentApp)
          axApp:setAttributeValue('AXEnhancedUserInterface', true)
          axApp:setAttributeValue('AXManualAccessibility', true)
          --hs.eventtap.leftClick(getFocusedElementPosition())
          local position = getFocusedElementPosition()
          debugInfo(position)
          hs.eventtap.rightClick(position)

        end
)

-- some more AX Stuff: https://github.com/dbalatero/dotfiles/blob/master/hammerspoon/experimental.lua#L424

-- see also: https://github.com/asmagill/hs._asm.axuielement/issues/24

local finspect = function(...)
  local stuff = { ... }
  if #stuff == 1 and type(stuff[1]) == "table" then stuff = stuff[1] end
  return hs.inspect(stuff, { newline = " ", indent = "" })
end



-- since this is used in both the keyDown and the keyUp functions, if we don't want it to be global,
-- it needs to be defined outside of both
local selectionRectangle = nil

hs.hotkey.bind(hyper, "y",
        keyInfo("test2 context menu"),
        function()
  local systemWideElement = axuielement.systemWideElement()
  local focusedElement    = systemWideElement.AXFocusedUIElement
  if focusedElement then
    local selectedRange = focusedElement.AXSelectedTextRange
    if selectedRange then
      local selectionBounds = focusedElement:parameterizedAttributeValue("AXBoundsForRange", selectedRange)
      if selectionBounds then
        selectionRectangle = canvas.new(selectionBounds):show()
        selectionRectangle[#selectionRectangle + 1] = {
          type        = "rectangle",
          strokeWidth = 5,
          action      = "stroke",
          strokeColor = { green = 1, blue = 1 },
        }
        print(finspect(selectionBounds))
        print(finspect(selectionRectangle))
        print(finspect(selectionRectangle:frame()))
        --frame = hs.geometry.new(selectionBounds)
        --debugInfo(frame)
        --drawInfo(frame)
        --drawInfo(hs.geometry.new(selectionRectangle))
        --drawInfo(selectionRectangle:frame())
      end
    end
  end
end, function()
  if selectionRectangle then
    selectionRectangle:hide()
    selectionRectangle = nil
  end
end)

-- see also: https://github.com/asmagill/hs._asm.axuielement/issues/24#issue-780507907
-- see also: https://balatero.com/writings/hammerspoon/retrieving-input-field-values-and-cursor-position-with-hammerspoon/
-- see also: https://stackoverflow.com/questions/6544311/how-to-get-global-screen-coordinates-of-currently-selected-text-via-accessibilit
