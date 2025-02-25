-- https://gist.github.com/kgriffs/124aae3ac80eefe57199451b823c24ec

function string:startsWith(start)
    return self:sub(1, #start) == start
end

function string:endswith(ending)
    return ending == "" or self:sub(-#ending) == ending
end
