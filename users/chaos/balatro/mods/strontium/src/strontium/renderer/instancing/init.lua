--- Instanced batch pipeline: replaces SpriteBatch with drawInstanced.

local builder = require('strontium.renderer.instancing.builder')
local draw = require('strontium.renderer.instancing.draw')
local shader = require('strontium.renderer.instancing.shader')

local instancing = {}

function instancing.attach(br)
    shader.attach(br)
    builder.attach(br)
    draw.attach(br)
end

return instancing
