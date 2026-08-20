--- Order-map shader setup and integration.

local util = require('strontium.renderer.util')
local buffer = require('strontium.renderer.buffer')

local order_map = {}

local ORDER_MAP_GLSL = [[
#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

#ifdef VERTEX
attribute MY_HIGHP_OR_MEDIUMP float OrderValue;
#endif
varying MY_HIGHP_OR_MEDIUMP float v_order;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_order = OrderValue;
    return transform_projection * vertex_position;
}
#endif

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    if (tex.a < 0.95 || v_order < 0.0) return vec4(0.0);
    return vec4(v_order, v_order, 0.0, 1.0);
}
]]

local ORDER_MASK_GLSL = [[
#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

extern Image order_map;
extern MY_HIGHP_OR_MEDIUMP vec2 order_map_size;
extern MY_HIGHP_OR_MEDIUMP float order_epsilon;

#ifdef VERTEX
attribute MY_HIGHP_OR_MEDIUMP float OrderValue;
#endif
varying MY_HIGHP_OR_MEDIUMP float v_order;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_order = OrderValue;
    return transform_projection * vertex_position;
}
#endif

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords) * colour;
    if (tex.a < 0.01) return tex;
    #if !defined(VERTEX)
    if (order_map_size.x > 0.0 && v_order >= 0.0) {
        vec2 om_uv = screen_coords / order_map_size;
        MY_HIGHP_OR_MEDIUMP float front = Texel(order_map, om_uv).r;
        if (front > 0.001 && (front - v_order) > order_epsilon) discard;
    }
    #endif
    return tex;
}
]]

local ORDER_MAP_INSTANCED_GLSL = [[
#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

#ifdef VERTEX
attribute MY_HIGHP_OR_MEDIUMP vec2 InstancePos;
attribute MY_HIGHP_OR_MEDIUMP vec2 InstanceScale;
attribute MY_HIGHP_OR_MEDIUMP float InstanceRot;
attribute MY_HIGHP_OR_MEDIUMP vec2 InstanceOrigin;
attribute MY_HIGHP_OR_MEDIUMP vec2 InstanceSize;
attribute MY_HIGHP_OR_MEDIUMP vec4 InstanceUV;
attribute MY_HIGHP_OR_MEDIUMP vec4 InstanceColor;
attribute MY_HIGHP_OR_MEDIUMP float OrderValue;
#endif

varying MY_HIGHP_OR_MEDIUMP float v_order;
varying MY_HIGHP_OR_MEDIUMP vec2 v_uv;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_order = OrderValue;
    v_uv = mix(InstanceUV.xy, InstanceUV.zw, VaryingTexCoord.xy);

    vec2 local = vertex_position.xy * InstanceSize - InstanceOrigin;
    local *= InstanceScale;
    if (InstanceRot != 0.0) {
        float c = cos(InstanceRot);
        float s = sin(InstanceRot);
        local = vec2(c * local.x - s * local.y, s * local.x + c * local.y);
    }
    vec2 world = local + InstancePos;
    return transform_projection * vec4(world, 0.0, 1.0);
}
#endif

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, v_uv);
    if (tex.a < 0.95 || v_order < 0.0) return vec4(0.0);
    return vec4(v_order, v_order, 0.0, 1.0);
}
]]

local ORDER_MASK_INSTANCED_GLSL = [[
#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

extern Image order_map;
extern MY_HIGHP_OR_MEDIUMP vec2 order_map_size;
extern MY_HIGHP_OR_MEDIUMP float order_epsilon;

#ifdef VERTEX
attribute MY_HIGHP_OR_MEDIUMP vec2 InstancePos;
attribute MY_HIGHP_OR_MEDIUMP vec2 InstanceScale;
attribute MY_HIGHP_OR_MEDIUMP float InstanceRot;
attribute MY_HIGHP_OR_MEDIUMP vec2 InstanceOrigin;
attribute MY_HIGHP_OR_MEDIUMP vec2 InstanceSize;
attribute MY_HIGHP_OR_MEDIUMP vec4 InstanceUV;
attribute MY_HIGHP_OR_MEDIUMP vec4 InstanceColor;
attribute MY_HIGHP_OR_MEDIUMP float OrderValue;
#endif

varying MY_HIGHP_OR_MEDIUMP float v_order;
varying MY_HIGHP_OR_MEDIUMP vec2 v_uv;
varying MY_HIGHP_OR_MEDIUMP vec4 v_color;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_order = OrderValue;
    v_color = InstanceColor;
    v_uv = mix(InstanceUV.xy, InstanceUV.zw, VaryingTexCoord.xy);

    vec2 local = vertex_position.xy * InstanceSize - InstanceOrigin;
    local *= InstanceScale;
    if (InstanceRot != 0.0) {
        float c = cos(InstanceRot);
        float s = sin(InstanceRot);
        local = vec2(c * local.x - s * local.y, s * local.x + c * local.y);
    }
    vec2 world = local + InstancePos;
    return transform_projection * vec4(world, 0.0, 1.0);
}
#endif

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, v_uv) * v_color;
    if (tex.a < 0.01) return tex;
    #if !defined(VERTEX)
    if (order_map_size.x > 0.0 && v_order >= 0.0) {
        vec2 om_uv = screen_coords / order_map_size;
        MY_HIGHP_OR_MEDIUMP float front = Texel(order_map, om_uv).r;
        if (front > 0.001 && (front - v_order) > order_epsilon) discard;
    }
    #endif
    return tex;
}
]]

