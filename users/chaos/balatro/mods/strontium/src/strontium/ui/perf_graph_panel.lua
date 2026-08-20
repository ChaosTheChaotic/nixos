local panel = require('strontium.ui.panel')
local panel_manager = require('strontium.ui.panel_manager')

local perf_graph = {}

local MAX_SAMPLES = 300
local samples = {}
local sample_index = 0

local draw_calls_scale = 200
local cached_stats = { min = 0, max = 0, avg = 0, current = 0, draws_max = 0, draws_current = 0 }

local sample_interval = 0.05  -- 50ms = 20 samples/sec, 300 samples = 15 sec history
local time_accumulator = 0
local frame_accumulator = { dt_sum = 0, dt_max = 0, draws_sum = 0, draws_max = 0, count = 0 }

local CONFIG = {
    target_60fps = 1000 / 60,
    target_30fps = 1000 / 30,
    max_ms = 50,
    graph_height = 130,
    left_margin = 35,
    right_margin = 35,
}

local state = { panel = nil }

local function reset_accumulator()
    frame_accumulator.dt_sum = 0
    frame_accumulator.dt_max = 0
    frame_accumulator.draws_sum = 0
    frame_accumulator.draws_max = 0
    frame_accumulator.count = 0
end

local function init_samples()
    samples = {}
    for i = 1, MAX_SAMPLES do
        samples[i] = { time = 0, dt = 0, draws = 0 }
    end
    sample_index = 0
    time_accumulator = 0
    reset_accumulator()
end

local function write_sample(dt_ms, draw_calls)
    sample_index = (sample_index % MAX_SAMPLES) + 1
    local s = samples[sample_index]
    s.time = love.timer.getTime()
    s.dt = dt_ms
    s.draws = draw_calls or 0
    cached_stats.current = s.dt
    cached_stats.draws_current = s.draws
end

function perf_graph.update(dt)
    local dt_ms = dt * 1000
    frame_accumulator.dt_sum = frame_accumulator.dt_sum + dt_ms
    if dt_ms > frame_accumulator.dt_max then
        frame_accumulator.dt_max = dt_ms
    end
    frame_accumulator.count = frame_accumulator.count + 1
    
    time_accumulator = time_accumulator + dt
end

function perf_graph.flush(draw_calls)
    frame_accumulator.draws_sum = frame_accumulator.draws_sum + (draw_calls or 0)
    if (draw_calls or 0) > frame_accumulator.draws_max then
        frame_accumulator.draws_max = draw_calls or 0
    end
    
    if time_accumulator >= sample_interval then
        time_accumulator = time_accumulator - sample_interval
        
        if frame_accumulator.count > 0 then
            local dt_to_record = frame_accumulator.dt_max
            local draws_to_record = math.floor(frame_accumulator.draws_sum / frame_accumulator.count)
            write_sample(dt_to_record, draws_to_record)
        end
        
        reset_accumulator()
    end
end

function perf_graph.record_draw_stats()
    local stats = love.graphics.getStats()
    perf_graph.flush(stats and stats.drawcalls or 0)
end

local function get_ordered_samples()
    local ordered = {}
    for i = 1, MAX_SAMPLES do
        local idx = ((sample_index + i - 1) % MAX_SAMPLES) + 1
        ordered[i] = samples[idx]
    end
    return ordered
end

local function calc_stats(ordered)
    local sum, min_v, max_v, max_d = 0, math.huge, 0, 0
    local valid = 0
    for i = 1, MAX_SAMPLES do
        local s = ordered[i]
        if s.time > 0 then
            valid = valid + 1
            sum = sum + s.dt
            if s.dt < min_v then min_v = s.dt end
            if s.dt > max_v then max_v = s.dt end
            if s.draws > max_d then max_d = s.draws end
        end
    end
    if valid > 0 then
        cached_stats.min = min_v
        cached_stats.max = max_v
        cached_stats.avg = sum / valid
        cached_stats.draws_max = max_d
    else
        cached_stats.min, cached_stats.max, cached_stats.avg, cached_stats.draws_max = 0, 0, 0, 0
    end
