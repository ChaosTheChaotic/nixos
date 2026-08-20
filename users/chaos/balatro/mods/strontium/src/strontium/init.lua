local strontium = {}

strontium.shaders = nil
strontium.batched_renderer = nil
strontium.renderer = nil
strontium.debug = nil

local _initialized = false

function strontium.init()
    if _initialized then return end
    _initialized = true
    
    G.USE_BATCHED_RENDERER = false
    G.BATCHED_RENDERER = nil

    G.USE_STRONTIUM_RENDERER = true
    G.STRONTIUM_RENDERER = nil
    G.USE_STRONTIUM_RENDERER_RECORD = false
    G.STRONTIUM_UBERSHADER = true
    G.STRONTIUM_INSTANCING = true
    G.STRONTIUM_SORT_X = true
    G.STRONTIUM_DEBUG_OCCLUSION = false
    G.STRONTIUM_CULL_COVERED = true
    G.STRONTIUM_CULL_FACE = false
    G.STRONTIUM_MIN_VISIBLE_RATIO = 0.0

    G.BATCHED_EDITION_INTEGRATED = true

    G.PERF_DEBUG = false

    strontium.shaders = require('strontium.shaders')
    strontium.batched_renderer = require('strontium.batched_renderer')
    strontium.renderer = require('strontium.renderer.strontium')
    strontium.debug = require('strontium.debug')

    strontium.batched_renderer.init()
    strontium.renderer.init()
    
    if strontium.debug and strontium.debug.init then
        strontium.debug.init()
    end
end

function strontium.init_shaders()
    if strontium.shaders then
        strontium.shaders.init()
    end
end

-- Patch entrypoints.

function init_strontium()
    strontium.init()
end

function init_strontium_shaders()
    strontium.init_shaders()
end

function draw_strontium_debug()
    if strontium.debug then
        strontium.debug.draw()
    end
end

function update_strontium_debug(dt)
    if strontium.debug and strontium.debug.update then
        strontium.debug.update(dt)
    end
end

function handle_strontium_input(key)
    if strontium.debug then
        return strontium.debug.handle_input(key)
    end
    return false
end

function handle_strontium_textinput(text)
    if strontium.debug and strontium.debug.textinput then
        return strontium.debug.textinput(text)
    end
    return false
end

function handle_strontium_wheelmoved(x, y)
    if strontium.debug and strontium.debug.wheelmoved then
        return strontium.debug.wheelmoved(x, y)
    end
    return false
end

function handle_strontium_keyreleased(key)
    if strontium.debug and strontium.debug.keyreleased then
        strontium.debug.keyreleased(key)
    end
end

function handle_strontium_mousepressed(x, y, button)
    if strontium.debug and strontium.debug.mousepressed then
        return strontium.debug.mousepressed(x, y, button)
    end
    return false
end

function handle_strontium_mousereleased(x, y, button)
    if strontium.debug and strontium.debug.mousereleased then
        return strontium.debug.mousereleased(x, y, button)
    end
    return false
end

function handle_strontium_mousemoved(x, y, dx, dy)
    if strontium.debug and strontium.debug.mousemoved then
        return strontium.debug.mousemoved(x, y, dx, dy)
    end
    return false
end

return strontium
