-- Kopiert den Titel und die URL aus Chrome und speichert sie als Markdown in die Zwischenablage

fileInfo()

-- Configuration: domains mapped to a set (table with true values) of parameters to keep
local PARAM_WHITELIST_BY_DOMAIN = {
    ["google.com"] = { q = true },
    -- add more:
    -- ["example.com"] = { id = true }
}

local function escapeMarkdownLabel(text)
    local s = tostring(text or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub("%]", "\\]")
    s = s:gsub("%[", "\\[")
    return s
end


local function processTitleAndURL(output)
    local json = hs.json.decode(output)
    if not json or json.error then
        print("Failed to extract URL and title: " .. (json and json.error or "Unknown error"))
        return
    end

    local tld = helper.url.getTld(json.url) or "link"
    if tld == "link" then
        print("Could not determine TLD for URL, using fallback: " .. tostring(json.url))
    end

    local filteredUrl = helper.url.filterUrlParams(json.url, tld, PARAM_WHITELIST_BY_DOMAIN) or json.url
    local safeTitle = escapeMarkdownLabel(json.title)

    -- TODO make as config
    local info_template = "Copied to clipboard:\n\n- Domain: %s\n-  Title: %s\n-    URL: %s"
    local markdown = string.format("%s: [%s](%s)", tld, safeTitle, filteredUrl)
    local info = string.format(info_template, tld, json.title, filteredUrl)
    return {
        markdown = markdown,
        info = info
    }
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
    local result
    if ok and output and output ~= "" then
        result = processTitleAndURL(output)
    else
        print("Error fetching data from Chrome: " .. tostring(message))
    end
    return result
end

local function fetchTitleAndURLFromChromeToClipboard()
    local result = fetchTitleAndURLFromChrome()
    if result and result.markdown and result.markdown ~= "" then
        hs.pasteboard.setContents(result.markdown)
        print("Copied to clipboard:\n" .. result.markdown)
        hs.alert.show(result.info, { textFont = "Menlo" }, 4)
    end
end

local function fetchTitleAndURLFromChromeAndPaste()
    local result = fetchTitleAndURLFromChrome()
    if result and result.markdown and result.markdown ~= "" then
        -- too slow
        -- hs.eventtap.keyStrokes(result.markdown)
        hs.pasteboard.setContents(result.markdown)
        hs.timer.usleep(10000) -- 10ms
        hs.eventtap.keyStroke({"cmd"}, "v")
    end
end

local function fetchAllTabsFromCurrentWindow()
    print("Fetching all tabs from current Chrome window...")

    local script = [[
        (function() {
            const app = Application("Google Chrome");
            const frontWindow = app.windows[0];

            if (!frontWindow) return JSON.stringify({ error: "No Chrome window found" });

            const allTabs = [];
            const tabs = frontWindow.tabs;

            for (let i = 0; i < tabs.length; i++) {
                allTabs.push({
                    title: tabs[i].title(),
                    url: tabs[i].url()
                });
            }

            return JSON.stringify({ tabs: allTabs });
        })();
    ]]

    local ok, output, message = hs.osascript.javascript(script)
    if ok and output and output ~= "" then
        return hs.json.decode(output)
    else
        print("Error fetching all tabs from Chrome: " .. tostring(message))
        return nil
    end
end

local function formatTabsAsMarkdown(tabsData)
    if not tabsData or not tabsData.tabs or #tabsData.tabs == 0 then
        return nil, "No tabs found"
    end

    local lines = {}
    table.insert(lines, "Tabs (" .. #tabsData.tabs .. " total):")

    for i, tab in ipairs(tabsData.tabs) do
        local tld = helper.url.getTld(tab.url) or "link"
        local filteredUrl = helper.url.filterUrlParams(tab.url, tld, PARAM_WHITELIST_BY_DOMAIN) or tab.url
        local safeTitle = escapeMarkdownLabel(tab.title)
        local markdown = string.format("- %s: [%s](%s)", tld, safeTitle, filteredUrl)
        table.insert(lines, markdown)
    end

    return table.concat(lines, "\n")
end

local function fetchAllTabsToClipboardAndPaste()
    local tabsData = fetchAllTabsFromCurrentWindow()
    if not tabsData then return end

    local markdown, err = formatTabsAsMarkdown(tabsData)
    if not markdown then
        print("Error formatting tabs: " .. err)
        return
    end

    hs.pasteboard.setContents(markdown)
    local info = string.format("Copied %d tabs from current window", #tabsData.tabs)
    print(info .. ":\n" .. markdown)
    hs.timer.usleep(10000) -- 10ms
    hs.eventtap.keyStroke({"cmd"}, "v")
end

hs.hotkey.bind(hyper, "c", keyInfo("Copy ChromeTab URL"), function()
    fetchTitleAndURLFromChromeToClipboard()
end)

hs.hotkey.bind({ "shift", "ctrl"}, "v", keyInfo("insert ChromeTab URL"), function()
    fetchTitleAndURLFromChromeAndPaste()
end)

hs.hotkey.bind({ "cmd", "shift", "ctrl"}, "v", keyInfo("insert all ChromeTabs from window"), function()
    fetchAllTabsToClipboardAndPaste()
end)
