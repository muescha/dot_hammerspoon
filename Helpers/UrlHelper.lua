-- URL helper module

local UrlHelper = {}
UrlHelper.__index = UrlHelper

-- Configuration: domains mapped to a set (table with true values) of parameters to keep
local PARAM_WHITELIST_BY_DOMAIN = {
    ["google.com"] = { q = true, rlz = true },
    -- extend as needed:
    -- ["example.com"] = { id = true }
}

-- Extract hostname using hs.http.urlParts
local function getHostnameInternal(url)
    local parts = hs.http.urlParts(url)
    if not parts or not parts.host then return nil end
    return parts.host:gsub("^www%.", "")
end

function UrlHelper.getHostname(url)
    return getHostnameInternal(url)
end

function UrlHelper.getTld(url)
    local host = getHostnameInternal(url)
    if not host then return nil end
    -- last two labels (simple heuristic, not PSL-aware)
    local tld = host:match("([^%.]+%.[^%.]+)$")
    return tld or host
end

-- Normalize parts.queryItems (array of single-key tables) into a key->value map
local function normalizeQueryItemsToMap(qItems)
    local map = {}
    if type(qItems) ~= "table" then return map end
    for _, entry in ipairs(qItems) do
        if type(entry) == "table" then
            for k, v in pairs(entry) do
                map[tostring(k)] = tostring(v or "")
                break
            end
        end
    end
    return map
end

local function urlEncode(str)
    str = tostring(str or "")
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

-- Keep-only filter for query parameters based on domain whitelist, using hs.http.urlParts
function UrlHelper.filterUrlParams(url, tld)
    if not url then return url end
    local _tld = tld or UrlHelper.getTld(url)
    if not _tld then return url end

    local keep = PARAM_WHITELIST_BY_DOMAIN[_tld]
    if not keep then return url end

    local parts = hs.http.urlParts(url)
    if not parts then return url end

    local queryMap = {}
    if parts.queryItems and type(parts.queryItems) == "table" and #parts.queryItems > 0 then
        queryMap = normalizeQueryItemsToMap(parts.queryItems)
    end

    local filtered = {}
    for keepKey, shouldKeep in pairs(keep) do
        if shouldKeep then
            local v = queryMap[keepKey]
            if v ~= nil then
                table.insert(filtered, urlEncode(keepKey) .. "=" .. urlEncode(v))
            end
        end
    end

    local query = table.concat(filtered, "&")

    -- Rebuild URL from parts
    local scheme = parts.scheme or "https"
    local userinfo = parts.userinfo and (parts.userinfo .. "@") or ""
    local host = parts.host or ""
    local port = parts.port and (":" .. tostring(parts.port)) or ""
    local path = parts.path or ""
    if path == "" then path = "/" end
    local frag = parts.fragment and ("#" .. parts.fragment) or ""

    local rebuilt = string.format("%s://%s%s%s%s", scheme, userinfo, host, port, path)
    if query ~= "" then
        rebuilt = rebuilt .. "?" .. query
    end
    rebuilt = rebuilt .. frag
    return rebuilt
end

return UrlHelper
