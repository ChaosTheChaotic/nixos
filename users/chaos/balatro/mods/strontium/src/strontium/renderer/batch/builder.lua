--- Batch builder: encode effect colors, compute sprite params, build batches.

local state = require('strontium.renderer.state')
local util = require('strontium.renderer.util')

local builder = {}

-- GC_HACK: Reusable tables to reduce frame allocs.
local _effect_color = { 0, 0, 0, 0 }
local _zero_color = { 0, 0, 0, 0 }
local _draw_params = {
    atlas = nil, quad = nil,
    x = 0, y = 0, r = 0,
    sx = 1, sy = 1, ox = 0, oy = 0,
}

function builder.attach(br)
    -- Encode effect metadata into vertex color (effect_id + param_index).
    -- Returns a reused table, make sure not to store this as a reference.
    function br:encode_effect_color(intent)
        if not intent then return _zero_color end
        local effect_id = intent.effect_id or 0
        local param_index = intent.param_index or 0

        local eff_lo = effect_id % 256
        local eff_hi = math.floor(effect_id / 256) % 256
        local param_lo = param_index % 256
        local param_hi = math.floor(param_index / 256) % 256

        _effect_color[1] = eff_lo / 255
        _effect_color[2] = eff_hi / 255
        _effect_color[3] = param_lo / 255
        _effect_color[4] = param_hi / 255

        return _effect_color
    end

    local function move_layer_stat(stats_layers, layer, from_key, to_key)
        if not stats_layers then return end
        if not stats_layers[layer] then return end

        local entry = stats_layers[layer]
        local from_val = entry[from_key]

        if from_val and from_val > 0 then
            entry[from_key] = from_val - 1
        end
        entry[to_key] = (entry[to_key] or 0) + 1
    end

    -- Get or create a SpriteBatch for a layer/atlas pair.
    function br:get_batch(layer, atlas)
        if not atlas or not atlas.image then return nil end
        state.ensure_layer_tables(self, layer)

        local key = atlas.name or tostring(atlas.image)
        local layer_tab = self.layer_batches[layer]
        local batch_obj = layer_tab[key]

        -- Size batches avoid realloc when the card count grows.
        local desired = self.desired_batch_size or 512
        local prev_img = self.layer_atlas_image[layer][key]
        local prev_tile = self.layer_atlas_tile[layer][key]
        local new_px = atlas.px or 0
        local new_py = atlas.py or 0

        -- Rebuild batch if atlas or tile size changes.
        local atlas_changed = false
        if prev_img and prev_img ~= atlas.image then
            atlas_changed = true
        end
        if prev_tile and (prev_tile[1] ~= new_px or prev_tile[2] ~= new_py) then
            atlas_changed = true
        end
        if batch_obj and batch_obj.getTexture and batch_obj:getTexture() ~= atlas.image then
            atlas_changed = true
        end

        local needs_recreate = (not batch_obj) or atlas_changed
        if not needs_recreate and desired and batch_obj.getBufferSize and batch_obj:getBufferSize() < desired then
            needs_recreate = true
        end

        if needs_recreate then
            batch_obj = love.graphics.newSpriteBatch(atlas.image, desired, "stream")
            layer_tab[key] = batch_obj
            self.layer_sorted_dirty[layer] = true
            self.layer_atlas_dims[layer][key] = false
        end

        local last_tab = self.layer_last_cleared[layer]
        if last_tab[key] ~= self.frame_id then
            batch_obj:clear()
            last_tab[key] = self.frame_id
        end

        self.layer_sort_name[layer][key] = self.layer_sort_name[layer][key] or (atlas.name or key)
        self.layer_atlas_image[layer][key] = atlas.image

        local tile = self.layer_atlas_tile[layer][key]
        if tile then
            tile[1], tile[2] = new_px, new_py
        else
            self.layer_atlas_tile[layer][key] = { new_px, new_py }
        end

        return batch_obj
    end

    -- Compute transforms for a sprite intent (position, scale, rotation).
    function br:compute_draw_params(intent)
        local sprite = intent.sprite_ref
        if not sprite or not sprite.states or not sprite.states.visible then return nil end
        local atlas = intent.atlas or sprite.atlas
        local quad = intent.quad or sprite.sprite
        if not (atlas and atlas.image and quad) then return nil end

        -- Use the anchor sprite for overlay alignment.
        local ref_sprite = intent.relative_to or sprite
        local vt = ref_sprite.VT
        if not (vt and vt.w and vt.h and vt.scale) then return nil end

        local scale = G.TILESCALE * G.TILESIZE

        -- Parallax offsets on the sprite or its parent must be folded into world space.
        local px = (ref_sprite.layered_parallax and ref_sprite.layered_parallax.x) or
            (ref_sprite.parent and ref_sprite.parent.layered_parallax and ref_sprite.parent.layered_parallax.x) or 0
        local py = (ref_sprite.layered_parallax and ref_sprite.layered_parallax.y) or
            (ref_sprite.parent and ref_sprite.parent.layered_parallax and ref_sprite.parent.layered_parallax.y) or 0

        local x = (vt.x + vt.w / 2 + px) * scale
        local y = (vt.y + vt.h / 2 + py) * scale
        local r = vt.r or 0

        -- Apply nested transforms to attempt to match vanilla rendering.
        x, y, r = util.apply_all_container_transforms(ref_sprite, x, y, r)

        -- Use sprite scale as scale denominator, otherwise use tile size.
        local denom_x = (sprite.scale and sprite.scale.x) or atlas.px
        local denom_y = (sprite.scale and sprite.scale.y) or atlas.py
        if not denom_x or not denom_y or denom_x == 0 or denom_y == 0 then
            return nil
        end

        local vt_scale = vt.scale
        local tw = (ref_sprite.T and ref_sprite.T.w) or vt.w
        local th = (ref_sprite.T and ref_sprite.T.h) or vt.h

        -- Attempt to compensate for sprite-to-texture size diffs.
        local pinch_x = (tw and tw ~= 0) and (vt.w / tw) or 1
        local pinch_y = (th and th ~= 0) and (vt.h / th) or 1

        local sx = (vt.w * scale * vt_scale * pinch_x) / denom_x
        local sy = (vt.h * scale * vt_scale * pinch_y) / denom_y

        local ox = denom_x / 2
        local oy = denom_y / 2

        -- Optional per-intent transform overrides (for overlays, buttons, etc).
        local override = intent.transform_override
        if override then
            if override.offset_x then x = x + override.offset_x end
            if override.offset_y then y = y + override.offset_y end
            if override.rotate then r = r + override.rotate end

            if override.scale_mult then
                sx = sx * override.scale_mult
                sy = sy * override.scale_mult
            end

            if override.x then x = override.x end
            if override.y then y = override.y end
            if override.r then r = override.r end
            if override.sx then sx = override.sx end
            if override.sy then sy = override.sy end
            if override.ox then ox = override.ox end
            if override.oy then oy = override.oy end
        end

        _draw_params.atlas = atlas
        _draw_params.quad = quad
        _draw_params.x = x
        _draw_params.y = y
        _draw_params.r = r
        _draw_params.sx = sx
        _draw_params.sy = sy
        _draw_params.ox = ox
        _draw_params.oy = oy
        return _draw_params
    end

    -- Convert intents into SpriteBatch entries.
    function br:build_batches()
        -- GC_HACK: Keep batch capacity ahead of current demand to reduce realloc churn.
        self.desired_batch_size = math.max(512, #self.lanes.batch + 64)
        local stats_layers = self.stats and self.stats.layers or nil

        -- TODO: This is dogshit, make it better.
        for i = 1, #self.lanes.batch do
            local intent = self.lanes.batch[i]
            if not intent then goto continue end

            local layer = intent.layer or "center"
            if self.layer_uber_enabled and self.layer_uber_enabled[layer] == nil and self.build_layer_shader then
                self:build_layer_shader(layer)
            end

            local draw = self:compute_draw_params(intent)
            if not draw then
                self.lanes.immediate[#self.lanes.immediate + 1] = intent
                self.stats.immediate = self.stats.immediate + 1
                move_layer_stat(stats_layers, layer, "batch", "immediate")
                goto continue
            end

            local batch_obj = self:get_batch(layer, draw.atlas)
            if not batch_obj then
                self.lanes.immediate[#self.lanes.immediate + 1] = intent
                self.stats.immediate = self.stats.immediate + 1
                move_layer_stat(stats_layers, layer, "batch", "immediate")
                goto continue
            end

            local color = intent.color
            if (not G or G.STRONTIUM_UBERSHADER ~= false) and self.layer_uber_enabled and self.layer_uber_enabled[layer] then
                color = self:encode_effect_color(intent)
            end

            if color then
                batch_obj:setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            else
                batch_obj:setColor(1, 1, 1, 1)
            end

            batch_obj:add(draw.quad, draw.x, draw.y, draw.r, draw.sx, draw.sy, draw.ox, draw.oy)
            if self.order_map and self.order_map.enabled then
                local key = draw.atlas.name or tostring(draw.atlas.image)
                local layer_values = self.layer_order_values[layer]
                local list = layer_values[key]
                if not list then
                    list = {}
                    layer_values[key] = list
                end
                local n = #list + 1
                list[n] = (intent.order_value ~= nil) and intent.order_value or -1
            end
            ::continue::
        end
    end
end

return builder
