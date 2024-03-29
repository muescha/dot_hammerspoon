---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 06.08.22 14:46
---

fileInfo()

hs.hotkey.bind(hyper, "h", keyInfo("Highlight Current App"), function()

    local app = hs.application.frontmostApplication()
    local window = app:mainWindow()
    local rect = window:frame()

    drawRect(rect)

    local center = hs.geometry.rectMidPoint(rect)
    hs.mouse.absolutePosition(center)

    mouseHighlight()

    --hs.alert.show("Center mouse related to app ".. app:name() )
end )

function mouseHighlight()

    -- Get the current co-ordinates of the mouse pointer
    local mousepoint = hs.mouse.absolutePosition()

    drawCircle(mousepoint, 40)

end
hs.hotkey.bind(hyper, "g", keyInfo("Highlight mouse position"),mouseHighlight)


function showTimed(object, seconds, callevent)

    local fadeIn = .5
    local fadeOut = 1

    object:show(fadeIn)

    local hideTimer = hs.timer.doAfter(seconds + fadeIn, function()
        object:hide(fadeOut)
    end)

    local destroyTimer = hs.timer.doAfter(seconds + fadeIn + fadeOut, function()

        object:delete()
        object = nil

        if callevent then
            callevent:stop()
            callevent = nil
        end
    end)

end

function drawRect(frame)

    local box = hs.drawing.rectangle(frame)
    box:setFillColor({["red"]=1,["blue"]=0.1,["green"]=0.1,["alpha"]=0.5}):setFill(true)
    box:setRoundedRectRadii(10.0, 10.0)
    box:setLevel(hs.drawing.windowLevels["floating"])

    showTimed(box,0.5)
end

function getCircleRect(centerPoint, radius)
    return hs.geometry.rect(centerPoint.x-radius, centerPoint.y-radius, 2*radius, 2*radius)
end

function drawCircle(centerPoint, radius)

    local circle = hs.drawing.circle(getCircleRect(centerPoint, radius))
    circle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    circle:setFill(false)
    circle:setStrokeWidth(5)

    -- https://github.com/szymonkaliski/hhann/blob/master/hhann/init.lua
    local tapMove = hs.eventtap.new({
        hs.eventtap.event.types.mouseMoved
    }, function(e)

        if circle.frame then
            local eventLocation = e:location()
            circle:setFrame(getCircleRect(eventLocation, radius))
        end
    end)

    tapMove:start()
    showTimed(circle,2,tapMove)

end
