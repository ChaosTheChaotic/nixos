--- Default composer stages for base game rendering.

local util = require('strontium.renderer.util')

local stages = {}

-- Seal alpha encoding used by the shader.
local SEAL_ALPHA = {
    Gold   = 0.25,
    Purple = 0.5,
    Red    = 0.75,
    Blue   = 1.0,
}

-- Resolve overrides. Key takes precedence over instance IDs.
local function resolve_declared_def(br, card)
    if not (br and br.declared_cards and card) then return nil end
    local def = nil
    local center = card.config and card.config.center or nil
    if center and center.key then
        def = br.declared_cards[center.key]
    end
    if not def and card.ID then
        def = br.declared_cards[card.ID]
    end
    return def
end

-- Map layer names to their default card sprites.
local function resolve_default_sprite(card, layer)
    if not (card and card.children) then return nil end
    if layer == "center" then return card.children.center end
    if layer == "front" then return card.children.front end
    if layer == "back" then return card.children.back end
    if layer == "floating" then return card.children.floating_sprite end
    if layer == "shadow" then return card.children.center or card.children.back end
    return nil
end

-- Build params for vanilla shaders.
local function build_send_to_shader(card)
    if not card then return nil end
    card.ARGS = card.ARGS or {}
    local params = card.ARGS.send_to_shader or {}
    card.ARGS.send_to_shader = params

    -- TODO: This is a stupid hash function.
    local cid = card.ID or 0
    params[1] = ((cid * 73 + 17) % 256) / 255
    params[2] = ((cid * 151 + 101) % 256) / 255
    return params
end

-- Return center and front edition effects.
local function build_edition_effects(card)
    local edition = card and card.edition or nil
    local is_antimatter = (card and card.ability and card.ability.name == "Antimatter")
        and (card.config and card.config.center)
        and (card.config.center.discovered or card.bypass_discovery_center)

    if not (edition or is_antimatter) then return nil end

    local params = build_send_to_shader(card)
    if is_antimatter or (edition and edition.negative) then
        return {
            { effect_key = "negative", params = params },
            { effect_key = "negative_shine", params = params },
        }, {
            { effect_key = "negative", params = params },
        }
    end

    local effect_key = nil
    if edition and edition.holo then
        effect_key = "holo"
    elseif edition and edition.foil then
        effect_key = "foil"
    elseif edition and edition.polychrome then
        effect_key = "polychrome"
    end
    if effect_key then
        local effects = {
            { effect_key = effect_key, params = params },
        }
        return effects, effects
    end

    return nil
end

-- Invisible Joker uses the voucher shader
local function build_invisible_effects(card)
    if not (card and card.ability and card.ability.name == "Invisible Joker") then
        return nil
    end
    local center = card.config and card.config.center
    if not (center and (center.discovered or card.bypass_discovery_center)) then
        return nil
    end
    local params = build_send_to_shader(card)
    return {
        { effect_key = "voucher", params = params },
    }
end

