table.sorted = function(tab, func)
    local tab = {table.unpack(tab)}
    table.sort(tab, func)
    return tab
end