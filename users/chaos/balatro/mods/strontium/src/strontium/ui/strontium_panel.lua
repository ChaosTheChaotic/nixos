-- Main panel

local panel = require('strontium.ui.panel')
local panel_manager = require('strontium.ui.panel_manager')
local components = require('strontium.ui.components')

local strontium_panel = {}

local panels = {
    perf_graph = nil,
    perf_breakdown = nil,
    inspector = nil,
    effect_lab = nil,
    gc_panel = nil,
}

local state = {
    panel = nil,
    hover_button = nil,
    caps_cache = nil,
    caps_cache_time = 0,
}

local BUTTONS = {
    { id = "graph", label = "Performance Graph", target = "perf_graph" },
    { id = "perf_breakdown", label = "Profiler", target = "perf_breakdown" },
    { id = "inspector", label = "Object Inspector", target = "inspector" },
    { id = "effect_lab", label = "Effect Editor", target = "effect_lab" },
    { id = "gc_panel", label = "GC Monitor", target = "gc_panel" },
}

local CONFIGS = {
    { id = "batched", label = "Batched Renderer", key = "G.USE_BATCHED_RENDERER", default = false },
    { id = "strontium", label = "Strontium Renderer", key = "G.USE_STRONTIUM_RENDERER", default = true },
    { id = "ubershader", label = "Ubershader", key = "G.STRONTIUM_UBERSHADER", default = true },
    { id = "instancing", label = "Instancing", key = "G.STRONTIUM_INSTANCING", default = true },
    { id = "profiling", label = "ProFI profiler", key = "G.STRONTIUM_PROFILING", default = false },
    { id = "order_map", label = "Order Map", key = "G.STRONTIUM_ORDER_MAP", default = true },
    { id = "sort_x", label = "Sort Cards By X", key = "G.STRONTIUM_SORT_X", default = true },
    { id = "cull_covered", label = "Cull Covered Stickers", key = "G.STRONTIUM_CULL_COVERED", default = true },
    { id = "cull_faces", label = "Cull Covered Faces", key = "G.STRONTIUM_CULL_FACE", default = false },
    { id = "occlusion", label = "Occlusion Debug", key = "G.STRONTIUM_DEBUG_OCCLUSION", default = false },
}

local CONFIG_INDEX = {}
for i, cfg in ipairs(CONFIGS) do
    CONFIG_INDEX[cfg.id] = i
end

local COLORS = {
    button_bg = {0.2, 0.35, 0.5, 0.9},
    button_bg_hover = {0.3, 0.5, 0.7, 1.0},
    button_text = {0.9, 0.95, 1.0, 1.0},
    toggle_on = {0.3, 0.8, 0.4, 1.0},
    toggle_off = {0.4, 0.4, 0.45, 0.8},
    toggle_bg = {0.15, 0.15, 0.2, 0.9},
    section_title = {1.0, 0.85, 0.3, 1.0},
    stat_label = {0.6, 0.7, 0.8, 0.9},
    stat_value = {0.9, 0.95, 1.0, 1.0},
    stat_good = {0.3, 1.0, 0.5, 1.0},
    stat_warning = {1.0, 0.9, 0.3, 1.0},
    stat_bad = {1.0, 0.4, 0.3, 1.0},
    divider = {0.3, 0.4, 0.5, 0.5},
}

local CONTROL_COLORS = {
    button_bg = COLORS.button_bg,
    button_bg_hover = COLORS.button_bg_hover,
    button_text = COLORS.button_text,
    toggle_on = COLORS.toggle_on,
    toggle_off = COLORS.toggle_off,
    toggle_bg = COLORS.toggle_bg,
    toggle_border = {0.3, 0.4, 0.5, 0.8},
    toggle_border_hover = {0.5, 0.7, 0.9, 1.0},
}

local function count_cards()
    if G.I and G.I.CARD then
        return #G.I.CARD
    end
    local count = 0
    local card_mt = rawget(_G, 'Card')
    if card_mt and G.MOVEABLES then
        for i = 1, #G.MOVEABLES do
            local obj = G.MOVEABLES[i]
            if obj and getmetatable(obj) == card_mt then
                count = count + 1
            end
        end
    end
    return count
end

local function yesno(value)
    if value == nil then return "Unknown" end
    return value and "Yes" or "No"
