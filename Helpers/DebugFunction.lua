-- Michael Nietzold


-- https://github.com/CapsAdmin/oohh/tree/master/mmyy/lua/platforms/standard/extensions
-- https://github.com/CapsAdmin/goluwa/tree/master/core/lua/libraries/extensions
-- similar debug info here: https://github.com/CapsAdmin/oohh/blob/master/mmyy/lua/platforms/standard/meta/function.lua

-- better getInfo: https://github.com/Chain-of-Insight/nomsu/blob/9c04fab370b2b963b561c5c843f720ddcf105ef4/error_handling.moon

-- enhanced: https://github.com/GitoriousLispBackup/praxis/blob/master/prods/Cognitive/dribble.lua

function ReadSource(filename, fromLine, toLine)

    if toLine == nil then toLine = fromLine end

    local function skip_n_lines(f, n)
        while f:read('*l') do
            n = n - 1
            if n == 0 then break end
        end
        return n
    end

    local function read_n_lines(f, n)
        local t = {}
        for i = 1, n do
            local s = f:read('*l')
            if not s then break end
            t[#t + 1] = s
        end
        return t
    end

    local data = {}

    --local f = io.open(filename, 'rb+')
    local f = io.open(filename)
    if 0 == skip_n_lines(f, fromLine) then
        data = read_n_lines(f, toLine-fromLine+1)
    end
    return data
end


function debugFunction(fun)
    local info = debug.getinfo(fun,"Sln")
    -- debugInfo(info)
    local sourcePath = info.source:match("@?(.*)") -- remove @ from beginning
    local sourceText = ReadSource(sourcePath, info.linedefined-1, info.lastlinedefined)

    local sourcePathAndLocation = info.source .. ":" .. info.linedefined .. "-" .. info.lastlinedefined

    print("Source: " .. sourcePathAndLocation .. "\n\n" .. table.concat(sourceText,"\n"))
end
