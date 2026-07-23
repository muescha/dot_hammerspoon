local ChromeCDP = {}

ChromeCDP.host = "127.0.0.1"
ChromeCDP.port = 9222
ChromeCDP.timeout = 5

-- WebSockets müssen referenziert bleiben, solange sie geöffnet sind.
ChromeCDP._connections = {}

local function endpoint(path)
    return string.format(
        "http://%s:%d%s",
        ChromeCDP.host,
        ChromeCDP.port,
        path
    )
end

local function safeCallback(callback, ...)
    if callback then
        callback(...)
    end
end

local function decodeJson(value)
    local ok, result = pcall(hs.json.decode, value)

    if not ok then
        return nil, "Invalid JSON response: " .. tostring(result)
    end

    return result
end

local function removeConnection(connectionId)
    ChromeCDP._connections[connectionId] = nil
end

local function createConnectionId()
    return string.format(
        "%d-%d",
        os.time(),
        math.random(100000, 999999)
    )
end

-- Lädt alle CDP-Targets von /json/list.
function ChromeCDP.getTargets(callback)
    hs.http.asyncGet(
        endpoint("/json/list"),
        nil,
        function(status, body)
            if status ~= 200 then
                safeCallback(
                    callback,
                    nil,
                    string.format(
                        "Could not load Chrome targets: HTTP %s",
                        tostring(status)
                    )
                )
                return
            end

            local targets, err = decodeJson(body)

            if not targets then
                safeCallback(callback, nil, err)
                return
            end

            safeCallback(callback, targets, nil)
        end
    )
end

-- Liefert nur echte Seiten, keine iframe-, worker- oder sonstigen Targets.
function ChromeCDP.getPages(callback)
    ChromeCDP.getTargets(function(targets, err)
        if not targets then
            safeCallback(callback, nil, err)
            return
        end

        local pages = {}

        for _, target in ipairs(targets) do
            if
                target.type == "page"
                and target.webSocketDebuggerUrl
            then
                table.insert(pages, target)
            end
        end

        safeCallback(callback, pages, nil)
    end)
end

-- Findet Seiten anhand einer URL oder eines URL-Teils.
function ChromeCDP.findPagesByUrl(search, callback)
    ChromeCDP.getPages(function(pages, err)
        if not pages then
            safeCallback(callback, nil, err)
            return
        end

        local matches = {}

        for _, page in ipairs(pages) do
            if
                page.url
                and string.find(page.url, search, 1, true)
            then
                table.insert(matches, page)
            end
        end

        safeCallback(callback, matches, nil)
    end)
end

-- Führt einen beliebigen CDP-Befehl auf einem Page-Target aus.
function ChromeCDP.sendCommand(page, method, params, callback)
    if not page then
        safeCallback(callback, nil, "Missing page")
        return
    end

    if not page.webSocketDebuggerUrl then
        safeCallback(
            callback,
            nil,
            "Page has no webSocketDebuggerUrl"
        )
        return
    end

    local connectionId = createConnectionId()
    local requestId = 1
    local completed = false
    local socket
    local timeoutTimer

    local function finish(result, err)
        if completed then
            return
        end

        completed = true

        if timeoutTimer then
            timeoutTimer:stop()
            timeoutTimer = nil
        end

        if socket then
            socket:close()
        end

        removeConnection(connectionId)
        safeCallback(callback, result, err)
    end

    timeoutTimer = hs.timer.doAfter(
        ChromeCDP.timeout,
        function()
            finish(nil, "CDP request timed out")
        end
    )

    socket = hs.websocket.new(
        page.webSocketDebuggerUrl,
        function(action, message)
            if action == "open" then
                local command = {
                    id = requestId,
                    method = method,
                    params = params or {}
                }

                local encoded = hs.json.encode(command)

                -- false erzwingt eine WebSocket-Textnachricht.
                socket:send(encoded, false)
                return
            end

            if action == "received" then
                local response, decodeErr = decodeJson(message)

                if not response then
                    finish(nil, decodeErr)
                    return
                end

                -- CDP kann zusätzlich Events ohne id senden.
                if response.id ~= requestId then
                    return
                end

                if response.error then
                    finish(
                        nil,
                        string.format(
                            "CDP error %s: %s",
                            tostring(response.error.code),
                            tostring(response.error.message)
                        )
                    )
                    return
                end

                finish(response.result, nil)
                return
            end

            if action == "fail" then
                finish(
                    nil,
                    "WebSocket connection failed: "
                        .. tostring(message)
                )
                return
            end

            if action == "closed" and not completed then
                finish(
                    nil,
                    "WebSocket closed before receiving a response"
                )
            end
        end
    )

    ChromeCDP._connections[connectionId] = socket