end

local function get_bound_label(draw_ms, frame_ms)
    if not draw_ms or not frame_ms or frame_ms <= 0 then
        return "Unknown", COLORS.stat_value
    end
    local ratio = draw_ms / frame_ms
    if ratio >= 0.75 then
        return "GPU/Draw (est.)", COLORS.stat_warning
    end
    if ratio <= 0.4 then
        return "CPU/Update (est.)", COLORS.stat_warning
    end
    return "Mixed (est.)", COLORS.stat_value
end

local function get_caps_snapshot()
    local now = love.timer.getTime()
    if state.caps_cache and (now - (state.caps_cache_time or 0)) < 1.0 then
        return state.caps_cache
    end

    local api, version, vendor, device = love.graphics.getRendererInfo()
    local supported = love.graphics.getSupported and love.graphics.getSupported() or {}
    local rgba16f = nil
    if love.graphics.getCanvasFormats then
        local ok, formats = pcall(love.graphics.getCanvasFormats)
        if ok and formats then
            rgba16f = formats.rgba16f
        end
    end

    local br = G.STRONTIUM_RENDERER
    local pb = br and br.param_buffer or nil
    local param_format = pb and pb.format or "Unknown"
    local param_size = (pb and pb.width and pb.height) and string.format("%dx%d", pb.width, pb.height) or nil

    state.caps_cache = {
        os = (love.system and love.system.getOS and love.system.getOS()) or "Unknown",
        api = api or "Unknown",
        version = version or "Unknown",
        vendor = vendor or "Unknown",
        device = device or "Unknown",
        glsl3 = supported.glsl3 == true,
        pixelshaderhighp = supported.pixelshaderhighp == true,
        instancing = supported.instancing == true,
        rgba16f = rgba16f == true,
        param_format = param_format,
        param_size = param_size,
    }
    state.caps_cache_time = now
    return state.caps_cache
end

local function get_config_value(cfg)
    if cfg.key == "G.USE_BATCHED_RENDERER" then
        return G.USE_BATCHED_RENDERER
    elseif cfg.key == "G.USE_STRONTIUM_RENDERER" then
        return G.USE_STRONTIUM_RENDERER
    elseif cfg.key == "G.STRONTIUM_UBERSHADER" then
        return G.STRONTIUM_UBERSHADER ~= false
    elseif cfg.key == "G.STRONTIUM_INSTANCING" then
        return G.STRONTIUM_INSTANCING == true
    elseif cfg.key == "G.STRONTIUM_PROFILING" then
        local profiler = require('strontium.profiler')
        return profiler.is_enabled()
    elseif cfg.key == "G.STRONTIUM_ORDER_MAP" then
        return G.STRONTIUM_ORDER_MAP ~= false
    elseif cfg.key == "G.STRONTIUM_SORT_X" then
        return G.STRONTIUM_SORT_X ~= false
    elseif cfg.key == "G.STRONTIUM_CULL_COVERED" then
        return G.STRONTIUM_CULL_COVERED ~= false
    elseif cfg.key == "G.STRONTIUM_CULL_FACE" then
        return G.STRONTIUM_CULL_FACE == true
    elseif cfg.key == "G.STRONTIUM_DEBUG_OCCLUSION" then
        return G.STRONTIUM_DEBUG_OCCLUSION
    end
    return false
end

