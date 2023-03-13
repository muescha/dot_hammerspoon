---
--- Generated by Luanalysis
--- Created by muescha.
--- DateTime: 06.08.22 14:51
---


fileInfo()

--local allNetworks = table.concat(hs.wifi.availableNetworks(), ',')
--debugInfo(allNetworks)

--networks = hs.wifi.availableNetworks()
--table.sort(networks)
--print('\n\n' .. table.concat(networks,"\n")..'\n\n')

--print('\n\n' .. table.concat(table.sorted(hs.wifi.availableNetworks()),"\n")..'\n\n')


-- Show Wi-Fi notifications
wifiMenu = hs.menubar.new()
local wifiwatcher = hs.wifi.watcher.new(function()
    local wifiName = hs.wifi.currentNetwork()
    if wifiName then
        hs.notify.show("Connected to Wi-Fi network", "", wifiName, "")
        wifiMenu:setTitle("ᯤ " .. wifiName)
    else
        hs.notify.show("You lost Wi-Fi connection", "", "", "")
        wifiMenu:setTitle("ᯤ Wifi OFF")
    end
end)

currentNetwork = hs.wifi.currentNetwork()

wifiMenu:setTitle("ᯤ " .. ((currentNetwork ~= nil) and currentNetwork or '<none>'))
wifiwatcher:start()


