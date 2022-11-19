
function enum(tbl)
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end

function enumString(tbl)
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = v
    end

    return tbl
end