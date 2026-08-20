--- Layer shader resolution and ubershader selection.

local shader = {}

local _uniform_cache = setmetatable({}, { __mode = "k" })

function shader.attach(br)
    function br:set_layer_shader(layer, shader_ref)
        if not layer then return end
        self.layer_shaders[layer] = shader_ref
    end

    function br:get_layer_shader(layer)
        local use_instancing = G and G.STRONTIUM_INSTANCING

        -- Fast path: check caches before doing any work
        if use_instancing then
            local cached = self.instancing.cache[layer]
            if cached then return cached end
            -- Only build if not yet attempted (nil means not tried, false means failed)
            if self.layer_uber_enabled[layer] == nil and self.build_instanced_shader then
                local instanced = self:build_instanced_shader(layer)
                if instanced then return instanced end
            end
        else
            local cached = self.ubershader.cache[layer]
            if cached then return cached end
            if self.layer_uber_enabled[layer] == nil and self.build_layer_shader then
                local uber = self:build_layer_shader(layer)
                if uber then return uber end
            end
        end

        -- Fallback to explicit layer shader or order map mask
        local ref = self.layer_shaders[layer]
        if not ref then
            local om = self.order_map
            if om and om.enabled and om.mask_layers and om.mask_layers[layer] then
                if use_instancing then
                    local mask = om.instanced_mask_shader
                    if mask then return mask end
                elseif om.mask_shader then
                    return om.mask_shader
                end
            end
            return nil
        end
        if type(ref) == "string" then
            return (G.SHADERS and G.SHADERS[ref]) or nil
        end
        return ref
    end

    function br:apply_layer_shader(layer)
        local next_shader = self:get_layer_shader(layer)
        if next_shader ~= self.active_shader then
            love.graphics.setShader(next_shader)
            self.active_shader = next_shader
            if next_shader and next_shader.hasUniform then
                if next_shader:hasUniform("time") then
                    next_shader:send("time", (G.TIMERS and G.TIMERS.REAL) or 0)
                end
                self:bind_param_buffer(next_shader)
                if self.bind_order_map then
                    self:bind_order_map(layer, next_shader)
                end
            end
            self.layer_shader_last_key[layer] = nil
        end
        return next_shader
    end

    -- Send atlas or tile data per atlas key when requested.
    function br:send_layer_atlas_uniforms(layer, shader_obj, atlas_key)
        if not (shader_obj and shader_obj.hasUniform) then return end
        local last_key = self.layer_shader_last_key[layer]
        if last_key == atlas_key then return end

        local cache = _uniform_cache[shader_obj]
        if not cache then
            cache = {
                needs_atlas = shader_obj:hasUniform("atlas_size"),
                needs_tile = shader_obj:hasUniform("tile_size"),
            }
            _uniform_cache[shader_obj] = cache
        end

        local needs_atlas = cache.needs_atlas
        local needs_tile = cache.needs_tile
        if not (needs_atlas or needs_tile) then
            self.layer_shader_last_key[layer] = atlas_key
            return
        end

        local layer_dims = self.layer_atlas_dims[layer]
        local dims = layer_dims and layer_dims[atlas_key] or nil
        if not dims then
            local layer_images = self.layer_atlas_image[layer]
            local layer_tiles = self.layer_atlas_tile[layer]
            local img = layer_images and layer_images[atlas_key] or nil
            local tile = layer_tiles and layer_tiles[atlas_key] or nil
            if img and img.getDimensions then
                local w, h = img:getDimensions()
                dims = {
                    w = w,
                    h = h,
                    px = math.max(1, (tile and tile[1]) or 1),
                    py = math.max(1, (tile and tile[2]) or 1),
                }
            else
                dims = { w = 1, h = 1, px = 1, py = 1 }
            end

            dims.atlas = { dims.w, dims.h }
            dims.tile = { dims.px, dims.py }
            if layer_dims then
                layer_dims[atlas_key] = dims
            end
        end

        if needs_atlas then
            shader_obj:send("atlas_size", dims.atlas)
        end
        if needs_tile then
            shader_obj:send("tile_size", dims.tile)
        end

        self.layer_shader_last_key[layer] = atlas_key
    end

    -- Cleanup to avoid bleeding over other passes
    function br:clear_layer_shader()
        if self.active_shader then
            love.graphics.setShader()
            self.active_shader = nil
        end
    end
end

return shader
