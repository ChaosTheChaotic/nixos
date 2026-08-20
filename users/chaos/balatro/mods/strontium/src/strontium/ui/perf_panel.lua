-- Profiling panel (for our integrated profiling)

local panel = require('strontium.ui.panel')
local panel_manager = require('strontium.ui.panel_manager')
local perf = require('strontium.perf')

local perf_panel = {}

local state = {
    panel = nil,
    sort = "avg",
    toggle_bounds = nil,
    last_report = nil,
    recording = false,
}

local function toggle_recording()
    if state.recording then
        state.recording = false
        state.last_report = perf.write_report()
    else
        perf.reset()
        state.recording = true
        state.last_report = nil
    end
end

local function stop_sampling()
    if state.recording then
        toggle_recording()
    end
    perf.set_enabled(false)
end

local function calc_max_avg(entries, count)
    local max_avg = 0
    for i = 1, count do
        local entry = entries[i]
        if entry.avg > max_avg then
            max_avg = entry.avg
        end
    end
    return max_avg
end

local function draw_toggle(x, y, w, h, value, hovered)
    local c = panel.COLORS
    love.graphics.setColor(hovered and c.border_hover or c.border)
    love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)
    local knob_x = value and (x + w - h + 2) or (x + 2)
    local knob_r = h / 2 - 2
    love.graphics.setColor(value and c.value_bool_true or c.value_bool_false)
    love.graphics.circle("fill", knob_x + knob_r, y + h / 2, knob_r)
end