local function toggle_config(cfg)
    if cfg.key == "G.USE_BATCHED_RENDERER" then
        G.USE_BATCHED_RENDERER = not G.USE_BATCHED_RENDERER
        if G.USE_BATCHED_RENDERER then
            G.USE_STRONTIUM_RENDERER = false
        end
    elseif cfg.key == "G.USE_STRONTIUM_RENDERER" then
        G.USE_STRONTIUM_RENDERER = not G.USE_STRONTIUM_RENDERER
        if G.USE_STRONTIUM_RENDERER then
            G.USE_BATCHED_RENDERER = false
        end
    elseif cfg.key == "G.STRONTIUM_UBERSHADER" then
        G.STRONTIUM_UBERSHADER = not (G.STRONTIUM_UBERSHADER ~= false)
        local br = G.STRONTIUM_RENDERER
        if br then
            if br.invalidate_all_ubershaders then
                br:invalidate_all_ubershaders()
            end
            if br.invalidate_all_instanced_shaders then
                br:invalidate_all_instanced_shaders()
            end
        end
    elseif cfg.key == "G.STRONTIUM_INSTANCING" then
        G.STRONTIUM_INSTANCING = not (G.STRONTIUM_INSTANCING == true)
        local br = G.STRONTIUM_RENDERER
        if br then
            if br.invalidate_all_instanced_shaders then
                br:invalidate_all_instanced_shaders()
            end
            if br.invalidate_all_ubershaders then
                br:invalidate_all_ubershaders()
            end
            if br.layer_sorted_dirty and br.registry and br.registry.layer_order then
                for i = 1, #br.registry.layer_order do
                    br.layer_sorted_dirty[br.registry.layer_order[i]] = true
                end
            end
            if br.layer_uber_enabled and br.registry and br.registry.layer_order then
                for i = 1, #br.registry.layer_order do
                    br.layer_uber_enabled[br.registry.layer_order[i]] = nil
                end
            end
        end
    elseif cfg.key == "G.STRONTIUM_PROFILING" then
        local profiler = require('strontium.profiler')
        profiler.set_enabled(not profiler.is_enabled())
    elseif cfg.key == "G.STRONTIUM_ORDER_MAP" then
        G.STRONTIUM_ORDER_MAP = not (G.STRONTIUM_ORDER_MAP ~= false)
    elseif cfg.key == "G.STRONTIUM_SORT_X" then
        G.STRONTIUM_SORT_X = not (G.STRONTIUM_SORT_X ~= false)
    elseif cfg.key == "G.STRONTIUM_CULL_COVERED" then
        G.STRONTIUM_CULL_COVERED = not (G.STRONTIUM_CULL_COVERED ~= false)
    elseif cfg.key == "G.STRONTIUM_CULL_FACE" then
        G.STRONTIUM_CULL_FACE = not (G.STRONTIUM_CULL_FACE == true)
    elseif cfg.key == "G.STRONTIUM_DEBUG_OCCLUSION" then
        G.STRONTIUM_DEBUG_OCCLUSION = not G.STRONTIUM_DEBUG_OCCLUSION
    end
end

local function current_renderer_label()
    if G.USE_STRONTIUM_RENDERER then
        return "Strontium"
    elseif G.USE_BATCHED_RENDERER then
        return "Batched"
    end
    return "Vanilla"
end

local function draw_toggle(x, y, w, h, value, hovered)
    components.draw_toggle(x, y, w, h, value, hovered, CONTROL_COLORS)
end

local function draw_button(x, y, w, h, label, hovered)
    components.draw_button(x, y, w, h, label, hovered, CONTROL_COLORS)
end

local function panel_is_visible(target)
    if not target then return false end
    if type(target.is_visible) == "function" then
        return target.is_visible()
    end
    if target.panel and type(target.panel.is_visible) == "function" then
        return target.panel.is_visible()
    end
    local panel_ref = target.panel or target
    if panel_ref and panel_ref.visible ~= nil then
        return panel_ref.visible
    end
    return false
end

local function panel_toggle(target)
    if not target then return end
    if type(target.toggle) == "function" then
        target.toggle()
        return
    end
    if target.panel and type(target.panel.toggle) == "function" then
        target.panel.toggle()
        return
    end
    if type(target.show) == "function" and type(target.hide) == "function" then
        if target.is_visible and target.is_visible() then
            target.hide()
        else
            target.show()
        end
        return
    end
    if target.panel and type(target.panel.show) == "function" and type(target.panel.hide) == "function" then
        if target.panel.is_visible and target.panel.is_visible() then
            target.panel.hide()
        else
            target.panel.show()
        end
        return
    end
    local panel_ref = target.panel or target
    if panel_ref and panel_ref.visible ~= nil then
        panel_ref.visible = not panel_ref.visible
    end
end

