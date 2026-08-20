-- Strontium API. Forwards calls to the active renderer.
--
-- Most of these calls will be no-ops if Strontium is not enabled.
--
-- Examples:
--   -- Register a batch-safe effect module and attach it to a card.
--   Strontium.register_effect({
--     key = "glow",
--     layer = "center",
--     glsl = "vec4 glow(vec4 color, vec2 uv, vec2 p) { return color; }",
--     params = { "strength", "speed" },
--     flags = { batch_safe = true },
--   })
--   Strontium.declare_card({
--     card = card,
--     effects = { { effect_key = "glow", params = { 0.4, 1.2 } } },
--   })
--
--   -- Add a UI node that only appears when the card is highlighted.
--   Strontium.add_card_ui(card, {
--     node = my_ui,
--     only_highlighted = true,
--   })
local public_api = {}

local function get_renderer()
    return (G and G.STRONTIUM_RENDERER) or nil
end

function public_api.install(renderer)
    local api = _G.Strontium or {}
    _G.Strontium = api

    local function use_renderer()
        return renderer or get_renderer()
    end

    -- Expose the renderer instance for more complicated stuff.
    api.get_renderer = function()
        return use_renderer()
    end

    -- Register a reload callback. Runs when dev reload is requested.
    -- Useful for seeing changes without restarting the game.
    -- Callbacks should be idempotent and only re-register registered registrations.
    -- Of course you can go crazy with it too.
    api.on_reload = function(fn)
        if type(fn) ~= "function" then return nil end
        local list = api._reload_handlers
        if not list then
            list = {}
            api._reload_handlers = list
        end
        list[#list + 1] = fn
        return fn
    end

    -- Reload a single module and return it.
    api.reload_module = function(module_name)
        if type(module_name) ~= "string" or module_name == "" then return nil end
        package.loaded[module_name] = nil
        local ok, mod = pcall(require, module_name)
        if not ok then
            if G and G.STRONTIUM_DEBUG_RELOAD then
                print("Strontium reload_module failed:", module_name, mod)
            end
            return nil
        end
        return mod
    end

    -- Reload builtins, calls reload hooks, rebuilds ubershaders.
    api.reload = function(opts)
        local br = use_renderer()
        if not br then return false end
        opts = opts or {}

        local reload_builtins = (opts.reload_builtins ~= false)
        if reload_builtins then
            local modules = opts.modules or {
                "strontium.renderer.base.effects",
                "strontium.renderer.base.overlays",
                "strontium.renderer.base.definitions",
            }
            for i = 1, #modules do
                local mod = api.reload_module(modules[i])
                if mod and mod.attach then
                    mod.attach(br)
                end
            end
            if br.register_builtin_effects then br:register_builtin_effects() end
            if br.register_builtin_overlays then br:register_builtin_overlays() end
        end

        local handlers = api._reload_handlers
        if handlers then
            for i = 1, #handlers do
                local ok, err = pcall(handlers[i])
                if not ok and G and G.STRONTIUM_DEBUG_RELOAD then
                    print("Strontium reload hook failed:", err)
                end
            end
        end

        if br.invalidate_all_ubershaders then
            br:invalidate_all_ubershaders()
        elseif br.invalidate_ubershader and br.registry and br.registry.layer_order then
            for i = 1, #br.registry.layer_order do
                br:invalidate_ubershader(br.registry.layer_order[i])
            end
        end

        return true
    end

    -- Registration helpers: register layers/effects/textures/overlays up front.
    -- Pure data, this just renders them with strontium

    api.register_layer = function(def)
        local br = use_renderer()
        if br then return br:register_layer(def) end
        return nil
    end

    api.register_effect = function(def)
        local br = use_renderer()
        if br then return br:register_effect(def) end
        return nil
    end

    api.register_texture = function(def)
        local br = use_renderer()
        if br then return br:register_texture(def) end
        return nil
    end

    api.register_overlay = function(def)
        local br = use_renderer()
        if br then return br:register_overlay(def) end
        return nil
    end

    -- Emission helpers that submit intents for this frame.
    -- The renderer chooses a lane (batch/overlay/immediate) based on effect and texture props.

    api.emit_intent = function(intent)
        local br = use_renderer()
        if br then return br:emit_intent(intent) end
        return nil
    end

    api.emit_sticker = function(card, sprite_ref, opts)
        local br = use_renderer()
        if br then return br:emit_sticker(card, sprite_ref, opts) end
        return nil
    end

    api.emit_seal_sprite = function(card, sprite_ref, opts)
        local br = use_renderer()
        if br then return br:emit_seal_sprite(card, sprite_ref, opts) end
        return nil
    end

    -- UI helpers: overlay nodes are routed through the UI lane.
    -- Use these when you need card-aligned UI that needs the layered render order.

    api.emit_ui_node = function(card, node, opts)
        local br = use_renderer()
        if br and br.emit_ui_node then
            return br:emit_ui_node(card, node, opts)
        end
        return nil
    end

    api.add_card_ui = function(card, def)
        local br = use_renderer()
        if br and br.add_card_ui then
            return br:add_card_ui(card, def)
        end
        return nil
    end

    -- Card-level declarations for effects and arrays.
    -- Use this unless you need to manually emit intents per frame.

    api.declare_card = function(def)
        local br = use_renderer()
        if br then return br:declare_card(def) end
        return nil
    end

    -- Emit a card configured with just builtins.
    api.emit_card_defaults = function(def)
        local br = use_renderer()
        if br and br.emit_card_defaults then
            return br:emit_card_defaults(def)
        end
        return nil
    end

    api.emit_card_stickers = function(card, opts)
        local br = use_renderer()
        if br and br.emit_card_stickers then
            return br:emit_card_stickers(card, opts)
        end
        return nil
    end

    -- Helper for matching vanilla edition colors when building custom effects.
    api.build_edition_color = function(card, seal_alpha)
        local br = use_renderer()
        if br and br.build_edition_color then
            return br:build_edition_color(card, seal_alpha)
        end
        return nil
    end
end

return public_api
