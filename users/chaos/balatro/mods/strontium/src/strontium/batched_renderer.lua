-- This is the first prototype renderer. Strontium came after this.
-- It's largely hardcoded and the code itself is quite terrible, but it runs fast.
-- I have left a toggle in the menu to enable this. In vanilla you'll find it to be
-- about 5-10 fps faster than the Strontium renderer. 

local batched_renderer = {}

function batched_renderer.init()
    -- All layer names in draw order
    -- Seals are composited by the shader (no separate layer).
    local all_layers = {'shadow', 'back', 'center', 'front', 'sticker', 'floating'}
    
    local function make_layer_table(default)
        local t = {}
        for _, layer in ipairs(all_layers) do
            t[layer] = type(default) == 'function' and default() or default
        end
        return t
    end
    
    G.BATCHED_RENDERER = {
        stats = { batches = 0, draws_saved = 0, cards_rendered = 0, fallback_cards = 0 },
        frame_id = 0,
        all_layers = all_layers,
        layer_batches = make_layer_table(function() return {} end),
        layer_last_cleared = make_layer_table(function() return {} end),
        layer_sort_name = make_layer_table(function() return {} end),

        -- Cached iteration order to avoid per-frame table churn.
        layer_sorted_keys = make_layer_table(function() return {} end),
        layer_sorted_dirty = make_layer_table(true),

        -- Cache atlas dimensions + tile sizes for shader uniform sends.
        layer_atlas_dims = make_layer_table(function() return {} end),

        -- Reduce redundant shader:send calls when a layer only uses one atlas.
        edition_shader_last_key = make_layer_table(nil),
        
        -- Track cards that need vanilla fallback (dissolving, hovering, etc.)
        fallback_queue = {},
    }
    
    function G.BATCHED_RENDERER:reset_frame()
        self.stats.batches = 0
        self.stats.draws_saved = 0
        self.stats.cards_rendered = 0
        self.stats.shader_switches = 0
        
        -- Clear batches at frame start to prevent ghost cards.
        -- Clearing only on access can leave stale sprites for atlases not touched this frame.
        self.frame_id = (self.frame_id or 0) + 1
        for layer, batches in pairs(self.layer_batches) do
            for key, batch in pairs(batches) do
                if batch and batch.clear then
                    batch:clear()
                end
                if self.layer_last_cleared[layer] then
                    self.layer_last_cleared[layer][key] = self.frame_id
                end
            end
        end
    end
    
    function G.BATCHED_RENDERER:get_batch(layer, atlas)
        if not atlas or not atlas.image then return nil end
        if not self.layer_batches[layer] then return nil end

        local key = atlas.name or tostring(atlas.image)
        local layer_tab = self.layer_batches[layer]
        local batch = layer_tab[key]

        -- Cache atlas metadata for shader reconstruction of sprite-local UVs.
        -- Note: SpriteBatches are bound to a texture at creation time. If the atlas reloads
        -- (e.g. texture scaling change), we must recreate batches or they will render garbage.
        self.layer_atlas_image = self.layer_atlas_image or {}
        self.layer_atlas_tile = self.layer_atlas_tile or {}
        self.layer_atlas_image[layer] = self.layer_atlas_image[layer] or {}
        self.layer_atlas_tile[layer] = self.layer_atlas_tile[layer] or {}

        local desired = self.desired_batch_size or 2000
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
        if batch and batch.getTexture and batch:getTexture() ~= atlas.image then
            atlas_changed = true
        end

        local needs_recreate = (not batch) or atlas_changed
        if not needs_recreate and desired and batch.getBufferSize and batch:getBufferSize() < desired then
            needs_recreate = true
        end

        if needs_recreate then
            batch = love.graphics.newSpriteBatch(atlas.image, desired, "stream")
            layer_tab[key] = batch
            if self.layer_last_cleared[layer] then
                self.layer_last_cleared[layer][key] = nil
            end
            self.layer_sorted_dirty[layer] = true
            if self.layer_atlas_dims and self.layer_atlas_dims[layer] then
                self.layer_atlas_dims[layer][key] = false
            end
        end

        local last_tab = self.layer_last_cleared[layer]
        if last_tab[key] ~= self.frame_id then
            batch:clear()
            last_tab[key] = self.frame_id
        end

        self.layer_sort_name[layer][key] = self.layer_sort_name[layer][key] or (atlas.name or key)

        self.layer_atlas_image[layer][key] = atlas.image
        local tile = self.layer_atlas_tile[layer][key]
        if tile then
            tile[1], tile[2] = new_px, new_py
        else
            self.layer_atlas_tile[layer][key] = {new_px, new_py}
        end

        return batch
    end
    
    function G.BATCHED_RENDERER:draw_layer(layer)
        local count = 0
        if self.layer_batches[layer] then
            local use_editions = (G.BATCHED_EDITION_INTEGRATED and (layer == 'center' or layer == 'front') and G.SHADERS and G.SHADERS['edition_integrated'])
            local shader = use_editions and G.SHADERS['edition_integrated'] or nil
            if shader then
                shader:send('time', G.TIMERS.REAL)
                love.graphics.setShader(shader)
            end

            -- Build sorted key list only when new atlases appear.
            if self.layer_sorted_dirty[layer] then
                local sorted = {}
                for key in pairs(self.layer_batches[layer]) do
                    sorted[#sorted+1] = key
                end
                table.sort(sorted, function(a, b)
                    return (self.layer_sort_name[layer][a] or a) < (self.layer_sort_name[layer][b] or b)
                end)
                self.layer_sorted_keys[layer] = sorted
                self.layer_sorted_dirty[layer] = false
            end

            local keys = self.layer_sorted_keys[layer]
            local last_key = shader and self.edition_shader_last_key[layer] or nil

            for i = 1, #keys do
                local k = keys[i]
                local batch = self.layer_batches[layer][k]
                if batch and batch:getCount() > 0 then
                    if shader and k ~= last_key then
                        -- Lazy cache of atlas dimensions.
                        local dims = self.layer_atlas_dims[layer][k]
                        if not dims then
                            local img = self.layer_atlas_image and self.layer_atlas_image[layer] and self.layer_atlas_image[layer][k]
                            if img and img.getDimensions then
                                local w, h = img:getDimensions()
                                local tile = self.layer_atlas_tile and self.layer_atlas_tile[layer] and self.layer_atlas_tile[layer][k]
                                local px = (tile and tile[1]) or 0
                                local py = (tile and tile[2]) or 0
                                dims = {w = w, h = h, px = math.max(1, px), py = math.max(1, py)}
                            else
                                dims = {w = 1, h = 1, px = 1, py = 1}
                            end
                            self.layer_atlas_dims[layer][k] = dims
                        end

                        shader:send('atlas_size', {dims.w, dims.h})
                        shader:send('tile_size', {dims.px, dims.py})
                        last_key = k
                    end

                    love.graphics.draw(batch, 0, 0)
                    count = count + 1
                end
            end

            if shader then
                self.edition_shader_last_key[layer] = last_key
            end

            if shader then
                love.graphics.setShader()
            end
        end
        return count
    end

    function G.BATCHED_RENDERER:draw_all_cards(cards)
        if not cards then return false end
        
        local cards_drawn = 0
        local fallback_count = 0
        local scale = G.TILESCALE * G.TILESIZE

        -- Staged drawhash entries for batched cards.
        -- Controller hover picking scans G.DRAW_HASH from the end, so ordering must match render order.
        local drawhash_queue = {}

        self.fallback_queue = {}

        local approx_cards = #cards
        self.desired_batch_size = math.max(2000, approx_cards + 256)

        local record_renderer = (G.USE_STRONTIUM_RENDERER_RECORD and G.STRONTIUM_RENDERER) or nil
        if record_renderer then
            record_renderer:reset_frame()
        end

        -- Helpers
        
        local function apply_container_transform(obj, x, y, r)
            local container = obj.container
            if not container or container == obj then return x, y, r end
            
            local ct = container.T
            local scale_px = G.TILESCALE * G.TILESIZE
            
            local w2 = (ct.w or 0) * scale_px * 0.5
            local h2 = (ct.h or 0) * scale_px * 0.5
            local cx = (ct.x or 0) * scale_px
            local cy = (ct.y or 0) * scale_px
            local cr = ct.r or 0
            
            -- Match `Node:translate_container()`:
            -- translate(center); rotate(r); translate(-center + pos)
            -- => p' = R * (p - center + pos) + center
            local px = x - w2 + cx
            local py = y - h2 + cy
            
            if cr ~= 0 then
                local cos_r = math.cos(cr)
                local sin_r = math.sin(cr)
                local rx = px * cos_r - py * sin_r
                local ry = px * sin_r + py * cos_r
                px, py = rx, ry
            end
            
            x, y, r = px + w2, py + h2, r + cr
            
            return apply_container_transform(container, x, y, r)
        end

        local function apply_all_container_transforms(obj, x, y, r)
            if not obj then return x, y, r end
            if obj.container then
                return apply_container_transform(obj, x, y, r)
            end
            return apply_all_container_transforms(obj.area or obj.parent, x, y, r)
        end

        local function record_intent(layer, sprite, card, color, transform_override, relative_to)
            if not record_renderer then return end
            record_renderer:emit_intent({
                card = card,
                layer = layer,
                sprite_ref = sprite,
                color = color,
                transform_override = transform_override,
                relative_to = relative_to,
                lane = "batch",
            })
        end
        
        -- Add a sprite to a batch layer with optional edition encoding and seal
        -- seal_alpha: 0=none, 0.25=Gold, 0.5=Purple, 0.75=Red, 1.0=Blue
        local function add_sprite_to_layer(layer, sprite, edition_r, seed_g, seed_b, offset_x, offset_y, seal_alpha, color_override, scale_multiplier, card)
            if not sprite or not sprite.states or not sprite.states.visible then return false end
            if not (sprite.atlas and sprite.atlas.image and sprite.sprite) then return false end
            
            local vt = sprite.VT
            if not (vt and vt.w and vt.h and vt.scale) then return false end

            local batch = self:get_batch(layer, sprite.atlas)
            if not batch then return false end

            local px = (sprite.layered_parallax and sprite.layered_parallax.x) or (sprite.parent and sprite.parent.layered_parallax and sprite.parent.layered_parallax.x) or 0
            local py = (sprite.layered_parallax and sprite.layered_parallax.y) or (sprite.parent and sprite.parent.layered_parallax and sprite.parent.layered_parallax.y) or 0
            
            -- Apply additional offsets (for shadow parallax, etc.)
            px = px + (offset_x or 0)
            py = py + (offset_y or 0)

            local x = (vt.x + vt.w/2 + px) * scale
            local y = (vt.y + vt.h/2 + py) * scale
            local r = vt.r or 0

            x, y, r = apply_all_container_transforms(sprite, x, y, r)

            local qw = sprite.atlas.px
            local qh = sprite.atlas.py
            local denom_x = (sprite.scale and sprite.scale.x) or qw
            local denom_y = (sprite.scale and sprite.scale.y) or qh

            local vt_scale = vt.scale * (scale_multiplier or 1)
            local tw = (sprite.T and sprite.T.w) or vt.w
            local th = (sprite.T and sprite.T.h) or vt.h
            local pinch_x = (tw and tw ~= 0) and (vt.w / tw) or 1
            local pinch_y = (th and th ~= 0) and (vt.h / th) or 1

            local sx = (vt.w * scale * vt_scale * pinch_x) / denom_x
            local sy = (vt.h * scale * vt_scale * pinch_y) / denom_y

            local ox = denom_x / 2
            local oy = denom_y / 2

            local use_meta = (G.BATCHED_EDITION_INTEGRATED and (layer == 'center' or layer == 'front') and G.SHADERS and G.SHADERS['edition_integrated'])
            local actual_seal_alpha = seal_alpha
            if actual_seal_alpha == nil then actual_seal_alpha = 0 end

            if record_renderer then
                local record_color = color_override
                if not record_color and use_meta then
                    record_color = {edition_r or 0, seed_g or 0, seed_b or 0, actual_seal_alpha}
                end

                local override = nil
                if offset_x or offset_y or scale_multiplier then
                    override = {
                        offset_x = offset_x,
                        offset_y = offset_y,
                        scale_mult = scale_multiplier,
                    }
                end

                record_intent(layer, sprite, card, record_color, override, nil)
            end

            if color_override then
                batch:setColor(color_override[1] or 1, color_override[2] or 1, color_override[3] or 1, color_override[4] or 1)
            elseif use_meta then
                -- seal_alpha: 0=no seal, 0.25=Gold, 0.5=Purple, 0.75=Red, 1.0=Blue
                -- Don't use `or` as a fallback here; 0 is a valid value (no seal).
                batch:setColor(edition_r or 0, seed_g or 0, seed_b or 0, actual_seal_alpha)
            else
                batch:setColor(1, 1, 1, 1)
            end
            batch:add(sprite.sprite, x, y, r, sx, sy, ox, oy)
            return true
        end
        
        -- Add a shared sprite (seal/sticker) positioned relative to a card
        local function add_shared_sprite_to_layer(layer, shared_sprite, card)
            if not shared_sprite or not card then return false end
            if not (shared_sprite.atlas and shared_sprite.atlas.image and shared_sprite.sprite) then return false end
            
            -- Use card's center sprite for positioning reference
            local ref_sprite = card.children.center or card.children.back
            if not ref_sprite or not ref_sprite.VT then return false end

            record_intent(layer, shared_sprite, card, nil, nil, ref_sprite)
            
            local vt = ref_sprite.VT
            local batch = self:get_batch(layer, shared_sprite.atlas)
            if not batch then return false end
            
            local px = (ref_sprite.layered_parallax and ref_sprite.layered_parallax.x) or 0
            local py = (ref_sprite.layered_parallax and ref_sprite.layered_parallax.y) or 0
            
            local x = (vt.x + vt.w/2 + px) * scale
            local y = (vt.y + vt.h/2 + py) * scale
            local r = vt.r or 0
            
            x, y, r = apply_all_container_transforms(ref_sprite, x, y, r)
            
            -- Shared sprites use their own scale info
            local qw = shared_sprite.atlas.px
            local qh = shared_sprite.atlas.py
            local denom_x = (shared_sprite.scale and shared_sprite.scale.x) or qw
            local denom_y = (shared_sprite.scale and shared_sprite.scale.y) or qh
            
            local tw = (ref_sprite.T and ref_sprite.T.w) or vt.w
            local th = (ref_sprite.T and ref_sprite.T.h) or vt.h
            local pinch_x = (tw and tw ~= 0) and (vt.w / tw) or 1
            local pinch_y = (th and th ~= 0) and (vt.h / th) or 1

            local sx = (vt.w * scale * vt.scale * pinch_x) / denom_x
            local sy = (vt.h * scale * vt.scale * pinch_y) / denom_y
            
            local ox = denom_x / 2
            local oy = denom_y / 2
            
            batch:setColor(1, 1, 1, 1)
            batch:add(shared_sprite.sprite, x, y, r, sx, sy, ox, oy)
            return true
        end

        -- Card eligibility checks
        
        -- Check if card should skip batching entirely (deck cards, dragging, focused)
        -- These cards use vanilla rendering for proper z-order (focused/dragging drawn last)
        local function is_ui_parented(card)
            local p = card and card.parent
            if not p then return false end
            local mt = getmetatable(p)
            if rawget(_G, 'UIElement') and mt == UIElement then return true end
            if rawget(_G, 'UIBox') and mt == UIBox then return true end
            if p.UIT ~= nil or p.UIBox ~= nil then return true end
            return false
        end

        local function should_skip_card(card)
            if not (card and card.states and card.states.visible and card.children) then return true end
            -- Match vanilla Game:draw card loop: parent-owned cards are drawn by UI, not the main card pass.
            if is_ui_parented(card) then return true end
            -- Skip deck-type areas
            if card.area and card.area.config and card.area.config.type == 'deck' then return true end
            -- Skip discard-type areas (cards positioned at origin or off-screen)
            local dominated_by_discard = card.area and (
                card.area == G.discard or 
                (card.area.config and card.area.config.type == 'discard')
            )
            if dominated_by_discard and not (card.states and card.states.drag and card.states.drag.is) then return true end
            if G.CONTROLLER and G.CONTROLLER.dragging and G.CONTROLLER.dragging.target == card then return true end
            -- Skip focused cards - vanilla draws them last for proper z-ordering
            if G.CONTROLLER and G.CONTROLLER.focused and G.CONTROLLER.focused.target == card then return true end
            return false
        end
        
        -- Seals supported by the shader
        local SUPPORTED_SEALS = { Gold = true, Purple = true, Red = true, Blue = true }
        
        -- Check if a card needs hover/tilt effects (drawn individually with the tilt shader).
        -- Only actively hovered/focused/dragged cards go to `hover_queue`; juice stays batched to
        -- avoid painter-order artifacts when scrubbing across cards.
        local function needs_hover_draw(card)
            if not card.states then return false end
            -- Only actually hovered or focused cards need late draw for proper Z
            if card.states.hover.is or card.states.focus.is then return true end
            -- Dragged cards must be on top
            if G.CONTROLLER and G.CONTROLLER.dragging and G.CONTROLLER.dragging.target == card then return true end
            return false
        end
        
        -- Check if card needs vanilla fallback (dissolving, special effects)
        local function needs_fallback(card)
            -- Dissolving cards (animated burn effect)
            if card.dissolve and card.dissolve > 0 and card.dissolve < 1 then return true end
            
            -- Mod seals not supported by shader (fallback to vanilla for proper rendering)
            if card.seal and not SUPPORTED_SEALS[card.seal] then return true end
            
            -- Undiscovered cards (need animated overlay)
            if card.config and card.config.center then
                local center = card.config.center
                if not (center.discovered or card.bypass_discovery_center) then
                    if center.set == 'Joker' or center.set == 'Tarot' or center.set == 'Spectral' 
                       or center.set == 'Planet' or center.set == 'Voucher' then
                        return true
                    end
                end
            end
            
            -- Soul cards with animated floating sprite
            if card.config and card.config.center and card.config.center.soul_pos then return true end
            
            -- Hologram joker with special effect
            if card.ability and card.ability.name == 'Hologram' then return true end
            
            return false
        end
        
        -- Check if shadow should be drawn for this card
        local function should_draw_shadow(card)
            if card.no_shadow then return false end
            if not (G.SETTINGS and G.SETTINGS.GRAPHICS and G.SETTINGS.GRAPHICS.shadows == 'On') then return false end
            -- Glass Card effect disables shadows
            if card.ability and card.ability.effect == 'Glass Card' then return false end
            -- Greyed/played cards may have shadows disabled
            if card.greyed then return false end
            -- Vanilla doesn't draw shadows in discard/deck (unless dragging).
            if card.area and card.area == G.discard and not (card.states and card.states.drag and card.states.drag.is) then return false end
            if card.area and card.area.config and card.area.config.type == 'deck' and not (card.states and card.states.drag and card.states.drag.is) then return false end
            -- Perf mode disables shadows when many cards
            if G.PERF_MODE and approx_cards >= (G.PERF_MODE_THRESHOLD or 200) then return false end
            return true
        end

        -- Shadow rendering:
        -- Vanilla draws `G.shared_shadow` (center/back sprite) through `dissolve` with `shadow=true`,
        -- which turns it into a black silhouette. We emulate that by tinting black with alpha=0.3.
        
        local function draw_shadow_for_card(card)
            if not should_draw_shadow(card) then return end
            
            -- Determine shadow source: center if front-facing, back otherwise
            local shadow_sprite = (card.sprite_facing == 'front') and card.children.center or card.children.back
            if not shadow_sprite then return end
            
            local area_type = card.area and card.area.config and card.area.config.type
            local is_dragged = (G.CONTROLLER and G.CONTROLLER.dragging and G.CONTROLLER.dragging.target == card) or (card.states and card.states.drag and card.states.drag.is)

            -- Calculate shadow height like vanilla (velocity term intentionally 0'd).
            local shadow_height = (0 * (0.08 + 0.4 * math.sqrt((card.velocity and card.velocity.x or 0) ^ 2)))
            shadow_height = shadow_height + (((card.highlighted and card.area == G.play) or is_dragged) and 0.35 or (area_type == 'title_2') and 0.04 or 0.1)

            -- Apply shadow parallax + shrink like `Sprite:draw_shader('dissolve', shadow_height)`.
            local shadow_parallax_x = -((card.shadow_parrallax and card.shadow_parrallax.x) or 0) * shadow_height
            local shadow_parallax_y = -((card.shadow_parrallax and card.shadow_parrallax.y) or 0) * shadow_height
            local shadow_scale_mult = (1 - 0.2 * shadow_height)

            add_sprite_to_layer("shadow", shadow_sprite, 0, 0, 0, shadow_parallax_x, shadow_parallax_y, nil, {0, 0, 0, 0.3}, shadow_scale_mult, card)
        end

        -- Seals are composited by the `edition_integrated` shader.
        -- Seal type is encoded in alpha: 0=none, 0.25=Gold, 0.5=Purple, 0.75=Red, 1.0=Blue.
        -- If a seal isn't in the base atlas (e.g. modded), the card falls back to vanilla rendering.

        -- Sticker rendering + visibility culling
        
        -- Cache for area visibility calculations (cleared each frame)
        local area_visibility_cache = {}
        
        -- Rough fan-layout culling: returns (fully_visible, sticker_visible).
        -- Based on spacing/card width; tweak with `G.BATCHED_MIN_VISIBLE_RATIO`.
        -- Stickers/seals live in the top-right, so sticker visibility is stricter.
        local function get_visible_card_counts(area)
            if not area or not area.config then return 999, 999 end -- Show all if unknown
            
            if area_visibility_cache[area] then
                return area_visibility_cache[area].fully, area_visibility_cache[area].sticker
            end
            
            local area_type = area.config.type
            if area_type ~= 'joker' and area_type ~= 'consumeable' and area_type ~= 'title_2' 
               and area_type ~= 'hand' then
                area_visibility_cache[area] = { fully = 999, sticker = 999 }
                return 999, 999 -- Non-fan areas show all cards
            end
            
            local card_count = #area.cards
            if card_count <= 2 then 
                area_visibility_cache[area] = { fully = card_count, sticker = card_count }
                return card_count, card_count -- All visible
            end
            
            local area_w = area.T and area.T.w or 6 -- Approximate if unknown
            local card_w = area.card_w or G.CARD_W or 1
            
            local spacing = (area_w - card_w) / (card_count - 1)
            local visible_ratio = spacing / card_w
            
            -- If spacing >= card width, no overlap at all
            if visible_ratio >= 1.0 then
                area_visibility_cache[area] = { fully = card_count, sticker = card_count }
                return card_count, card_count
            end
            
            -- How many cards get editions; below the threshold we only bother on the rightmost.
            local min_visible_ratio = G.BATCHED_MIN_VISIBLE_RATIO or 0.0
            local fully_visible_count = card_count -- Default: all cards get editions
            
            if visible_ratio < min_visible_ratio then
                fully_visible_count = 1
            end
            
            -- Sticker region is ~top-right quarter; treat it as covered when spacing is tight.
            local sticker_visible_count = fully_visible_count
            if visible_ratio < 0.25 then
                sticker_visible_count = 1
            elseif visible_ratio < 0.75 then
                sticker_visible_count = math.max(1, math.ceil(0.25 / (1 - visible_ratio)))
            end
            
            area_visibility_cache[area] = { fully = fully_visible_count, sticker = sticker_visible_count }
            return fully_visible_count, sticker_visible_count
        end
        
        -- Card index within its area (cached when possible).
        local function get_card_area_index(card)
            if not card.area then return nil end
            
            if card._area_index and card.area.cards[card._area_index] == card then
                return card._area_index
            end
            
            local area_cards = card.area.cards
            if not area_cards then return nil end
            for i, c in ipairs(area_cards) do
                if c == card then
                    card._area_index = i
                    return i
                end
            end
            return nil
        end
        
        -- Covered-card culling (disable via `G.BATCHED_CULL_COVERED = false`).
        local function is_card_fully_covered(card)
            if G.BATCHED_CULL_COVERED == false then return false end
            
            if not card.area then return false end
            
            local card_index = get_card_area_index(card)
            if not card_index then return false end
            
            -- Calculate how many rightmost cards are visible
            local fully_visible_count, _ = get_visible_card_counts(card.area)
            local card_count = #card.area.cards
            
            -- Card is fully covered if its position from the right is > fully_visible_count
            local position_from_right = card_count - card_index + 1
            return position_from_right > fully_visible_count
        end
        
        -- Check if a card's sticker/seal region is covered by another card to its right
        -- Uses heuristic based on area geometry instead of per-card overlap detection.
        -- Toggle: set G.BATCHED_CULL_COVERED = false to disable sticker culling
        local function is_sticker_region_covered(card)
            if G.BATCHED_CULL_COVERED == false then return false end
            
            if not card.area then return false end
            
            local card_index = get_card_area_index(card)
            if not card_index then return false end
            
            -- Calculate how many rightmost cards show stickers
            local _, sticker_visible_count = get_visible_card_counts(card.area)
            local card_count = #card.area.cards
            
            -- Card's sticker is covered if its position from the right is > sticker_visible_count
            local position_from_right = card_count - card_index + 1
            return position_from_right > sticker_visible_count
        end
        
        local function draw_stickers_for_card(card)
            -- Skip stickers for cards that are covered by another card
            -- Stickers are in the corner and would appear floating on top otherwise
            if is_sticker_region_covered(card) then return end
            
            -- Eternal sticker
            if card.ability and card.ability.eternal then
                local sticker = G.shared_stickers and G.shared_stickers.eternal
                if sticker then
                    add_shared_sprite_to_layer("sticker", sticker, card)
                end
            end
            
            -- Perishable sticker
            if card.ability and card.ability.perishable then
                local sticker = G.shared_stickers and G.shared_stickers.perishable
                if sticker then
                    add_shared_sprite_to_layer("sticker", sticker, card)
                end
            end
            
            -- Rental sticker
            if card.ability and card.ability.rental then
                local sticker = G.shared_stickers and G.shared_stickers.rental
                if sticker then
                    add_shared_sprite_to_layer("sticker", sticker, card)
                end
            end
            
            -- Run stake stickers (Jokers only)
            if card.sticker_run and G.shared_stickers and G.shared_stickers[card.sticker_run] then
                add_shared_sprite_to_layer("sticker", G.shared_stickers[card.sticker_run], card)
            end
            
            -- Generic stickers
            if card.sticker and G.shared_stickers and G.shared_stickers[card.sticker] then
                add_shared_sprite_to_layer("sticker", G.shared_stickers[card.sticker], card)
            end
        end

        -- Batched card draw
        
        -- Seal type to alpha encoding: 0=none, 0.25=Gold, 0.5=Purple, 0.75=Red, 1.0=Blue
        local SEAL_ALPHA = {
            Gold = 0.25,
            Purple = 0.5,
            Red = 0.75,
            Blue = 1.0,
        }
        
        local function draw_one_card(card)
            draw_shadow_for_card(card)

            -- Check if card's face is covered (skip expensive edition effects)
            local face_covered = is_card_fully_covered(card)

            -- Edition encoding for center/front
            local edition_id_byte = 0
            local seed1_byte = 0
            local seed2_byte = 0

            if card.sprite_facing == 'front' then
                -- Front-facing: draw center and optionally front
                local cid = card.ID or 0
                seed1_byte = (cid * 73 + 17) % 256
                seed2_byte = (cid * 151 + 101) % 256

                -- Only calculate edition encoding if face is visible
                -- This saves GPU shader work for cards behind other cards
                if not face_covered then
                    local is_antimatter = (card.ability and card.ability.name == 'Antimatter' and (card.config and card.config.center) and (card.config.center.discovered or card.bypass_discovery_center))
                    if is_antimatter or (card.edition and card.edition.negative) then
                        edition_id_byte = 255
                    elseif card.edition and card.edition.holo then
                        edition_id_byte = 128
                    elseif card.edition and card.edition.foil then
                        edition_id_byte = 64
                    elseif card.edition and card.edition.polychrome then
                        edition_id_byte = 192
                    end
                end
                
                local edition_r = edition_id_byte / 255
                local seed_g = seed1_byte / 255
                local seed_b = seed2_byte / 255
                
                -- Seal is encoded in alpha on the center sprite (same top-right region as stickers).
                local seal_alpha = 0
                if card.seal and SEAL_ALPHA[card.seal] then
                    if not is_sticker_region_covered(card) then
                        seal_alpha = SEAL_ALPHA[card.seal]
                    end
                end

                add_sprite_to_layer("center", card.children.center, edition_r, seed_g, seed_b, nil, nil, seal_alpha, nil, nil, card)

                if card.children.front and (not card.ability or card.ability.effect ~= 'Stone Card') then
                    add_sprite_to_layer("front", card.children.front, edition_r, seed_g, seed_b, nil, nil, 0, nil, nil, card)
                end
                
                draw_stickers_for_card(card)
            else
                add_sprite_to_layer("back", card.children.back, nil, nil, nil, nil, nil, nil, nil, nil, card)
            end

            drawhash_queue[#drawhash_queue + 1] = card
            cards_drawn = cards_drawn + 1

            return true
        end
        
        -- Overlay draws (unbatched; need shaders)
        
        local function draw_card_overlays(card)
            if not (card and card.states and card.states.visible and card.children) then return end
            
            -- Draw a child with optional shader; `draw_major` matters for dissolve/tilt/etc.
            local function draw_overlay(child, shader_name, ...)
                if not child then return end
                child.role = child.role or {}
                child.role.draw_major = card
                love.graphics.push()
                child:translate_container()
                if shader_name and G.SHADERS and G.SHADERS[shader_name] then
                    child:draw_shader(shader_name, ...)
                else
                    child:draw()
                end
                love.graphics.pop()
            end
            
            if card.debuff and card.children.center then
                draw_overlay(card.children.center, 'debuff')
            end
            
            if card.greyed and card.children.center then
                draw_overlay(card.children.center, 'played')
            end
            
            if card.config and card.config.center and card.config.center.set == 'Voucher' then
                if card.children.center then
                    draw_overlay(card.children.center, 'voucher')
                end
            end
            
            if card.config and card.config.center then
                local set = card.config.center.set
                if set == 'Booster' or set == 'Spectral' then
                    if card.children.center then
                        draw_overlay(card.children.center, 'booster')
                    end
                end
            end
            
            if card.ability and card.ability.name == 'Invisible Joker' then
                if card.children.center then
                    draw_overlay(card.children.center, 'voucher')
                end
            end
            
            -- Gold seal shimmer: vanilla shimmers `G.shared_seals['Gold']` (the seal sprite), not
            -- `card.children.center`. Doing it here via the voucher shader caused Z-order issues,
            -- so it's omitted.
            
            if card.children.floating_sprite then
                draw_overlay(card.children.floating_sprite)
            end
            
            if card.children.soul_parts then
                draw_overlay(card.children.soul_parts)
            end
        end

        -- Card UI draw (buttons, particles, price, etc.)
        
        local function draw_card_ui(card)
            if not (card and card.states and card.states.visible and card.children) then return end
            if card.area and card.area.config and card.area.config.type == 'deck' then return end

            for k, v in pairs(card.children) do
                if v.VT then v.VT.scale = card.VT.scale end
            end

            local function draw_child(child)
                if not child then return end
                love.graphics.push()
                child:translate_container()
                child:draw()
                love.graphics.pop()
            end

            draw_child(card.children.particles)
            draw_child(card.children.price)

            if card.children.buy_button then
                if card.highlighted then
                    card.children.buy_button.states.visible = true
                    draw_child(card.children.buy_button)
                    if card.children.buy_and_use_button then
                        draw_child(card.children.buy_and_use_button)
                    end
                else
                    card.children.buy_button.states.visible = false
                end
            end

            if card.children.use_button and card.highlighted then
                draw_child(card.children.use_button)
            end

            for k, v in pairs(card.children) do
                if k ~= 'focused_ui' and k ~= "front" and k ~= "back" and k ~= "soul_parts" 
                   and k ~= "center" and k ~= 'floating_sprite' and k ~= "shadow"
                   and k ~= "use_button" and k ~= 'buy_button' and k ~= 'buy_and_use_button'
                   and k ~= "debuff" and k ~= 'price' and k ~= 'particles' and k ~= 'h_popup' then
                    draw_child(v)
                end
            end

            if card.area == G.hand and card.children.focused_ui then
                draw_child(card.children.focused_ui)
            end
        end
        
        -- Vanilla fallback draw (dissolving/animated cards)
        
        local function draw_card_vanilla(card)
            if not card then return end
            -- Set flag to bypass the batched renderer early-return in Card:draw
            card._batched_force_draw = true
            love.graphics.push()
            card:translate_container()
            card:draw()
            love.graphics.pop()
            card._batched_force_draw = nil
            -- `card:draw()` already handles UI + DRAW_HASH.
            fallback_count = fallback_count + 1
        end
        
        -- Hover draw (tilt via our shader)
        
        -- Compute tilt_var like vanilla Card:draw does
        local function compute_tilt_var(card)
            card.tilt_var = card.tilt_var or {mx = 0, my = 0, dx = 0, dy = 0, amt = 0}
            local tilt_factor = 0.3
            
            if card.states.focus.is then
                card.tilt_var.mx = G.CONTROLLER.cursor_position.x + (card.tilt_var.dx or 0)*card.T.w*G.TILESCALE*G.TILESIZE
                card.tilt_var.my = G.CONTROLLER.cursor_position.y + (card.tilt_var.dy or 0)*card.T.h*G.TILESCALE*G.TILESIZE
                card.tilt_var.amt = math.abs((card.hover_offset and card.hover_offset.y or 0) + (card.hover_offset and card.hover_offset.x or 0) - 1 + (card.tilt_var.dx or 0) + (card.tilt_var.dy or 0) - 1)*tilt_factor
            elseif card.states.hover.is then
                card.tilt_var.mx = G.CONTROLLER.cursor_position.x
                card.tilt_var.my = G.CONTROLLER.cursor_position.y
                card.tilt_var.amt = math.abs((card.hover_offset and card.hover_offset.y or 0) + (card.hover_offset and card.hover_offset.x or 0) - 1)*tilt_factor
            elseif card.ambient_tilt then
                local tilt_angle = G.TIMERS.REAL*(1.56 + (card.ID/1.14212)%1) + card.ID/1.35122
                card.tilt_var.mx = ((0.5 + 0.5*card.ambient_tilt*math.cos(tilt_angle))*card.VT.w+card.VT.x+(G.ROOM and G.ROOM.T.x or 0))*G.TILESIZE*G.TILESCALE
                card.tilt_var.my = ((0.5 + 0.5*card.ambient_tilt*math.sin(tilt_angle))*card.VT.h+card.VT.y+(G.ROOM and G.ROOM.T.y or 0))*G.TILESIZE*G.TILESCALE
                card.tilt_var.amt = card.ambient_tilt*(0.5+math.cos(tilt_angle))*tilt_factor
            else
                card.tilt_var.amt = 0
            end
        end
        
        -- Clear tilt uniforms (for batched non-hover cards)
        local function clear_tilt_uniforms()
            local shader = G.SHADERS['edition_integrated']
            if shader then
                shader:send('hovering', 0)
            end
        end
        
        -- Direct sprite draw (bypasses `Sprite:draw`)
        
        -- Minimal `Sprite:draw` replacement (optionally relative to another sprite).
        local function draw_sprite_direct(sprite, color, shadow_offset_x, shadow_offset_y, shadow_scale_mult, relative_to, scale_mod, rotate_mod)
            if not sprite or not sprite.atlas or not sprite.atlas.image then return end
            if sprite.states and not sprite.states.visible then return end
            
            if sprite.sprite_pos.x ~= sprite.sprite_pos_copy.x or sprite.sprite_pos.y ~= sprite.sprite_pos_copy.y then
                sprite:set_sprite_pos(sprite.sprite_pos)
            end
            
            shadow_offset_x = shadow_offset_x or 0
            shadow_offset_y = shadow_offset_y or 0
            shadow_scale_mult = shadow_scale_mult or 1
            scale_mod = scale_mod or 0
            rotate_mod = rotate_mod or 0
            
            love.graphics.push()
            
            if relative_to then
                -- Relative draw for stickers/seals.
                local other = relative_to
                local other_VT = other.VT
                local other_T = other.T
                
                love.graphics.scale(G.TILESCALE * G.TILESIZE)
                
                local px = (other.layered_parallax and other.layered_parallax.x) or
                           (other.parent and other.parent.layered_parallax and other.parent.layered_parallax.x) or 0
                local py = (other.layered_parallax and other.layered_parallax.y) or
                           (other.parent and other.parent.layered_parallax and other.parent.layered_parallax.y) or 0
                
                love.graphics.translate(
                    other_VT.x + other_VT.w/2 + shadow_offset_x + px,
                    other_VT.y + other_VT.h/2 + shadow_offset_y + py
                )
                
                if other_VT.r ~= 0 or other.juice or rotate_mod ~= 0 then
                    love.graphics.rotate(other_VT.r + rotate_mod)
                end
                
                local scale = other_VT.scale * shadow_scale_mult * (1 + scale_mod)
                love.graphics.translate(-other_VT.w * scale / 2, -other_VT.h * scale / 2)
                love.graphics.scale(scale)
                
                love.graphics.scale(1 / (other.scale_mag or other_VT.scale))
                
                love.graphics.setColor(color or G.C.WHITE)
                love.graphics.draw(
                    sprite.atlas.image,
                    sprite.sprite,
                    -(other_T.w/2 - other_VT.w/2) * 10,
                    0, 0,
                    other_VT.w / other_T.w,
                    other_VT.h / other_T.h
                )
            else
                local VT = sprite.VT
                local T = sprite.T
                
                love.graphics.scale(G.TILESCALE * G.TILESIZE)
                
                local px = (sprite.layered_parallax and sprite.layered_parallax.x) or
                           (sprite.parent and sprite.parent.layered_parallax and sprite.parent.layered_parallax.x) or 0
                local py = (sprite.layered_parallax and sprite.layered_parallax.y) or
                           (sprite.parent and sprite.parent.layered_parallax and sprite.parent.layered_parallax.y) or 0
                
                love.graphics.translate(
                    VT.x + VT.w/2 + shadow_offset_x + px,
                    VT.y + VT.h/2 + shadow_offset_y + py
                )
                
                if VT.r ~= 0 or sprite.juice then
                    love.graphics.rotate(VT.r)
                end
                
                local scale = VT.scale * shadow_scale_mult
                love.graphics.translate(-VT.w * scale / 2, -VT.h * scale / 2)
                love.graphics.scale(scale)
                
                love.graphics.scale(1 / (sprite.scale.x / VT.w), 1 / (sprite.scale.y / VT.h))
                
                love.graphics.setColor(color or G.C.WHITE)
                love.graphics.draw(
                    sprite.atlas.image,
                    sprite.sprite,
                    0, 0, 0,
                    VT.w / T.w,
                    VT.h / T.h
                )
            end
            
            love.graphics.pop()
        end
        
        -- Set up dissolve shader for tilt effect (shared utility)
        local function setup_dissolve_shader_for_tilt(sprite, card, is_shadow, no_tilt)
            local dissolve_shader = G.SHADERS['dissolve']
            if not dissolve_shader then return end
            
            local mx = (card.tilt_var and card.tilt_var.mx or 0) * (G.CANV_SCALE or 1)
            local my = (card.tilt_var and card.tilt_var.my or 0) * (G.CANV_SCALE or 1)
            local screen_scale = G.TILESCALE * G.TILESIZE * (card.mouse_damping or 1) * (G.CANV_SCALE or 1)
            local hover_tilt = no_tilt and 0 or ((card.hover_tilt or 1) * (card.tilt_var and card.tilt_var.amt or 0))
            
            dissolve_shader:send('mouse_screen_pos', {mx, my})
            dissolve_shader:send('screen_scale', screen_scale)
            dissolve_shader:send('hovering', hover_tilt)
            dissolve_shader:send('dissolve', math.abs(card.dissolve or 0))
            dissolve_shader:send('time', 123.33412 * ((card.ID or 12.5) / 1.14212) % 3000)
            dissolve_shader:send('texture_details', sprite:get_pos_pixel())
            dissolve_shader:send('image_details', sprite:get_image_dims())
            dissolve_shader:send('burn_colour_1', card.dissolve_colours and card.dissolve_colours[1] or G.C.CLEAR)
            dissolve_shader:send('burn_colour_2', card.dissolve_colours and card.dissolve_colours[2] or G.C.CLEAR)
            dissolve_shader:send('shadow', is_shadow or false)
            
            love.graphics.setShader(dissolve_shader)
        end
        
        -- Set up voucher shader for shimmer effects (stickers, gold seal)
        local function setup_voucher_shader(card)
            local voucher_shader = G.SHADERS['voucher']
            if not voucher_shader then return end
            
            local send_val_1 = math.min((card.VT.r or 0) * 3, 1) + (G.TIMERS.REAL or 0) / 28 + 
                              (card.juice and card.juice.r * 20 or 0) + (card.tilt_var and card.tilt_var.amt or 0)
            local send_val_2 = G.TIMERS.REAL or 0
            
            local mx = (card.tilt_var and card.tilt_var.mx or 0) * (G.CANV_SCALE or 1)
            local my = (card.tilt_var and card.tilt_var.my or 0) * (G.CANV_SCALE or 1)
            local screen_scale = G.TILESCALE * G.TILESIZE * (card.mouse_damping or 1) * (G.CANV_SCALE or 1)
            local hover_tilt = (card.hover_tilt or 1) * (card.tilt_var and card.tilt_var.amt or 0)
            
            voucher_shader:send('mouse_screen_pos', {mx, my})
            voucher_shader:send('screen_scale', screen_scale)
            voucher_shader:send('hovering', hover_tilt)
            voucher_shader:send('voucher', {send_val_1, send_val_2})
            
            love.graphics.setShader(voucher_shader)
        end
        
        -- Stickers need dissolve (tilt) + voucher (shimmer).
        local function draw_sticker_direct(sticker, card, center_sprite)
            if not sticker or not sticker.atlas or not sticker.atlas.image then return end
            if sticker.states and not sticker.states.visible then return end
            
            if sticker.sprite_pos.x ~= sticker.sprite_pos_copy.x or sticker.sprite_pos.y ~= sticker.sprite_pos_copy.y then
                sticker:set_sprite_pos(sticker.sprite_pos)
            end
            
            setup_dissolve_shader_for_tilt(sticker, card, false, false)
            draw_sprite_direct(sticker, G.C.WHITE, 0, 0, 1, center_sprite)
            
            setup_voucher_shader(card)
            draw_sprite_direct(sticker, G.C.WHITE, 0, 0, 1, center_sprite)
            
            love.graphics.setShader()
        end
        
        -- Seals, drawn like stickers (relative to the center sprite).
        local function draw_seal_direct(seal_name, card, center_sprite)
            if not seal_name or not G.shared_seals or not G.shared_seals[seal_name] then return end
            local seal_sprite = G.shared_seals[seal_name]
            
            if not seal_sprite or not seal_sprite.atlas then return end
            
            if seal_sprite.sprite_pos.x ~= seal_sprite.sprite_pos_copy.x or seal_sprite.sprite_pos.y ~= seal_sprite.sprite_pos_copy.y then
                seal_sprite:set_sprite_pos(seal_sprite.sprite_pos)
            end
            
            setup_dissolve_shader_for_tilt(seal_sprite, card, false, false)
            draw_sprite_direct(seal_sprite, G.C.WHITE, 0, 0, 1, center_sprite)
            
            -- Gold seal gets voucher shimmer
            if seal_name == 'Gold' then
                setup_voucher_shader(card)
                draw_sprite_direct(seal_sprite, G.C.WHITE, 0, 0, 1, center_sprite)
            end
            
            love.graphics.setShader()
        end
        
        -- Hover/tilt draw path (direct `love.graphics` calls; bypasses vanilla draw code).
        local function draw_card_hover(card)
            if not card then return end
            
            -- Compute and set tilt uniforms
            compute_tilt_var(card)
            
            local shader = G.SHADERS['edition_integrated']
            
            -- Calculate tilt values for our shader
            local hover_tilt = (card.hover_tilt or 1) * (card.tilt_var and card.tilt_var.amt or 0)
            local mx = (card.tilt_var and card.tilt_var.mx or 0) * (G.CANV_SCALE or 1)
            local my = (card.tilt_var and card.tilt_var.my or 0) * (G.CANV_SCALE or 1)
            local screen_scale = G.TILESCALE * G.TILESIZE * (card.mouse_damping or 1) * (G.CANV_SCALE or 1)
            
            -- Container transform (replicating Node:translate_container inline)
            love.graphics.push()
            if card.container and card.container ~= card then
                local ct = card.container.T
                local scale = G.TILESCALE * G.TILESIZE
                love.graphics.translate(ct.w * scale * 0.5, ct.h * scale * 0.5)
                love.graphics.rotate(ct.r)
                love.graphics.translate(
                    -ct.w * scale * 0.5 + ct.x * scale,
                    -ct.h * scale * 0.5 + ct.y * scale
                )
            end
            
            -- Draw shadow with tilt
            if should_draw_shadow(card) then
                local shadow_sprite = (card.sprite_facing == 'front') and card.children.center or card.children.back
                if shadow_sprite and shadow_sprite.atlas then
                    local drag_is = card.states and card.states.drag and card.states.drag.is
                    local shadow_height = (((card.highlighted and card.area == G.play) or drag_is) and 0.35) or 
                                         (card.area and card.area.config and card.area.config.type == 'title_2' and 0.04) or 0.1
                    
                    -- Use dissolve shader for shadow
                    local dissolve_shader = G.SHADERS['dissolve']
                    if dissolve_shader then
                        dissolve_shader:send('mouse_screen_pos', {mx, my})
                        dissolve_shader:send('screen_scale', screen_scale)
                        dissolve_shader:send('hovering', 0) -- Shadow doesn't tilt
                        dissolve_shader:send('dissolve', 0)
                        dissolve_shader:send('time', 123.33412 * ((card.ID or 12.5) / 1.14212) % 3000)
                        dissolve_shader:send('texture_details', shadow_sprite:get_pos_pixel())
                        dissolve_shader:send('image_details', shadow_sprite:get_image_dims())
                        dissolve_shader:send('burn_colour_1', G.C.CLEAR)
                        dissolve_shader:send('burn_colour_2', G.C.CLEAR)
                        dissolve_shader:send('shadow', true)
                        love.graphics.setShader(dissolve_shader)
                    end
                    
                    -- Calculate shadow parallax offset
                    local spx = card.shadow_parrallax and card.shadow_parrallax.x or 0
                    local spy = card.shadow_parrallax and card.shadow_parrallax.y or 0
                    local shadow_offset_x = -spx * shadow_height
                    local shadow_offset_y = -spy * shadow_height
                    local shadow_scale = 1 - 0.2 * shadow_height
                    
                    draw_sprite_direct(shadow_sprite, G.C.WHITE, shadow_offset_x, shadow_offset_y, shadow_scale)
                    love.graphics.setShader()
                end
            end
            
            -- Draw card body with edition shader (which has tilt)
            if shader then
                shader:send('time', G.TIMERS.REAL or 0)
                shader:send('hovering', hover_tilt)
                shader:send('mouse_screen_pos', {mx, my})
                shader:send('screen_scale', screen_scale)
                love.graphics.setShader(shader)
            end
            
            -- Encode edition (seals are drawn separately via `G.shared_seals`).
            local edition_r, seed_g, seed_b = 0, 0, 0
            
            if card.sprite_facing == 'front' then
                local cid = card.ID or 0
                seed_g = ((cid * 73 + 17) % 256) / 255
                seed_b = ((cid * 151 + 101) % 256) / 255
                
                local is_antimatter = (card.ability and card.ability.name == 'Antimatter' and card.config and card.config.center and (card.config.center.discovered or card.bypass_discovery_center))
                if is_antimatter or (card.edition and card.edition.negative) then
                    edition_r = 1
                elseif card.edition and card.edition.holo then
                    edition_r = 128/255
                elseif card.edition and card.edition.foil then
                    edition_r = 64/255
                elseif card.edition and card.edition.polychrome then
                    edition_r = 192/255
                end
                
                -- Send atlas info (even though no seal encoding, shader might need it)
                if card.children.center and card.children.center.atlas then
                    local atlas = card.children.center.atlas
                    local w, h = atlas.image:getDimensions()
                    shader:send('atlas_size', {w, h})
                    shader:send('tile_size', {atlas.px or 71, atlas.py or 95})
                end
                
        -- Draw center directly (seal_alpha=0; seals are composited)
                if card.children.center then
                    draw_sprite_direct(card.children.center, {edition_r, seed_g, seed_b, 0})
                end
                
                -- Draw front directly
                if card.children.front and (not card.ability or card.ability.effect ~= 'Stone Card') then
                    draw_sprite_direct(card.children.front, {edition_r, seed_g, seed_b, 0})
                end
            else
                -- Back facing
                if card.children.back then
                    draw_sprite_direct(card.children.back, {0, 0, 0, 0})
                end
            end
            
            love.graphics.setShader()
            love.graphics.setColor(1, 1, 1, 1)
            
            -- Draw stickers and seals directly (relative to center sprite)
            if card.sprite_facing == 'front' and card.children.center then
                local center = card.children.center
                
                -- Draw seal first (vanilla draws seals before stickers)
                if card.seal then
                    draw_seal_direct(card.seal, card, center)
                end
                
                -- Draw stickers
                if card.ability and card.ability.eternal and G.shared_sticker_eternal then
                    draw_sticker_direct(G.shared_sticker_eternal, card, center)
                end
                if card.ability and card.ability.perishable and G.shared_sticker_perishable then
                    draw_sticker_direct(G.shared_sticker_perishable, card, center)
                end
                if card.ability and card.ability.rental and G.shared_sticker_rental then
                    draw_sticker_direct(G.shared_sticker_rental, card, center)
                end
                if card.sticker and G.shared_stickers and G.shared_stickers[card.sticker] then
                    draw_sticker_direct(G.shared_stickers[card.sticker], card, center)
                end
                if card.sticker_run and G.shared_stickers and G.shared_stickers[card.sticker_run] and G.SETTINGS.run_stake_stickers then
                    draw_sticker_direct(G.shared_stickers[card.sticker_run], card, center)
                end
            end
            
            love.graphics.pop()
            
            draw_card_overlays(card)
            
            if _G.add_to_drawhash then _G.add_to_drawhash(card) end
            
            clear_tilt_uniforms()
            
            cards_drawn = cards_drawn + 1
        end

        -- Main draw loop
        
        for k in pairs(area_visibility_cache) do area_visibility_cache[k] = nil end
        
        local batch_queue = {}
        local highlighted_queue = {}
        local hover_queue = {}
        local fallback_queue = {}
        local ui_queue = {}
        local overlay_queue = {}

        local function process_cards(card_list)
            if not card_list then return end
            local iter = (type(card_list) == 'table' and #card_list > 0) and ipairs or pairs
            for _, card in iter(card_list) do
                if not should_skip_card(card) then
                    local is_fallback = needs_fallback(card)
                    local is_hover = needs_hover_draw(card)
                    
                    if is_fallback then
                        fallback_queue[#fallback_queue + 1] = card
                        -- `draw_card_vanilla` handles UI + DRAW_HASH for fallback cards.
                    elseif is_hover then
                        hover_queue[#hover_queue + 1] = card
                        -- Hover cards have their own draw path with tilt
                        ui_queue[#ui_queue + 1] = card
                    else
                        -- Normal batched card
                        local area_type = card.area and card.area.config and card.area.config.type
                        if (area_type == 'joker' or area_type == 'consumeable' or area_type == 'shop' or area_type == 'title_2') and card.highlighted then
                            highlighted_queue[#highlighted_queue + 1] = card
                        else
                            batch_queue[#batch_queue + 1] = card
                        end
                        ui_queue[#ui_queue + 1] = card
                    end
                    
                    -- Check if card needs overlay draws (batched cards only - hover/fallback handle their own)
                    -- Note: is_card_fully_covered check is done in draw_one_card to skip edition effects
                    if not is_fallback and not is_hover and (card.debuff or card.greyed or card.seal == 'Gold' 
                       or (card.config and card.config.center and (card.config.center.set == 'Voucher' or card.config.center.set == 'Booster' or card.config.center.set == 'Spectral'))
                       or (card.ability and card.ability.name == 'Invisible Joker')
                       or card.children.floating_sprite or card.children.soul_parts) then
                        overlay_queue[#overlay_queue + 1] = card
                    end
                end
            end
        end
        
        process_cards(cards)

        -- Sort by X for painter order in fan layouts; disable via `G.BATCHED_X_SORT = false`.
        local function sort_by_x(a, b)
            local ax = a.VT and a.VT.x or (a.T and a.T.x or 0)
            local bx = b.VT and b.VT.x or (b.T and b.T.x or 0)
            return ax < bx
        end
        if G.BATCHED_X_SORT ~= false then
            table.sort(batch_queue, sort_by_x)
            table.sort(highlighted_queue, sort_by_x)
        end

        for i = 1, #batch_queue do
            draw_one_card(batch_queue[i])
        end
        for i = 1, #highlighted_queue do
            draw_one_card(highlighted_queue[i])
        end
        
        love.graphics.setShader()
        love.graphics.setColor(1, 1, 1, 1)
        
        local batch_count = 0
        batch_count = batch_count + self:draw_layer("shadow")
        batch_count = batch_count + self:draw_layer("back")
        batch_count = batch_count + self:draw_layer("center")
        batch_count = batch_count + self:draw_layer("front")
        batch_count = batch_count + self:draw_layer("sticker")
        batch_count = batch_count + self:draw_layer("floating")

        -- Keep DRAW_HASH order consistent with render order for controller hover picking.
        if G.BATCHED_X_SORT ~= false then
            table.sort(drawhash_queue, sort_by_x)
        end
        
        for i = 1, #drawhash_queue do
            if _G.add_to_drawhash then _G.add_to_drawhash(drawhash_queue[i]) end
        end
        
        if G.BATCHED_X_SORT ~= false then
            table.sort(overlay_queue, sort_by_x)
            table.sort(hover_queue, sort_by_x)
            table.sort(fallback_queue, sort_by_x)
            table.sort(ui_queue, sort_by_x)
        end
        
        for i = 1, #overlay_queue do
            draw_card_overlays(overlay_queue[i])
        end
        
        for i = 1, #hover_queue do
            draw_card_hover(hover_queue[i])
        end
        
        for i = 1, #fallback_queue do
            draw_card_vanilla(fallback_queue[i])
        end

        for i = 1, #ui_queue do
            draw_card_ui(ui_queue[i])
        end

        self.stats.batches = batch_count
        self.stats.cards_rendered = cards_drawn
        self.stats.fallback_cards = fallback_count
        self.stats.hover_cards = #hover_queue

        if record_renderer then
            record_renderer:classify_intents()
            record_renderer:pack_params()
        end
        return cards_drawn > 0
    end
end

return batched_renderer