local function draw_content(self, x, y, w, h)
    local mx, my = love.mouse.getPosition()
    local line_h = panel.DEFAULTS.line_height
    local base_y = y - (self.scroll_offset or 0) * line_h
    local cur_y = base_y
    local toggle_w = 40
    local toggle_h = 18

    state.hover_button = nil

    local function advance_lines(lines)
        cur_y = cur_y + line_h * (lines or 1)
    end

    local function advance_px(px)
        cur_y = cur_y + px
    end

    local function draw_section(title)
        love.graphics.setColor(COLORS.section_title)
        love.graphics.print(title, x, cur_y)
        advance_lines(1.2)
    end

    local function draw_stat(label, value, color)
        love.graphics.setColor(COLORS.stat_label)
        love.graphics.print(label, x, cur_y)
        love.graphics.setColor(color or COLORS.stat_value)
        love.graphics.print(value, x + 160, cur_y)
        advance_lines(1)
    end

    local function draw_config_toggle(id)
        local idx = CONFIG_INDEX[id]
        local cfg = idx and CONFIGS[idx] or nil
        if not cfg then return end

        local toggle_x = x + w - toggle_w - 10
        local toggle_y = cur_y + 1
        local value = get_config_value(cfg)
        local is_hovered = panel.point_in_rect(mx, my, toggle_x, toggle_y, toggle_w, toggle_h)

        if is_hovered then
            state.hover_button = { type = "config", index = idx }
        end

        love.graphics.setColor(COLORS.stat_label)
        love.graphics.print(cfg.label, x, cur_y)
        draw_toggle(toggle_x, toggle_y, toggle_w, toggle_h, value, is_hovered)
        advance_lines(1.1)
    end

    local function draw_stepper(step_id, label, value, step, min_val, max_val, fmt)
        local btn_w = 22
        local btn_h = 18
        local plus_x = x + w - btn_w - 6
        local minus_x = plus_x - btn_w - 6
        local btn_y = cur_y + 1

        local minus_hover = panel.point_in_rect(mx, my, minus_x, btn_y, btn_w, btn_h)
        local plus_hover = panel.point_in_rect(mx, my, plus_x, btn_y, btn_w, btn_h)

        if minus_hover then state.hover_button = { type = step_id, delta = -step, min = min_val, max = max_val } end
        if plus_hover then state.hover_button = { type = step_id, delta = step, min = min_val, max = max_val } end

        love.graphics.setColor(COLORS.stat_label)
        love.graphics.print(label, x, cur_y)

        components.draw_button(minus_x, btn_y, btn_w, btn_h, "-", minus_hover, CONTROL_COLORS)
        components.draw_button(plus_x, btn_y, btn_w, btn_h, "+", plus_hover, CONTROL_COLORS)

        love.graphics.setColor(COLORS.stat_value)
        love.graphics.print(string.format(fmt, value), minus_x - 68, cur_y)

        advance_lines(1.1)
    end

    draw_section("Quick Stats")

    local fps = love.timer.getFPS()
    local br = G.STRONTIUM_RENDERER
    local fps_color = fps >= 55 and COLORS.stat_good or (fps >= 30 and COLORS.stat_warning or COLORS.stat_bad)
    draw_stat("FPS", string.format("%d", fps), fps_color)
    draw_stat("Frame", string.format("%.1fms", 1000 / math.max(1, fps)))
    local bound_label, bound_color = get_bound_label(
        (G.USE_STRONTIUM_RENDERER and br and br.stats and br.stats.draw_ms) or nil,
        fps > 0 and (1000 / fps) or nil
    )
    draw_stat("Bound", bound_label, bound_color)

    local gfx_stats = love.graphics.getStats()
    draw_stat("Draw calls", string.format("%d", gfx_stats.drawcalls))
    draw_stat("Shaders", string.format("%d", gfx_stats.shaderswitches))

    draw_stat("Renderer", current_renderer_label())
    local param_rows = br and br.stats and br.stats.param_rows or 0
    local param_intents = br and br.stats and br.stats.param_intents or 0
    draw_stat("Params", string.format("%d/%d", param_rows, param_intents))

    local card_count = count_cards()
    local total = G.MOVEABLES and #G.MOVEABLES or 0
    draw_stat("Cards", string.format("%d", card_count))
    draw_stat("Objects", string.format("%d", total))

    advance_lines(0.6)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Renderer")
    draw_config_toggle("strontium")
    draw_config_toggle("batched")

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Renderer Backends")
    draw_config_toggle("instancing")

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Effects")
    draw_config_toggle("ubershader")
    draw_config_toggle("order_map")

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Ordering")
    draw_config_toggle("sort_x")
    draw_stepper("order_map_scale", "Resolution Scale", G.STRONTIUM_ORDER_MAP_SCALE or 1, 0.25, 0.25, 2.0, "x%.2f")

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Culling")
    draw_config_toggle("cull_covered")
    draw_config_toggle("cull_faces")
    draw_stepper("min_visible_ratio", "Min Visible Ratio", G.STRONTIUM_MIN_VISIBLE_RATIO or 0, 0.05, 0.0, 1.0, "%.2f")

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Panels")
    for i, btn in ipairs(BUTTONS) do
        local toggle_x = x + w - toggle_w - 10
        local toggle_y = cur_y + 1
        local target_panel = panels[btn.target]
        local is_open = panel_is_visible(target_panel)
        local is_hovered = panel.point_in_rect(mx, my, toggle_x, toggle_y, toggle_w, toggle_h)

        if is_hovered then
            state.hover_button = { type = "panel", index = i }
        end

        love.graphics.setColor(COLORS.stat_label)
        love.graphics.print(btn.label, x, cur_y)
        draw_toggle(toggle_x, toggle_y, toggle_w, toggle_h, is_open, is_hovered)
        advance_lines(1.1)
    end

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Debug")
    draw_config_toggle("occlusion")
    draw_config_toggle("profiling")

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Device Info")
    local caps = get_caps_snapshot()
    draw_stat("OS", caps.os)
    draw_stat("API", caps.api)
    draw_stat("GL", caps.version)
    draw_stat("Vendor", caps.vendor)
    draw_stat("Device", caps.device)
    draw_stat("GLSL3", yesno(caps.glsl3))
    draw_stat("Frag Highp", yesno(caps.pixelshaderhighp))
    draw_stat("Instancing", yesno(caps.instancing))
    draw_stat("RGBA16F", yesno(caps.rgba16f))
    if caps.param_size then
        draw_stat("Params Tex", string.format("%s %s", caps.param_format, caps.param_size))
    else
        draw_stat("Params Tex", caps.param_format)
    end

    advance_lines(0.4)
    love.graphics.setColor(COLORS.divider)
    love.graphics.line(x, cur_y, x + w - 10, cur_y)
    advance_lines(0.8)

    draw_section("Test Actions")
    local btn_h = 26
    local btn_w = (w - 10) / 2
    local clear_hovered = panel.point_in_rect(mx, my, x, cur_y, btn_w, btn_h)
    if clear_hovered then
        state.hover_button = { type = "action", action = "clear_jokers" }
    end
    draw_button(x, cur_y, btn_w, btn_h, "Clear Jokers", clear_hovered)

    local add_x = x + btn_w + 10
    local add_hovered = panel.point_in_rect(mx, my, add_x, cur_y, btn_w, btn_h)
    if add_hovered then
        state.hover_button = { type = "action", action = "add_jokers" }
    end
    draw_button(add_x, cur_y, btn_w, btn_h, "+50 Jokers", add_hovered)
    advance_px(btn_h + 8)

    local reload_w = w - 10
    local reload_hovered = panel.point_in_rect(mx, my, x, cur_y, reload_w, btn_h)
    if reload_hovered then
        state.hover_button = { type = "action", action = "reload_ubershader" }
    end
    draw_button(x, cur_y, reload_w, btn_h, "Reload Ubershader (F6)", reload_hovered)
    advance_px(btn_h + 8)

    love.graphics.setColor(panel.COLORS.hint)
    love.graphics.print("Scroll to see more - ` toggles panel", x, cur_y)
    advance_lines(1)

    self:update_scroll(math.ceil((cur_y - base_y) / line_h))
    love.graphics.setColor(1, 1, 1, 1)
