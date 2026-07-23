-- Michael Nietzold


-- https://github.com/CapsAdmin/oohh/tree/master/mmyy/lua/platforms/standard/extensions
-- https://github.com/CapsAdmin/goluwa/tree/master/core/lua/libraries/extensions
-- similar debug info here: https://github.com/CapsAdmin/oohh/blob/master/mmyy/lua/platforms/standard/meta/function.lua

-- better getInfo: https://github.com/Chain-of-Insight/nomsu/blob/9c04fab370b2b963b561c5c843f720ddcf105ef4/error_handling.moon

-- enhanced: https://github.com/GitoriousLispBackup/praxis/blob/master/prods/Cognitive/dribble.lua


function getFunctionName(fun)
    local info = debug.getinfo(fun,"S")
    local sourcePath = info.source:match("@?(.*)") -- remove @ from beginning
    local sourceText = ReadSource(sourcePath, info.linedefined-1, info.linedefined-1)
    return table.concat(sourceText,"\n")
end

function debugFunction(fun)
    local info = debug.getinfo(fun,"Sln")
    -- debugInfo(info)
    local sourcePath = info.source:match("@?(.*)") -- remove @ from beginning
    local sourceText = ReadSource(sourcePath, info.linedefined-1, info.lastlinedefined)

    local sourcePathAndLocation = info.source .. ":" .. info.linedefined .. "-" .. info.lastlinedefined

    print("Source: " .. sourcePathAndLocation .. "\n\n" .. table.concat(sourceText,"\n"))
end
