-- Table Viewer - Recursive table inspection windows

local panel = require('strontium.ui.panel')
local panel_manager = require('strontium.ui.panel_manager')

local table_viewer = {}

local windows = {}
local next_window_id = 1

local dragging = {
    window = nil,
    offset_x = 0,
    offset_y = 0,
}

local DEFAULT_WIDTH = 380
local DEFAULT_HEIGHT = 350

local CLASS_NAMES = {
    'Card', 'Blind', 'Card_Character', 'Sprite', 'AnimatedSprite',
    'UIBox', 'UIElement', 'CardArea', 'DynaText', 'Particles',
    'Moveable', 'Node', 'Object',
}

local function clamp(value, min_val, max_val)
    return math.max(min_val, math.min(value, max_val))
end

local function get_class_name(obj)
    if not obj or type(obj) ~= "table" then return nil end
    local mt = getmetatable(obj)
    if not mt then return nil end
    
    for _, name in ipairs(CLASS_NAMES) do
        if rawget(_G, name) and mt == _G[name] then
            return name
        end
    end
    return nil
end

local function format_value(v, max_len)
    max_len = max_len or 40
    local t = type(v)
    local str, color, is_table
    local c = panel.COLORS
    
    if t == "nil" then
        str, color = "nil", c.value_nil
    elseif t == "boolean" then
        str = tostring(v)
        color = v and c.value_bool_true or c.value_bool_false
    elseif t == "number" then
        if v == math.floor(v) and math.abs(v) < 1000000 then
            str = tostring(v)
        else
            str = string.format("%.4f", v)
        end
        color = c.value_number
    elseif t == "string" then
        str = '"' .. v:sub(1, max_len) .. (v:len() > max_len and '...' or '') .. '"'
        color = c.value_string
    elseif t == "table" then
        is_table = true
        local class_name = get_class_name(v)
        if class_name then
            str = "<" .. class_name .. ">"
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
        local us = tostring(v)
        if #us > max_len then us = us:sub(1, max_len) .. "..." end
        str = "<" .. us .. ">"
        color = c.value_function
    else
        str = tostring(v):sub(1, max_len)
        color = c.value_nil
    end
    
    return str, color, is_table
end

local function build_entries(tbl)
    if type(tbl) ~= "table" then return {} end
    
    local entries = {}
    local keys = {}
    
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then
            if ta == "number" then return true end
            if tb == "number" then return false end
            return ta < tb
        end
        if ta == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)
    
    for _, k in ipairs(keys) do
        local v = tbl[k]
        local val_str, val_color, is_table = format_value(v)
        table.insert(entries, {
            key = tostring(k),
            value = v,
            value_str = val_str,
            color = val_color,
            is_table = is_table,
        })
    end
    
    return entries
end

local function get_visible_lines(window)
    local d = panel.DEFAULTS
    local content_height = window.height - d.header_height - 20
    return math.floor(content_height / d.line_height)
end

local function draw_window_content(window)
    local d = panel.DEFAULTS
    local c = panel.COLORS
    local mx, my = love.mouse.getPosition()
    
    local content_x = window.x + d.padding
    local content_y = window.y + d.header_height + 2
    local content_w = window.width - d.padding * 2 - d.scrollbar_width
    local content_h = window.height - d.header_height - 20
    
    -- Clip content to the scroll window so expanded tables dont bleed
    love.graphics.setScissor(content_x, content_y, content_w + d.scrollbar_width, content_h)
    
    local visible_lines = get_visible_lines(window)
    local total_lines = #window.entries
    local max_scroll = math.max(0, total_lines - visible_lines)
    window.scroll_offset = clamp(window.scroll_offset, 0, max_scroll)
    
    window.hover_entry = nil
    
    for i = 1, visible_lines do
        local entry_idx = i + window.scroll_offset
        local entry = window.entries[entry_idx]
        if not entry then goto continue end

        local line_y = content_y + (i - 1) * d.line_height
        local is_entry_hovered = panel.point_in_rect(mx, my, content_x, line_y, content_w, d.line_height)

        if is_entry_hovered and entry.is_table then
            window.hover_entry = entry_idx
            love.graphics.setColor(0.3, 0.5, 0.7, 0.3)
            love.graphics.rectangle("fill", content_x, line_y, content_w, d.line_height)
        end

        love.graphics.setColor(c.key)
        love.graphics.print(entry.key, content_x, line_y)

        love.graphics.setColor(entry.color)
        love.graphics.print(entry.value_str, content_x + 120, line_y)

        if entry.is_table then
            love.graphics.setColor(is_entry_hovered and c.expand_btn_hover or c.expand_btn)
            love.graphics.print("[+]", content_x + content_w - 25, line_y)
        end
        ::continue::
    end
    
    love.graphics.setScissor()
    
    if total_lines > visible_lines then
        local scrollbar_h = (visible_lines / total_lines) * content_h
        local scrollbar_y = content_y + (window.scroll_offset / max_scroll) * (content_h - scrollbar_h)
        love.graphics.setColor(c.scrollbar)
        love.graphics.rectangle("fill", window.x + window.width - d.scrollbar_width - 3, scrollbar_y, d.scrollbar_width - 2, scrollbar_h, 2, 2)
    end
    
    love.graphics.setColor(c.hint)
    love.graphics.print("Click table to expand | Drag header to move", content_x, window.y + window.height - 16)
