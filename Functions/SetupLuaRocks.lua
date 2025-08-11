fileInfo()

-- See: https://github.com/asmagill/hammerspoon/wiki/Luarocks-and-Hammerspoon#addressing-paths

local lVer = _VERSION:match("Lua (.+)$")

--local luarocks = hs.execute("which luarocks"):gsub("\n", "")
local luarocks = "/Users/muescha/.asdf/shims/luarocks"

local cmd_path = luarocks .. " --lua-version " .. lVer .. " path --lr-path "
local cmd_cpath = luarocks .. " --lua-version " .. lVer .. " path --lr-cpath"

local luarocks_path = hs.execute(cmd_path, true):gsub("\n", "")
local luarocks_cpath = hs.execute(cmd_cpath, true):gsub("\n", "")

package.path = package.path .. ";" .. luarocks_path
package.cpath = package.cpath .. ";" .. luarocks_cpath

--print("Luarocks Paths:")
--local cmd_check = 'zsh -l -c "which /Users/muescha/.asdf/shims/luarocks"'
--print(hs.execute(cmd_check))
--local cmd_test = 'zsh -l -c "/Users/muescha/.asdf/shims/luarocks --lua-version ' .. lVer .. ' list"'
--print(hs.execute(cmd_test))
--print("lVer: ".. _VERSION)
--print("lVer: ".. lVer)
--print("cmd_path:  ".. cmd_path)
--print("cmd_cpath: ".. cmd_cpath)
--print(hs.execute(cmd_path, true))
--print(hs.execute(cmd_cpath, true))
--print("luarocks_path:  " .. luarocks_path)
--print("luarocks_cpath: " .. luarocks_cpath)
--print(package.path:gsub(';', ";\n"))
--print(package.cpath:gsub(';', ";\n"))

