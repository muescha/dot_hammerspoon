-- https://gist.github.com/kgriffs/124aae3ac80eefe57199451b823c24ec

function string:startsWith(start)
    return self:sub(1, #start) == start
end

function string:endswith(ending)
    return ending == "" or self:sub(-#ending) == ending
end


-- Define the standalone stringToHex function
function stringToHex(str)
    if not str then
        return ""  -- Return empty string for nil or non-existent input
    end

    if str == "" then
        return ""  -- Return empty string for empty string input
    end

    local result = {}
    for i = 1, #str do
        table.insert(result, string.format("%02X", string.byte(str, i)))
    end
    return table.concat(result, " ")
end

function string:toHex()
    return stringToHex(self)
end