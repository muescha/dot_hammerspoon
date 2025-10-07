-- Kopiert den Titel und die URL aus Chrome und speichert sie als Markdown in die Zwischenablage

fileInfo()

-- Configuration: domains mapped to a set (table with true values) of parameters to keep
local PARAM_WHITELIST_BY_DOMAIN = {
    ["google.com"] = { q = true },
    -- add more:
    -- ["example.com"] = { id = true }
}



local function processTitleAndURL(output)
    local json = hs.json.decode(output)
    if not json or json.error then
        print("Failed to extract URL and title: " .. (json and json.error or "Unknown error"))
        return
    end

    local tld = helper.url.getTld(json.url)
    if not tld then
        print("Could not determine TLD for URL: " .. json.url)
        return
    end

    local filteredUrl = helper.url.filterUrlParams(json.url, tld, PARAM_WHITELIST_BY_DOMAIN)

    -- TODO make as config
    local info_template = "Copied to clipboard:\n\n- Domain: %s\n-  Title: %s\n-    URL: %s"
    local markdown = string.format("%s: [%s](%s)", tld, json.title, filteredUrl)
    local info = string.format(info_template, tld, json.title, filteredUrl)
    hs.pasteboard.setContents(markdown)
    print("Copied to clipboard:\n" .. markdown)
    hs.alert.show(info, { textFont = "Menlo"}, 4)
end

local function fetchTitleAndURLFromChrome()
    print("Fetching title and URL from Google Chrome...")

    local script = [[
        (function() {
            const app = Application("Google Chrome");
            const frontWindow = app.windows[0];

            if (!frontWindow) return JSON.stringify({ error: "No Chrome window found" });

            const activeTab = frontWindow.activeTab;
            return JSON.stringify({
                title: activeTab.title(),
                url: activeTab.url()
            });
        })();
    ]]

    local ok, output, message = hs.osascript.javascript(script)
    if ok and output and output ~= "" then
        processTitleAndURL(output)
    else
        print("Error fetching data from Chrome: " .. tostring(message))
    end
end

hs.hotkey.bind(hyper, "c", keyInfo("Copy ChromeTab URL"), function()
    fetchTitleAndURLFromChrome()
end)