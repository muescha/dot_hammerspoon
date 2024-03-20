fileInfo()

-- See: https://github.com/asmagill/hammerspoon/wiki/Luarocks-and-Hammerspoon#addressing-paths

local lVer = _VERSION:match("Lua (.+)$")

--local luarocks = hs.execute("which luarocks"):gsub("\n", "")
local luarocks = "/Users/muescha/.asdf/shims/luarocks"

local luarocks_path = hs.execute(luarocks .. " --lua-version " .. lVer .. " path --lr-path"):gsub("\n", "")
local luarocks_cpath = hs.execute(luarocks .. " --lua-version " .. lVer .. " path --lr-cpath"):gsub("\n", "")

package.path = package.path .. ";" .. luarocks_path
package.cpath = package.cpath .. ";" .. luarocks_cpath

--print(package.path:gsub(';', ";\n"))
--print(package.cpath:gsub(';', ";\n"))

