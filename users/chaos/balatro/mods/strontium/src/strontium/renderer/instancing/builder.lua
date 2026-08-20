--- Instanced batch builder: build per-atlas instance buffers.

local state = require('strontium.renderer.state')
local buffer = require('strontium.renderer.buffer')
local builder = {}

local HAS_FFI = buffer.available()

local GEOMETRY_FORMAT = {
    { "VertexPosition", "float", 2 },
    { "VertexTexCoord", "float", 2 },
}

local GEOMETRY_VERTS = {
    { 0, 0, 0, 0 },
    { 1, 0, 1, 0 },
    { 1, 1, 1, 1 },
    { 0, 0, 0, 0 },
    { 1, 1, 1, 1 },
    { 0, 1, 0, 1 },
}

local INSTANCE_FORMAT = {
    { "InstancePos", "float", 2 },
    { "InstanceScale", "float", 2 },
    { "InstanceRot", "float", 1 },
    { "InstanceOrigin", "float", 2 },
    { "InstanceSize", "float", 2 },
    { "InstanceUV", "float", 4 },
    { "InstanceColor", "float", 4 },
    { "OrderValue", "float", 1 },
}

local INSTANCE_FLOATS = 18

local DEFAULT_COLOR = { 1, 1, 1, 1 }

-- Pre-allocated vertex row pool to avoid per-frame allocations
local _vertex_pool = {}
local _vertex_pool_size = 0

local function get_vertex_row(index)
    local row = _vertex_pool[index]
    if not row then
        row = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
        _vertex_pool[index] = row
        _vertex_pool_size = index
    end
    return row
end

local function create_geometry_mesh()
    return love.graphics.newMesh(GEOMETRY_FORMAT, GEOMETRY_VERTS, "triangles", "static")
end

local function create_instance_mesh(capacity)
    local mesh = love.graphics.newMesh(INSTANCE_FORMAT, capacity, "points", "stream")
    return mesh
end

local function ensure_instance_buffer(batch, capacity)
    if not HAS_FFI then return end
    if not batch.buffer then
        batch.buffer = buffer.new_float()
    end
    if buffer.ensure_float(batch.buffer, capacity, INSTANCE_FLOATS) then
        batch.buffer_ptr = batch.buffer.ptr
    else
        batch.buffer = nil
        batch.buffer_ptr = nil
    end
end

local function attach_instance_attributes(mesh, instance_mesh)
    mesh:attachAttribute("InstancePos", instance_mesh, "perinstance")
    mesh:attachAttribute("InstanceScale", instance_mesh, "perinstance")
    mesh:attachAttribute("InstanceRot", instance_mesh, "perinstance")
    mesh:attachAttribute("InstanceOrigin", instance_mesh, "perinstance")
    mesh:attachAttribute("InstanceSize", instance_mesh, "perinstance")
    mesh:attachAttribute("InstanceUV", instance_mesh, "perinstance")
    mesh:attachAttribute("InstanceColor", instance_mesh, "perinstance")
    mesh:attachAttribute("OrderValue", instance_mesh, "perinstance")
end

-- Cache quad viewport results to avoid repeated method calls
local _quad_cache = setmetatable({}, { __mode = "k" })
local _quad_uv_cache = setmetatable({}, { __mode = "k" })

local function resolve_quad_viewport(quad, atlas)
    if quad then
        local cached = _quad_cache[quad]
        if cached then
            return cached[1], cached[2], cached[3], cached[4], cached[5], cached[6]
        end
        if quad.getViewport then
            local x, y, w, h, sw, sh = quad:getViewport()
            if sw and sh and sw > 0 and sh > 0 then
                _quad_cache[quad] = { x or 0, y or 0, w or 0, h or 0, sw, sh }
                return x or 0, y or 0, w or 0, h or 0, sw, sh
            end
            if atlas and atlas.image and atlas.image.getDimensions then
                local iw, ih = atlas.image:getDimensions()
                _quad_cache[quad] = { x or 0, y or 0, w or 0, h or 0, iw, ih }
                return x or 0, y or 0, w or 0, h or 0, iw, ih
            end
        end
    end
    if atlas and atlas.image and atlas.image.getDimensions then
        local iw, ih = atlas.image:getDimensions()
        return 0, 0, atlas.px or iw, atlas.py or ih, iw, ih
    end
    return 0, 0, 1, 1, 1, 1
