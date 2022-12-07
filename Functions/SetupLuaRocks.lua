fileInfo()

local lVer = _VERSION:match("Lua (.+)$")

--local luarocks = hs.execute("which luarocks"):gsub("\n", "")
local luarocks = "/Users/muescha/.asdf/shims/luarocks"

local loarocks_path = hs.execute(luarocks .. " --lua-version " .. lVer .. " path --lr-path"):gsub("\n", "")
local loarocks_cpath = hs.execute(luarocks .. " --lua-version " .. lVer .. " path --lr-cpath"):gsub("\n", "")

package.path = package.path .. ";" .. loarocks_path
package.cpath = package.cpath .. ";" .. loarocks_cpath

--print(package.path:gsub(';', ";\n"))
--print(package.cpath:gsub(';', ";\n"))