end

-- Trash
local function handle_click(self, x, y, button)
    if not state.hover_button then return false end
    
    local hb = state.hover_button
    
    if hb.type == "config" then
        local cfg = CONFIGS[hb.index]
        if cfg then
            toggle_config(cfg)
            return true
        end
    elseif hb.type == "panel" then
        local btn = BUTTONS[hb.index]
        if btn and panels[btn.target] then
            panel_toggle(panels[btn.target])
            -- Sync global flags
            if btn.target == "perf_graph" then
                G.PERF_GRAPH = panel_is_visible(panels[btn.target])
            elseif btn.target == "inspector" then
                G.CARD_INSPECTOR = panel_is_visible(panels[btn.target])
            end
            return true
        end
    elseif hb.type == "order_map_scale" then
        local delta = hb.delta or 0
        local scale = (G.STRONTIUM_ORDER_MAP_SCALE or 1) + delta
        scale = math.max(0.25, math.min(scale, 2.0))
        G.STRONTIUM_ORDER_MAP_SCALE = scale
        if G.STRONTIUM_RENDERER and G.STRONTIUM_RENDERER.order_map then
            G.STRONTIUM_RENDERER.order_map.scale = scale
        end
        return true
    elseif hb.type == "min_visible_ratio" then
        local delta = hb.delta or 0
        local ratio = (G.STRONTIUM_MIN_VISIBLE_RATIO or 0) + delta
        ratio = math.max(0.0, math.min(ratio, 1.0))
        G.STRONTIUM_MIN_VISIBLE_RATIO = ratio
        return true
    elseif hb.type == "action" then
        if hb.action == "clear_jokers" then
            if G.jokers and G.jokers.cards then
                for i = #G.jokers.cards, 1, -1 do
                    local card = G.jokers.cards[i]
                    if card then card:remove() end
                end
            end
            return true
        elseif hb.action == "reload_ubershader" then
            local br = G.STRONTIUM_RENDERER
            if br then
                if br.invalidate_all_ubershaders then
                    br:invalidate_all_ubershaders()
                elseif br.invalidate_ubershader and br.registry and br.registry.layer_order then
                    for i = 1, #br.registry.layer_order do
                        br:invalidate_ubershader(br.registry.layer_order[i])
                    end
                end
            end
            return true
        elseif hb.action == "add_jokers" then
            if G.jokers then
                local joker_keys = {
                    'j_joker', 'j_greedy_joker', 'j_lusty_joker', 'j_wrathful_joker', 'j_gluttenous_joker',
                    'j_jolly', 'j_zany', 'j_mad', 'j_crazy', 'j_droll'
                }
                for i = 1, 50 do
                    local joker_key = joker_keys[(i % #joker_keys) + 1]
                    local _area = G.jokers
                    local _T = _area.T
                    local card = Card(_T.x, _T.y, G.CARD_W, G.CARD_H, G.P_CARDS.empty, G.P_CENTERS[joker_key])
                    
                    local m = i % 3
                    if m == 1 then
                        card:set_edition({foil = true}, true, true)
                    elseif m == 2 then
                        card:set_edition({holo = true}, true, true)
                    else
                        card:set_edition({polychrome = true}, true, true)
                    end
                    
                    card:add_to_deck()
                    _area:emplace(card)
                end
            end
            return true
        end
    end
    
    return false
end

function strontium_panel.init()
    state.panel = panel.new({
        id = "strontium",
        title = "◈ Strontium",
        x = 10,
        y = 10,
        width = 380,
        height = 520,
        closable = true,
        minimizable = true,
        draggable = true,
        scrollable = true,
        visible = true,
        on_draw_content = draw_content,
        on_click = handle_click,
        on_close = function()
            G.STRONTIUM_OPEN = false
        end,
    })
    
    return state.panel
end

function strontium_panel.set_panels(p)
    panels = p
end

function strontium_panel.get_panel()
    return state.panel
end

function strontium_panel.show()
    if state.panel then
        panel_manager.position_panel(state.panel)
        state.panel.visible = true
        G.STRONTIUM_OPEN = true
    end
end

function strontium_panel.hide()
    if state.panel then
        state.panel.visible = false
        G.STRONTIUM_OPEN = false
    end
end

function strontium_panel.toggle()
    if state.panel then
        if not state.panel.visible then
            panel_manager.position_panel(state.panel)
        end
        state.panel.visible = not state.panel.visible
        G.STRONTIUM_OPEN = state.panel.visible
    end
end

function strontium_panel.is_visible()
    return state.panel and state.panel.visible
end

function strontium_panel.update(dt)
    if state.panel then
        state.panel:update(dt)
    end
end

function strontium_panel.draw()
    if state.panel and state.panel.visible then
        state.panel:draw()
    end
end

return strontium_panel