end

local function draw_window(window)
    local d = panel.DEFAULTS
    local c = panel.COLORS
    local mx, my = love.mouse.getPosition()
    
    love.graphics.setColor(c.background)
    love.graphics.rectangle("fill", window.x, window.y, window.width, window.height, 5, 5)
    
    local is_hovered = panel.point_in_rect(mx, my, window.x, window.y, window.width, window.height)
    love.graphics.setColor(is_hovered and c.border_hover or c.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", window.x, window.y, window.width, window.height, 5, 5)
    
    love.graphics.setColor(c.header)
    love.graphics.rectangle("fill", window.x, window.y, window.width, d.header_height, 5, 5)
    love.graphics.rectangle("fill", window.x, window.y + 5, window.width, d.header_height - 5)
    
    love.graphics.setColor(c.header_text)
    local title_max = math.floor((window.width - d.close_btn_size - 20) / 7)
    local title = window.title
    if #title > title_max then title = title:sub(1, title_max - 3) .. "..." end
    love.graphics.print(title, window.x + 8, window.y + 5)
    
    local close_x = window.x + window.width - d.close_btn_size - 4
    local close_y = window.y + 3
    window.hover_close = panel.point_in_rect(mx, my, close_x, close_y, d.close_btn_size, d.close_btn_size)
    love.graphics.setColor(window.hover_close and c.close_btn_hover or c.close_btn)
    love.graphics.rectangle("fill", close_x, close_y, d.close_btn_size, d.close_btn_size, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(close_x + 5, close_y + 5, close_x + d.close_btn_size - 5, close_y + d.close_btn_size - 5)
    love.graphics.line(close_x + d.close_btn_size - 5, close_y + 5, close_x + 5, close_y + d.close_btn_size - 5)
    
    draw_window_content(window)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function table_viewer.open(tbl, title, x, y)
    if type(tbl) ~= "table" then return nil end
    
    local class_name = get_class_name(tbl)
    local default_title = class_name or ("table: " .. tostring(tbl):sub(8, 20))
    
    local offset = (#windows % 10) * 25
    
    local window = {
        id = next_window_id,
        table = tbl,
        title = title or default_title,
        x = x or (150 + offset),
        y = y or (100 + offset),
        width = DEFAULT_WIDTH,
        height = DEFAULT_HEIGHT,
        scroll_offset = 0,
        entries = build_entries(tbl),
        hover_close = false,
        hover_entry = nil,
    }
    
    next_window_id = next_window_id + 1
    table.insert(windows, window)
    
    return window
end

function table_viewer.close(id)
    for i, w in ipairs(windows) do
        if w.id == id then
            table.remove(windows, i)
            return true
        end
    end
    return false
end

function table_viewer.close_all()
    windows = {}
end

function table_viewer.draw()
    for _, window in ipairs(windows) do
        draw_window(window)
    end
end

function table_viewer.update(dt)
    for _, window in ipairs(windows) do
        if window.table then
            window.entries = build_entries(window.table)
        end
    end
end

function table_viewer.mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    local d = panel.DEFAULTS
    
    for i = #windows, 1, -1 do
        local window = windows[i]
        
        local close_x = window.x + window.width - d.close_btn_size - 4
        local close_y = window.y + 3
        if panel.point_in_rect(x, y, close_x, close_y, d.close_btn_size, d.close_btn_size) then
            table.remove(windows, i)
            return true
        end
        
        if panel.point_in_rect(x, y, window.x, window.y, window.width, d.header_height) then
            dragging.window = window
            dragging.offset_x = x - window.x
            dragging.offset_y = y - window.y
            table.remove(windows, i)
            table.insert(windows, window)
            return true
        end
        
        if window.hover_entry then
            local entry = window.entries[window.hover_entry]
            if entry and entry.is_table and type(entry.value) == "table" then
                local new_title = window.title .. "." .. entry.key
                table_viewer.open(entry.value, new_title, window.x + 30, window.y + 30)
                return true
            end
        end
        
        if panel.point_in_rect(x, y, window.x, window.y, window.width, window.height) then
            table.remove(windows, i)
            table.insert(windows, window)
            return true
        end
    end
    
    return false
end

function table_viewer.mousereleased(x, y, button)
    if button == 1 and dragging.window then
        dragging.window = nil
        return true
    end
    return false
end

function table_viewer.mousemoved(x, y)
    if dragging.window then
        dragging.window.x = x - dragging.offset_x
        dragging.window.y = y - dragging.offset_y
        return true
    end
    return false
end

function table_viewer.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    
    for i = #windows, 1, -1 do
        local window = windows[i]
        if panel.point_in_rect(mx, my, window.x, window.y, window.width, window.height) then
            window.scroll_offset = window.scroll_offset - y * 3
            local visible_lines = get_visible_lines(window)
            local max_scroll = math.max(0, #window.entries - visible_lines)
            window.scroll_offset = clamp(window.scroll_offset, 0, max_scroll)
            return true
        end
    end
    
    return false
end

function table_viewer.has_windows()
    return #windows > 0
end

function table_viewer.window_count()
    return #windows
end

return table_viewer