end

local function get_color(dt_ms)
    local c = panel.COLORS
    if dt_ms <= CONFIG.target_60fps then
        return c.good[1], c.good[2], c.good[3]
    elseif dt_ms <= CONFIG.target_30fps then
        local t = (dt_ms - CONFIG.target_60fps) / (CONFIG.target_30fps - CONFIG.target_60fps)
        return c.good[1] + t * (c.warning[1] - c.good[1]),
               c.good[2] + t * (c.warning[2] - c.good[2]),
               c.good[3] + t * (c.warning[3] - c.good[3])
    else
        local t = math.min(1, (dt_ms - CONFIG.target_30fps) / CONFIG.target_30fps)
        return c.warning[1] + t * (c.bad[1] - c.warning[1]),
               c.warning[2] + t * (c.bad[2] - c.warning[2]),
               c.warning[3] + t * (c.bad[3] - c.warning[3])
    end
end

local frame_line = {}
local draws_line = {}

local function draw_content(self, x, y, w, h)
    local c = panel.COLORS
    local ordered = get_ordered_samples()
    calc_stats(ordered)

    local gx = x + CONFIG.left_margin
    local gw = w - CONFIG.left_margin - CONFIG.right_margin
    local gh = CONFIG.graph_height
    local gy = y
    local gb = gy + gh  -- graph bottom

    local y_max = math.max(CONFIG.max_ms, cached_stats.max * 1.1)

    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1, 0.7)
    love.graphics.rectangle("fill", gx, gy, gw, gh)
    love.graphics.setColor(c.border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", gx, gy, gw, gh)

    -- Grid
    love.graphics.setColor(0.2, 0.3, 0.4, 0.5)
    for i = 1, 3 do
        local ly = gy + gh * i * 0.25
        love.graphics.line(gx, ly, gx + gw, ly)
    end

    -- 60fps line
    local y60 = gy + gh - (CONFIG.target_60fps / y_max) * gh
    if y60 > gy and y60 < gy + gh then
        love.graphics.setColor(0.3, 0.8, 0.3, 0.8)
        love.graphics.line(gx, y60, gx + gw, y60)
    end

    -- 30fps line
    local y30 = gy + gh - (CONFIG.target_30fps / y_max) * gh
    if y30 > gy and y30 < gy + gh then
        love.graphics.setColor(0.8, 0.6, 0.2, 0.8)
        love.graphics.line(gx, y30, gx + gw, y30)
    end

    -- Target scalke
    local target_scale = math.max(100, cached_stats.draws_max * 1.2)
    if cached_stats.draws_max > draw_calls_scale then
        draw_calls_scale = cached_stats.draws_max * 1.2
    else
        draw_calls_scale = draw_calls_scale + (target_scale - draw_calls_scale) * 0.02
    end

    -- Draw bars and collect line points
    -- TODO: Laggy and slow and slow
    local bar_w = gw / MAX_SAMPLES
    local frame_pt_count = 0
    local draws_pt_count = 0

    for i = 1, MAX_SAMPLES do
        local s = ordered[i]
        local px = gx + (i - 1) * bar_w

        -- Frame time bar
        local bar_h = math.min(gh, (s.dt / y_max) * gh)
        local py = gb - bar_h
        if s.time > 0 and bar_h > 0 then
            local r, g, b = get_color(s.dt)
            love.graphics.setColor(r, g, b, 0.8)
            love.graphics.rectangle("fill", px, py, bar_w + 1, bar_h)
        end

        -- Frame time line point
        frame_pt_count = frame_pt_count + 1
        frame_line[frame_pt_count * 2 - 1] = px + bar_w * 0.5
        frame_line[frame_pt_count * 2] = py

        -- Draw calls line as a three point smoothed average
        local draws_avg = s.draws
        if i > 1 and i < MAX_SAMPLES then
            local prev = ordered[i - 1].draws
            local next = ordered[i + 1].draws
            draws_avg = (prev + s.draws + next) / 3
        end
        local dh = math.min(gh, (draws_avg / draw_calls_scale) * gh)
        local dy = gb - dh
        draws_pt_count = draws_pt_count + 1
        draws_line[draws_pt_count * 2 - 1] = px + bar_w * 0.5
        draws_line[draws_pt_count * 2] = dy
    end

    -- Clear leftover points
    for i = frame_pt_count * 2 + 1, #frame_line do frame_line[i] = nil end
    for i = draws_pt_count * 2 + 1, #draws_line do draws_line[i] = nil end

    -- Frame time line
    if frame_pt_count >= 2 then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.line(frame_line)
    end

    -- Draw calls line
    if draws_pt_count >= 2 then
        love.graphics.setColor(0.4, 0.7, 0.9, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(draws_line)
    end

    love.graphics.setColor(0.4, 0.7, 0.9, 1)
    love.graphics.print(string.format("%d", math.floor(draw_calls_scale)), x, gy)
    love.graphics.print("0", x + 15, gy + gh - 12)

    love.graphics.setColor(c.text_dim)
    love.graphics.print(string.format("%.0fms", y_max), gx + gw + 3, gy)
    love.graphics.print("0ms", gx + gw + 3, gy + gh - 12)
    if y60 > gy + 10 and y60 < gy + gh - 10 then
        love.graphics.setColor(0.3, 0.8, 0.3, 1)
        love.graphics.print("60", gx + gw + 3, y60 - 6)
    end

    -- Stats
    local sy = gy + gh + 8
    local lh = 16
    local fps = love.timer.getFPS()
    local fps_col = fps >= 55 and c.good or (fps >= 30 and c.warning or c.bad)
    love.graphics.setColor(fps_col[1], fps_col[2], fps_col[3], 1)
    love.graphics.print(string.format("FPS: %d", fps), x, sy)

    love.graphics.setColor(c.text)
    love.graphics.print(string.format("Frame: %.1fms", cached_stats.current), x + 80, sy)
    love.graphics.print(string.format("Avg: %.1fms", cached_stats.avg), x + 190, sy)
    love.graphics.print(string.format("Max: %.1fms", cached_stats.max), x + 290, sy)

    local gfx = love.graphics.getStats()
    love.graphics.setColor(0.4, 0.7, 0.9, 1)
    love.graphics.print(string.format("Draw calls: %d", gfx.drawcalls), x, sy + lh)
    love.graphics.setColor(c.text_dim)
    love.graphics.print(string.format("Shaders: %d", gfx.shaderswitches), x + 130, sy + lh)
    love.graphics.print(string.format("Tex: %.1fMB", gfx.texturememory / 1024 / 1024), x + 230, sy + lh)

    love.graphics.setColor(1, 1, 1, 1)
end

function perf_graph.init()
    init_samples()
    state.panel = panel.new({
        id = "perf_graph",
        title = "Performance",
        x = 50, y = 10,
        width = 580, height = 210,
        closable = true, minimizable = true, draggable = true,
        scrollable = false, visible = false,
        on_draw_content = draw_content,
        on_close = function() G.PERF_GRAPH = false end,
    })
    return state.panel
end

function perf_graph.get_panel() return state.panel end

function perf_graph.show()
    if state.panel then
        panel_manager.position_panel(state.panel)
        state.panel.visible = true
    end
end

function perf_graph.hide()
    if state.panel then state.panel.visible = false end
end

function perf_graph.toggle()
    if state.panel then
        if not state.panel.visible then
            panel_manager.position_panel(state.panel)
        end
        state.panel.visible = not state.panel.visible
        G.PERF_GRAPH = state.panel.visible
    end
end

function perf_graph.is_visible()
    return state.panel and state.panel.visible
end

function perf_graph.draw()
    if state.panel and state.panel.visible then
        state.panel:draw()
    end
end

return perf_graph