-- Append effect arrays without mutating inputs
local function merge_effects(base, extra)
    if not (extra and #extra > 0) then return base end
    if not (base and #base > 0) then return extra end

    local merged = {}
    for i = 1, #base do
        merged[#merged + 1] = base[i]
    end
    for i = 1, #extra do
        merged[#merged + 1] = extra[i]
    end
    return merged
end

-- Normalize order values into [0,1]. 
-- Somewhat hacky fix to force dragged cards to front.
local function compute_order_value(card, index, denom)
    local order_value = (index - 1) / (denom + 1)
    local states = card.states
    if states and states.drag and states.drag.is then
        return 1
    end
    if states and states.focus and states.focus.is then
        return 1
    end
    if card.highlighted then
        return 1
    end
    return order_value
end

local function apply_hover_tilt(tilt_var, hover_offset, tilt_factor, extra)
    local hx = hover_offset.x or 0
    local hy = hover_offset.y or 0
    tilt_var.amt = math.abs(hy + hx - 1 + (extra or 0)) * tilt_factor
end

-- Emit a basic sprite intent with optional overrides.
local function emit_basic_intent(ctx, br, card, layer, sprite_ref, order_value, opts)
    if not (ctx and sprite_ref) then return nil end
    local intent = br:get_pooled_intent()
    intent.card = card
    intent.layer = layer
    intent.sprite_ref = sprite_ref
    intent.order_value = order_value
    if opts then
        intent.color = opts.color
        intent.effects = opts.effects
        intent.relative_to = opts.relative_to
        intent.transform_override = opts.transform_override
    end
    ctx.intents[#ctx.intents + 1] = intent
    return intent
end

-- Match vanilla tilt/hover state so overlay shaders warp consistently.
-- Largely ported
local function update_card_tilt(card)
    if not card then return end
    card.hover_tilt = 1

    local tilt_var = card.tilt_var
    if not tilt_var then
        tilt_var = { mx = 0, my = 0, dx = 0, dy = 0, amt = 0 }
        card.tilt_var = tilt_var
    end

    local states = card.states or {}
    local cursor = (G.CONTROLLER and G.CONTROLLER.cursor_position) or nil
    local cursor_x = cursor and cursor.x or 0
    local cursor_y = cursor and cursor.y or 0
    local hover_offset = card.hover_offset or {}
    local tilt_factor = 0.3
    local scale = G.TILESCALE * G.TILESIZE

    if states.focus and states.focus.is then
        local dx = tilt_var.dx or 0
        local dy = tilt_var.dy or 0
        local t = card.T or {}
        tilt_var.mx = cursor_x + dx * (t.w or 0) * scale
        tilt_var.my = cursor_y + dy * (t.h or 0) * scale
        apply_hover_tilt(tilt_var, hover_offset, tilt_factor, dx + dy - 1)
        return
    end

    if states.hover and states.hover.is then
        tilt_var.mx = cursor_x
        tilt_var.my = cursor_y
        apply_hover_tilt(tilt_var, hover_offset, tilt_factor, 0)
        return
    end

    if card.ambient_tilt then
        local id = card.ID or 0
        local real_time = (G.TIMERS and G.TIMERS.REAL) or 0
        local tilt_angle = real_time * (1.56 + (id / 1.14212) % 1) + id / 1.35122
        local room_t = (G.ROOM and G.ROOM.T) or {}
        local vt = card.VT or {}

        tilt_var.mx = ((0.5 + 0.5 * card.ambient_tilt * math.cos(tilt_angle)) * (vt.w or 0)
            + (vt.x or 0) + (room_t.x or 0)) * scale
        tilt_var.my = ((0.5 + 0.5 * card.ambient_tilt * math.sin(tilt_angle)) * (vt.h or 0)
            + (vt.y or 0) + (room_t.y or 0)) * scale
        tilt_var.amt = card.ambient_tilt * (0.5 + math.cos(tilt_angle)) * tilt_factor
        return
    end

    tilt_var.amt = 0
end

-- Evaluate highlight/visibility gates for UI overlays.
local function passes_ui_overlay_gate(card, overlay, only_highlighted, when)
    if only_highlighted and not card.highlighted then return false end
    if when == nil then return true end
    if type(when) == "function" then
        return when(card, overlay)
    end
    return not not when
end

-- Emit a UI overlay entry with optional gating and ordering overrides.
local function emit_ui_overlay_entry(ctx, card, overlay, order_value)
    if not (ctx and card and overlay) then return end
    local node = overlay
    local opts = { order_value = order_value }
    local only_highlighted = false
    local when = nil

    if type(overlay) == "table" and (overlay.node or overlay.ui or overlay.ui_ref) then
        node = overlay.ui_ref or overlay.node or overlay.ui
        opts.order_value = overlay.order_value or order_value
        opts.order_bias = overlay.order_bias
        opts.layer = overlay.layer
        opts.lane = overlay.lane
        opts.lane_policy = overlay.lane_policy
        opts.draw = overlay.draw
        only_highlighted = overlay.only_highlighted == true
        when = overlay.when
    end

    if not node then return end
    if not passes_ui_overlay_gate(card, overlay, only_highlighted, when) then return end
    ctx.br:emit_ui_node(card, node, opts)
end

-- Cull cards that should be handled by vanilla UI or hidden areas.
-- TODO: Optimize as much as possible, this is currently a huge bottleneck in the pipeline.
local _parent_ui_cache = setmetatable({}, { __mode = "k" })

local function parent_is_ui(parent, ui_element, ui_box)
    if not parent then return false end
    local cached = _parent_ui_cache[parent]
    if cached ~= nil then
        return cached
    end

    local is_ui = false
    if parent.UIT ~= nil or parent.UIBox ~= nil then
        is_ui = true
    else
        local mt = getmetatable(parent)
        if (ui_element and mt == ui_element) or (ui_box and mt == ui_box) then
            is_ui = true
        end
    end

    _parent_ui_cache[parent] = is_ui
    return is_ui
end

local function should_skip_card(card, drag_target, focus_target, ui_element, ui_box)
    -- Basic visibility check.
    local states = card and card.states
    local children = card and card.children
    if not (states and states.visible and children) then
        return true
    end
    local is_dragged = states.drag and states.drag.is

    -- Check if card is parented to a UI element.
    local p = card.parent
    if p and parent_is_ui(p, ui_element, ui_box) then
        return true
    end

    -- Check if card is in a deck-type area.
    local area = card.area
    local area_config = area and area.config
    if area_config and area_config.type == "deck" then
        return true
    end

    -- Check if card is in discard (unless being dragged).
    local in_discard = area and (
        area == G.discard or
        (area_config and area_config.type == "discard")
    )
    if in_discard and not is_dragged then
        return true
    end

    -- Check if card is being dragged by the controller.
    if drag_target == card or focus_target == card then
        return true
    end

    return false
end

-- Keep shadow rules aligned with vanilla visibility conds.
local function should_draw_shadow(card)
    if card.no_shadow then return false end

    if card.greyed then return false end
    if card.ability and card.ability.effect == "Glass Card" then return false end

    local graphics = G.SETTINGS and G.SETTINGS.GRAPHICS
    if not (graphics and graphics.shadows == "On") then return false end

    -- Vanilla doesn't draw shadows in the deck unless dragging.
    if card.area then
        local is_dragged = card.states and card.states.drag and card.states.drag.is
        if card.area == G.discard then
            if not is_dragged then return false end
        end
        if card.area.config and card.area.config.type == "deck" then
            if not is_dragged then return false end
        end
    end

    return true
end

local function shadow_height_for_card(card, area_type, is_dragged)
    if (card.highlighted and card.area == G.play) or is_dragged then
        return 0.35
    end
    if area_type == "title_2" then
        return 0.04
    end
    return 0.1
end

local function should_draw_floating(card)
    local center = card.config and card.config.center
    if not (center and center.soul_pos) then return false end
    if card.sprite_facing ~= "front" then return false end
    return (center.discovered or card.bypass_discovery_center)
end

local function sort_ui_entries(a, b)
    local av = a.order_value or 0
    local bv = b.order_value or 0
    if av == bv then
        return (a.index or 0) < (b.index or 0)
    end
    return av < bv
end

stages.Cull = {
    name = "cull",
    order = 100,
}

function stages.Cull:run(ctx)
    local cards = ctx.cards or {}
    local scratch = ctx.scratch
    if not scratch then
        scratch = {}
        ctx.scratch = scratch
    end
    local visible = scratch.visible_cards or {}
    scratch.visible_cards = visible

    local count = 0
    local controller = G.CONTROLLER
    local drag_target = controller and controller.dragging and controller.dragging.target or nil
    local focus_target = controller and controller.focused and controller.focused.target or nil
    local ui_element = rawget(_G, "UIElement")
    local ui_box = rawget(_G, "UIBox")
    local sort_x = G.STRONTIUM_SORT_X ~= false
    local sorted_by_x = sort_x
    local prev_x = nil

    for i = 1, #cards do
        local card = cards[i]
        if not card or should_skip_card(card, drag_target, focus_target, ui_element, ui_box) then
            goto continue
        end

        update_card_tilt(card)
        count = count + 1
        visible[count] = card

        if not (sort_x and sorted_by_x) then
            goto continue
        end

        -- Track monotonic X so we can skip a full sort when already ordered.
        local vt = card.VT
        local x = (vt and vt.x) or (card.T and card.T.x or 0)
        if prev_x ~= nil and x < prev_x then
            sorted_by_x = false
            goto continue
        end

        prev_x = x
        ::continue::
    end
    for i = count + 1, #visible do
        visible[i] = nil
    end

    -- Sort by X position for consistent left to right rendering.
    if sort_x and count > 1 and not sorted_by_x then
        table.sort(visible, util.sort_by_x)
        sorted_by_x = true
    end

    -- Cache for later stages
    ctx.cache.visible_cards = visible
    ctx.cache.visible_count = count
    ctx.cache.ui_queue_sorted = sorted_by_x
end

stages.Shadow = {
    name = "shadow",
    order = 200,
}

-- GC_HACK: Reuse shadow color table.
local _shadow_color = { 0, 0, 0, 0.3 }

function stages.Shadow:run(ctx)
    -- Emit shadow intents with vanilla offsets and parallax.
    local br = ctx.br
    local visible = ctx.cache.visible_cards or {}

    for _, card in ipairs(visible) do
        if not should_draw_shadow(card) then
            goto continue
        end

        local shadow_sprite = (card.sprite_facing == "front")
            and card.children.center
            or card.children.back
        if not shadow_sprite then
            goto continue
        end

        -- Calculate shadow offset based on card state.
        local area_type = card.area and card.area.config and card.area.config.type
        local is_dragged = (G.CONTROLLER and G.CONTROLLER.dragging and G.CONTROLLER.dragging.target == card)
            or (card.states and card.states.drag and card.states.drag.is)

        local shadow_height = shadow_height_for_card(card, area_type, is_dragged)

        -- Calculate parallax and scale
        local parallax_x = -((card.shadow_parrallax and card.shadow_parrallax.x) or 0) * shadow_height
        local parallax_y = -((card.shadow_parrallax and card.shadow_parrallax.y) or 0) * shadow_height
        local scale_mult = 1 - 0.2 * shadow_height

        emit_basic_intent(ctx, br, card, "shadow", shadow_sprite, nil, {
            color = _shadow_color,
            transform_override = {
                offset_x = parallax_x,
                offset_y = parallax_y,
                scale_mult = scale_mult,
            },
        })
        ::continue::
    end
end

stages.Body = {
    name = "body",
    order = 300,
}

function stages.Body:run(ctx)
    -- Emit base card sprites and edition/declared effects.
    local br = ctx.br
    local visible = ctx.cache.visible_cards or {}
    local visible_count = ctx.cache.visible_count or #visible
    local denom = (visible_count > 1) and (visible_count - 1) or 1
    local scratch = ctx.scratch
    if not scratch then
        scratch = {}
        ctx.scratch = scratch
    end
    local ui_queue = scratch.ui_queue or {}
    scratch.ui_queue = ui_queue
    local ui_count = 0

    for i, card in ipairs(visible) do
        local order_value = compute_order_value(card, i, denom)

        -- Cache card for UI
        ui_count = ui_count + 1
        ui_queue[ui_count] = card

        if card.sprite_facing ~= "front" then
            emit_basic_intent(ctx, br, card, "back", card.children.back, order_value)
            goto continue
        end

        -- Optional aggressive cull for cards fully buried in a fan layout.
        -- HACK: This is not a stable method.
        if G.STRONTIUM_CULL_FACE == true and br.is_face_region_covered and br:is_face_region_covered(card) then
            goto continue
        end

        -- Seal alpha is encoded into the edition color unless occluded.
        local seal_alpha = card.seal and SEAL_ALPHA[card.seal] or 0
        if seal_alpha > 0 and br.is_sticker_region_covered and br:is_sticker_region_covered(card) then
            seal_alpha = 0
        end

        -- Edition color encodes edition type and shader seeds.
        local edition_color = br.build_edition_color and br:build_edition_color(card, seal_alpha) or nil

        -- Merge declared effects with edition and special effects.
        local declared_def = resolve_declared_def(br, card)
        local declared_effects = declared_def and declared_def.effects or nil
        local edition_center_effects, edition_front_effects = build_edition_effects(card)
        local invisible_effects = build_invisible_effects(card)
        local center_effects = merge_effects(declared_effects, edition_center_effects)
        center_effects = merge_effects(center_effects, invisible_effects)

        emit_basic_intent(ctx, br, card, "center", card.children.center, order_value, {
            color = edition_color,
            effects = center_effects,
        })

        if card.children.front and (not card.ability or card.ability.effect ~= "Stone Card") then
            local front_color = br.build_edition_color and br:build_edition_color(card, 0) or nil
            emit_basic_intent(ctx, br, card, "front", card.children.front, order_value, {
                color = front_color,
                effects = edition_front_effects,
            })
        end

        ::continue::
    end

    for i = ui_count + 1, #ui_queue do
        ui_queue[i] = nil
    end
    ctx.cache.ui_queue = ui_queue
end

stages.Sticker = {
    name = "sticker",
    order = 400,
}

function stages.Sticker:run(ctx)
    -- Emit sticker sprites for non-occluded cards.
    local br = ctx.br
    local visible = ctx.cache.visible_cards or {}
    local visible_count = ctx.cache.visible_count or #visible
    local denom = (visible_count > 1) and (visible_count - 1) or 1

    local function emit_sticker(card, sticker_sprite, order_value)
        if not sticker_sprite then return end
        emit_basic_intent(ctx, br, card, "sticker", sticker_sprite, order_value, {
            relative_to = card.children.center,
        })
    end

    for i, card in ipairs(visible) do
        if card.sprite_facing ~= "front" then
            goto continue
        end

        if br.is_sticker_region_covered and br:is_sticker_region_covered(card) then
            goto continue
        end

        local order_value = (i - 1) / denom

        if card.ability and card.ability.eternal then
            emit_sticker(card, G.shared_sticker_eternal, order_value)
        end

        if card.ability and card.ability.perishable then
            emit_sticker(card, G.shared_sticker_perishable, order_value)
        end

        if card.ability and card.ability.rental then
            emit_sticker(card, G.shared_sticker_rental, order_value)
        end

        if card.sticker_run and G.shared_stickers and G.shared_stickers[card.sticker_run] and G.SETTINGS.run_stake_stickers then
            emit_sticker(card, G.shared_stickers[card.sticker_run], order_value)
        end

        if card.sticker and G.shared_stickers and G.shared_stickers[card.sticker] then
            emit_sticker(card, G.shared_stickers[card.sticker], order_value)
        end

        ::continue::
    end
end

stages.Floating = {
    name = "floating",
    order = 450,
}

function stages.Floating:run(ctx)
    -- Emit floating/soul overlays for cards that register soul_pos.
    -- TODO: Still a bit janky, needs some work.
    local br = ctx.br
    local visible = ctx.cache.visible_cards or {}
    local visible_count = ctx.cache.visible_count or #visible
    local denom = (visible_count > 1) and (visible_count - 1) or 1

    local t = (G.TIMERS and G.TIMERS.REAL) or 0
    local base_scale = 0.07 + 0.02 * math.sin(1.8 * t)
    local base_rotate = 0.05 * math.sin(1.219 * t)

    local function emit_overlay(card, entry, order_value)
        local layer = entry.layer or "floating"
        if layer ~= "floating" then return false end

        local entry_sprite = entry.sprite_ref or entry.sprite or resolve_default_sprite(card, layer)
        if not entry_sprite then return false end

        local intent = br:get_pooled_intent()
        intent.card = card
        intent.layer = layer
        intent.sprite_ref = entry_sprite
        intent.relative_to = entry.relative_to or (card.children and card.children.center) or nil
        intent.color = entry.color
        intent.order_value = entry.order_value or order_value
        intent.lane = entry.lane or "overlay"
        intent.lane_policy = entry.lane_policy
        intent.overlay_key = entry.overlay_key or entry.overlay
        intent.draw = entry.draw
        intent.params = entry.params
        intent.transform_override = entry.transform_override
        intent.scale_mod = entry.scale_mod or base_scale
        intent.rotate_mod = entry.rotate_mod or base_rotate
        intent.scale_mult = entry.scale_mult
        intent.rotate_mult = entry.rotate_mult

        ctx.intents[#ctx.intents + 1] = intent
        return entry.replace_base == true
    end

    for i, card in ipairs(visible) do
        if not should_draw_floating(card) then
            goto continue
        end

        local sprite = card.children and card.children.floating_sprite
        if not sprite then
            goto continue
        end

        local order_value = compute_order_value(card, i, denom)
        local declared_def = resolve_declared_def(br, card)
        local overlays = declared_def and declared_def.overlays or nil
        local skip_base = false

        if overlays then
            -- Declared floating overlays may replace the base soul sprite (hologram).
            for j = 1, #overlays do
                local entry = overlays[j]
                if not entry then goto continue end
                if emit_overlay(card, entry, order_value) then
                    skip_base = true
                end
                ::continue::
            end
        end

        if not skip_base then
            local intent = br:get_pooled_intent()
            intent.card = card
            intent.layer = "floating"
            intent.sprite_ref = sprite
            intent.relative_to = card.children and card.children.center or nil
            intent.order_value = order_value
            intent.transform_override = {
                scale_mult = 1 + base_scale,
                rotate = base_rotate,
            }

            ctx.intents[#ctx.intents + 1] = intent
        end

        ::continue::
    end
end

stages.CardUI = {
    name = "card_ui",
    order = 475,
}

function stages.CardUI:run(ctx)
    -- Emit UI overlays in card order.
    -- necessary for sell and buy buttons, otherwise they render occluded.
    local br = ctx.br
    local visible = ctx.cache.visible_cards or {}
    local visible_count = ctx.cache.visible_count or #visible
    local denom = (visible_count > 1) and (visible_count - 1) or 1

    local scratch = ctx.scratch
    if not scratch then
        scratch = {}
        ctx.scratch = scratch
    end
    local entries = scratch.ui_entries or {}
    scratch.ui_entries = entries

    local function populate_entries()
        local count = 0
        local sorted = true
        local prev_order = nil
        for i = 1, #visible do
            local card = visible[i]
            if not card then goto continue end

            count = count + 1
            local entry = entries[count]
            if not entry then
                entry = {}
                entries[count] = entry
            end
            local order_value = compute_order_value(card, i, denom)
            entry.card = card
            entry.order_value = order_value
            entry.index = i
            if prev_order ~= nil and order_value < prev_order then
                sorted = false
            end
            prev_order = order_value
            ::continue::
        end
        for i = count + 1, #entries do
            entries[i] = nil
        end
        return count, sorted
    end

    local function emit_overlay_list(card, order_value, overlays)
        if not overlays then return end
        for j = 1, #overlays do
            emit_ui_overlay_entry(ctx, card, overlays[j], order_value)
        end
    end

    local count, sorted = populate_entries()
    if count > 1 and not sorted then
        table.sort(entries, sort_ui_entries)
    end

    for i = 1, count do
        local entry = entries[i]
        local card = entry.card
        local order_value = entry.order_value

        local ui_node = card and card.children and card.children.use_button or nil
        if ui_node and card.highlighted then
            emit_ui_overlay_entry(ctx, card, ui_node, order_value)
        end

        local center = card and card.config and card.config.center or nil
        local center_def = (center and center.key) and br.declared_cards[center.key] or nil
        local id_def = (card and card.ID) and br.declared_cards[card.ID] or nil

        emit_overlay_list(card, order_value, center_def and center_def.ui_overlays or nil)
        if id_def and id_def ~= center_def then
            emit_overlay_list(card, order_value, id_def.ui_overlays)
        end
        emit_overlay_list(card, order_value, card and card.strontium_ui_overlays or nil)
    end
end

-- Register base pipeline.
function stages.register_defaults(br)
    if not br.composer then
        error("Composer not initialized. Call composer.attach(br) first.")
    end

    br.composer:add_stage(stages.Cull, { name = "cull", order = 100 })
    br.composer:add_stage(stages.Shadow, { name = "shadow", order = 200 })
    br.composer:add_stage(stages.Body, { name = "body", order = 300 })
    br.composer:add_stage(stages.Sticker, { name = "sticker", order = 400 })
    br.composer:add_stage(stages.Floating, { name = "floating", order = 450 })
    br.composer:add_stage(stages.CardUI, { name = "card_ui", order = 475 })
    br.ui_layered_buttons = true
end

return stages
