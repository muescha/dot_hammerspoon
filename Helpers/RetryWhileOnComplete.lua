--- retryWhileOnComplete: Keep retrying while conditionFn returns true, with optional completion callback.
--- Supports either positional arguments or a single options table.
---
--- Usage (positional):
--- retryWhileOnComplete(conditionFn, [onComplete], [delay], [maxTries])
---
--- Usage (named args table):
--- retryWhileOnComplete{
---   conditionFn = function() ... end,
---   onComplete = function(success) ... end,  -- optional
---   delay = 0.1,                              -- optional, default 0.1 seconds
---   maxTries = 3                             -- optional, default 3 retries
--- }
---
--- @param conditionFn function Required. Function returning true to retry, false to stop.
--- @param onComplete function Optional. Called once with boolean success when retry ends.
--- @param delay number Optional. Seconds between retries. Defaults to 0.1.
--- @param maxTries number Optional. Max retry attempts. Defaults to 3.
function retryWhileOnComplete(...)
    local args = {...}
    local conditionFn, onComplete, delay, maxTries

    if type(args[1]) == "table" then
        local opts = args[1]
        conditionFn = opts.conditionFn
        onComplete = opts.onComplete
        delay = opts.delay or 0.1
        maxTries = opts.maxTries or 3
    else
        conditionFn = args[1]
        if type(args[2]) == "function" then
            onComplete = args[2]
            delay = args[3] or 0.1
            maxTries = args[4] or 3
        else
            onComplete = nil
            delay = args[2] or 0.1
            maxTries = args[3] or 3
        end
    end

    if type(conditionFn) ~= "function" then
        error("retryWhile: conditionFn must be a function")
    end

    local function loop(triesLeft)
        if triesLeft <= 0 then
            if onComplete then onComplete(false) end -- failed: max tries reached
            return
        end

        if conditionFn() then
            hs.timer.doAfter(delay, function()
                loop(triesLeft - 1)
            end)
        else
            if onComplete then onComplete(true) end -- success: condition false
        end
    end

    loop(maxTries)
end
