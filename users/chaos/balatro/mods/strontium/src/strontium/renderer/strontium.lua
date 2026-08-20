--- The one and only.

local core = require('strontium.renderer.core')
local adapter = require('strontium.renderer.base.adapter')
local batch = require('strontium.renderer.batch')
local composer = require('strontium.renderer.composer')
local draw = require('strontium.renderer.draw')
local effects = require('strontium.renderer.base.effects')
local overlays = require('strontium.renderer.base.overlays')
local order_map = require('strontium.renderer.order_map')
local instancing = require('strontium.renderer.instancing')
local params = require('strontium.renderer.params')
local public_api = require('strontium.api')
local shader = require('strontium.renderer.shader')
local stages = require('strontium.renderer.base.stages')
local ubershader = require('strontium.renderer.ubershader')
local state = require('strontium.renderer.state')
local vanilla_definitions = require('strontium.renderer.base.definitions')

local renderer = {}

function renderer.init()
    G.STRONTIUM_RENDERER = state.new()
    local br = G.STRONTIUM_RENDERER

    -- Attach our modules. This is a somewhat cursed take on the factory pattern.
    core.attach(br)
    params.attach(br)
    shader.attach(br)
    ubershader.attach(br)
    order_map.attach(br)
    instancing.attach(br)
    adapter.attach(br)
    batch.attach(br)
    draw.attach(br)
    effects.attach(br)
    overlays.attach(br)
    vanilla_definitions.attach(br)

    -- Setup composer pipeline.
    composer.attach(br)
    stages.register_defaults(br)

    -- Register builtins
    br:register_defaults()
    br:register_builtin_effects()
    br:register_builtin_overlays()

    if G.BATCHED_EDITION_INTEGRATED then
        br:set_layer_shader("center", "edition_integrated")
        br:set_layer_shader("front", "edition_integrated")
    end

    if public_api and public_api.install then
        public_api.install(br)
    end
end

return renderer
