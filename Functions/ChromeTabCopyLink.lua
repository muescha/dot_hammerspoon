-- Kopiert den Titel und die URL aus Chrome und speichert sie als Markdown in die Zwischenablage

fileInfo()

local function getTLD(url)
    local hostname = url:match("://(.-)/") or url
    hostname = hostname:gsub("^www%.", "")
    return hostname:match("([^%.]+%.[^%.]+)$") -- Holt das letzte Domain-Level
end

local function processTitleAndURL(output)
    local json = hs.json.decode(output)
    if not json or json.error then
        print("Failed to extract URL and title: " .. (json and json.error or "Unknown error"))
        return
    end

    local tld = getTLD(json.url)
    if not tld then
        print("Could not determine TLD for URL: " .. json.url)
        return
    end

    -- TODO make as config
    local markdown = string.format("%s: [%s](%s)", tld, json.title, json.url)
    hs.pasteboard.setContents(markdown)
    print("Copied to clipboard:\n" .. markdown)
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