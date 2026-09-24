local Performance = {}

--[[
Generic performance logger for Hammerspoon scripts.

Design goals:

* Keep domain knowledge outside this helper. The caller decides whether a slow
  bucket means "app", "item", "network", "cache", etc.
* Keep the public API small and dot-based:

      perf.newRun()
      perf.start("phaseName")
      local value = perf.value("phaseName", "fieldName", function()
          return expensiveRead()
      end)
      perf.trace("phaseName", {
          bucket = "item",
          phase = "phaseName",
          fields = { app = "Safari", item = "Downloads" },
          log = {
              thresholdMs = 30,
              label = "metadata trace",
              fields = { app = "Safari", item = "Downloads", fields = perf.values("phaseName") },
              order = { "app", "item", "fields" }
          }
      })
      perf.count("items")
      perf.logSummary()

Configuration examples:

1. Simple command runner:

      local perf = require("Helpers.Performance").init("CommandRunner", {
          logFileName = "CommandRunner.log",
          summary = {
              { key = "commands", label = "commands" },
              { key = "failed", label = "failed" }
          },
          slow = {
              command = {
                  thresholdMs = 100,
                  label = "slow command",
                  fields = { "phase", "name", "exitCode" }
              }
          }
      })

      perf.newRun()
      perf.start("runCommand")
      local ok = runCommand()
      perf.trace("runCommand", {
          bucket = "command",
          fields = { name = "brew update", exitCode = ok and 0 or 1 }
      })
      perf.count("commands")
      perf.logSummary()

2. UI scanner with detailed value timing:

      local perf = require("Helpers.Performance").init("UiScanner", {
          fieldValueMaxLength = 60,
          summary = {
              { key = "nodes", label = "nodes" },
              { key = "matches", label = "matches" }
          },
          slow = {
              node = {
                  thresholdMs = 20,
                  label = "slow node",
                  fields = { "phase", "role", "title" }
              }
          }
      })

      perf.newRun()
      perf.start("metadata")
      local role = perf.value("metadata", "role", function()
          return element:attributeValue("AXRole")
      end)
      local title = perf.value("metadata", "title", function()
          return element:attributeValue("AXTitle")
      end)
      perf.trace("metadata", {
          bucket = "node",
          fields = { role = role, title = title },
          log = {
              thresholdMs = 50,
              label = "node metadata",
              fields = { role = role, title = title, reads = perf.values("metadata") },
              order = { "role", "title", "reads" }
          }
      })
      perf.count("nodes")

3. Cache refresh:

      local perf = require("Helpers.Performance").init("CacheRefresh", {
          summary = {
              { key = "keys", label = "keys" },
              { key = "misses", label = "misses" }
          },
          slow = {
              read = {
                  thresholdMs = 10,
                  label = "slow read",
                  fields = { "phase", "key", "source" }
              },
              write = {
                  thresholdMs = 25,
                  label = "slow write",
                  fields = { "phase", "key", "target" }
              }
          }
      })
]]

local DEFAULT_CONFIG = {
    enabled = true,
    maxSlowEntries = 10,
    fieldValueMaxLength = 80,
    logToFile = true,
    logDir = hs.configdir .. "/Logs",
    logFileName = nil,
    summary = {},
    slow = {}
}

local function now()
    return hs.timer.secondsSinceEpoch()
end

local function mergeConfig(namespace, overrides)
    local config = {}
    for key, value in pairs(DEFAULT_CONFIG) do
        config[key] = value
    end
    for key, value in pairs(overrides or {}) do
        config[key] = value
    end
    config.namespace = namespace
    config.logFileName = config.logFileName or (namespace .. ".log")
    config.prefix = "[" .. namespace .. "][perf]"
    return config
end

local function newStats()
    -- One run is usually one user-visible action, such as opening a chooser.
    return {
        startedAt = now(),
        markers = {},
        phases = {},
        counters = {},
        slow = {}
    }
end

local function startMarker(stats, markerName)
    -- A marker can collect both elapsed time and nested value timings.
    stats.markers[markerName] = {
        startedAt = now(),
        values = {}
    }
end

local function markerElapsedMs(stats, markerName)
    local marker = stats.markers[markerName]
    if not marker then
        return 0
    end
    stats.markers[markerName] = nil
    return (now() - marker.startedAt) * 1000
end

local function addPhase(stats, phaseName, elapsedMs)
    stats.phases[phaseName] = (stats.phases[phaseName] or 0) + elapsedMs
end

