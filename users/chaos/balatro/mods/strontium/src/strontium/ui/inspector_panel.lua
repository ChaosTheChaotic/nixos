local panel = require('strontium.ui.panel')
local panel_manager = require('strontium.ui.panel_manager')

local inspector_panel = {}

local table_viewer = nil

local CLASS_NAMES = {
    'Card', 'Blind', 'Card_Character', 'Sprite', 'AnimatedSprite',
    'UIBox', 'UIElement', 'CardArea', 'DynaText', 'Particles',
    'Moveable', 'Node', 'Object',
}

local state = {
    panel = nil,
    target = nil,
    frozen_target = nil,
    frozen = false,
    ctrl_held = false,
    copy_flash = 0,
    hover_line = nil,
    inspection_data = nil,
}

local function get_class_name(obj)
    if not obj then return "nil" end
    local mt = getmetatable(obj)
    if not mt then return "table" end
    
    for _, name in ipairs(CLASS_NAMES) do
        if rawget(_G, name) and mt == _G[name] then
            return name
        end
    end
    return "unknown"
end

local function format_value(v, max_len)
    max_len = max_len or 60
    local t = type(v)
    local str, color
    local c = panel.COLORS
    
    if t == "nil" then
        str, color = "nil", c.value_nil
    elseif t == "boolean" then
        str = tostring(v)
        color = v and c.value_bool_true or c.value_bool_false
    elseif t == "number" then
        if v == math.floor(v) then
            str = tostring(v)
        else
            str = string.format("%.4f", v)
        end
        color = c.value_number
    elseif t == "string" then
        str = '"' .. v:sub(1, max_len) .. (v:len() > max_len and '...' or '') .. '"'
        color = c.value_string
    elseif t == "table" then
        local mt = getmetatable(v)
        if mt and mt.__index then
            local class_name = get_class_name(v)
            if class_name ~= "unknown" then
                str = "<" .. class_name .. ">"
            else
                str = "<table:" .. tostring(v):sub(8, 20) .. ">"
            end
        else
            local count = 0
            for _ in pairs(v) do count = count + 1 end
            str = "{" .. count .. " items}"
        end
        color = c.value_table
    elseif t == "function" then
        str = "<function>"
        color = c.value_function
    elseif t == "userdata" then
        str = "<userdata: " .. tostring(v):sub(1, 20) .. ">"
        color = c.value_function
    else
        str = tostring(v):sub(1, max_len)
        color = c.value_nil
    end
    
    return str, color
end

local function find_hovered_object()
    if not G or not G.CONTROLLER then return nil end
    
    if G.CONTROLLER.hovering and G.CONTROLLER.hovering.target then
        return G.CONTROLLER.hovering.target
    end
    
    if G.CONTROLLER.focused and G.CONTROLLER.focused.target then
        return G.CONTROLLER.focused.target
    end
    
    -- Cursor hit test. This sucks but it's UI code so, whatever.
    if G.I and G.I.CARD then
        local cx, cy = G.CURSOR.T.x, G.CURSOR.T.y
        for i = #G.I.CARD, 1, -1 do
            local card = G.I.CARD[i]
            if card and card.VT then
                local vt = card.VT
                if cx >= vt.x and cx <= vt.x + vt.w and
                   cy >= vt.y and cy <= vt.y + vt.h then
                    return card
                end
            end
        end
    end
    
    return nil
end

