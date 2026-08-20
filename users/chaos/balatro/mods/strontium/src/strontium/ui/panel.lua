local panel = {}
panel.COLORS = {
    background = {0.1, 0.1, 0.15, 0.95},
    header = {0.15, 0.15, 0.22, 1.0},
    header_text = {0.4, 0.9, 1.0, 1.0},
    border = {0.3, 0.6, 0.9, 0.8},
    border_hover = {0.5, 0.8, 1.0, 1.0},
    border_frozen = {1.0, 0.6, 0.2, 1.0},
    close_btn = {1.0, 0.4, 0.4, 1.0},
    close_btn_hover = {1.0, 0.6, 0.6, 1.0},
    minimize_btn = {1.0, 0.9, 0.3, 1.0},
    minimize_btn_hover = {1.0, 1.0, 0.5, 1.0},
    scrollbar = {0.4, 0.6, 0.9, 0.5},
    scrollbar_hover = {0.5, 0.7, 1.0, 0.7},
    hint = {0.5, 0.5, 0.6, 0.8},
    text = {0.9, 0.95, 1.0, 1.0},
    text_dim = {0.6, 0.7, 0.8, 0.8},
    section = {1.0, 0.8, 0.3, 1.0},
    key = {0.7, 0.85, 1.0, 1.0},
    value_string = {0.6, 1.0, 0.6, 1.0},
    value_number = {1.0, 0.8, 0.5, 1.0},
    value_bool_true = {0.4, 1.0, 0.4, 1.0},
    value_bool_false = {1.0, 0.4, 0.4, 1.0},
    value_nil = {0.5, 0.5, 0.5, 1.0},
    value_table = {0.9, 0.7, 1.0, 1.0},
    value_function = {0.7, 0.7, 0.9, 1.0},
    expand_btn = {0.5, 0.8, 1.0, 0.9},
    expand_btn_hover = {0.7, 0.9, 1.0, 1.0},
    good = {0.2, 1.0, 0.4},
    warning = {1.0, 0.9, 0.2},
    bad = {1.0, 0.3, 0.2},
}

panel.DEFAULTS = {
    width = 380,
    height = 350,
    min_width = 200,
    min_height = 100,
    header_height = 28,
    line_height = 18,
    close_btn_size = 20,
    minimize_btn_size = 20,
    scrollbar_width = 8,
    padding = 5,
    resize_handle_size = 14,
}

function panel.point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function clamp(value, min_val, max_val)
    return math.max(min_val, math.min(value, max_val))
end

local function truncate_title(text, max_len)
    if #text <= max_len then return text end
    return text:sub(1, max_len - 3) .. "..."
end

local function get_screen_size()
    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight()
    if screen_w == 0 then screen_w = 1920 end
    if screen_h == 0 then screen_h = 1080 end
    return screen_w, screen_h
end

local function button_layout(self)
    local d = panel.DEFAULTS
    local layout = {}
    local btn_y = self.y + (d.header_height - d.close_btn_size) / 2
    local cursor_x = self.x + self.width - d.close_btn_size - 4

    if self.closable then
        layout.close = { x = cursor_x, y = btn_y, w = d.close_btn_size, h = d.close_btn_size }
        cursor_x = cursor_x - d.minimize_btn_size - 4
    end
    if self.minimizable then
        layout.minimize = { x = cursor_x, y = btn_y, w = d.minimize_btn_size, h = d.minimize_btn_size }
        cursor_x = cursor_x - d.minimize_btn_size - 4
    end
    if self.help_lines then
        layout.help = { x = cursor_x, y = btn_y, w = d.minimize_btn_size, h = d.minimize_btn_size }
    end

    return layout
end

