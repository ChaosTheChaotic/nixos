-- Effect Editor - Browse and live-edit registered effect modules.

local panel = require('strontium.ui.panel')
local panel_manager = require('strontium.ui.panel_manager')
local components = require('strontium.ui.components')

local effect_lab = {}

local PHASES = { "color", "overlay", "post" }
local CONTROL_COLORS = {
    button_bg = {0.2, 0.35, 0.5, 0.9},
    button_bg_hover = {0.3, 0.5, 0.7, 1.0},
    button_text = {0.9, 0.95, 1.0, 1.0},
    toggle_on = {0.3, 0.8, 0.4, 1.0},
    toggle_off = {0.4, 0.4, 0.45, 0.8},
    toggle_bg = {0.15, 0.15, 0.2, 0.9},
    toggle_border = {0.3, 0.4, 0.5, 0.8},
}

local state = {
    panel = nil,
    effects = {},
    selected_key = nil,
    list_scroll = 0,
    list_hover = nil,
    list_count = 0,
    refresh_timer = 0,
    refresh_interval = 0.5,
    edit = nil,
    editor = {
        lines = { "" },
        caret_line = 1,
        caret_col = 1,
        scroll = 0,
        hscroll = 0,
        active = false,
        font = nil,
    },
    -- Local repeat for editor navigation
    -- I hate this.
    key_repeat = {
        delay = 0.35,
        interval = 0.05,
        timers = {},
        keys = { "left", "right", "up", "down", "backspace", "delete" },
    },
}

local function get_renderer()
    return (G and G.STRONTIUM_RENDERER) or nil
end

local function copy_list(src)
    if type(src) ~= "table" then return nil end
    local out = {}
    for i = 1, #src do
        out[i] = src[i]
    end
    return out
end

local function copy_table(src)
    if type(src) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(src) do
        out[k] = v
    end
    return out
end

local function clone_effect(mod)
    if type(mod) ~= "table" then return nil end
    local def = {}
    for k, v in pairs(mod) do
        def[k] = v
    end
    if mod.params_layout then def.params_layout = copy_list(mod.params_layout) end
    if mod.params_defaults then def.params_defaults = copy_list(mod.params_defaults) end
    if type(mod.layers) == "table" then def.layers = copy_list(mod.layers) end
    if mod.flags then def.flags = copy_table(mod.flags) end
    return def
end

local function split_lines(text)
    local lines = {}
    text = text or ""
    if text == "" then
        lines[1] = ""
        return lines
    end
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function editor_text()
    return table.concat(state.editor.lines, "\n")
end

local function editor_set_text(text)
    state.editor.lines = split_lines(text)
    state.editor.caret_line = 1
    state.editor.caret_col = 1
    state.editor.scroll = 0
    state.editor.hscroll = 0
end

local function editor_line_length(line_idx)
    local line = state.editor.lines[line_idx] or ""
    return #line
end