function order_map.attach(br)
    if G.STRONTIUM_ORDER_MAP == nil then
        G.STRONTIUM_ORDER_MAP = true
    end
    if br.order_map then
        br.order_map.enabled = (G.STRONTIUM_ORDER_MAP ~= false)
    end
    local function ensure_order_map_canvas()
        local om = br.order_map
        if not om or not om.enabled then return nil end
        local w, h
        if G and G.CANVAS and G.CANVAS.getDimensions then
            w, h = G.CANVAS:getDimensions()
        else
            local active = love.graphics.getCanvas()
            if active and active.getDimensions then
                w, h = active:getDimensions()
            else
                w, h = love.graphics.getDimensions()
            end
        end
        om.logical_width = w
        om.logical_height = h

        local scale = (G and G.STRONTIUM_ORDER_MAP_SCALE) or om.scale or 1
        scale = math.max(0.25, math.min(scale, 2.0))
        om.scale = scale

        local cw = math.max(1, math.floor(w * scale + 0.5))
        local ch = math.max(1, math.floor(h * scale + 0.5))

        if om.canvas and om.width == cw and om.height == ch then
            return om.canvas
        end

        -- Simple format is sufficient - we only store order values [0,1]
        local ok, canvas = pcall(love.graphics.newCanvas, cw, ch, { format = "rg8" })
        if not ok then
            canvas = love.graphics.newCanvas(cw, ch)
        end
        canvas:setFilter("nearest", "nearest")
        om.canvas = canvas
        om.width = cw
        om.height = ch
        return canvas
    end

    local function ensure_order_map_shaders()
        local om = br.order_map
        if not om then return end
        if not om.shader then
            local ok, shader_obj = pcall(love.graphics.newShader, ORDER_MAP_GLSL)
            if ok then
                om.shader = shader_obj
            else
                print("[Strontium] Order map shader compile failed: " .. tostring(shader_obj))
            end
        end
        if not om.mask_shader then
            local ok, shader_obj = pcall(love.graphics.newShader, ORDER_MASK_GLSL)
            if ok then
                om.mask_shader = shader_obj
            else
                print("[Strontium] Order mask shader compile failed: " .. tostring(shader_obj))
            end
        end
    end

    function br:ensure_order_map_instanced_shaders()
        local om = self.order_map
        if not om then return nil, nil end
        -- Already compiled - fast return
        if om.instanced_shader and om.instanced_mask_shader then
            return om.instanced_shader, om.instanced_mask_shader
        end
        -- Mark as attempted even on failure to avoid retrying
        if om._instanced_shaders_attempted then
            return om.instanced_shader, om.instanced_mask_shader
        end
        om._instanced_shaders_attempted = true
        if not om.instanced_shader then
            local ok, shader_obj = pcall(love.graphics.newShader, ORDER_MAP_INSTANCED_GLSL)
            if ok then
                om.instanced_shader = shader_obj
            else
                print("[Strontium] Instanced order map shader compile failed: " .. tostring(shader_obj))
            end
        end
        if not om.instanced_mask_shader then
            local ok, shader_obj = pcall(love.graphics.newShader, ORDER_MASK_INSTANCED_GLSL)
            if ok then
                om.instanced_mask_shader = shader_obj
            else
                print("[Strontium] Instanced order mask shader compile failed: " .. tostring(shader_obj))
            end
        end
        return om.instanced_shader, om.instanced_mask_shader
    end

    -- Attach/update OrderValue attributes on batches that need masking.
    -- TODO: This sucks, clean it up.
    function br:build_order_attributes()
        local om = self.order_map
        if om and G.STRONTIUM_ORDER_MAP ~= nil then
            om.enabled = (G.STRONTIUM_ORDER_MAP ~= false)
        end
        if not (om and om.enabled) then return end
        if not om.mask_layers then return end

        for layer, batches in pairs(self.layer_batches) do
            if not om.mask_layers[layer] then
                goto continue
            end

            local layer_values = self.layer_order_values[layer]
            local layer_meshes = self.layer_order_meshes[layer]
            local layer_vertices = self.layer_order_vertices[layer]
            local layer_buffers = self.layer_order_buffers and self.layer_order_buffers[layer] or nil
            if not layer_buffers then
                layer_buffers = {}
                if self.layer_order_buffers then
                    self.layer_order_buffers[layer] = layer_buffers
                end
            end

            for key, batch_obj in pairs(batches) do
                local count = batch_obj:getCount()
                local values = layer_values and layer_values[key]
                if count > 0 and values then
                    local vertex_count = count * 4
                    local mesh = layer_meshes[key]
                    if not mesh or mesh:getVertexCount() < vertex_count then
                        local alloc_size = math.max(vertex_count, 256)
                        mesh = love.graphics.newMesh({ { "OrderValue", "float", 1 } }, alloc_size, "points", "stream")
                        layer_meshes[key] = mesh
                    end

                    local buf = layer_buffers[key]
                    if buffer.available() then
                        if not buf then
                            buf = buffer.new_float()
                            layer_buffers[key] = buf
                        end
                        buffer.ensure_float(buf, alloc_size, 1)
                    else
                        buf = nil
                    end

                    if buf and buf.ptr and buf.data then
                        local ptr = buf.ptr
                        local idx = 0
                        for i = 1, count do
                            local v = values[i] or -1
                            ptr[idx] = v
                            ptr[idx + 1] = v
                            ptr[idx + 2] = v
                            ptr[idx + 3] = v
                            idx = idx + 4
                        end
                        mesh:setVertices(buf.data, 1, vertex_count)
                    else
                        local verts = layer_vertices[key]
                        if not verts then
                            verts = {}
                            for j = 1, 1024 do verts[j] = { 0 } end
                            layer_vertices[key] = verts
                        end

                        local idx = 0
                        for i = 1, count do
                            local v = values[i] or -1
                            local t1, t2, t3, t4 = verts[idx+1], verts[idx+2], verts[idx+3], verts[idx+4]
                            if not t1 then t1 = {v}; verts[idx+1] = t1 else t1[1] = v end
                            if not t2 then t2 = {v}; verts[idx+2] = t2 else t2[1] = v end
                            if not t3 then t3 = {v}; verts[idx+3] = t3 else t3[1] = v end
                            if not t4 then t4 = {v}; verts[idx+4] = t4 else t4[1] = v end
                            idx = idx + 4
                        end

                        mesh:setVertices(verts, 1, vertex_count)
                    end
                    batch_obj:attachAttribute("OrderValue", mesh)
                else
                    if batch_obj.detachAttribute then
                        batch_obj:detachAttribute("OrderValue")
                    end
                end
            end
            ::continue::
        end
    end

    function br:draw_order_map()
        local om = self.order_map
        if om and G.STRONTIUM_ORDER_MAP ~= nil then
            om.enabled = (G.STRONTIUM_ORDER_MAP ~= false)
        end
        if not (om and om.enabled) then return end

        ensure_order_map_shaders()
        local canvas = ensure_order_map_canvas()
        if not (canvas and om.shader) then return end

        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(om.shader)
        love.graphics.setBlendMode("lighten", "premultiplied")

        -- If the map is downscaled, draw geometry scaled to fit.
        if om.scale and om.scale ~= 1 then
            love.graphics.push()
            love.graphics.scale(om.scale, om.scale)
        end

        local layers = self.registry.layer_order
        for i = 1, #layers do
            local layer = layers[i]
            if not (om.map_layers and om.map_layers[layer]) then
                goto continue
            end

            local batches = self.layer_batches[layer]
            if not batches then
                goto continue
            end

            if self.layer_sorted_dirty[layer] then
                local sorted = self.layer_sorted_keys[layer]
                local n = 0
                for key in pairs(batches) do
                    n = n + 1
                    sorted[n] = key
                end
                for j = n + 1, #sorted do sorted[j] = nil end
                local sort_names = self.layer_sort_name[layer]
                table.sort(sorted, function(a, b)
                    return (sort_names[a] or a) < (sort_names[b] or b)
                end)
                self.layer_sorted_dirty[layer] = false
            end

            local keys = self.layer_sorted_keys[layer]
            for j = 1, #keys do
                local k = keys[j]
                local batch_obj = batches[k]
                if batch_obj and batch_obj:getCount() > 0 then
                    love.graphics.draw(batch_obj, 0, 0)
                end
            end
            ::continue::
        end

        if om.scale and om.scale ~= 1 then
            love.graphics.pop()
        end

        love.graphics.pop()
    end

    -- Bind order map uniforms for shaders that opt in.
    function br:bind_order_map(layer, shader_obj)
        if not (shader_obj and shader_obj.hasUniform) then return end
        local om = self.order_map
        local enabled = om and om.enabled and om.canvas and om.mask_layers and om.mask_layers[layer]

        if shader_obj:hasUniform("order_map_size") then
            if enabled then
                shader_obj:send("order_map_size", { om.logical_width or 0, om.logical_height or 0 })
            else
                shader_obj:send("order_map_size", { 0, 0 })
            end
        end
        if not enabled then return end

        if shader_obj:hasUniform("order_map") then
            shader_obj:send("order_map", om.canvas)
        end
        if shader_obj:hasUniform("order_epsilon") then
            shader_obj:send("order_epsilon", om.epsilon or (1 / 512))
        end
    end
end

return order_map