function panel.new(config)
    config = config or {}
    
    local p = {
        id = config.id or tostring({}):sub(8),
        title = config.title or "Panel",
        
        x = config.x or 100,
        y = config.y or 100,
        width = config.width or panel.DEFAULTS.width,
        height = config.height or panel.DEFAULTS.height,
        
        visible = config.visible ~= false,
        minimized = config.minimized or false,
        frozen = config.frozen or false,
        closable = config.closable ~= false,
        minimizable = config.minimizable ~= false,
        draggable = config.draggable ~= false,
        scrollable = config.scrollable ~= false,
        resizable = config.resizable ~= false,
        
        help_lines = config.help_lines or nil,
        help_expanded = false,
        
        scroll_offset = 0,
        max_scroll = 0,
        content_height = 0,
        
        _hover_close = false,
        _hover_minimize = false,
        _hover_help = false,
        _hover_header = false,
        _hover_content = false,
        _hover_scrollbar = false,
        _scrollbar_drag = false,
        _scrollbar_drag_offset = 0,
        _hover_resize = false,
        _resize_drag = false,
        _resize_start_w = 0,
        _resize_start_h = 0,
        _resize_start_x = 0,
        _resize_start_y = 0,
        
        colors = config.colors or nil,
        
        on_close = config.on_close or nil,
        on_minimize = config.on_minimize or nil,
        on_draw_content = config.on_draw_content or nil,
        on_click = config.on_click or nil,
        on_scroll = config.on_scroll or nil,
        on_update = config.on_update or nil,
    }
    
    setmetatable(p, { __index = panel })
    return p
end


function panel:get_color(name)
    if self.colors and self.colors[name] then
        return self.colors[name]
    end
    return panel.COLORS[name] or {1, 1, 1, 1}
end

function panel:get_content_rect()
    local d = panel.DEFAULTS
    local x = self.x + d.padding
    local y = self.y + d.header_height + d.padding
    local w = self.width - d.padding * 2 - (self.scrollable and d.scrollbar_width or 0)
    local h = self.height - d.header_height - d.padding * 2
    return x, y, w, h
end

function panel:get_visible_lines()
    local d = panel.DEFAULTS
    local content_h = self.height - d.header_height - d.padding * 2
    return math.floor(content_h / d.line_height)
end

function panel:get_scrollbar_geom()
    if not self.scrollable or self.max_scroll <= 0 then return nil end

    local d = panel.DEFAULTS
    local _, content_y, _, content_h = self:get_content_rect()
    local scrollbar_x = self.x + self.width - d.scrollbar_width - d.padding
    local scrollbar_w = d.scrollbar_width - 2
    local scrollbar_track_h = content_h
    local visible_lines = self:get_visible_lines()
    local scrollbar_h = math.max(20, (visible_lines / (self.max_scroll + visible_lines)) * scrollbar_track_h)
    local track_range = scrollbar_track_h - scrollbar_h
    local scrollbar_y = content_y
    if track_range > 0 then
        scrollbar_y = content_y + (self.scroll_offset / self.max_scroll) * track_range
    end
    return scrollbar_x, content_y, scrollbar_w, scrollbar_track_h, scrollbar_y, scrollbar_h
end

function panel:get_resize_handle_rect()
    if not self.resizable or self.minimized then return nil end
    local d = panel.DEFAULTS
    local size = d.resize_handle_size
    local x = self.x + self.width - size - 2
    local y = self.y + self.height - size - 2
    return x, y, size, size
end

function panel:update_scroll(content_line_count)
    local visible_lines = self:get_visible_lines()
    self.max_scroll = math.max(0, content_line_count - visible_lines)
    self.scroll_offset = clamp(self.scroll_offset, 0, self.max_scroll)
    self.content_height = content_line_count * panel.DEFAULTS.line_height
end

function panel:scroll(dy)
    if not self.scrollable then return false end
    self.scroll_offset = self.scroll_offset - dy * 3
    self.scroll_offset = clamp(self.scroll_offset, 0, self.max_scroll)
    return true
end

function panel:draw_minimized(mx, my)
    local d = panel.DEFAULTS
    love.graphics.setColor(self:get_color('header'))
    love.graphics.rectangle("fill", self.x, self.y, self.width, d.header_height, 5, 5)

    love.graphics.setColor(self:get_color('border'))
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, d.header_height, 5, 5)

    love.graphics.setColor(self:get_color('header_text'))
    local font = love.graphics.getFont()
    local text_h = font:getHeight()
    love.graphics.print(self.title .. " [+]", self.x + 8, self.y + (d.header_height - text_h) / 2)

    self:draw_buttons(mx, my)
