---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 07.04.23 11:26
--- https://github.com/mtarbit/dotfiles/blob/master/source/.hammerspoon/util.lua

function readFile(path)
    local f = io.open(path, 'r')
    if f==nil then
        error("\nERROR: missing File: "..path)
    end
    local s = f:read('a')
    f:close()
    return s
end

-- TODO: Remove because better implementation is in hs.fnutils.partial
function partial(fn, arg)
    return function(...)
        return fn(arg, ...)
    end
end

-- usage:
-- template([[
--   var name = "{{ action }}";
-- ]], {
--        value=(value and 1 or 0),
--        something=value,
--        javascript=readFile('assets/breaks/main.js')
-- })

function template(s, t)
    local pattern = '{{%s*([^}]-)%s*}}'
    -- allow usage of backticks ` in javascript files
    -- and do not replace ${} placeholder in first place.
    local replace = function(k)
        return tostring(t[k])
                :gsub("`", "\\`")
                :gsub("%$", "\\$")
    end
    --local replace = function(k) return tostring(t[k]) end
    local result, _ = s:gsub(pattern, replace)
    return result
end

function readFileTemplate(path, t)
    return template(template(readFile(path), t),t)
end

function runJavaScriptInBrowser(code, browser, wrapper)
    return runJavaScript(
            readFileTemplate(wrapper, {
                code = code,
                application = browser,
            }
        )
    )
end

function runJavaScript(code)
    debugInfo("JS: ", code)
    return hs.osascript.javascript(code)
end

function runAppleScript(code)
    debugInfo("AS: ", code)
    return hs.osascript.applescript(code)
end