end

-- Führt JavaScript im Hauptkontext einer Seite aus.
function ChromeCDP.evaluate(page, javascript, callback, options)
    options = options or {}

    ChromeCDP.sendCommand(
        page,
        "Runtime.evaluate",
        {
            expression = javascript,
            returnByValue = options.returnByValue ~= false,
            awaitPromise = options.awaitPromise ~= false,
            userGesture = options.userGesture == true
        },
        function(result, err)
            if not result then
                safeCallback(callback, nil, err)
                return
            end

            if result.exceptionDetails then
                local details = result.exceptionDetails
                local description

                if
                    details.exception
                    and details.exception.description
                then
                    description = details.exception.description
                else
                    description = details.text
                end

                safeCallback(
                    callback,
                    nil,
                    "JavaScript exception: "
                        .. tostring(description)
                )
                return
            end

            local remoteObject = result.result

            if not remoteObject then
                safeCallback(
                    callback,
                    nil,
                    "CDP returned no Runtime result"
                )
                return
            end

            if remoteObject.type == "undefined" then
                safeCallback(callback, nil, nil)
                return
            end

            if remoteObject.value ~= nil then
                safeCallback(callback, remoteObject.value, nil)
                return
            end

            if remoteObject.unserializableValue ~= nil then
                safeCallback(
                    callback,
                    remoteObject.unserializableValue,
                    nil
                )
                return
            end

            -- Bei returnByValue=false wird gegebenenfalls ein RemoteObject
            -- mit objectId zurückgegeben.
            safeCallback(callback, remoteObject, nil)
        end
    )
end

-- Ermittelt Sichtbarkeit und Fokus einer Seite.
function ChromeCDP.getPageState(page, callback)
    ChromeCDP.evaluate(
        page,
        [[
            ({
                title: document.title,
                url: location.href,
                visibilityState: document.visibilityState,
                hidden: document.hidden,
                hasFocus: document.hasFocus()
            })
        ]],
        callback
    )
end

-- Ermittelt alle sichtbaren Tabs.
--
-- Bei mehreren Chrome-Fenstern kann pro Fenster jeweils ein Tab sichtbar sein.
function ChromeCDP.getVisiblePages(callback)
    ChromeCDP.getPages(function(pages, err)
        if not pages then
            safeCallback(callback, nil, err)
            return
        end

        if #pages == 0 then
            safeCallback(callback, {}, nil)
            return
        end

        local remaining = #pages
        local visiblePages = {}

        for _, page in ipairs(pages) do
            ChromeCDP.getPageState(page, function(state, stateErr)
                if state then
                    page.state = state

                    if state.visibilityState == "visible" then
                        table.insert(visiblePages, page)
                    end
                else
                    page.stateError = stateErr
                end

                remaining = remaining - 1

                if remaining == 0 then
                    safeCallback(callback, visiblePages, nil)
                end
            end)
        end
    end)
end

-- Ermittelt den aktuell verwendeten Tab.
--
-- Priorität:
-- 1. sichtbarer Tab mit document.hasFocus() == true
-- 2. der einzige sichtbare Tab
-- 3. kein eindeutiges Ergebnis
function ChromeCDP.getActivePage(callback)
    ChromeCDP.getVisiblePages(function(visiblePages, err)
        if not visiblePages then
            safeCallback(callback, nil, err)
            return
        end

        local focusedPages = {}

        for _, page in ipairs(visiblePages) do
            if page.state and page.state.hasFocus then
                table.insert(focusedPages, page)
            end
        end

        if #focusedPages == 1 then
            safeCallback(callback, focusedPages[1], nil)
            return
        end

        if #focusedPages > 1 then
            safeCallback(
                callback,
                nil,
                "Multiple Chrome pages report document focus"
            )
            return
        end

        if #visiblePages == 1 then
            safeCallback(callback, visiblePages[1], nil)
            return
        end

        if #visiblePages == 0 then
            safeCallback(
                callback,
                nil,
                "No visible Chrome page found"
            )
            return
        end

        safeCallback(
            callback,
            nil,
            "Chrome is not focused and multiple Chrome windows are visible"
        )
    end)
end

-- Führt JavaScript im aktiven Tab aus.
function ChromeCDP.executeJavascript(javascript, callback, options)
    ChromeCDP.getActivePage(function(page, err)
        if not page then
            safeCallback(callback, nil, err)
            return
        end

        ChromeCDP.evaluate(
            page,
            javascript,
            function(result, evaluateErr)
                safeCallback(
                    callback,
                    result,
                    evaluateErr,
                    page
                )
            end,
            options
        )
    end)
end

return ChromeCDP