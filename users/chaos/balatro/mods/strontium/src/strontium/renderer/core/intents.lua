--- Intent processing: normalization, resolution, lane classification

local util = require('strontium.renderer.util')

local intents = {}

-- GC_HACK: Reusable color table for edition encoding
local _edition_color = { 0, 0, 0, 0 }

-- GC_HACK: Reusable buffer for group_key parts
local _group_key_parts = {}
local _group_key_sep = "|"

local function draw_ui_node(_, intent)
    local node = intent and intent.ui_ref
    if not node then return end
    if node.states and node.states.visible == false then return end
    love.graphics.push()
    node:translate_container()
    node:draw()
    love.graphics.pop()
end

local function normalize_intent_fields(intent)
    if intent.sprite_ref == nil and intent.sprite ~= nil then
        intent.sprite_ref = intent.sprite
    end
    if intent.effect_key == nil and intent.effect ~= nil then
        intent.effect_key = intent.effect
    end
    if intent.lane == nil and intent.mode ~= nil then
        intent.lane = intent.mode
    end
    if intent.transform_override == nil and intent.transform ~= nil then
        intent.transform_override = intent.transform
    end
    if intent.overlay_key == nil and intent.overlay ~= nil then
        intent.overlay_key = intent.overlay
    end
end

local function effect_priority(entry)
    if not entry then return 0 end
    local module = entry._module
    return (module and module.priority) or 0
end

local function module_supports_layer(module, layer)
    if not module then return false end
    if module.layer == nil and module.layers == nil then return true end
    if module.layer == layer then return true end
    local layers = module.layers
    if layers then
        if layers[layer] then return true end
        for i = 1, #layers do
            if layers[i] == layer then return true end
        end
    end
    return false
end

local function effect_key(entry)
    return (entry and entry.effect_key) or ""
end

local function sort_by_priority_desc(a, b)
    local pa = effect_priority(a)
    local pb = effect_priority(b)
    if pa == pb then
        return effect_key(a) < effect_key(b)
    end
    return pa > pb
end

local function resolve_default_sprite(card, layer)
    if not (card and card.children) then return nil end
    if layer == "center" then return card.children.center end
    if layer == "front" then return card.children.front end
    if layer == "back" then return card.children.back end
    if layer == "floating" then return card.children.floating_sprite end
    if layer == "shadow" then return card.children.center or card.children.back end
    return nil
end

local function group_key(layer, sprite_ref, relative_to, color, transform_override, lane, lane_policy)
    -- GC_HACK: Reuse buffer to avoid alloc
    _group_key_parts[1] = tostring(layer)
    _group_key_parts[2] = tostring(sprite_ref)
    _group_key_parts[3] = tostring(relative_to)
    _group_key_parts[4] = tostring(color)
    _group_key_parts[5] = tostring(transform_override)
    _group_key_parts[6] = tostring(lane)
    _group_key_parts[7] = tostring(lane_policy)
    return table.concat(_group_key_parts, _group_key_sep, 1, 7)
end

local SEAL_ALPHA = {
    Gold = 0.25,
    Purple = 0.5,
    Red = 0.75,
    Blue = 1.0,
}