local function topEntries(entries, limit)
    table.sort(entries, function(a, b)
        return a.elapsedMs > b.elapsedMs
    end)

    local top = {}
    for index = 1, math.min(#entries, limit) do
        table.insert(top, entries[index])
    end
    return top
end

local function formatPhases(phases)
    local names = {}
    for name, _ in pairs(phases) do
        table.insert(names, name)
    end
    table.sort(names)

    local parts = {}
    for _, name in ipairs(names) do
        table.insert(parts, string.format("%s=%.1fms", name, phases[name]))
    end
    return table.concat(parts, " ")
end

local function formatValue(value, maxLength)
    -- Keep log lines compact and stable even when values are nil or tables.
    if value == nil then
        return "<empty>"
    end

    local valueType = type(value)
    if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" then
        return "<" .. valueType .. ">"
    end

    local text = tostring(value):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if text == "" then
        return "<empty>"
    end
    if maxLength and #text > maxLength then
        text = text:sub(1, maxLength - 1) .. "…"
    end
    return text
end

local function formatFields(fields, order)
    local parts = {}
    local seen = {}

    for _, key in ipairs(order or {}) do
        seen[key] = true
        table.insert(parts, string.format("%s=%s", key, fields[key] or "-"))
    end

    local names = {}
    for key, _ in pairs(fields or {}) do
        if not seen[key] then
            table.insert(names, key)
        end
    end
    table.sort(names)

    for _, key in ipairs(names) do
        table.insert(parts, string.format("%s=%s", key, fields[key] or "-"))
    end

    return table.concat(parts, " ")
end

function Performance.init(namespace, overrides)
    local config = mergeConfig(namespace, overrides)
    local stats = nil
    local logger = {}

    local function logFilePath()
        return config.logDir .. "/" .. config.logFileName
    end

    local function writeLogLine(line, mode)
        if not config.enabled or not config.logToFile then
            return
        end

        local ok, err = pcall(function()
            hs.fs.mkdir(config.logDir)
            local file = assert(io.open(logFilePath(), mode or "a"))
            file:write(os.date("%Y-%m-%d %H:%M:%S"), " ", line, "\n")
            file:close()
        end)

        if not ok then
            hs.printf("%s failed to write log file: %s", config.prefix, tostring(err))
        end
    end

    function logger.resetLogFile()
        if not config.enabled or not config.logToFile then
            return
        end

        local ok, err = pcall(function()
            hs.fs.mkdir(config.logDir)
            local file = assert(io.open(logFilePath(), "w"))
            file:close()
        end)

        if not ok then
            hs.printf("%s failed to reset log file: %s", config.prefix, tostring(err))
        end
    end

    function logger.log(message, ...)
        local line = string.format(message, ...)
        hs.printf("%s", line)
        writeLogLine(line)
    end

    function logger.newRun()
        if not config.enabled then
            stats = nil
            return
        end

        stats = newStats()
    end

    function logger.start(markerName)
        if not stats then
            return
        end
        startMarker(stats, markerName)
    end

    function logger.finish(markerName, phaseName)
        if not stats then
            return
        end
        addPhase(stats, phaseName or markerName, markerElapsedMs(stats, markerName))
    end

    function logger.value(markerName, valueName, reader)
        -- Measures an expensive value read inside an active marker.
        if not stats then
            return reader()
        end

        local marker = stats.markers[markerName]
        local startedAt = now()
        local value = reader()
        if marker then
            table.insert(marker.values, {
                name = valueName,
                value = value,
                elapsedMs = (now() - startedAt) * 1000
            })
        end
        return value
    end

    function logger.values(markerName)
        -- Returns a compact "field=1.2ms:value" list for detail log lines.
        if not stats then
            return "-"
        end

        local marker = stats.markers[markerName]
        if not marker or #marker.values == 0 then
            return "-"
        end

        local parts = {}
        for _, entry in ipairs(marker.values) do
            table.insert(parts, string.format(
                    "%s=%.1fms:%s",
                    entry.name,
                    entry.elapsedMs,
                    formatValue(entry.value, config.fieldValueMaxLength)
            ))
        end
        return table.concat(parts, " | ")
    end

    function logger.trace(markerName, entry)
        -- Finishes a marker, records its phase total, optionally stores a slow
        -- entry in a configured bucket, and optionally emits a detail line.
        if not stats then
            return
        end

        entry = entry or {}
        local phaseName = entry.phase or markerName
        local elapsedMs = markerElapsedMs(stats, markerName)
        addPhase(stats, phaseName, elapsedMs)

        local bucketName = entry.bucket
        local bucketConfig = bucketName and config.slow[bucketName]
        if bucketConfig and elapsedMs >= (bucketConfig.thresholdMs or 0) then
            stats.slow[bucketName] = stats.slow[bucketName] or {}
            local fields = entry.fields or {}
            fields.phase = fields.phase or phaseName
            table.insert(stats.slow[bucketName], {
                elapsedMs = elapsedMs,
                fields = fields
            })
        end

        if entry.log and elapsedMs >= (entry.log.thresholdMs or 0) then
            logger.log(
                    "%s %s %.1fms %s",
                    config.prefix,
                    entry.log.label or "trace",
                    elapsedMs,
                    formatFields(entry.log.fields or {}, entry.log.order)
            )
        end
    end

    function logger.count(counterName, amount)
        if not stats then
            return
        end

        stats.counters[counterName] = (stats.counters[counterName] or 0) + (amount or 1)
    end

    function logger.logSummary()
        if not stats then
            return
        end

        local summaryFields = {}
        local summaryOrder = {}
        for _, entry in ipairs(config.summary or {}) do
            table.insert(summaryOrder, entry.label)
            summaryFields[entry.label] = stats.counters[entry.key] or 0
        end

        logger.log(
                "%s total=%.1fms %s phases: %s",
                config.prefix,
                (now() - stats.startedAt) * 1000,
                formatFields(summaryFields, summaryOrder),
                formatPhases(stats.phases)
        )

        local slowBucketNames = {}
        for name, _ in pairs(stats.slow) do
            table.insert(slowBucketNames, name)
        end
        table.sort(slowBucketNames)

        for _, bucketName in ipairs(slowBucketNames) do
            local bucketConfig = config.slow[bucketName] or {}
            for index, entry in ipairs(topEntries(stats.slow[bucketName], config.maxSlowEntries)) do
                logger.log(
                        "%s %s #%d %.1fms %s",
                        config.prefix,
                        bucketConfig.label or bucketName,
                        index,
                        entry.elapsedMs,
                        formatFields(entry.fields or {}, bucketConfig.fields)
                )
            end
        end
    end

    return logger
end

return Performance
