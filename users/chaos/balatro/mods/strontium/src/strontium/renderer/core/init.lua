--- Core module aggregator

local registry = require('strontium.renderer.core.registry')
local intents = require('strontium.renderer.core.intents')
local params = require('strontium.renderer.core.params')
local frame = require('strontium.renderer.core.frame')

local core = {}

function core.attach(br)
    registry.attach(br)
    intents.attach(br)
    params.attach(br)
    frame.attach(br)
end

-- Re-export helpers for external use
core.normalize_effect_def = registry.normalize_effect_def
core.bump_registry_version = registry.bump_registry_version
core.normalize_intent_fields = intents.normalize_intent_fields

return core