end

function panel:draw_body(mx, my)
    local d = panel.DEFAULTS
    love.graphics.setColor(self:get_color('background'))
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 5, 5)

    local is_hovered = panel.point_in_rect(mx, my, self.x, self.y, self.width, self.height)
    local border_color = self.frozen and self:get_color('border_frozen')
        or (is_hovered and self:get_color('border_hover') or self:get_color('border'))
    love.graphics.setColor(border_color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)

    love.graphics.setColor(self:get_color('header'))
    love.graphics.rectangle("fill", self.x, self.y, self.width, d.header_height, 5, 5)
    love.graphics.rectangle("fill", self.x, self.y + 5, self.width, d.header_height - 5)

    love.graphics.setColor(self:get_color('header_text'))
    local font = love.graphics.getFont()
    local text_h = font:getHeight()
    local title_max = math.floor((self.width - d.close_btn_size - d.minimize_btn_size - 30) / 7)
    local title = truncate_title(self.title, title_max)
    love.graphics.print(title, self.x + 8, self.y + (d.header_height - text_h) / 2)

    self:draw_buttons(mx, my)
    self:draw_resize_handle(mx, my)
end

function panel:draw_frame()
    if not self.visible then return end

    local mx, my = love.mouse.getPosition()
    if self.minimized then
        self:draw_minimized(mx, my)
        return
    end

    self:draw_body(mx, my)
end

function panel:draw_buttons(mx, my)
    local d = panel.DEFAULTS
    local layout = button_layout(self)

    if layout.close then
        local bx, by, bw, bh = layout.close.x, layout.close.y, layout.close.w, layout.close.h
        self._hover_close = panel.point_in_rect(mx, my, bx, by, bw, bh)
        love.graphics.setColor(self._hover_close and self:get_color('close_btn_hover') or self:get_color('close_btn'))
        love.graphics.rectangle("fill", bx, by, bw, bh, 3, 3)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(bx + 5, by + 5, bx + bw - 5, by + bh - 5)
        love.graphics.line(bx + bw - 5, by + 5, bx + 5, by + bh - 5)
    end

    if layout.minimize then
        local bx, by, bw, bh = layout.minimize.x, layout.minimize.y, layout.minimize.w, layout.minimize.h
        self._hover_minimize = panel.point_in_rect(mx, my, bx, by, bw, bh)
        love.graphics.setColor(self._hover_minimize and self:get_color('minimize_btn_hover') or self:get_color('minimize_btn'))
        love.graphics.rectangle("fill", bx, by, bw, bh, 3, 3)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(2)
        if self.minimized then
            love.graphics.line(bx + 5, by + bh / 2, bx + bw - 5, by + bh / 2)
            love.graphics.line(bx + bw / 2, by + 5, bx + bw / 2, by + bh - 5)
        else
            love.graphics.line(bx + 5, by + bh / 2, bx + bw - 5, by + bh / 2)
        end
    end

    if layout.help then
        local bx, by, bw, bh = layout.help.x, layout.help.y, layout.help.w, layout.help.h
        self._hover_help = panel.point_in_rect(mx, my, bx, by, bw, bh)
        love.graphics.setColor(self._hover_help and {0.5, 0.7, 0.9, 1} or {0.3, 0.5, 0.7, 0.9})
        love.graphics.rectangle("fill", bx, by, bw, bh, 3, 3)
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local qw = font:getWidth("?")
        local qh = font:getHeight()
        love.graphics.print("?", bx + (bw - qw) / 2, by + (bh - qh) / 2)
    end
end

function panel:draw_scrollbar()
    if not self.visible or self.minimized or not self.scrollable then return end
    if self.max_scroll <= 0 then return end
    
    local sx, sy, sw, sh, handle_y, handle_h = self:get_scrollbar_geom()
    if not sx then return end

    local color = self._scrollbar_drag and 'scrollbar_hover' or 'scrollbar'
    love.graphics.setColor(self:get_color(color))
    love.graphics.rectangle("fill", sx, handle_y, sw, handle_h, 2, 2)
