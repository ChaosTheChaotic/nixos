--- Batch renderer entry point.

local builder = require('strontium.renderer.batch.builder')
local draw = require('strontium.renderer.batch.draw')

local batch = {}

function batch.attach(br)
    builder.attach(br)
    draw.attach(br)
end

return batch
