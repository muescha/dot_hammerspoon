---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 26.07.22 16:45
---

-- Helper Functions

function defaultStr(value)
    return value and " " .. value or ""
end

function debugMenuItem(application, element, description)
    local names = element:actionNames()
    if names then
        for i, name in ipairs(names) do
            print(defaultStr(application:name()) .. " " .. i ..". ".. defaultStr(element.AXTitle) .. defaultStr(element.AXValue) .. defaultStr(element.AXDescription).. defaultStr(element.AXHelp).. ' - "' .. name .. '": ' .. element:actionDescription(name))
        end
    end

end

function debugElement(element, description)
    if description then
        print("Check element: ".. description)
    end
    if not element then
        print("  Error: no element exists")
        return
    end

    if not element['attributeNames'] then
        print("  Error: element:attributeNames() not exists")
        return
    end

    local attributeNames = element:attributeNames()
    if attributeNames then
        for i, v in pairs(attributeNames) do
            local o = element:attributeValue(v)
            print("attributeValue " .. i .. ". " .. v .. ": " .. hs.inspect(o))
        end
    end

    local parameterizedAttributeNames = element:parameterizedAttributeNames()
    --     logger.i(inspect(currentElement:parameterizedAttributeNames()))
    if parameterizedAttributeNames then
        for i, name in ipairs(parameterizedAttributeNames) do
            print("parameterizedAttributeNames " .. i .. ". " .. name .. ': ' .. hs.inspect(element:parameterizedAttributeValue(name, {})))
        end
    end

    -- see more: https://github.com/dbalatero/dotfiles/blob/88db55576616a697e81cbc7478eecbec5672a22e/hammerspoon/experimental.lua#L267

    print('--------------------')
    print('action names:')
    local names = element:actionNames()
    print(hs.inspect(names))
    print('--------------------')
    print('action descriptions:')

    if names then
        for i, name in ipairs(names) do
            print("actionDescription " .. i .. '.  "' .. name .. '": ' .. (element:actionDescription(name) or '{null}'))
        end
    end

    print('Children:' .. hs.inspect(element:attributeValue('AXChildren')))

    -- more debugging in https://github.com/dbalatero/dotfiles/blob/master/hammerspoon/experimental.lua#L424


end

function debugInfo(...)
    local info = ""

    -- not work for args :( breaks on nil value
    -- for index, value in ipairs({...}) do

    local arg = { ... }
    for index = 1, #arg do
        local value = arg[index]
        if value == nil then
            info = info .. '<nil>'
        else
            if type(value) == 'string' then
                info = info .. value
            else
                info = info .. hs.inspect(value)
            end
        end
    end
    print(info)
end

function debugTable(obj)
    print(dumpTableToString(obj))
end

function dumpTableToString(o, level)
    if level == nil then
        level = 1
    end
    local showCounter = false
    local intend = string.rep('  ', level)
    if type(o) == 'table' then
        local info = {}
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                --k = '  ["'..k..'"] = '
                k = '  ' .. k .. ' = '
            else
                k = '  '
            end
            table.insert(info, intend .. k .. dumpTableToString(v, level + 1))

            --if type(k) ~= 'number' then k = '"'..k..'"' end
            --table.insert(info, intend.. '  ['..k..'] = ' .. dumpTableToString(v, level+1))
        end

        local s
        if #info > 0 then
            local counter = (showCounter and ('<' .. #info .. '>') or '')
            s = counter .. '{\n' .. table.concat(info, ',\n') .. '\n' .. intend .. '}'
        else
            s = '{}'
        end

        return s
    else
        --return tostring(o)
        return hs.inspect(o)
    end
end

function debugTraceback ()
    local level = 1
    while true do
        local info = debug.getinfo(level, "Sl")
        if not info then
            break
        end
        if info.what == "C" then
            -- is a C function?
            print(level, "C function")
        else
            -- a Lua function
            print(string.format("[%s]:%d",
                    info.short_src, info.currentline))
        end
        level = level + 1
    end
end

function ReadLine(src, line)
    return ReadSource(src:match("@?(.*)"), line)
    -- debugInfo(src)
    -- debugInfo(src:match("@?(.*)"))
    --if line == nil then return "?" end
    --local f = io.open(src:match("@?(.*)"))
    --local i = 1 -- line counter
    --for l in f:lines() do -- lines iterator, "l" returns the line
    --    if i == line then return l end -- we found this line, return it
    --    i = i + 1 -- counting lines
    --end
    --return "" -- Doesn't have that line
end

function debugTracePrint (event, line)
    local info = debug.getinfo(2)
    local s = info.short_src
    if info.source:startswith("@/Application") then
        return
    end

    local source = ReadLine(info.source, line)
    --local source = "x"

    print(s .. ":" .. line .. " " .. table.concat(source))
end

function debugTrace()
    debug.sethook(debugTracePrint, "l")
end


-- debugTrace()