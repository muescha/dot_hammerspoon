-- wifi/network watching
function wifiwatcher(watcher, message, interface, rssi, rate)

    print("message: " .. (message or "??"))
    print("interface: " .. (interface  or "??"))
    print("rssi (or other):" .. (rssi  or "??"))
    print("rate: " .. (rate or "??"))
end

local allTypes = {
    "SSIDChange", -- monitor when the associated network for the Wi-Fi interface changes
    "BSSIDChange", -- monitor when the base station the Wi-Fi interface is connected to changes
    "countryCodeChange", -- monitor when the adopted country code of the Wi-Fi interface changes
    "linkChange", -- monitor when the link state for the Wi-Fi interface changes
    "linkQualityChange", -- monitor when the RSSI or transmit rate for the Wi-Fi interface changes
    "modeChange", -- monitor when the operating mode of the Wi-Fi interface changes
    "powerChange", -- monitor when the power state of the Wi-Fi interface changes
    "scanCacheUpdated" -- monitor when the scan cache of the Wi-Fi interface is updated with new information
}

wifiWatcher = hs.wifi.watcher.new(wifiwatcher)
--wifiWatcher:watchingFor({"SSIDChange", "linkChange", "powerChange"})
wifiWatcher:watchingFor(allTypes)
wifiWatcher:start()