local function editor_set_caret(line, col)
    line = math.max(1, math.min(line, #state.editor.lines))
    local max_col = editor_line_length(line) + 1
    col = math.max(1, math.min(col, max_col))
    state.editor.caret_line = line
    state.editor.caret_col = col
end

local function editor_insert_text(text)
    local line = state.editor.lines[state.editor.caret_line] or ""
    local col = state.editor.caret_col
    local before = line:sub(1, col - 1)
    local after = line:sub(col)

    if text:find("\n") then
        local parts = split_lines(text)
        state.editor.lines[state.editor.caret_line] = before .. parts[1]
        local insert_idx = state.editor.caret_line + 1
        for i = 2, #parts do
            table.insert(state.editor.lines, insert_idx, parts[i])
            insert_idx = insert_idx + 1
        end
        state.editor.lines[insert_idx - 1] = state.editor.lines[insert_idx - 1] .. after
        editor_set_caret(insert_idx - 1, #parts[#parts] + 1)
        return
    end

    state.editor.lines[state.editor.caret_line] = before .. text .. after
    editor_set_caret(state.editor.caret_line, col + #text)
end

local function editor_backspace()
    local line_idx = state.editor.caret_line
    local col = state.editor.caret_col
    if col > 1 then
        local line = state.editor.lines[line_idx]
        state.editor.lines[line_idx] = line:sub(1, col - 2) .. line:sub(col)
        editor_set_caret(line_idx, col - 1)
        return
    end
    if line_idx <= 1 then return end
    local prev = state.editor.lines[line_idx - 1]
    local line = state.editor.lines[line_idx]
    local new_col = #prev + 1
    state.editor.lines[line_idx - 1] = prev .. line
    table.remove(state.editor.lines, line_idx)
    editor_set_caret(line_idx - 1, new_col)
end

local function editor_delete()
    local line_idx = state.editor.caret_line
    local col = state.editor.caret_col
    local line = state.editor.lines[line_idx] or ""
    if col <= #line then
        state.editor.lines[line_idx] = line:sub(1, col - 1) .. line:sub(col + 1)
        return
    end
    if line_idx >= #state.editor.lines then return end
    local next_line = state.editor.lines[line_idx + 1]
    state.editor.lines[line_idx] = line .. next_line
    table.remove(state.editor.lines, line_idx + 1)
end

local function editor_newline()
    local line_idx = state.editor.caret_line
    local col = state.editor.caret_col
    local line = state.editor.lines[line_idx] or ""
    local before = line:sub(1, col - 1)
    local after = line:sub(col)
    state.editor.lines[line_idx] = before
    table.insert(state.editor.lines, line_idx + 1, after)
    editor_set_caret(line_idx + 1, 1)
end

local function editor_move(dx, dy)
    local line = state.editor.caret_line + dy
    line = math.max(1, math.min(line, #state.editor.lines))
    local col = state.editor.caret_col
    if dy ~= 0 then
        col = math.min(col, editor_line_length(line) + 1)
    else
        col = col + dx
    end
    editor_set_caret(line, col)
end

local function editor_tab()
    editor_insert_text("    ")
end

local function editor_ensure_visible(visible_lines, visible_width, line_number_w, font)
    local line = state.editor.caret_line
    local top = state.editor.scroll + 1
    local bottom = state.editor.scroll + visible_lines
    if line < top then
        state.editor.scroll = line - 1
    elseif line > bottom then
        state.editor.scroll = line - visible_lines
    end
    if state.editor.scroll < 0 then state.editor.scroll = 0 end

    if visible_width and font then
        local text = state.editor.lines[state.editor.caret_line] or ""
        local prefix = text:sub(1, state.editor.caret_col - 1)
        local caret_x = font:getWidth(prefix)
        local left = state.editor.hscroll or 0
        local right = left + visible_width
        local pad = 12
        if caret_x < left + pad then
            state.editor.hscroll = math.max(0, caret_x - pad)
        elseif caret_x > right - pad then
            state.editor.hscroll = math.max(0, caret_x - (visible_width - pad))
        end
    end
end

local function editor_snapshot()
    return {
        line = state.editor.caret_line,
        col = state.editor.caret_col,
        scroll = state.editor.scroll,
        hscroll = state.editor.hscroll,
        active = state.editor.active,
    }
end

local function editor_restore(snapshot)
    if not snapshot then return end
    local max_scroll = math.max(0, #state.editor.lines - 1)
    state.editor.scroll = math.max(0, math.min(snapshot.scroll or 0, max_scroll))
    state.editor.hscroll = math.max(0, snapshot.hscroll or 0)
    editor_set_caret(snapshot.line or 1, snapshot.col or 1)
    if snapshot.active ~= nil then
        state.editor.active = snapshot.active
    end
end

local function editor_find_column(line, target_x, font)
    local text = state.editor.lines[line] or ""
    local col = 1
    local acc = 0
    for i = 1, #text do
        local w = font:getWidth(text:sub(i, i))
        if acc + w * 0.5 >= target_x then
            col = i
            return col
        end
        acc = acc + w
        col = i + 1
    end
    return col
end

local function editor_click(local_x, local_y, line_height, visible_lines, line_number_w, font)
    local line_idx = math.floor(local_y / line_height) + 1
    line_idx = math.max(1, math.min(line_idx, visible_lines))
    line_idx = line_idx + state.editor.scroll
    line_idx = math.max(1, math.min(line_idx, #state.editor.lines))
    local col_x = math.max(0, local_x - line_number_w) + (state.editor.hscroll or 0)
    local col = editor_find_column(line_idx, col_x, font)
    editor_set_caret(line_idx, col)
end

local function apply_editor_key(key, allow_escape)
    if key == "lctrl" or key == "rctrl" then
        return false
    end
    if key == "escape" then
        if allow_escape then
            state.editor.active = false
            return true
        end
        return false
    elseif key == "backspace" then
        editor_backspace()
        return true
    elseif key == "delete" then
        editor_delete()
        return true
    elseif key == "return" or key == "kpenter" then
        editor_newline()
        return true
    elseif key == "tab" then
        editor_tab()
        return true
    elseif key == "left" then
        editor_move(-1, 0)
        return true
    elseif key == "right" then
        editor_move(1, 0)
        return true
    elseif key == "up" then
        editor_move(0, -1)
        return true
    elseif key == "down" then
        editor_move(0, 1)
        return true
    elseif key == "home" then
        editor_set_caret(state.editor.caret_line, 1)
        return true
    elseif key == "end" then
        editor_set_caret(state.editor.caret_line, editor_line_length(state.editor.caret_line) + 1)
        return true
    end

    return false
end

local function update_key_repeat(dt)
    if not state.editor.active then
        if state.key_repeat and state.key_repeat.timers then
            state.key_repeat.timers = {}
        end
        return
    end
    local key_repeat = state.key_repeat
    if not key_repeat or not key_repeat.keys then return end

    for i = 1, #key_repeat.keys do
        local key = key_repeat.keys[i]
        if love.keyboard.isDown(key) then
            local entry = key_repeat.timers[key]
            if not entry then
                key_repeat.timers[key] = { time = 0, fired = false }
            else
                entry.time = entry.time + dt
                local threshold = entry.fired and key_repeat.interval or key_repeat.delay
                while entry.time >= threshold do
                    apply_editor_key(key, false)
                    entry.time = entry.time - threshold
                    entry.fired = true
                    threshold = key_repeat.interval
                end
            end
        else
            key_repeat.timers[key] = nil
        end
    end
end

local function refresh_effect_list(force)
    local br = get_renderer()
    local modules = br and br.registry and br.registry.modules or nil
    if not modules then
        state.effects = {}
        state.list_count = 0
        state.selected_key = nil
        state.edit = nil
        return
    end
    local count = 0
    for _ in pairs(modules) do count = count + 1 end
    if not force and state.list_count == count then
        return
    end
    local keys = {}
    for key in pairs(modules) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    state.effects = keys
    state.list_count = count
    if state.selected_key and modules[state.selected_key] then
        return
    end
    if #keys > 0 then
        state.selected_key = keys[1]
    else
        state.selected_key = nil
    end
end

local function select_effect(key)
    local br = get_renderer()
    local modules = br and br.registry and br.registry.modules or nil
    local mod = modules and modules[key] or nil
    if not mod then
        state.edit = nil
        return
    end

    local def = clone_effect(mod)
    local params = def.params_layout or def.params or {}
    local defaults = copy_list(def.params_defaults) or {}
    for i = #defaults + 1, #params do
        defaults[i] = 0
    end

    state.edit = {
        base = def,
        key = key,
        phase = def.phase or "color",
        priority = def.priority or 0,
        batch_safe = not (def.flags and def.flags.batch_safe == false),
        params = params,
        defaults = defaults,
    }

    local body = def.glsl_body or def.glsl or ""
    editor_set_text(body)
end

local function apply_effect_changes()
    local br = get_renderer()
    if not (br and state.edit and state.edit.base) then return end
    local snapshot = editor_snapshot()
    local def = clone_effect(state.edit.base)
    def.key = state.edit.key
    def.phase = state.edit.phase
    def.priority = state.edit.priority
    def.flags = def.flags or {}
    def.flags.batch_safe = state.edit.batch_safe
    def.params_defaults = copy_list(state.edit.defaults)
    def.glsl_body = editor_text()
    def.glsl = nil

    br:register_effect(def)
    if br.invalidate_all_ubershaders then
        br:invalidate_all_ubershaders()
    elseif br.invalidate_ubershader and br.registry and br.registry.layer_order then
        for i = 1, #br.registry.layer_order do
            br:invalidate_ubershader(br.registry.layer_order[i])
        end
    end
    select_effect(state.edit.key)
    editor_restore(snapshot)
end

local function reset_effect_changes()
    if not state.edit or not state.edit.key then return end
    select_effect(state.edit.key)
end

local function draw_toggle(x, y, w, h, value, hovered)
    components.draw_toggle(x, y, w, h, value, hovered, CONTROL_COLORS)
end

local function draw_button(x, y, w, h, label, hovered)
    components.draw_button(x, y, w, h, label, hovered, CONTROL_COLORS)
end

local function draw_stepper(x, y, w, h, value, hovered_minus, hovered_plus)
    components.draw_stepper(x, y, w, h, value, hovered_minus, hovered_plus, CONTROL_COLORS, "%.2f")
end

local function draw_content(self, x, y, w, h)
    local d = panel.DEFAULTS
    local mx, my = love.mouse.getPosition()
    local line_h = d.line_height

    refresh_effect_list(false)
    if state.selected_key and (not state.edit or state.edit.key ~= state.selected_key) then
        select_effect(state.selected_key)
    end

    local list_w = 220
    local list_x = x
    local list_y = y
    local list_h = h
    local detail_x = x + list_w + 10
    local detail_w = w - list_w - 10

    love.graphics.setColor(0.08, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", list_x, list_y, list_w, list_h, 4, 4)
    love.graphics.setColor(0.3, 0.4, 0.5, 0.8)
    love.graphics.rectangle("line", list_x, list_y, list_w, list_h, 4, 4)

    local list_visible = math.max(1, math.floor(list_h / line_h))
    local max_list_scroll = math.max(0, #state.effects - list_visible)
    if state.list_scroll > max_list_scroll then
        state.list_scroll = max_list_scroll
    end

    state.list_hover = nil
    for i = 1, list_visible do
        local idx = i + state.list_scroll
        local key = state.effects[idx]
        if not key then goto continue end

        local ly = list_y + (i - 1) * line_h
        local hovered = panel.point_in_rect(mx, my, list_x, ly, list_w, line_h)
        if hovered then
            state.list_hover = key
            love.graphics.setColor(0.2, 0.3, 0.45, 0.6)
            love.graphics.rectangle("fill", list_x, ly, list_w, line_h)
        elseif key == state.selected_key then
            love.graphics.setColor(0.25, 0.35, 0.5, 0.6)
            love.graphics.rectangle("fill", list_x, ly, list_w, line_h)
        end
        love.graphics.setColor(panel.COLORS.key)
        love.graphics.print(key, list_x + 6, ly)
        ::continue::
    end

    if not state.edit then
        love.graphics.setColor(panel.COLORS.hint)
        love.graphics.print("No renderer or effects found.", detail_x, list_y)
        return
    end

    local row_y = list_y
    love.graphics.setColor(panel.COLORS.section)
    love.graphics.print("Effect", detail_x, row_y)
    row_y = row_y + line_h

    love.graphics.setColor(panel.COLORS.text)
    love.graphics.print(state.edit.key, detail_x, row_y)
    row_y = row_y + line_h * 1.2

    love.graphics.setColor(panel.COLORS.text_dim)
    love.graphics.print("Phase", detail_x, row_y)
    local phase_btn_w = 90
    local phase_btn_h = 18
    local phase_x = detail_x + 80
    local phase_hover = panel.point_in_rect(mx, my, phase_x, row_y, phase_btn_w, phase_btn_h)
    draw_button(phase_x, row_y, phase_btn_w, phase_btn_h, state.edit.phase, phase_hover)
    row_y = row_y + line_h

    love.graphics.setColor(panel.COLORS.text_dim)
    love.graphics.print("Priority", detail_x, row_y)
    local pr_x = detail_x + 80
    local pr_w = 120
    local pr_h = 18
    local pr_minus = panel.point_in_rect(mx, my, pr_x, row_y, pr_h, pr_h)
    local pr_plus = panel.point_in_rect(mx, my, pr_x + pr_w - pr_h, row_y, pr_h, pr_h)
    draw_stepper(pr_x, row_y, pr_w, pr_h, state.edit.priority, pr_minus, pr_plus)
    row_y = row_y + line_h

    love.graphics.setColor(panel.COLORS.text_dim)
    love.graphics.print("Batch Safe", detail_x, row_y)
    local toggle_w = 40
    local toggle_h = 16
    local toggle_x = detail_x + 80
    local toggle_hover = panel.point_in_rect(mx, my, toggle_x, row_y, toggle_w, toggle_h)
    draw_toggle(toggle_x, row_y, toggle_w, toggle_h, state.edit.batch_safe)
    row_y = row_y + line_h * 1.2

    local params = state.edit.params or {}
    if #params > 0 then
        love.graphics.setColor(panel.COLORS.text_dim)
        love.graphics.print("Params", detail_x, row_y)
        row_y = row_y + line_h
        for i = 1, #params do
            local label = tostring(params[i])
            love.graphics.setColor(panel.COLORS.key)
            love.graphics.print(label, detail_x + 8, row_y)
            local val_x = detail_x + 120
            local val_w = 120
            local val_h = 18
            local minus = panel.point_in_rect(mx, my, val_x, row_y, val_h, val_h)
            local plus = panel.point_in_rect(mx, my, val_x + val_w - val_h, row_y, val_h, val_h)
            draw_stepper(val_x, row_y, val_w, val_h, state.edit.defaults[i] or 0, minus, plus)
            row_y = row_y + line_h
        end
        row_y = row_y + line_h * 0.3
    end

    local btn_w = 90
    local btn_h = 22
    local apply_x = detail_x
    local reset_x = detail_x + btn_w + 8
    local apply_hover = panel.point_in_rect(mx, my, apply_x, row_y, btn_w, btn_h)
    local reset_hover = panel.point_in_rect(mx, my, reset_x, row_y, btn_w, btn_h)
    draw_button(apply_x, row_y, btn_w, btn_h, "Apply", apply_hover)
    draw_button(reset_x, row_y, btn_w, btn_h, "Reset", reset_hover)
    row_y = row_y + btn_h + 8

    local code_y = row_y
    local code_h = list_y + list_h - code_y
    local code_x = detail_x
    local code_w = detail_w
    love.graphics.setColor(0.07, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", code_x, code_y, code_w, code_h, 4, 4)
    love.graphics.setColor(0.3, 0.4, 0.5, 0.7)
    love.graphics.rectangle("line", code_x, code_y, code_w, code_h, 4, 4)

    local prev_font = love.graphics.getFont()
    local font = state.editor.font or prev_font
    love.graphics.setFont(font)
    local code_line_h = font:getHeight() + 2
    local visible_lines = math.max(1, math.floor((code_h - 8) / code_line_h))
    local max_line = #state.editor.lines
    local line_number_w = font:getWidth(tostring(max_line)) + 12
    local text_w = math.max(0, code_w - 12 - line_number_w)
    editor_ensure_visible(visible_lines, text_w, line_number_w, font)

    local text_x = code_x + 6 + line_number_w
    local text_y = code_y + 4

    love.graphics.setScissor(code_x, code_y, code_w, code_h)

    for i = 1, visible_lines do
        local line_idx = i + state.editor.scroll
        local line = state.editor.lines[line_idx]
        if not line then goto continue end

        local draw_y = text_y + (i - 1) * code_line_h
        if line_idx == state.editor.caret_line then
            love.graphics.setColor(0.2, 0.25, 0.35, 0.5)
            love.graphics.rectangle("fill", code_x + 4, draw_y, code_w - 8, code_line_h)
        end
        love.graphics.setColor(panel.COLORS.text_dim)
        love.graphics.print(tostring(line_idx), code_x + 6, draw_y)
        love.graphics.setColor(panel.COLORS.text)
        love.graphics.print(line, text_x - (state.editor.hscroll or 0), draw_y)
        ::continue::
    end

    if state.editor.active then
        local caret_line = state.editor.caret_line - state.editor.scroll
        if caret_line >= 1 and caret_line <= visible_lines then
            local line = state.editor.lines[state.editor.caret_line] or ""
            local prefix = line:sub(1, state.editor.caret_col - 1)
            local caret_x = text_x + font:getWidth(prefix) - (state.editor.hscroll or 0)
            local caret_y = text_y + (caret_line - 1) * code_line_h
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.rectangle("fill", caret_x, caret_y + 2, 1, code_line_h - 4)
        end
    end

    love.graphics.setScissor()
    love.graphics.setFont(prev_font)
end

local function handle_click(self, x, y, button)
    if button ~= 1 then return false end

    local d = panel.DEFAULTS
    local cx, cy, cw, ch = self:get_content_rect()
    local line_h = d.line_height
    local list_w = 220
    local list_x = cx
    local list_y = cy
    local list_h = ch
    local detail_x = cx + list_w + 10
    local detail_w = cw - list_w - 10

    if panel.point_in_rect(x, y, list_x, list_y, list_w, list_h) then
        local idx = math.floor((y - list_y) / line_h) + 1 + state.list_scroll
        local key = state.effects[idx]
        if key then
            state.selected_key = key
            select_effect(key)
            return true
        end
    end

    if not state.edit then
        state.editor.active = false
        return false
    end

    local row_y = list_y + line_h * 2.2
    local phase_x = detail_x + 80
    local phase_btn_w = 90
    local phase_btn_h = 18
    if panel.point_in_rect(x, y, phase_x, row_y, phase_btn_w, phase_btn_h) then
        local idx = 1
        for i = 1, #PHASES do
            if PHASES[i] == state.edit.phase then idx = i break end
        end
        idx = (idx % #PHASES) + 1
        state.edit.phase = PHASES[idx]
        return true
    end
    row_y = row_y + line_h

    local pr_x = detail_x + 80
    local pr_w = 120
    local pr_h = 18
    local pr_minus = panel.point_in_rect(x, y, pr_x, row_y, pr_h, pr_h)
    local pr_plus = panel.point_in_rect(x, y, pr_x + pr_w - pr_h, row_y, pr_h, pr_h)
    if pr_minus then
        state.edit.priority = state.edit.priority - 1
        return true
    end
    if pr_plus then
        state.edit.priority = state.edit.priority + 1
        return true
    end
    row_y = row_y + line_h

    local toggle_x = detail_x + 80
    local toggle_w = 40
    local toggle_h = 16
    if panel.point_in_rect(x, y, toggle_x, row_y, toggle_w, toggle_h) then
        state.edit.batch_safe = not state.edit.batch_safe
        return true
    end
    row_y = row_y + line_h * 1.2

    local params = state.edit.params or {}
    if #params > 0 then
        row_y = row_y + line_h
        for i = 1, #params do
            local val_x = detail_x + 120
            local val_w = 120
            local val_h = 18
            local minus = panel.point_in_rect(x, y, val_x, row_y, val_h, val_h)
            local plus = panel.point_in_rect(x, y, val_x + val_w - val_h, row_y, val_h, val_h)
            if minus then
                state.edit.defaults[i] = (state.edit.defaults[i] or 0) - 0.05
                return true
            end
            if plus then
                state.edit.defaults[i] = (state.edit.defaults[i] or 0) + 0.05
                return true
            end
            row_y = row_y + line_h
        end
        row_y = row_y + line_h * 0.3
    end

    local btn_w = 90
    local btn_h = 22
    local apply_x = detail_x
    local reset_x = detail_x + btn_w + 8
    if panel.point_in_rect(x, y, apply_x, row_y, btn_w, btn_h) then
        apply_effect_changes()
        return true
    end
    if panel.point_in_rect(x, y, reset_x, row_y, btn_w, btn_h) then
        reset_effect_changes()
        return true
    end
    row_y = row_y + btn_h + 8

    local code_x = detail_x
    local code_y = row_y
    local code_w = detail_w
    local code_h = list_y + list_h - code_y
    if panel.point_in_rect(x, y, code_x, code_y, code_w, code_h) then
        local font = state.editor.font or love.graphics.getFont()
        local line_h_code = font:getHeight() + 2
        local visible_lines = math.max(1, math.floor((code_h - 8) / line_h_code))
        local max_line = #state.editor.lines
        local line_number_w = font:getWidth(tostring(max_line)) + 12
        editor_click(x - code_x - 6, y - code_y - 4, line_h_code, visible_lines, line_number_w, font)
        state.editor.active = true
        return true
    end

    state.editor.active = false
    return false
end

local function handle_scroll(self, x, y)
    local mx, my = love.mouse.getPosition()
    local cx, cy, cw, ch = self:get_content_rect()
    local list_w = 220
    local list_x = cx
    local list_y = cy
    local list_h = ch
    local detail_x = cx + list_w + 10
    local detail_w = cw - list_w - 10

    if panel.point_in_rect(mx, my, list_x, list_y, list_w, list_h) then
        state.list_scroll = state.list_scroll - y * 2
        local max_scroll = math.max(0, #state.effects - math.floor(list_h / panel.DEFAULTS.line_height))
        if state.list_scroll < 0 then state.list_scroll = 0 end
        if state.list_scroll > max_scroll then state.list_scroll = max_scroll end
        return true
    end

    local row_y = list_y + panel.DEFAULTS.line_height * 2.2
    row_y = row_y + panel.DEFAULTS.line_height
    row_y = row_y + panel.DEFAULTS.line_height
    row_y = row_y + panel.DEFAULTS.line_height * 1.2
    local params = state.edit and state.edit.params or {}
    if #params > 0 then
        row_y = row_y + panel.DEFAULTS.line_height
        row_y = row_y + panel.DEFAULTS.line_height * #params
        row_y = row_y + panel.DEFAULTS.line_height * 0.3
    end
    row_y = row_y + 22 + 8

    local code_x = detail_x
    local code_y = row_y
    local code_w = detail_w
    local code_h = list_y + list_h - code_y
    if panel.point_in_rect(mx, my, code_x, code_y, code_w, code_h) then
        local font = state.editor.font or love.graphics.getFont()
        local line_h = font:getHeight() + 2
        local visible_lines = math.max(1, math.floor((code_h - 8) / line_h))

        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") or x ~= 0 then
            local delta = (x ~= 0) and x or y
            state.editor.hscroll = math.max(0, (state.editor.hscroll or 0) - delta * 20)
            return true
        end

        state.editor.scroll = state.editor.scroll - y * 2
        if state.editor.scroll < 0 then state.editor.scroll = 0 end
        local max_scroll = math.max(0, #state.editor.lines - visible_lines)
        if state.editor.scroll > max_scroll then state.editor.scroll = max_scroll end
        return true
    end

    return false
end

function effect_lab.init()
    state.editor.font = love.graphics.newFont(12)
    state.panel = panel.new({
        id = "effect_lab",
        title = "Effect Editor",
        x = 120,
        y = 120,
        width = 860,
        height = 540,
        closable = true,
        minimizable = true,
        draggable = true,
        scrollable = false,
        visible = false,
        on_draw_content = draw_content,
        on_click = handle_click,
        on_scroll = handle_scroll,
        on_update = effect_lab.update,
    })

    return state.panel
end

function effect_lab.update(_, dt)
    dt = dt or 0
    state.refresh_timer = state.refresh_timer + dt
    if state.refresh_timer >= state.refresh_interval then
        state.refresh_timer = 0
        refresh_effect_list(true)
    end
    update_key_repeat(dt)
end

function effect_lab.is_visible()
    return state.panel and state.panel.visible
end

function effect_lab.is_editing()
    return state.panel and state.panel.visible and state.editor.active
end

function effect_lab.show()
    if state.panel then
        panel_manager.position_panel(state.panel)
        state.panel.visible = true
    end
end

function effect_lab.hide()
    if state.panel then
        state.panel.visible = false
    end
end

function effect_lab.toggle()
    if state.panel then
        if not state.panel.visible then
            panel_manager.position_panel(state.panel)
        end
        state.panel.visible = not state.panel.visible
    end
end

function effect_lab.handle_key(key)
    if not effect_lab.is_visible() then return false end
    if not state.editor.active then return false end
    apply_editor_key(key, true)
    return true
end

function effect_lab.textinput(text)
    if not effect_lab.is_visible() then return false end
    if not state.editor.active then return false end
    if text and text ~= "" then
        editor_insert_text(text)
        return true
    end
    return false
end

return effect_lab