local function build_inspection_data(obj)
    if not obj then return nil end
    
    local c = panel.COLORS
    local data = {
        class_name = get_class_name(obj),
        object = obj,
        lines = {},
        timestamp = love.timer.getTime(),
    }
    
    local function add_section(title)
        table.insert(data.lines, {section = title})
    end
    
    local function add_line(key, value, color, table_ref)
        table.insert(data.lines, {
            key = key,
            value = value,
            color = color or c.text,
            table_ref = table_ref,
        })
    end
    
    local function add_bool(key, value)
        add_line(key, tostring(value), value and c.value_bool_true or c.value_bool_false)
    end
    
    local function add_number(key, value, fmt)
        fmt = fmt or "%.3f"
        add_line(key, string.format(fmt, value or 0), c.value_number)
    end

    local function add_transform_section(title, prefix, t)
        if not t then return end
        add_section(title)
        add_number(prefix .. ".x", t.x)
        add_number(prefix .. ".y", t.y)
        add_number(prefix .. ".w", t.w)
        add_number(prefix .. ".h", t.h)
        add_number(prefix .. ".r", t.r, "%.4f")
        add_number(prefix .. ".scale", t.scale)
    end
    
    add_section("=== IDENTITY ===")
    add_line("Class", data.class_name, c.header_text)
    add_line("Address", tostring(obj), c.value_function)
    if obj.ID then
        add_line("ID", tostring(obj.ID), c.value_number)
    end
    
    add_transform_section("=== TRANSFORM (T) ===", "T", obj.T)
    add_transform_section("=== VISIBLE TRANSFORM (VT) ===", "VT", obj.VT)
    
    if obj.states then
        add_section("=== STATES ===")
        add_bool("visible", obj.states.visible)
        if obj.states.hover then
            add_bool("hover.is", obj.states.hover.is)
        end
        if obj.states.drag then
            add_bool("drag.is", obj.states.drag.is)
            add_bool("drag.can", obj.states.drag.can)
        end
        if obj.states.focus then
            add_bool("focus.is", obj.states.focus.is)
        end
        if obj.states.collide then
            add_bool("collide.can", obj.states.collide.can)
        end
    end
    
    if data.class_name == "Card" then
        add_section("=== CARD DATA ===")
        
        if obj.base then
            add_line("base.suit", tostring(obj.base.suit or "none"), c.value_string)
            add_line("base.value", tostring(obj.base.value or "none"), c.value_string)
            add_line("base.id", tostring(obj.base.id or "none"), c.value_number)
        end
        
        if obj.ability then
            add_line("ability.name", tostring(obj.ability.name or "none"), c.value_string)
            add_line("ability.effect", tostring(obj.ability.effect or "none"), c.value_string)
            add_line("ability.set", tostring(obj.ability.set or "none"), c.value_string)
        end
        
        if obj.config and obj.config.center then
            add_line("center.key", tostring(obj.config.center.key or "none"), c.value_string)
            add_line("center.set", tostring(obj.config.center.set or "none"), c.value_string)
        end
        
        add_line("sprite_facing", tostring(obj.sprite_facing or "nil"), c.value_string)
        add_line("facing", tostring(obj.facing or "nil"), c.value_string)
        
        if obj.edition then
            local ed_str = ""
            for k, v in pairs(obj.edition) do
                if v then ed_str = ed_str .. k .. " " end
            end
            add_line("edition", ed_str ~= "" and ed_str or "none", c.value_string)
        end
        
        if obj.seal then
            add_line("seal", tostring(obj.seal), c.value_string)
        end
        
        add_bool("debuff", obj.debuff)
        add_line("playing_card", tostring(obj.playing_card or "nil"), c.value_number)
    end
    
    if data.class_name == "Blind" then
        add_section("=== BLIND DATA ===")
        add_line("name", tostring(obj.name or "nil"), c.value_string)
        add_number("chips", obj.chips, "%d")
        add_number("mult", obj.mult, "%.2f")
        add_bool("boss", obj.boss)
        add_bool("disabled", obj.disabled)
    end
    
    if obj.area then
        add_section("=== AREA ===")
        local area = obj.area
        add_line("area", tostring(area), c.value_table, area)
        if area.config then
            add_line("area.config.type", tostring(area.config.type or "nil"), c.value_string)
        end
        if area.cards then
            for i, card in ipairs(area.cards) do
                if card == obj then
                    add_line("index_in_area", tostring(i), c.value_number)
                    break
                end
            end
        end
    end
    
    if obj.parent or obj.container then
        add_section("=== HIERARCHY ===")
        if obj.parent then
            add_line("parent", get_class_name(obj.parent) .. " " .. tostring(obj.parent), c.value_table, obj.parent)
        end
        if obj.container then
            add_line("container", get_class_name(obj.container) .. " " .. tostring(obj.container), c.value_table, obj.container)
        end
    end
    
    if obj.role then
        add_section("=== ROLE ===")
        add_line("role_type", tostring(obj.role.role_type or "nil"), c.value_string)
        if obj.role.major then
            add_line("major", get_class_name(obj.role.major) .. " " .. tostring(obj.role.major), c.value_table, obj.role.major)
        end
        if obj.role.offset then
            add_number("offset.x", obj.role.offset.x)
            add_number("offset.y", obj.role.offset.y)
        end
        add_line("xy_bond", tostring(obj.role.xy_bond or "nil"), c.value_string)
    end
    
    if obj.children then
        add_section("=== CHILDREN ===")
        local child_count = 0
        for k, v in pairs(obj.children) do
            child_count = child_count + 1
            add_line(tostring(k), get_class_name(v) .. " " .. tostring(v), c.value_table, v)
        end
        if child_count == 0 then
            add_line("(none)", "", c.value_nil)
        end
    end
    
    add_section("=== RENDERING ===")
    add_number("dissolve", obj.dissolve, "%.3f")
    add_bool("no_shadow", obj.no_shadow)
    add_bool("greyed", obj.greyed)
    if obj.hover_tilt then
        add_number("hover_tilt", obj.hover_tilt)
    end
    if obj.shadow_parrallax then
        add_number("shadow_parrallax.x", obj.shadow_parrallax.x)
        add_number("shadow_parrallax.y", obj.shadow_parrallax.y)
    end
    
    add_section("=== EXPAND TABLES ===")
    add_line("(Full Object)", data.class_name, c.value_table, obj)
    if obj.T then add_line("T", "Transform", c.value_table, obj.T) end
    if obj.VT then add_line("VT", "Visible Transform", c.value_table, obj.VT) end
    if obj.base then add_line("base", "Base Data", c.value_table, obj.base) end
    if obj.ability then add_line("ability", "Ability Data", c.value_table, obj.ability) end
    if obj.config then add_line("config", "Config", c.value_table, obj.config) end
    if obj.states then add_line("states", "States", c.value_table, obj.states) end
    if obj.role then add_line("role", "Role", c.value_table, obj.role) end
    if obj.children then add_line("children", "Children", c.value_table, obj.children) end
    
    return data
