
-- Function to count TLDs in Chrome tabs using JavaScript

fileInfo()

-- Function to fetch URLs from Chrome tabs
function fetchURLsFromChrome()
    print("Starting to fetch URLs from Google Chrome...")  -- Log the start of the fetch process

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

    -- Execute the JavaScript in the context of Google Chrome
    --hs.osascript.javascript(script, function(success, result)
    --    if success then
    --        print("Successfully fetched URLs from Chrome.")  -- Log success
    --        processURLs(result)  -- Call the Lua function to process URLs
    --    else
    --        print("Error fetching URLs from Chrome: " .. tostring(result))  -- Log any errors encountered
    --    end
    --end)

    local ok, output, message = hs.osascript.javascript(script)
    --debugInfo("runActionCode -      ok: ", ok)
    --debugInfo("runActionCode -  Output: ", output)
    --debugInfo("runActionCode - Message: ", message)
    if ok then
        print("Successfully fetched URLs from Chrome.")  -- Log success
        processURLs(output)  -- Call the Lua function to process URLs
    else
        print("Error fetching URLs from Chrome: " .. tostring(output))  -- Log any errors encountered
    end

end

-- Function to process the URLs and count TLDs
function processURLs(urls)
    print("Processing URLs...")  -- Log the start of processing
    local tldCounts = {}

    for _, url in ipairs(urls) do
        --print("Processing URL: " .. url)  -- Log each URL being processed
        local tld = getTLD(url)
        if tld then
            tldCounts[tld] = (tldCounts[tld] or 0) + 1
            --print("Found TLD: " .. tld .. ", Count: " .. tldCounts[tld])  -- Log found TLD and count
        else
            print("No valid TLD found for URL: " .. url)  -- Log if no TLD is found
        end
    end

    -- Function to sort TLDs by count in descending order
    local function sortTLDsByCount(tldCounts)
        local sortedTLDs = {}

        -- Create a sorted table
        for tld, count in pairs(tldCounts) do
            table.insert(sortedTLDs, {tld = tld, count = count})
        end

        -- Sort the table by count in descending order
        table.sort(sortedTLDs, function(a, b)
            return a.count > b.count
        end)

        return sortedTLDs
    end

    -- Call the sorting function
    local sortedTLDs = sortTLDsByCount(tldCounts)

    print("Final TLD Counts:")  -- Log the final counts

    -- Print the sorted TLDs and their counts
    for _, entry in ipairs(sortedTLDs) do
        if entry.count > 1 then
            print(entry.tld .. ": " .. entry.count)  -- Log each TLD and its count
        end
    end
end

-- Function to extract TLD from a URL
function getTLD(url)
    if not url or url == "" then
        print("Invalid URL: " .. tostring(url))  -- Log invalid URL
        return nil
    end
    local hostname = url:match("://(.-)/") or url  -- Extract hostname from URL
    hostname = hostname:gsub("^www%.", "")  -- Replace 'www.' at the start of the hostname
    return hostname
end

print("Press Command + Option + Control + T to count TLDs in Chrome.")

-- Bind a hotkey to trigger the TLD counting
hs.hotkey.bind(hyper, "f", keyInfo("Count Tab Domains"), function()
    fetchURLsFromChrome()
end)