function intents.attach(br)
    function br:get_effect_slot_budget(layer)
        local def = (layer and self.registry.layers[layer]) or nil
        local budget = (def and def.effect_slot_budget) or self.default_effect_slot_budget or 0
        if budget < 0 then budget = 0 end
        return budget
    end

    function br:resolve_intent_effects(intent)
        if not intent then return nil end
        if intent._resolved_effects ~= nil then
            return intent._resolved_effects ~= false and intent._resolved_effects or nil
        end

        intent.effect_overflowed = nil
        intent.effects_dropped = nil

        -- GC_HACK: Scratch tables to reduce frame alloc and memory pressure
        local scratch = self._effect_scratch
        if not scratch then
            scratch = { explicit = {}, auto = {}, slots = {} }
            self._effect_scratch = scratch
        end

        local explicit = scratch.explicit
        local auto = scratch.auto
        local slots = scratch.slots

        util.clear_array(explicit)
        util.clear_array(auto)

        for k in pairs(slots) do
            slots[k] = nil
        end

        local layer = intent.layer or "center"
        local entry_count = 0

        if intent.effects and #intent.effects > 0 then
            for i = 1, #intent.effects do
                local entry = intent.effects[i]
                if not entry then goto continue end

                normalize_intent_fields(entry)
                entry._module = entry.effect_key and self.registry.modules[entry.effect_key] or nil
                if entry._module and not module_supports_layer(entry._module, entry.layer or layer) then
                    entry._module = nil
                end

                if entry.effect_slot ~= nil then
                    explicit[#explicit + 1] = entry
                else
                    auto[#auto + 1] = entry
                end

                entry_count = entry_count + 1
                ::continue::
            end
        elseif intent.effect_key then
            normalize_intent_fields(intent)
            intent._module = intent.effect_key and self.registry.modules[intent.effect_key] or nil
            if intent._module and not module_supports_layer(intent._module, intent.layer or layer) then
                intent._module = nil
            end
            if intent.effect_slot ~= nil then
                explicit[1] = intent
            else
                auto[1] = intent
            end
            entry_count = 1
        end

        if entry_count == 0 then
            intent._resolved_effects = false
            return nil
        end

        local budget = self:get_effect_slot_budget(layer)
        local resolved = intent._resolved_effects
        if type(resolved) ~= "table" then
            resolved = {}
        else
            util.clear_array(resolved)
        end

        if budget <= 0 then
            intent.effect_overflowed = true
            intent.effects_dropped = entry_count
            intent._resolved_effects = resolved
            return resolved
        end

        table.sort(explicit, sort_by_priority_desc)
        table.sort(auto, sort_by_priority_desc)
        local dropped = 0

        for i = 1, #explicit do
            local entry = explicit[i]
            local slot = entry.effect_slot

            if type(slot) ~= "number" or slot ~= math.floor(slot) then
                dropped = dropped + 1
                goto continue
            end

            if slot < 0 or slot >= budget then
                dropped = dropped + 1
                goto continue
            end

            local existing = slots[slot]
            if not existing then
                slots[slot] = entry
                goto continue
            end

            if sort_by_priority_desc(entry, existing) then
                slots[slot] = entry
            end
            dropped = dropped + 1
            ::continue::
        end

        local next_slot = 0
        for i = 1, #auto do
            local entry = auto[i]
            while next_slot < budget and slots[next_slot] do
                next_slot = next_slot + 1
            end
            if next_slot >= budget then
                dropped = dropped + 1
                goto continue
            end
            entry.effect_slot = next_slot
            slots[next_slot] = entry
            next_slot = next_slot + 1
            ::continue::
        end

        for slot = 0, budget - 1 do
            local entry = slots[slot]
            if not entry then goto continue end
            resolved[#resolved + 1] = entry
            ::continue::
        end

        if dropped > 0 then
            intent.effect_overflowed = true
            intent.effects_dropped = dropped
        end

        intent._resolved_effects = resolved
        return resolved
    end

    -- Declare card capabilities for our API helpers
    function br:declare_card(def)
        if not def or not def.card then return nil end
        local card = def.card
        local key = card.ID or tostring(card)
        local entry = self.declared_cards[key] or { card = card }
        if def.effects then
            for i = 1, #def.effects do
                local effect = def.effects[i]
                if not effect then goto continue end
                normalize_intent_fields(effect)
                ::continue::
            end
        end
        if def.overlays then
            for i = 1, #def.overlays do
                local overlay = def.overlays[i]
                if not overlay then goto continue end
                normalize_intent_fields(overlay)
                ::continue::
            end
        end
        if def.ui_overlays then
            for i = 1, #def.ui_overlays do
                local overlay = def.ui_overlays[i]
                if not (overlay and type(overlay) == "table") then goto continue end

                normalize_intent_fields(overlay)
                if overlay.ui_ref == nil and overlay.node ~= nil then
                    overlay.ui_ref = overlay.node
                elseif overlay.ui_ref == nil and overlay.ui ~= nil then
                    overlay.ui_ref = overlay.ui
                end
                ::continue::
            end
        end
        entry.batch_safe = def.batch_safe
        entry.effects = def.effects
        entry.overlays = def.overlays
        entry.ui_overlays = def.ui_overlays
        entry.flags = def.flags
        self.declared_cards[key] = entry
        return entry
    end

    -- Decide which lane an intent should use.
    function br:resolve_lane(intent)
        local policy = util.normalize_lane_policy(intent.lane_policy)
        if policy == "force_immediate" then return "immediate" end
        if policy == "force_overlay" then return "overlay" end
        if policy == "force_batch" then return "batch" end

        local lane = intent.lane or "batch"
        if lane ~= "batch" then return lane end

        if intent.card_id and self.compat.cards[intent.card_id] then
            return "immediate"
        end

        local resolved_effects = self:resolve_intent_effects(intent)
        if resolved_effects and #resolved_effects > 0 then
            for i = 1, #resolved_effects do
                local entry = resolved_effects[i]
                local module = entry and entry._module or nil
                if not module or not (module.flags and module.flags.batch_safe) then
                    return "overlay"
                end
            end
        elseif resolved_effects == nil and intent.effect_key then
            local module = self.registry.modules[intent.effect_key]
            if not module or not (module.flags and module.flags.batch_safe) then
                return "overlay"
            end
        end

        local function check_texture_contract(layer, texture_key, commit)
            if not texture_key then return true end
            local textures = self.registry.textures
            if not textures then return true end
            local def = textures[texture_key]
            if not def then
                if G.STRONTIUM_DEBUG_TEXTURES then print("Texture check failed: def not found", layer, texture_key) end
                return false
            end
            if def.flags and def.flags.batch_safe == false then
                -- Explicitly unsafe textures are not errors, just standard fallback
                return false
            end

            local mode = def.mode
            if mode == "atlas" then
                return true
            end

            if mode == "slot" then
                local slot = def.slot
                if not slot then
                     if G.STRONTIUM_DEBUG_TEXTURES then print("Texture check failed: no slot defined", layer, texture_key) end
                     return false
                end
                local budget = def.slot_budget or self.default_texture_slot_budget or 0
                if slot < 1 or slot > budget then
                     if G.STRONTIUM_DEBUG_TEXTURES then print("Texture check failed: slot out of budget", layer, texture_key, slot, budget) end
                     return false
                end
                if commit then
                    local slots = self.texture_slots_used[layer]
                    if not slots then
                        slots = {}
                        self.texture_slots_used[layer] = slots
                    end
                    local used = slots[slot]
                    if used and used ~= texture_key then
                        if G.STRONTIUM_DEBUG_TEXTURES then print("Texture check failed: slot collision", layer, texture_key, slot, used) end
                        return false
                    end
                    slots[slot] = texture_key
                end
                return true
            end

            if mode == "array" then
                local size = def.size
                if not (size and size.w and size.h) then
                    if G.STRONTIUM_DEBUG_TEXTURES then print("Texture check failed: array size invalid", layer, texture_key) end
                    return false
                end
                if commit then
                    local existing = self.texture_array_sizes[layer]
                    if not existing then
                        self.texture_array_sizes[layer] = { w = size.w, h = size.h }
                    elseif existing.w ~= size.w or existing.h ~= size.h then
                        if G.STRONTIUM_DEBUG_TEXTURES then print("Texture check failed: array size mismatch", layer, texture_key) end
                        return false
                    end
                end
                return true
            end

            if G.STRONTIUM_DEBUG_TEXTURES then print("Texture check failed: unknown mode", layer, texture_key, mode) end
            return false
        end

        local function check_intent_textures(entry, layer, commit)
            if entry and entry.texture_key then
                return check_texture_contract(layer, entry.texture_key, commit)
            end
            return true
        end

        local intent_layer = intent.layer or "center"
        if not check_intent_textures(intent, intent_layer, false) then
            return "overlay"
        end
        if resolved_effects and #resolved_effects > 0 then
            for i = 1, #resolved_effects do
                local entry = resolved_effects[i]
                if entry and not check_intent_textures(entry, entry.layer or intent_layer, false) then
                    return "overlay"
                end
            end
        end
        check_intent_textures(intent, intent_layer, true)
        if resolved_effects and #resolved_effects > 0 then
            for i = 1, #resolved_effects do
                local entry = resolved_effects[i]
                if entry then
                    check_intent_textures(entry, entry.layer or intent_layer, true)
                end
            end
        end

        return "batch"
    end

    -- Split intents into batch/overlay/immediate lanes.
    function br:classify_intents()
        util.clear_array(self.lanes.batch)
        util.clear_array(self.lanes.overlay)
        util.clear_array(self.lanes.immediate)

        local batch = self.lanes.batch
        local overlay = self.lanes.overlay
        local immediate = self.lanes.immediate
        local stats = self.stats
        local layer_stats = stats and stats.layers

        if not layer_stats and stats then
            layer_stats = {}
            stats.layers = layer_stats
        end

        if layer_stats then
            for _, entry in pairs(layer_stats) do
                entry.batch = 0
                entry.overlay = 0
                entry.immediate = 0
            end
        end

        for i = 1, self.intent_count do
            local intent = self.intents[i]
            if not intent then goto continue end

            local lane = self:resolve_lane(intent)
            if lane == "batch" then
                batch[#batch + 1] = intent
            elseif lane == "overlay" then
                overlay[#overlay + 1] = intent
            else
                immediate[#immediate + 1] = intent
            end

            if layer_stats then
                local layer = intent.layer or "center"
                local entry = layer_stats[layer]
                if not entry then
                    entry = { batch = 0, overlay = 0, immediate = 0 }
                    layer_stats[layer] = entry
                end
                if lane == "batch" then
                    entry.batch = entry.batch + 1
                elseif lane == "overlay" then
                    entry.overlay = entry.overlay + 1
                else
                    entry.immediate = entry.immediate + 1
                end
            end
            ::continue::
        end

        self.stats.intents = self.intent_count
        self.stats.batch = #batch
        self.stats.overlay = #overlay
        self.stats.immediate = #immediate
    end

    -- Get a pooled intent table or create a new one if the pool is empty.
    -- caller must populate fields, then call emit_intent().
    -- GC_HACK: Abusing table pooling to reduce pressure.
    function br:get_pooled_intent()
        local pool_count = self.intent_pool_count
        if pool_count > 0 then
            local intent = self.intent_pool[pool_count]
            self.intent_pool[pool_count] = nil
            self.intent_pool_count = pool_count - 1
            return intent
        end
        return {}
    end

    -- Record an intent for the current frame.
    function br:emit_intent(intent)
        if not intent then return nil end
        normalize_intent_fields(intent)
        intent._resolved_effects = nil
        intent.effect_overflowed = nil
        intent.effects_dropped = nil
        if intent.card and not intent.card_id then
            intent.card_id = intent.card.ID or nil
        end
        local idx = self.intent_count + 1
        self.intent_count = idx
        intent.id = idx
        self.intents[idx] = intent
        return idx
    end

    -- Mark a card as legacy-compat (forced immediate lane).
    function br:mark_compat(card, reason)
        if self.compat.mode == "deny" then return end
        if not card then return end
        local id = card.ID or tostring(card)
        if not self.compat.cards[id] then
            self.compat.cards[id] = { card = card, reason = reason }
            self.compat.queue[#self.compat.queue + 1] = card
        end
    end

    function br:build_edition_color(card, seal_alpha)
        if not (G.BATCHED_EDITION_INTEGRATED and G.SHADERS and G.SHADERS["edition_integrated"]) then
            return nil
        end
        if not card then return nil end

        local edition_id = 0
        local is_antimatter = (card.ability and card.ability.name == "Antimatter")
            and (card.config and card.config.center)
            and (card.config.center.discovered or card.bypass_discovery_center)
        if is_antimatter or (card.edition and card.edition.negative) then
            edition_id = 255
        elseif card.edition and card.edition.holo then
            edition_id = 128
        elseif card.edition and card.edition.foil then
            edition_id = 64
        elseif card.edition and card.edition.polychrome then
            edition_id = 192
        end

        local cid = card.ID or 0
        local seed1 = ((cid * 73 + 17) % 256) / 255
        local seed2 = ((cid * 151 + 101) % 256) / 255

        -- GC_HACK: Reuse pooled color table
        _edition_color[1] = edition_id / 255
        _edition_color[2] = seed1
        _edition_color[3] = seed2
        _edition_color[4] = seal_alpha or 0
        return _edition_color
    end

    -- Emit a sticker intent with occlusion handling.
    function br:emit_sticker(card, sprite_ref, opts)
        if not (card and sprite_ref) then return nil end
        opts = opts or {}
        if opts.occlude ~= false and self:is_sticker_region_covered(card) then return nil end

        local relative_to = opts.relative_to or card.children.center or card.children.back
        local intent = self:get_pooled_intent()

        intent.card = card
        intent.layer = opts.layer or "sticker"
        intent.sprite_ref = sprite_ref
        intent.relative_to = relative_to
        intent.color = opts.color
        intent.lane = opts.lane or opts.mode
        intent.lane_policy = opts.lane_policy
        intent.effect_key = opts.effect_key or opts.effect
        intent.params = opts.params
        intent.order_value = opts.order_value

        return self:emit_intent(intent)
    end

    -- Emit a seal sprite. 
    -- TODO: Uses sticker layer, but we might want to move this to a dedicated layer.
    function br:emit_seal_sprite(card, sprite_ref, opts)
        opts = opts or {}
        if opts.layer == nil then
            opts.layer = "sticker"
        end
        return self:emit_sticker(card, sprite_ref, opts)
    end

    function br:emit_ui_node(card, node, opts)
        if not node then return nil end
        opts = opts or {}
        local intent = opts.intent or self:get_pooled_intent()
        intent.card = opts.card or card
        intent.layer = opts.layer or "ui"
        intent.lane = opts.lane or "overlay"
        intent.lane_policy = opts.lane_policy
        intent.draw = opts.draw or draw_ui_node
        intent.ui_ref = node

        local base_order = opts.order_value
        local order_bias = opts.order_bias or 0
        if base_order ~= nil then
            intent.order_value = base_order + order_bias
        elseif order_bias ~= 0 then
            intent.order_value = order_bias
        end

        return self:emit_intent(intent)
    end

    function br:add_card_ui(card, def)
        if not (card and def) then return nil end
        local list = card.strontium_ui_overlays
        if not list then
            list = {}
            card.strontium_ui_overlays = list
        end
        list[#list + 1] = def
        return def
    end

    function br:emit_card_stickers(card, opts)
        if not card then return nil end
        opts = opts or {}

        local function emit(sprite_ref)
            if not sprite_ref then return end
            self:emit_sticker(card, sprite_ref, {
                layer = opts.layer,
                relative_to = opts.relative_to,
                color = opts.color,
                lane = opts.lane,
                lane_policy = opts.lane_policy,
                effect_key = opts.effect_key or opts.effect,
                params = opts.params,
                order_value = opts.order_value,
                occlude = opts.occlude,
            })
        end

        if card.ability and card.ability.eternal then
            emit(G.shared_sticker_eternal or (G.shared_stickers and G.shared_stickers.eternal))
        end
        if card.ability and card.ability.perishable then
            emit(G.shared_sticker_perishable or (G.shared_stickers and G.shared_stickers.perishable))
        end
        if card.ability and card.ability.rental then
            emit(G.shared_sticker_rental or (G.shared_stickers and G.shared_stickers.rental))
        end
        if card.sticker and G.shared_stickers and G.shared_stickers[card.sticker] then
            emit(G.shared_stickers[card.sticker])
        end
        if card.sticker_run and G.shared_stickers and G.shared_stickers[card.sticker_run] and G.SETTINGS.run_stake_stickers then
            emit(G.shared_stickers[card.sticker_run])
        end
    end

    function br:emit_card_defaults_now(opts)
        if not opts or not opts.card then return nil end
        local card = opts.card
        if not (card.states and card.states.visible and card.children) then return nil end

        local declared = self.declared_cards[card.ID or tostring(card)]
        local effects = opts.effects or (declared and declared.effects) or nil
        local include_base = opts.include_base
        if include_base == nil then
            include_base = (effects == nil)
        end
        local include_editions = opts.include_editions == true
        local include_stickers = opts.include_stickers == true
        local include_seals = opts.include_seals
        if include_seals == nil then
            include_seals = include_editions
        end

        local base_lane = opts.lane
        if not base_lane and declared and declared.batch_safe == false then
            base_lane = "overlay"
        end

        local lane_policy = opts.lane_policy
        local order_value = opts.order_value
        local color = opts.color
        local relative_to = opts.relative_to

        -- TODO: Cleanup and optimize, this could be better structured.
        if effects and #effects > 0 then
            local groups = {}
            for i = 1, #effects do
                local entry = effects[i]
                if entry then
                    normalize_intent_fields(entry)
                    local layer = entry.layer or opts.layer or "center"
                    local sprite_ref = entry.sprite_ref or resolve_default_sprite(card, layer)
                    local entry_relative = entry.relative_to or relative_to
                    local entry_color = entry.color or color
                    local entry_transform = entry.transform_override or opts.transform_override
                    local entry_lane = entry.lane or base_lane
                    local entry_policy = entry.lane_policy or lane_policy
                    local key = group_key(layer, sprite_ref, entry_relative, entry_color, entry_transform, entry_lane, entry_policy)
                    local group = groups[key]
                    if not group then
                        group = {
                            card = card,
                            layer = layer,
                            sprite_ref = sprite_ref,
                            relative_to = entry_relative,
                            color = entry_color,
                            transform_override = entry_transform,
                            lane = entry_lane,
                            lane_policy = entry_policy,
                            order_value = order_value,
                            effects = {},
                        }
                        groups[key] = group
                    end
                    local effect_key = entry.effect_key
                    if effect_key then
                        group.effects[#group.effects + 1] = {
                            effect_key = effect_key,
                            params = entry.params,
                            effect_slot = entry.effect_slot,
                            texture_key = entry.texture_key,
                            lane = entry.lane,
                            lane_policy = entry.lane_policy,
                        }
                    end
                end
            end

            for _, group in pairs(groups) do
                if group.sprite_ref then
                    self:emit_intent(group)
                end
            end

            return true
        end

        if include_base then
            local facing = card.sprite_facing or "front"
            if facing == "front" then
                local center_color = color
                local front_color = color
                if include_editions and not color then
                    local seal_alpha = 0
                    if include_seals and card.seal and SEAL_ALPHA[card.seal] then
                        if not self:is_sticker_region_covered(card) then
                            seal_alpha = SEAL_ALPHA[card.seal]
                        end
                    end
                    center_color = self:build_edition_color(card, seal_alpha)
                    front_color = self:build_edition_color(card, 0)
                end

                local center = card.children.center
                if center then
                    self:emit_intent({
                        card = card,
                        layer = "center",
                        sprite_ref = center,
                        color = center_color,
                        lane = base_lane,
                        lane_policy = lane_policy,
                        order_value = order_value,
                    })
                end

                local front = card.children.front
                if front then
                    self:emit_intent({
                        card = card,
                        layer = "front",
                        sprite_ref = front,
                        color = front_color,
                        lane = base_lane,
                        lane_policy = lane_policy,
                        order_value = order_value,
                    })
                end
            else
                local back = card.children.back
                if back then
                    self:emit_intent({
                        card = card,
                        layer = "back",
                        sprite_ref = back,
                        color = color,
                        lane = base_lane,
                        lane_policy = lane_policy,
                        order_value = order_value,
                    })
                end
            end
        end

        if include_stickers then
            self:emit_card_stickers(card, {
                layer = opts.sticker_layer,
                relative_to = opts.sticker_relative_to,
                color = opts.sticker_color,
                lane = opts.sticker_lane or base_lane,
                lane_policy = opts.sticker_lane_policy or lane_policy,
                effect_key = opts.sticker_effect_key,
                effect = opts.sticker_effect,
                params = opts.sticker_params,
                order_value = order_value,
                occlude = opts.sticker_occlude,
            })
        end

        return true
    end

    -- Emit card with just builtins.
    function br:emit_card_defaults(opts)
        if not opts or not opts.card then return nil end
        local queue = self.card_defaults_queue
        local idx = #queue + 1
        queue[idx] = opts
        return idx
    end

    function br:flush_card_defaults()
        local queue = self.card_defaults_queue
        if not queue or #queue == 0 then return end
        for i = 1, #queue do
            local opts = queue[i]
            if opts then
                self:emit_card_defaults_now(opts)
            end
        end
        util.clear_array(queue)
    end
end

-- Expose helpers for other modules
intents.normalize_intent_fields = normalize_intent_fields

return intents
