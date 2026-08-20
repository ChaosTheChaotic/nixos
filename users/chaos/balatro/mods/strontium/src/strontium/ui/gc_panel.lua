-- GC Telemetry Panel - Memory and allocation trend display.

local panel = require('strontium.ui.panel')
local panel_manager = require('strontium.ui.panel_manager')

local gc_panel = {}

local state = {
    panel = nil,
    samples = {},
    deltas = {},
    rates = {},
    capacity = 180,
    head = 0,
    count = 0,
    last_mem = nil,
}

local function push_sample(mem_kb, dt)
    local head = state.head % state.capacity + 1
    local delta = state.last_mem and (mem_kb - state.last_mem) or 0
    local rate = (dt and dt > 0) and (delta / dt) or 0

    state.samples[head] = mem_kb
    state.deltas[head] = delta
    state.rates[head] = rate

    state.head = head
    state.count = math.min(state.count + 1, state.capacity)
    state.last_mem = mem_kb
end

local function iter_samples()
    local count = state.count
    if count == 0 then
        return function() return nil end
    end

    local start = (state.count < state.capacity) and 1 or (state.head % state.capacity + 1)
    local i = 0
    return function()
        if i >= count then return nil end
        i = i + 1
        local idx = ((start + i - 2) % state.capacity) + 1
        return idx
    end
end

local function compute_stats()
    local min_mem, max_mem, sum = nil, nil, 0
    local min_delta, max_delta, sum_delta = nil, nil, 0
    local min_rate, max_rate, sum_rate = nil, nil, 0
    local count = 0

    for idx in iter_samples() do
        local mem = state.samples[idx]
        local delta = state.deltas[idx] or 0
        local rate = state.rates[idx] or 0

        min_mem = (not min_mem or mem < min_mem) and mem or min_mem
        max_mem = (not max_mem or mem > max_mem) and mem or max_mem
        sum = sum + mem

        min_delta = (not min_delta or delta < min_delta) and delta or min_delta
        max_delta = (not max_delta or delta > max_delta) and delta or max_delta
        sum_delta = sum_delta + delta

        min_rate = (not min_rate or rate < min_rate) and rate or min_rate
        max_rate = (not max_rate or rate > max_rate) and rate or max_rate
        sum_rate = sum_rate + rate

        count = count + 1
    end

    if count == 0 then
        return nil
    end

    return {
        count = count,
        min_mem = min_mem,
        max_mem = max_mem,
        avg_mem = sum / count,
        min_delta = min_delta,
        max_delta = max_delta,
        avg_delta = sum_delta / count,
        min_rate = min_rate,
        max_rate = max_rate,
        avg_rate = sum_rate / count,
    }
end

local function draw_graph(x, y, w, h, stats)
    if not stats or stats.count < 2 then return end

    local min_mem = stats.min_mem or 0
    local max_mem = stats.max_mem or min_mem + 1
    local range = max_mem - min_mem
    if range <= 0 then range = 1 end

    local step = w / math.max(1, stats.count - 1)
    local last_x, last_y = nil, nil
    local i = 0

    for idx in iter_samples() do
        local mem = state.samples[idx]
        local t = (mem - min_mem) / range
        local px = x + i * step
        local py = y + h - t * h
        if last_x then
            love.graphics.line(last_x, last_y, px, py)
        end
        last_x, last_y = px, py
        i = i + 1
    end
end

local function draw_content(self, x, y, w, h)
    local c = panel.COLORS
    local line_h = panel.DEFAULTS.line_height
    local line = 0

    local function draw_line(text, color)
        love.graphics.setColor(color or c.text)
        love.graphics.print(text, x, y + line * line_h)
        line = line + 1
    end

    local mem_kb = collectgarbage("count") or 0
    push_sample(mem_kb, self._last_dt or 0)
    local stats = compute_stats()

    draw_line(string.format("Mem: %.2f MB", mem_kb / 1024), c.value_number)
    if stats then
        draw_line(string.format("Delta: %+0.2f KB", stats.avg_delta), c.text_dim)
        draw_line(string.format("Rate: %+0.2f KB/s", stats.avg_rate), c.text_dim)
        draw_line(string.format("Min/Max: %.2f/%.2f MB",
            stats.min_mem / 1024, stats.max_mem / 1024), c.text_dim)
    else
        draw_line("Sampling...", c.text_dim)
    end

    line = line + 0.4
    local graph_y = y + line * line_h
    local graph_h = math.max(60, h - (graph_y - y) - 10)
    love.graphics.setColor(0.15, 0.2, 0.25, 0.6)
    love.graphics.rectangle("fill", x, graph_y, w - 10, graph_h, 4, 4)

    love.graphics.setColor(0.35, 0.7, 1.0, 0.9)
    draw_graph(x + 4, graph_y + 4, w - 18, graph_h - 8, stats)

    self:update_scroll(math.ceil((graph_y + graph_h - y) / line_h))
    love.graphics.setColor(1, 1, 1, 1)
end

function gc_panel.init()
    state.panel = panel.new({
        id = "gc_panel",
        title = "GC Telemetry",
        x = 40,
        y = 40,
        width = 360,
        height = 240,
        closable = true,
        minimizable = true,
        draggable = true,
        scrollable = false,
        visible = false,
        on_draw_content = draw_content,
        on_update = function(self, dt)
            self._last_dt = dt
        end,
    })

    return state.panel
end

function gc_panel.show()
    if state.panel then
        panel_manager.position_panel(state.panel)
        state.panel.visible = true
    end
end

function gc_panel.hide()
    if state.panel then
        state.panel.visible = false
    end
end

function gc_panel.toggle()
    if state.panel then
        if not state.panel.visible then
            panel_manager.position_panel(state.panel)
        end
        state.panel.visible = not state.panel.visible
    end
end

function gc_panel.is_visible()
    return state.panel and state.panel.visible
end

return gc_panel
