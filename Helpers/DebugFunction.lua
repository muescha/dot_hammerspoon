-- Michael Nietzold


-- https://github.com/CapsAdmin/oohh/tree/master/mmyy/lua/platforms/standard/extensions
-- https://github.com/CapsAdmin/goluwa/tree/master/core/lua/libraries/extensions
-- similar debug info here: https://github.com/CapsAdmin/oohh/blob/master/mmyy/lua/platforms/standard/meta/function.lua

-- better getInfo: https://github.com/Chain-of-Insight/nomsu/blob/9c04fab370b2b963b561c5c843f720ddcf105ef4/error_handling.moon

-- enhanced: https://github.com/GitoriousLispBackup/praxis/blob/master/prods/Cognitive/dribble.lua


local function getFunctionInfo(fun)
    return debug.getinfo(fun, "S")
end

function getFunctionLocation(fun)
    local info = getFunctionInfo(fun)
    return info.source .. ":" .. info.linedefined .. "-" .. info.lastlinedefined
end

function getFunctionBody(fun)
    local info = getFunctionInfo(fun)
    local sourcePath = info.source:match("@?(.*)")
    local sourceText = ReadSource(sourcePath, info.linedefined, info.lastlinedefined)
    return table.concat(sourceText, "\n")
end

function getFunctionSignature(fun)
    return getFunctionBody(fun):match("([^\n]+)")
end

function getHammerspoonFunctionName(fun)
    local info = getFunctionInfo(fun)
    local signature = getFunctionSignature(fun)

    local moduleName = info.source:match("/extensions/hs/(.-)%.lua$")
    local functionName = signature:match("module%.([%w_]+)%s*=%s*function")

    if moduleName and functionName then
        return "hs." .. moduleName .. "." .. functionName
    end

    return signature
end

-- TODO: BETTER: debugFunctionBody
function debugFunction(fun)
    print("Source.path:\n\n" .. getFunctionLocation(fun) .. "\n\n")
    print("Source.body:\n\n" .. getFunctionBody(fun) .. "\n\n")
end