end

local function resolve_quad_uv(quad, atlas)
    local cached = _quad_uv_cache[quad]
    local img = atlas and atlas.image or nil
    local px = atlas and atlas.px or 0
    local py = atlas and atlas.py or 0
    if cached and cached.image == img and cached.px == px and cached.py == py then
        return cached
    end

    local qx, qy, qw, qh, sw, sh = resolve_quad_viewport(quad, atlas)
    local inv_sw = sw > 0 and (1 / sw) or 1
    local inv_sh = sh > 0 and (1 / sh) or 1

    cached = {
        image = img,
        px = px,
        py = py,
        qw = qw,
        qh = qh,
        u0 = qx * inv_sw,
        v0 = qy * inv_sh,
        u1 = (qx + qw) * inv_sw,
        v1 = (qy + qh) * inv_sh,
    }
    _quad_uv_cache[quad] = cached
    return cached
end

-- Track lane re-classification in layer stats.
local function move_layer_stat(stats_layers, layer, from_key, to_key)
    if not stats_layers or not stats_layers[layer] then return end

    local entry = stats_layers[layer]
    local from_val = entry[from_key]

    if from_val and from_val > 0 then
        entry[from_key] = from_val - 1
    end
    entry[to_key] = (entry[to_key] or 0) + 1
end

