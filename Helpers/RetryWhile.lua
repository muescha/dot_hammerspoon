--- retryWhile: Keep retrying while conditionFn returns true
--- Works like a `while` loop but with an async delay
--- @param conditionFn function Returns true to continue, false to stop
--- @param delay number Delay between tries (default 0.1)
--- @param maxTries number Maximum retries (default 3)
function retryWhile(conditionFn, delay, maxTries)
    delay = delay or 0.1
    maxTries = maxTries or math.huge  -- infinite if not specified

    local function loop(triesLeft)
        if triesLeft <= 0 then return end
        if conditionFn() then
            hs.timer.doAfter(delay, function()
                loop(triesLeft - 1)
            end)
        end
    end

    loop(maxTries)
end


