-- Panel Manager - z-ordering and input routing

local panel_manager = {}

local panels = {}

local dragging = {
    panel = nil,
    offset_x = 0,
    offset_y = 0,
}

local next_id = 1

local function get_screen_size()
    local screen_w = love.graphics.getWidth()
    local screen_h = love.graphics.getHeight()
    if screen_w == 0 then screen_w = 1920 end
    if screen_h == 0 then screen_h = 1080 end
    return screen_w, screen_h
end

local function collect_visible(exclude_panel)
    local list = {}
    for _, p in ipairs(panels) do
        if p.visible and p ~= exclude_panel then
            list[#list + 1] = p
        end
    end
    return list
end

local function panel_height(panel_instance)
    return panel_instance.minimized and 28 or panel_instance.height
end

local function rects_overlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

-- Find a position for a new panel that doesn't overlap existing visible panels
function panel_manager.find_available_position(width, height, preferred_x, preferred_y, exclude_panel)
    local margin = 10
    local screen_w, screen_h = get_screen_size()
    preferred_x = preferred_x or margin
    preferred_y = preferred_y or margin

    local visible_panels = collect_visible(exclude_panel)

    if #visible_panels == 0 then
        return preferred_x, preferred_y
    end
    
    local function position_clear(x, y)
        for _, p in ipairs(visible_panels) do
            local ph = panel_height(p)
            if rects_overlap(x, y, width, height, p.x, p.y, p.width, ph) then
                return false
            end
        end
        return true
    end
    
    if position_clear(preferred_x, preferred_y) then
        return preferred_x, preferred_y
    end
    
    for _, p in ipairs(visible_panels) do
        local x = p.x + p.width + margin
        local y = p.y
        if x + width <= screen_w and position_clear(x, y) then
            return x, y
        end
    end
    
    for _, p in ipairs(visible_panels) do
        local x = p.x
        local ph = panel_height(p)
        local y = p.y + ph + margin
        if y + height <= screen_h and position_clear(x, y) then
            return x, y
        end
    end
    
    local cascade_offset = #visible_panels * 30
    local x = margin + cascade_offset
    local y = margin + cascade_offset
    if x + width <= screen_w and y + height <= screen_h then
        return x, y
    end
    
    return preferred_x, preferred_y
end

function panel_manager.register(panel_instance)
    if not panel_instance then return nil end
    
    if not panel_instance.id then
        panel_instance.id = "panel_" .. next_id
        next_id = next_id + 1
    end
    
    table.insert(panels, panel_instance)
    
    return panel_instance
end

-- Reposition a panel to avoid overlap with other visible panels
-- TODO: This doesnt actually work consistently?
function panel_manager.position_panel(panel_instance)
    if not panel_instance then return end
    local x, y = panel_manager.find_available_position(
        panel_instance.width, 
        panel_instance.height, 
        panel_instance.x, 
        panel_instance.y,
        panel_instance
    )
    panel_instance.x = x
    panel_instance.y = y
end

function panel_manager.unregister(panel_instance)
    for i, p in ipairs(panels) do
        if p == panel_instance or p.id == panel_instance then
            table.remove(panels, i)
            return true
        end
    end
    return false
end

function panel_manager.clear()
    panels = {}
end

function panel_manager.get(id)
    for _, p in ipairs(panels) do
        if p.id == id then
            return p
        end
    end
    return nil
end

function panel_manager.get_all()
    return panels
end

function panel_manager.bring_to_front(panel_instance)
    for i, p in ipairs(panels) do
        if p == panel_instance then
            table.remove(panels, i)
            table.insert(panels, panel_instance)
            return true
        end
    end
    return false
end

function panel_manager.send_to_back(panel_instance)
    for i, p in ipairs(panels) do
        if p == panel_instance then
            table.remove(panels, i)
            table.insert(panels, 1, panel_instance)
            return true
        end
    end
    return false
end

function panel_manager.update(dt)
    for _, p in ipairs(panels) do
        if p.visible and p.update then
            p:update(dt)
        end
    end
end

function panel_manager.draw()
    for _, p in ipairs(panels) do
        if p.visible and p.draw then
            p:draw()
        end
    end
end

function panel_manager.mousepressed(x, y, button)
    if button ~= 1 then return false end
    
    for i = #panels, 1, -1 do
        local p = panels[i]
        if not p.visible then goto continue end

        if p.help_expanded then
            p.help_expanded = false
            return true
        end

        if p.is_close_click and p:is_close_click(x, y) then
            if p.on_close then
                p:on_close()
            end
            p.visible = false
            return true
        end

        if p.is_minimize_click and p:is_minimize_click(x, y) then
            p.minimized = not p.minimized
            if p.on_minimize then
                p:on_minimize(p.minimized)
            end
            return true
        end

        if p.is_help_click and p:is_help_click(x, y) then
            p.help_expanded = not p.help_expanded
            return true
        end

        if p.draggable and p.is_header_click and p:is_header_click(x, y) then
            dragging.panel = p
            dragging.offset_x = x - p.x
            dragging.offset_y = y - p.y
            panel_manager.bring_to_front(p)
            return true
        end

        if not p.minimized and p.mousepressed then
            if p:mousepressed(x, y, button) then
                panel_manager.bring_to_front(p)
                return true
            end
        end

        if p.contains_point and p:contains_point(x, y) then
            panel_manager.bring_to_front(p)
            return true
        end
        ::continue::
    end
    
    return false
end

function panel_manager.mousereleased(x, y, button)
    if button == 1 then
        if dragging.panel then
            dragging.panel = nil
            return true
        end

        for i = #panels, 1, -1 do
            local p = panels[i]
            if not (p.visible and p.mousereleased) then goto continue end
            if p:mousereleased(x, y, button) then
                return true
            end
            ::continue::
        end
    end
    return false
end

function panel_manager.mousemoved(x, y, dx, dy)
    if dragging.panel then
        dragging.panel.x = x - dragging.offset_x
        dragging.panel.y = y - dragging.offset_y
        return true
    end

    for i = #panels, 1, -1 do
        local p = panels[i]
        if not (p.visible and p.mousemoved) then goto continue end
        if p:mousemoved(x, y, dx, dy) then
            return true
        end
        ::continue::
    end
    return false
end

function panel_manager.wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()
    
    for i = #panels, 1, -1 do
        local p = panels[i]
        if not (p.visible and p.wheelmoved) then goto continue end
        if p:wheelmoved(wx, wy) then
            return true
        end
        ::continue::
    end
    
    return false
end

function panel_manager.any_contains_point(x, y)
    for i = #panels, 1, -1 do
        local p = panels[i]
        if not (p.visible and p.contains_point) then goto continue end
        if p:contains_point(x, y) then
            return true, p
        end
        ::continue::
    end
    return false, nil
end

function panel_manager.count()
    return #panels
end

function panel_manager.visible_count()
    local count = 0
    for _, p in ipairs(panels) do
        if p.visible then
            count = count + 1
        end
    end
    return count
end

return panel_manager