end

local function inspection_to_text(data)
    if not data then return "No inspection data" end
    
    local lines = {}
    table.insert(lines, "=== INSPECTOR: " .. data.class_name .. " ===")
    table.insert(lines, "Address: " .. tostring(data.object))
    table.insert(lines, "Timestamp: " .. string.format("%.3f", data.timestamp))
    table.insert(lines, "")
    
    for _, line in ipairs(data.lines) do
        if line.section then
            table.insert(lines, "")
            table.insert(lines, line.section)
        elseif line.key then
            table.insert(lines, line.key .. ": " .. (line.value or ""))
        end
    end
    
    return table.concat(lines, "\n")
end

local HELP_LINES = {
    "Hover over cards/objects to inspect them",
    "Press I to freeze/unfreeze inspection",
    "Press Ctrl+C to copy data to clipboard", 
    "Click [+] items to expand tables",
    "Scroll to see more properties",
}

local function draw_content(self, x, y, w, h)
    local c = panel.COLORS
    local line_h = panel.DEFAULTS.line_height
    local mx, my = love.mouse.getPosition()
    
    if not state.frozen then
        local hovered = find_hovered_object()
        if hovered then
            state.target = hovered
        end
    end
    
    if state.target then
        state.inspection_data = build_inspection_data(state.target)
    end
    
    local data = state.inspection_data
    if not data then
        love.graphics.setColor(c.hint)
        love.graphics.print("Hover over a card/object", x, y)
        love.graphics.print("Press I to freeze inspection", x, y + line_h)
        return
    end
    
    self:update_scroll(#data.lines)
    
    local visible_lines = self:get_visible_lines()
    state.hover_line = nil
    
    for i = 1, visible_lines do
        local line_idx = i + self.scroll_offset
        local line = data.lines[line_idx]
        if not line then goto continue end

        local ly = y + (i - 1) * line_h

        local is_hovered = mx >= x and mx <= x + w and my >= ly and my < ly + line_h
        local is_clickable = line.table_ref ~= nil

        if is_hovered and is_clickable then
            love.graphics.setColor(0.3, 0.4, 0.5, 0.5)
            love.graphics.rectangle("fill", x, ly, w, line_h)
            state.hover_line = line_idx
        end

        if line.section then
            love.graphics.setColor(c.section)
            love.graphics.print(line.section, x, ly)
            goto continue
        end

        love.graphics.setColor(c.key)
        love.graphics.print(line.key or "", x, ly)

        local value_color = line.color or c.text
        if is_clickable then
            value_color = is_hovered and {0.5, 0.8, 1.0, 1.0} or {0.3, 0.6, 0.8, 1.0}
        end
        love.graphics.setColor(value_color)
        local value_text = line.value or ""
        if is_clickable then
            value_text = "[+] " .. value_text
        end
        love.graphics.print(value_text, x + 160, ly)
        ::continue::
    end
    
    if state.copy_flash > 0 then
        love.graphics.setColor(0.3, 1.0, 0.5, state.copy_flash)
        love.graphics.rectangle("fill", x, y, w, 25)
        love.graphics.setColor(0, 0, 0, state.copy_flash)
        love.graphics.print("Copied to clipboard!", x + w/2 - 70, y + 5)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

local function handle_click(self, x, y, button)
    if not state.inspection_data then return false end
    
    local data = state.inspection_data
    local cx, cy, cw, ch = self:get_content_rect()
    local line_h = panel.DEFAULTS.line_height
    
    local relative_y = y - cy
    local clicked_visible_line = math.floor(relative_y / line_h) + 1
    local clicked_line_idx = clicked_visible_line + self.scroll_offset
    
    local line = data.lines[clicked_line_idx]
    if line and line.table_ref and table_viewer then
        local title = line.key or "Table"
        table_viewer.open(line.table_ref, title, x + 20, y)
        return true
    end
    
    return false
end

function inspector_panel.init()
    state.panel = panel.new({
        id = "inspector",
        title = "Inspector",
        x = 10,
        y = 10,
        width = 420,
        height = 500,
        closable = true,
        minimizable = true,
        draggable = true,
        scrollable = true,
        visible = false,
        help_lines = HELP_LINES,
        on_draw_content = draw_content,
        on_click = handle_click,
        on_close = function()
            G.CARD_INSPECTOR = false
            state.frozen = false
            state.target = nil
            state.inspection_data = nil
        end,
    })
    
    return state.panel
end

function inspector_panel.set_table_viewer(tv)
    table_viewer = tv
end

function inspector_panel.get_panel()
    return state.panel
end

function inspector_panel.show()
    if state.panel then
        panel_manager.position_panel(state.panel)
        state.panel.visible = true
    end
end

function inspector_panel.hide()
    if state.panel then
        state.panel.visible = false
    end
end

function inspector_panel.toggle()
    if state.panel then
        if not state.panel.visible then
            panel_manager.position_panel(state.panel)
        end
        state.panel.visible = not state.panel.visible
        G.CARD_INSPECTOR = state.panel.visible
        if not state.panel.visible then
            state.frozen = false
            state.target = nil
            state.inspection_data = nil
        end
    end
end

function inspector_panel.is_visible()
    return state.panel and state.panel.visible
end

function inspector_panel.toggle_freeze()
    state.frozen = not state.frozen
    if state.frozen then
        local hovered = find_hovered_object()
        if hovered then
            state.target = hovered
            state.inspection_data = build_inspection_data(hovered)
        end
        if state.panel then
            state.panel.title = "Inspector [FROZEN]"
            state.panel.frozen = true
        end
    else
        if state.panel then
            state.panel.title = "Inspector"
            state.panel.frozen = false
        end
    end
end

function inspector_panel.is_frozen()
    return state.frozen
end

function inspector_panel.copy_to_clipboard()
    if not state.inspection_data then return false end
    local text = inspection_to_text(state.inspection_data)
    love.system.setClipboardText(text)
    state.copy_flash = 1.0
    return true
end

function inspector_panel.set_ctrl_held(held)
    state.ctrl_held = held
end

function inspector_panel.is_ctrl_held()
    return state.ctrl_held
end

function inspector_panel.update(dt)
    if state.copy_flash > 0 then
        state.copy_flash = state.copy_flash - dt * 2
        if state.copy_flash < 0 then state.copy_flash = 0 end
    end
    if state.panel then
        state.panel:update(dt)
    end
end

function inspector_panel.draw()
    if state.panel and state.panel.visible then
        state.panel:draw()
    end
end

return inspector_panel
