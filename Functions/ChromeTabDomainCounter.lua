
-- Function to count TLDs in Chrome tabs using JavaScript

fileInfo()

function countTabDomains()
    showInfoStart()
    -- pause the loop to display the alert
    hs.timer.doAfter(0.1, function()
        local info_text = fetchURLsFromChrome()
        hs.alert.closeAll()
        showInfo(info_text)
    end)
end

function fetchURLsFromChrome()
    print("Starting to fetch URLs from Google Chrome...")

    local script = [[
        (function() {
                const app = Application("Google Chrome");

                const urls = [];

                app.windows().forEach((window, winIdx) => {
                    window.tabs().forEach((tab, tabIdx) => {
                        urls.push(tab.url());
                    });
                });
                return urls;
        })();
    ]]

    local ok, output, message = hs.osascript.javascript(script)
    --debugInfo("runActionCode -      ok: ", ok)
    --debugInfo("runActionCode -  Output: ", output)
    --debugInfo("runActionCode - Message: ", message)
    if ok then
        print("Successfully fetched URLs from Chrome.")
        return processURLs(output)

    else
        print("Error fetching URLs from Chrome: " .. tostring(output))
        return "Error fetching URLs from Chrome: " .. tostring(output)
    end

end

function processURLs(urls)
    print("Processing URLs...")
    local tldCounts = {}

    for _, url in ipairs(urls) do
        --print("Processing URL: " .. url)
        local tld = getTLD(url)
        if tld then
            tldCounts[tld] = (tldCounts[tld] or 0) + 1
            --print("Found TLD: " .. tld .. ", Count: " .. tldCounts[tld])
        else
            print("No valid TLD found for URL: " .. url)
        end
    end

    local function sortTLDsByCount(tldCounts)
        local sortedTLDs = {}

        for tld, count in pairs(tldCounts) do
            table.insert(sortedTLDs, {tld = tld, count = count})
        end

        table.sort(sortedTLDs, function(a, b)
            return a.count > b.count
        end)

        return sortedTLDs
    end

    local sortedTLDs = sortTLDsByCount(tldCounts)

    print("Final TLD Counts:")

    local info_text = "Found domains:\n"

    for _, entry in ipairs(sortedTLDs) do
        if entry.count > 1 then
            print(entry.tld .. ": " .. entry.count)
            info_text = info_text .. "\n-  " .. entry.tld .. ": " .. entry.count
        end
    end

    return info_text
end

function showInfoStart()
    local window = hs.window.frontmostWindow()
    hs.alert.show("Fetch urls ...", { textFont = "Menlo", atScreenEdge = 1}, window, 'do-not-close')
end

function showInfo(info_text)
    local window = hs.window.frontmostWindow()
    hs.alert.show(info_text, { textFont = "Menlo", atScreenEdge = 1}, window, 10)
end

function getTLD(url)
    if not url or url == "" then
        print("Invalid URL: " .. tostring(url))
        return nil
    end
    local hostname = url:match("://(.-)/") or url
    hostname = hostname:gsub("^www%.", "")
    return hostname
end

hs.hotkey.bind(hyper, "f", keyInfo(     "Count Tab Domains"), function()
    countTabDomains()
end)
