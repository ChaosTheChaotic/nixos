--- Base game overlay definitions and draw hooks.

local overlays = {}

local function build_hologram_params(card)
    if not card then return nil end
    card.ARGS = card.ARGS or {}
    local params = card.ARGS.send_to_shader or {}
    card.ARGS.send_to_shader = params

    local t = (G.TIMERS and G.TIMERS.REAL) or 0
    local vt = card.VT
    local tilt = (card.tilt_var and card.tilt_var.amt) or 0
    local juice = (card.juice and card.juice.r) or 0

    params[1] = math.min((vt and vt.r or 0) * 3, 1) + (t / 28) + (juice * 20) + tilt
    params[2] = t
    return params
end

local function draw_hologram_overlay(card, intent, overlay_def)
    local sprite = intent and intent.sprite_ref
    if not sprite then return end

    local params = intent and intent.params or nil
    if type(params) == "function" then
        params = params(card, intent, overlay_def)
    end
    if not params then
        params = build_hologram_params(card)
    end

    local center = (intent and intent.relative_to)
        or (card and card.children and card.children.center)
        or nil

    local t = (G.TIMERS and G.TIMERS.REAL) or 0
    local base_scale = 0.07 + 0.02 * math.sin(1.8 * t)
    local base_rotate = 0.05 * math.sin(1.219 * t)
    local scale_mod = (intent and intent.scale_mod) or base_scale
    local rotate_mod = (intent and intent.rotate_mod) or base_rotate

    local scale_mult = (intent and intent.scale_mult)
        or (overlay_def and overlay_def.scale_mult)
        or 2
    local rotate_mult = (intent and intent.rotate_mult)
        or (overlay_def and overlay_def.rotate_mult)
        or 2

    local prev_tilt = card and card.hover_tilt or 0
    if card then
        card.hover_tilt = prev_tilt * 1.5
    end
    love.graphics.push()
    if card and card.translate_container then
        card:translate_container()
    elseif sprite.translate_container then
        sprite:translate_container()
    end
    if card and sprite.role then
        sprite.role.draw_major = card
    end
    sprite:draw_shader("hologram", nil, params, nil, center, scale_mod * scale_mult, rotate_mod * rotate_mult)
    love.graphics.pop()
    if card then
        card.hover_tilt = prev_tilt
    end
end

local function register_builtin_overlays(br)
    if not (br and br.register_overlay) then return end

    br:register_overlay({
        key = "hologram",
        draw = draw_hologram_overlay,
        scale_mult = 2,
        rotate_mult = 2,
    })
end

function overlays.attach(br)
    function br:register_builtin_overlays()
        register_builtin_overlays(self)
    end
end

return overlays
