local debug = {}

local panel_manager = require('strontium.ui.panel_manager')
local perf_graph_panel = require('strontium.ui.perf_graph_panel')
local perf_panel = require('strontium.ui.perf_panel')
local strontium_panel = require('strontium.ui.strontium_panel')
local inspector_panel = require('strontium.ui.inspector_panel')
local table_viewer = require('strontium.ui.table_viewer')
local effect_lab_panel = require('strontium.ui.effect_lab_panel')
local gc_panel = require('strontium.ui.gc_panel')

function debug.init()
    G.PERF_GRAPH = false
    G.STRONTIUM_OPEN = false
    G.CARD_INSPECTOR = false
    
    local perf_graph = perf_graph_panel.init()
    local perf_breakdown = perf_panel.init()
    local strontium = strontium_panel.init()
    local insp = inspector_panel.init()
    local effect_lab = effect_lab_panel.init()
    local gc_stats = gc_panel.init()
    
    panel_manager.register(perf_graph)
    panel_manager.register(perf_breakdown)
    panel_manager.register(strontium)
    panel_manager.register(insp)
    panel_manager.register(effect_lab)
    panel_manager.register(gc_stats)
    
    inspector_panel.set_table_viewer(table_viewer)
    
    strontium_panel.set_panels({
        perf_graph = perf_graph,
        perf_breakdown = perf_panel,
        inspector = insp,
        effect_lab = effect_lab,
        gc_panel = gc_stats,
    })
end

function debug.update(dt)
    -- Always accumulate dt so the perf graph has correct timing when opened.
    perf_graph_panel.update(dt)
    
    if strontium_panel.is_visible() then
        strontium_panel.update(dt)
    end
    
    if inspector_panel.is_visible() then
        inspector_panel.update(dt)
    end
    
    if table_viewer.has_windows() then
        table_viewer.update(dt)
    end
    
    panel_manager.update(dt)
end

function debug.draw()
    -- Flush exactly one sample per rendered frame.
    -- Only query graphics stats when the perf graph is visible.
    if perf_graph_panel.is_visible() then
        local gfx_stats = love.graphics.getStats()
        perf_graph_panel.flush((gfx_stats and gfx_stats.drawcalls) or 0)
    else
        perf_graph_panel.flush(0)
    end
    
    panel_manager.draw()
    
    if table_viewer.has_windows() then
        table_viewer.draw()
    end
end

function debug.handle_input(key)
    if key == "lctrl" or key == "rctrl" then
        inspector_panel.set_ctrl_held(true)
        return false
    end

    if effect_lab_panel.handle_key and effect_lab_panel.handle_key(key) then
        return true
    end
    
    if key == "c" and inspector_panel.is_ctrl_held() and inspector_panel.is_visible() then
        if inspector_panel.copy_to_clipboard() then
            return true
        end
    end
    
    if key == "`" or key == "f8" then
        strontium_panel.toggle()
        return true
    end

    if key == "f6" then
        local br = G.STRONTIUM_RENDERER
        if br then
            if br.invalidate_all_ubershaders then
                br:invalidate_all_ubershaders()
            elseif br.invalidate_ubershader and br.registry and br.registry.layer_order then
                for i = 1, #br.registry.layer_order do
                    br:invalidate_ubershader(br.registry.layer_order[i])
                end
            end
            return true
        end
    end
    
    if key == "f12" then
        inspector_panel.toggle()
        return true
    end

    if key == "f10" then
        if G.STRONTIUM_RENDERER then
            G.USE_STRONTIUM_RENDERER = not G.USE_STRONTIUM_RENDERER
            if G.USE_STRONTIUM_RENDERER then
                G.USE_BATCHED_RENDERER = false
            end
            return true
        end
    end
    
    if key == "i" and inspector_panel.is_visible() then
        inspector_panel.toggle_freeze()
        return true
    end
    
    if key == "escape" then
        if strontium_panel.is_visible() or inspector_panel.is_visible() or 
           perf_graph_panel.is_visible() or table_viewer.has_windows() or 
           effect_lab_panel.is_visible() or gc_panel.is_visible() then
            debug.close_all()
            return true
        end
    end
    
    return false
end

function debug.keyreleased(key)
    if key == "lctrl" or key == "rctrl" then
        inspector_panel.set_ctrl_held(false)
    end
end

function debug.wheelmoved(x, y)
    if table_viewer.wheelmoved(x, y) then
        return true
    end
    
    if panel_manager.wheelmoved(x, y) then
        return true
    end
    
    return false
end

function debug.textinput(text)
    if effect_lab_panel.textinput then
        return effect_lab_panel.textinput(text)
    end
    return false
end

function debug.mousepressed(x, y, button)
    local mx, my = love.mouse.getPosition()
    
    if table_viewer.mousepressed(mx, my, button) then
        return true
    end
    
    if panel_manager.mousepressed(mx, my, button) then
        return true
    end
    
    return false
end

function debug.mousereleased(x, y, button)
    local mx, my = love.mouse.getPosition()
    
    if table_viewer.mousereleased(mx, my, button) then
        return true
    end
    
    if panel_manager.mousereleased(mx, my, button) then
        return true
    end
    
    return false
end

function debug.mousemoved(x, y, dx, dy)
    local mx, my = love.mouse.getPosition()
    
    if table_viewer.mousemoved(mx, my, dx, dy) then
        return true
    end
    
    if panel_manager.mousemoved(mx, my, dx, dy) then
        return true
    end
    
    return false
end

function debug.get_state()
    return {
        strontium_visible = strontium_panel.is_visible(),
        perf_graph_visible = perf_graph_panel.is_visible(),
        inspector_visible = inspector_panel.is_visible(),
        inspector_frozen = inspector_panel.is_frozen(),
        table_viewer_count = table_viewer.window_count(),
    }
end

function debug.close_all()
    strontium_panel.hide()
    perf_graph_panel.hide()
    perf_panel.hide()
    inspector_panel.hide()
    effect_lab_panel.hide()
    gc_panel.hide()
    table_viewer.close_all()
    
    G.STRONTIUM_OPEN = false
    G.PERF_GRAPH = false
    G.CARD_INSPECTOR = false
end

return debug