local function draw_content(self, x, y, w, h)
    local c = panel.COLORS
    local line_h = panel.DEFAULTS.line_height
    local base_y = y - (self.scroll_offset or 0) * line_h
    local cur_y = base_y
    local toggle_w = 40
    local toggle_h = 18
    local mx, my = love.mouse.getPosition()

    local function advance(lines)
        cur_y = cur_y + line_h * (lines or 1)
    end

    local function draw_text(text, color, dx)
        love.graphics.setColor(color or c.text)
        love.graphics.print(text, x + (dx or 0), cur_y)
    end
    local extra_lines = 0
    local function advance_layer(lines)
        local n = lines or 1
        advance(n)
        extra_lines = extra_lines + n
    end

    local toggle_x = x + w - toggle_w - 10
    local toggle_y = cur_y + 1
    local hovered = panel.point_in_rect(mx, my, toggle_x, toggle_y, toggle_w, toggle_h)
    state.toggle_bounds = { x = toggle_x, y = toggle_y, w = toggle_w, h = toggle_h }

    draw_text("Recording:", c.key)
    draw_text(state.recording and "ON" or "OFF", state.recording and c.value_bool_true or c.value_bool_false, 110)
    draw_toggle(toggle_x, toggle_y, toggle_w, toggle_h, state.recording, hovered)
    advance(1.2)

    if state.last_report then
        draw_text("Saved:", c.key)
        draw_text(state.last_report, c.text_dim, 60)
        advance(1.1)
    end

    local entries, count = perf.get_sorted(state.sort)
    if count == 0 then
        draw_text("No samples yet.", c.text_dim)
        advance(1)
        self:update_scroll(8)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local last_x = x + w - 160
    local avg_x = x + w - 100
    local max_x = x + w - 50
    local bar_x = x + 150
    local bar_w = math.max(0, last_x - bar_x - 10)

    love.graphics.setColor(c.section)
    love.graphics.print("Section", x, cur_y)
    love.graphics.setColor(c.text_dim)
    love.graphics.print("Last", last_x, cur_y)
    love.graphics.print("Avg", avg_x, cur_y)
    love.graphics.print("Max", max_x, cur_y)
    advance(1)

    local max_avg = calc_max_avg(entries, count)

    local name_limit = math.max(8, math.floor((bar_x - x - 8) / 7))
    for i = 1, count do
        local entry = entries[i]
        local name = entry.name or "unknown"
        if #name > name_limit then
            name = name:sub(1, name_limit - 3) .. "..."
        end

        if bar_w > 0 and max_avg > 0 then
            love.graphics.setColor(0.15, 0.2, 0.25, 0.6)
            love.graphics.rectangle("fill", bar_x, cur_y + 3, bar_w, line_h - 6, 2, 2)
            local fill = (entry.avg / max_avg) * bar_w
            love.graphics.setColor(0.35, 0.7, 1.0, 0.85)
            love.graphics.rectangle("fill", bar_x, cur_y + 3, fill, line_h - 6, 2, 2)
        end

        love.graphics.setColor(c.text)
        love.graphics.print(name, x, cur_y)

        love.graphics.setColor(c.value_number)
        love.graphics.print(string.format("%.2f", entry.last), last_x, cur_y)
        love.graphics.print(string.format("%.2f", entry.avg), avg_x, cur_y)
        love.graphics.print(string.format("%.2f", entry.max), max_x, cur_y)

        advance(1)
    end

    local br = G.STRONTIUM_RENDERER
    local layer_stats = br and br.stats and br.stats.layers or nil
    local layer_order = br and br.registry and br.registry.layer_order or nil
    if layer_stats and layer_order and G.USE_STRONTIUM_RENDERER then
        advance_layer(0.8)
        love.graphics.setColor(c.section)
        love.graphics.print("Layer lanes", x, cur_y)
        advance_layer(1)

        local known = {}
        for i = 1, #layer_order do
            local key = layer_order[i]
            known[key] = true
            local entry = layer_stats[key]
            if not entry then
                goto continue
            end

            local total = (entry.batch or 0) + (entry.overlay or 0) + (entry.immediate or 0)
            if total <= 0 then
                goto continue
            end

            draw_text(string.format("%s: b=%d o=%d i=%d", key, entry.batch or 0, entry.overlay or 0, entry.immediate or 0), c.text_dim)
            advance_layer(1)

            ::continue::
        end

        local extras = {}
        for key, entry in pairs(layer_stats) do
            if known[key] then
                goto continue
            end

            local total = (entry.batch or 0) + (entry.overlay or 0) + (entry.immediate or 0)
            if total <= 0 then
                goto continue
            end

            extras[#extras + 1] = key

            ::continue::
        end
        if #extras > 0 then
            table.sort(extras)
            for i = 1, #extras do
                local key = extras[i]
                local entry = layer_stats[key]
                if not entry then
                    goto continue
                end

                draw_text(string.format("%s: b=%d o=%d i=%d", key, entry.batch or 0, entry.overlay or 0, entry.immediate or 0), c.text_dim)
                advance_layer(1)

                ::continue::
            end
        end
    end

    local total_lines = count + 4 + (state.last_report and 1 or 0) + extra_lines
    self:update_scroll(total_lines)
    love.graphics.setColor(1, 1, 1, 1)
end

function perf_panel.init()
    state.panel = panel.new({
        id = "perf_breakdown",
        title = "Perf Breakdown",
        x = 20,
        y = 20,
        width = 520,
        height = 320,
        closable = true,
        minimizable = true,
        draggable = true,
        scrollable = true,
        visible = false,
        on_draw_content = draw_content,
        on_close = function()
            stop_sampling()
        end,
        on_click = function(self, px, py)
            local bounds = state.toggle_bounds
            if bounds and panel.point_in_rect(px, py, bounds.x, bounds.y, bounds.w, bounds.h) then
                toggle_recording()
                return true
            end
            return false
        end,
    })
    state.panel:update_scroll(12)
    return state.panel
end

function perf_panel.show()
    if state.panel then
        panel_manager.position_panel(state.panel)
        state.panel.visible = true
        perf.set_enabled(true)
    end
end

function perf_panel.hide()
    if state.panel then
        state.panel.visible = false
        stop_sampling()
    end
end

function perf_panel.toggle()
    if state.panel then
        if not state.panel.visible then
            panel_manager.position_panel(state.panel)
        end
        state.panel.visible = not state.panel.visible
        if state.panel.visible then
            perf.set_enabled(true)
        else
            stop_sampling()
        end
    end
end

function perf_panel.is_visible()
    return state.panel and state.panel.visible
end

return perf_panel