function builder.attach(br)
    function br:get_instance_batch(layer, atlas)
        if not atlas or not atlas.image then return nil end
        state.ensure_instance_tables(self, layer)

        local key = atlas.name or tostring(atlas.image)
        local layer_tab = self.layer_instances[layer]
        local batch = layer_tab[key]

        local desired = self.desired_batch_size or 512
        local prev_img = self.layer_atlas_image[layer][key]
        local prev_tile = self.layer_atlas_tile[layer][key]
        local new_px = atlas.px or 0
        local new_py = atlas.py or 0

        local atlas_changed = false
        if prev_img and prev_img ~= atlas.image then
            atlas_changed = true
        end
        if prev_tile and (prev_tile[1] ~= new_px or prev_tile[2] ~= new_py) then
            atlas_changed = true
        end

        local needs_recreate = (not batch) or atlas_changed
        local needs_texture = needs_recreate
        if not needs_recreate and desired and batch.capacity and batch.capacity < desired then
            needs_recreate = true
        end

        if needs_recreate then
            local mesh = create_geometry_mesh()
            local instance_mesh = create_instance_mesh(desired)
            attach_instance_attributes(mesh, instance_mesh)

            batch = {
                mesh = mesh,
                instance_mesh = instance_mesh,
                vertices = {},
                capacity = desired,
                count = 0,
                texture = nil,
            }
            layer_tab[key] = batch
            self.layer_sorted_dirty[layer] = true
            self.layer_atlas_dims[layer][key] = false
            needs_texture = true
        end

        if batch then
            ensure_instance_buffer(batch, batch.capacity or desired)
        end

        if batch and batch.mesh and batch.mesh.setTexture then
            if needs_texture or batch.texture ~= atlas.image then
                batch.mesh:setTexture(atlas.image)
                batch.texture = atlas.image
            end
        end

        self.layer_sort_name[layer][key] = self.layer_sort_name[layer][key] or (atlas.name or key)
        self.layer_atlas_image[layer][key] = atlas.image
        local tile = self.layer_atlas_tile[layer][key]
        if tile then
            tile[1], tile[2] = new_px, new_py
        else
            self.layer_atlas_tile[layer][key] = { new_px, new_py }
        end

        return batch
    end

    function br:build_instances()
        local batch_lane = self.lanes.batch
        local batch_count = #batch_lane
        self.desired_batch_size = math.max(512, batch_count + 64)
        local stats_layers = self.stats and self.stats.layers or nil
        local immediate_lane = self.lanes.immediate
        local stats = self.stats
        local layer_uber = self.layer_uber_enabled
        local use_uber = not G or G.STRONTIUM_UBERSHADER ~= false

        -- Reset counts
        for _, batches in pairs(self.layer_instances) do
            for _, batch in pairs(batches) do
                batch.count = 0
            end
        end

        -- Single pass: write directly to batch vertex arrays
        for i = 1, batch_count do
            local intent = batch_lane[i]
            if not intent then goto continue end

            local layer = intent.layer or "center"

            local draw = self:compute_draw_params(intent)
            if not draw then
                immediate_lane[#immediate_lane + 1] = intent
                stats.immediate = stats.immediate + 1
                move_layer_stat(stats_layers, layer, "batch", "immediate")
                goto continue
            end

            local batch = self:get_instance_batch(layer, draw.atlas)
            if not batch then
                immediate_lane[#immediate_lane + 1] = intent
                stats.immediate = stats.immediate + 1
                move_layer_stat(stats_layers, layer, "batch", "immediate")
                goto continue
            end

            local color = intent.color
            if not color then
                color = (G and G.C and G.C.WHITE) or DEFAULT_COLOR
            end
            if use_uber and layer_uber and layer_uber[layer] then
                color = self:encode_effect_color(intent)
            end

            local uv = resolve_quad_uv(draw.quad, draw.atlas)

            local idx = batch.count + 1
            batch.count = idx

            if HAS_FFI and batch.buffer_ptr then
                local base = (idx - 1) * INSTANCE_FLOATS
                local ptr = batch.buffer_ptr
                ptr[base + 0] = draw.x
                ptr[base + 1] = draw.y
                ptr[base + 2] = draw.sx
                ptr[base + 3] = draw.sy
                ptr[base + 4] = draw.r or 0
                ptr[base + 5] = draw.ox or 0
                ptr[base + 6] = draw.oy or 0
                ptr[base + 7] = uv.qw
                ptr[base + 8] = uv.qh
                ptr[base + 9] = uv.u0
                ptr[base + 10] = uv.v0
                ptr[base + 11] = uv.u1
                ptr[base + 12] = uv.v1
                ptr[base + 13] = color[1] or 1
                ptr[base + 14] = color[2] or 1
                ptr[base + 15] = color[3] or 1
                ptr[base + 16] = color[4] or 1
                ptr[base + 17] = intent.order_value or -1
            else
                local v = get_vertex_row(idx)
                v[1] = draw.x
                v[2] = draw.y
                v[3] = draw.sx
                v[4] = draw.sy
                v[5] = draw.r or 0
                v[6] = draw.ox or 0
                v[7] = draw.oy or 0
                v[8] = uv.qw
                v[9] = uv.qh
                v[10] = uv.u0
                v[11] = uv.v0
                v[12] = uv.u1
                v[13] = uv.v1
                v[14] = color[1] or 1
                v[15] = color[2] or 1
                v[16] = color[3] or 1
                v[17] = color[4] or 1
                v[18] = intent.order_value or -1

                batch.vertices[idx] = v
            end

            ::continue::
        end

        -- Upload all batches
        for _, batches in pairs(self.layer_instances) do
            for _, batch in pairs(batches) do
                if batch.count > 0 then
                    if HAS_FFI and batch.buffer and batch.buffer.data then
                        batch.instance_mesh:setVertices(batch.buffer.data, 1, batch.count)
                    else
                        batch.instance_mesh:setVertices(batch.vertices, 1, batch.count)
                    end
                end
            end
        end
    end
end

return builder
