
--[[
    Try to find how i can simulate a mouse right click
    find the exact current position of the cursor
      - in Text
      - in Menu
    then simulate a right mouse click at this place
--]]

hs.hotkey.bind({"shift"}, "F10", function()
  local ax = hs.axuielement
  local systemElement = ax.systemWideElement()
  local currentElement = systemElement:attributeValue("AXFocusedUIElement")

  -- local value = currentElement:attributeValue("AXValue")
  -- local textLength = currentElement:attributeValue("AXNumberOfCharacters")
  --hs.alert.show("->"..hs.inspect(currentElement:attributeNames()))
  debugElement(currentElement)

  local child = currentElement:attributeValue("AXSelectedChildren")

  debugElement(child)
  -- print(hs.inspect(currentElement:attributeNames()))
  local position = currentElement:attributeValue("AXPosition")

  local point = hs.mouse.getAbsolutePosition()

  print("Mouse : " .. hs.inspect(point))

  hs.alert.show(" at ".. position.x .. ":".. position.y .. " or ".. point.x ..":"..point.y)


  local point = position
  local clickState = hs.eventtap.event.properties.mouseEventClickState
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types["rightMouseDown"], point):setProperty(clickState, 1):post()
  hs.eventtap.event.newMouseEvent(hs.eventtap.event.types["rightMouseUp"], point):setProperty(clickState, 1):post()
end)