end

function panel:draw_resize_handle(mx, my)
    if not self.resizable or self.minimized then return end
    local rx, ry, rw, rh = self:get_resize_handle_rect()
    if not rx then return end

    local hovered = panel.point_in_rect(mx, my, rx, ry, rw, rh)
    self._hover_resize = hovered

    local color = hovered and self:get_color('border_hover') or self:get_color('border')
    love.graphics.setColor(color)
    love.graphics.setLineWidth(1)

    local x2 = rx + rw - 2
    local y2 = ry + rh - 2
    love.graphics.line(x2 - 2, y2, x2, y2 - 2)
    love.graphics.line(x2 - 6, y2, x2, y2 - 6)
    love.graphics.line(x2 - 10, y2, x2, y2 - 10)
end

function panel:draw_help_overlay()
    if not self.help_lines or not self.help_expanded then return end
    
    local d = panel.DEFAULTS
    local c = panel.COLORS
    local line_h = d.line_height
    local padding = 12
    local overlay_w = self.width - 20
    local overlay_h = #self.help_lines * (line_h + 2) + padding * 2 + 30
    local overlay_x = self.x + 10
    local overlay_y = self.y + d.header_height + 8
    -- Ethan was here 
    love.graphics.setColor(0.06, 0.08, 0.12, 0.98)
    love.graphics.rectangle("fill", overlay_x, overlay_y, overlay_w, overlay_h, 6, 6)
    
    love.graphics.setColor(0.4, 0.6, 0.8, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", overlay_x, overlay_y, overlay_w, overlay_h, 6, 6)
    
    love.graphics.setColor(c.header_text)
    love.graphics.print("Help", overlay_x + padding, overlay_y + padding)
    
    love.graphics.setColor(0.3, 0.4, 0.5, 0.6)
    local divider_y = overlay_y + padding + 20
    love.graphics.line(overlay_x + padding, divider_y, overlay_x + overlay_w - padding, divider_y)

    local line_x = overlay_x + padding
    local line_y = overlay_y + padding + 26
    local line_step = line_h + 2
    love.graphics.setColor(c.text)
    for i = 1, #self.help_lines do
        love.graphics.print("•  " .. self.help_lines[i], line_x, line_y)
        line_y = line_y + line_step
    end
    
    love.graphics.setColor(c.hint)
    love.graphics.print("Click anywhere to close", overlay_x + padding, overlay_y + overlay_h - line_h - 8)
end

function panel:draw()
    if not self.visible then return end
    
    self:draw_frame()
    
    if not self.minimized then
        local cx, cy, cw, ch = self:get_content_rect()
        love.graphics.setScissor(cx, cy, cw + (self.scrollable and panel.DEFAULTS.scrollbar_width or 0), ch)
        
        if self.on_draw_content then
            self:on_draw_content(cx, cy, cw, ch)
        end
        
        love.graphics.setScissor()
        
        self:draw_scrollbar()
        
        self:draw_help_overlay()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function panel:update(dt)
    if self.on_update then
        self:on_update(dt)
    end
end

function panel:is_header_click(x, y)
    local d = panel.DEFAULTS
    return panel.point_in_rect(x, y, self.x, self.y, self.width, d.header_height)
end

function panel:is_close_click(x, y)
    local layout = button_layout(self)
    local btn = layout.close
    if not btn then return false end
    return panel.point_in_rect(x, y, btn.x, btn.y, btn.w, btn.h)
end

function panel:is_minimize_click(x, y)
    local layout = button_layout(self)
    local btn = layout.minimize
    if not btn then return false end
    return panel.point_in_rect(x, y, btn.x, btn.y, btn.w, btn.h)
end

function panel:is_help_click(x, y)
    local layout = button_layout(self)
    local btn = layout.help
    if not btn then return false end
    return panel.point_in_rect(x, y, btn.x, btn.y, btn.w, btn.h)
end

function panel:contains_point(x, y)
    local h = self.minimized and panel.DEFAULTS.header_height or self.height
    return panel.point_in_rect(x, y, self.x, self.y, self.width, h)
end

function panel:mousepressed(x, y, button)
    if not self.visible then return false end
    if button ~= 1 then return false end
    
    if self.help_expanded then
        self.help_expanded = false
        return true
    end
    
    if self:is_close_click(x, y) then
        if self.on_close then
            self:on_close()
        end
        self.visible = false
        return true
    end
    
    if self:is_minimize_click(x, y) then
        self.minimized = not self.minimized
        if self.on_minimize then
            self:on_minimize(self.minimized)
        end
        return true
    end
    
    if self:is_help_click(x, y) then
        self.help_expanded = not self.help_expanded
        return true
    end

    if not self.minimized and self.resizable then
        local rx, ry, rw, rh = self:get_resize_handle_rect()
        if rx and panel.point_in_rect(x, y, rx, ry, rw, rh) then
            self._resize_drag = true
            self._resize_start_w = self.width
            self._resize_start_h = self.height
            self._resize_start_x = x
            self._resize_start_y = y
            return true
        end
    end
    
    if not self.minimized then
        if self.scrollable and self.max_scroll > 0 then
            local sx, sy, sw, sh, handle_y, handle_h = self:get_scrollbar_geom()
            if sx and panel.point_in_rect(x, y, sx, sy, sw, sh) then
                local offset = y - handle_y
                if offset < 0 or offset > handle_h then
                    local track_range = sh - handle_h
                    if track_range > 0 then
                        local new_pos = clamp(y - sy - handle_h * 0.5, 0, track_range)
                        self.scroll_offset = (new_pos / track_range) * self.max_scroll
                    else
                        self.scroll_offset = 0
                    end
                    offset = handle_h * 0.5
                end
                self._scrollbar_drag = true
                self._scrollbar_drag_offset = clamp(offset, 0, handle_h)
                return true
            end
        end

        local cx, cy, cw, ch = self:get_content_rect()
        if panel.point_in_rect(x, y, cx, cy, cw, ch) then
            if self.on_click then
                return self:on_click(x, y, button)
            end
        end
    end
    
    -- Consume click if inside panel
    return self:contains_point(x, y)
end

function panel:mousereleased(x, y, button)
    if button ~= 1 then return false end
    if self._resize_drag then
        self._resize_drag = false
        return true
    end
    if self._scrollbar_drag then
        self._scrollbar_drag = false
        return true
    end
    return false
end

function panel:mousemoved(x, y, dx, dy)
    if self._resize_drag then
        local screen_w, screen_h = get_screen_size()
        local max_w = math.max(panel.DEFAULTS.min_width, screen_w - self.x - 10)
        local max_h = math.max(panel.DEFAULTS.min_height, screen_h - self.y - 10)
        local new_w = clamp(self._resize_start_w + (x - self._resize_start_x), panel.DEFAULTS.min_width, max_w)
        local new_h = clamp(self._resize_start_h + (y - self._resize_start_y), panel.DEFAULTS.min_height, max_h)
        self.width = new_w
        self.height = new_h
        return true
    end

    if not self._scrollbar_drag then return false end
    if not self.visible or self.minimized or not self.scrollable then
        self._scrollbar_drag = false
        return false
    end

    local sx, sy, sw, sh, handle_y, handle_h = self:get_scrollbar_geom()
    if not sx then
        self._scrollbar_drag = false
        return false
    end

    local track_range = sh - handle_h
    if track_range <= 0 then
        self.scroll_offset = 0
        return true
    end

    local new_pos = clamp(y - sy - self._scrollbar_drag_offset, 0, track_range)
    self.scroll_offset = (new_pos / track_range) * self.max_scroll
    return true
end

function panel:wheelmoved(x, y)
    if not self.visible or self.minimized then return false end

    local mx, my = love.mouse.getPosition()
    if self:contains_point(mx, my) then
        if self.on_scroll then
            return self:on_scroll(x, y)
        end
        if self.scrollable then
            return self:scroll(y)
        end
    end
    return false
end

return panel
