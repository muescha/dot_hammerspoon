
--[[

Creates a 2-way enum insted of a normal table

debugTable(enum({"a","b","c"}))
{
    [1] = "a",
    [2] = "b",
    [3] = "c",
    ["a"] = 1,
    ["b"] = 2,
    ["c"] = 3,
}

]]--

function enum(tbl)
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end


--[[

Creates a named map

debugTable(enum({"a","b","c"}))
2022-11-19 19:48:58:

{
    ["a"] = "a",
    ["b"] = "b",
    ["c"] = "c",
}

]]--

---@param tbl table<number,string>
---@return table<string,string>
---
function enumString(tbl)

    local length = #tbl

    ---@type table<string,string>
    local enum = {}
    for i = 1, length do
        local v = tbl[i]
        enum[v] = v
    end

    return enum
end