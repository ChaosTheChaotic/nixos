-- Lightweight frame profiler for Strontium. Not especially accurate but it's a vibes thing.

local perf = {}

local _enabled = false
local _sections = {}
local _sorted = {}

local _frame_names = {}
local _frame_times = {}
local _frame_count = 0

local _stack_names = {}
local _stack_starts = {}
local _stack_count = 0

local _get_time = (love and love.timer and love.timer.getTime) or os.clock

local function now()
    return _get_time()
end

function perf.set_enabled(enabled)
    _enabled = enabled and true or false
end

function perf.is_enabled()
    return _enabled
end

function perf.toggle()
    _enabled = not _enabled
end

function perf.reset()
    for k in pairs(_sections) do
        _sections[k] = nil
    end
end

function perf.frame_begin()
    if not _enabled then return end
    _frame_count = 0
    _stack_count = 0
end

function perf.begin(name)
    if not _enabled then return end
    local idx = _stack_count + 1
    _stack_count = idx
    _stack_names[idx] = name
    _stack_starts[idx] = now()
end

function perf.finish(name)
    if not _enabled then return end
    local idx = _stack_count
    if idx <= 0 then return end
    local label = _stack_names[idx]
    local start = _stack_starts[idx]
    _stack_count = idx - 1

    local dt = now() - start
    local total = _frame_times[label]
    if total == nil then
        _frame_count = _frame_count + 1
        _frame_names[_frame_count] = label
        _frame_times[label] = dt
    else
        _frame_times[label] = total + dt
    end
end

function perf.frame_end()
    if not _enabled then return end
    for i = 1, _frame_count do
        local name = _frame_names[i]
        local dt = _frame_times[name] or 0
        local entry = _sections[name]
        if not entry then
            entry = { name = name, last = 0, avg = 0, max = 0, samples = 0 }
            _sections[name] = entry
        end
        local ms = dt * 1000
        entry.last = ms
        entry.samples = entry.samples + 1
        if entry.samples == 1 then
            entry.avg = ms
        else
            local alpha = 0.15
            entry.avg = entry.avg + (ms - entry.avg) * alpha
        end
        if ms > entry.max then
            entry.max = ms
        end
    end

    for i = 1, _frame_count do
        local name = _frame_names[i]
        _frame_times[name] = nil
        _frame_names[i] = nil
    end
    _frame_count = 0
end

function perf.get_sections()
    return _sections
end

function perf.get_sorted(order)
    order = order or "avg"
    local n = 0
    for _, entry in pairs(_sections) do
        n = n + 1
        _sorted[n] = entry
    end
    for i = n + 1, #_sorted do
        _sorted[i] = nil
    end
    table.sort(_sorted, function(a, b)
        return (a[order] or 0) > (b[order] or 0)
    end)
    return _sorted, n
end

function perf.write_report(filename)
    if not (love and love.filesystem and love.filesystem.write) then
        return nil
    end
    if not filename then
        filename = string.format("strontium_perf_%s.txt", os.date("%Y%m%d_%H%M%S"))
    end

    local lines = {}
    lines[#lines + 1] = "Strontium Perf Report"
    lines[#lines + 1] = "Generated: " .. os.date("%Y-%m-%d %H:%M:%S")
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("%-32s %8s %8s %8s %8s", "Section", "Last", "Avg", "Max", "Samples")
    lines[#lines + 1] = string.rep("-", 72)

    local entries, count = perf.get_sorted("avg")
    for i = 1, count do
        local entry = entries[i]
        local name = entry.name or "unknown"
        if #name > 32 then
            name = name:sub(1, 29) .. "..."
        end
        lines[#lines + 1] = string.format(
            "%-32s %8.2f %8.2f %8.2f %8d",
            name,
            entry.last or 0,
            entry.avg or 0,
            entry.max or 0,
            entry.samples or 0
        )
    end

    love.filesystem.write(filename, table.concat(lines, "\n"))
    if love.filesystem.getSaveDirectory then
        return love.filesystem.getSaveDirectory() .. "/" .. filename
    end
    return filename
end

return perf
