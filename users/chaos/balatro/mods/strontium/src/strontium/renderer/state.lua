--- Renderer state defaults and per-frame containers.

local state = {}

-- Layer builtigs. These are required for base-game rendering.
state.DEFAULT_LAYERS = {
    { key = "shadow", order = 10, effect_slot_budget = 4 },
    { key = "back", order = 20, effect_slot_budget = 4 },
    { key = "center", order = 30, effect_slot_budget = 4 },
    { key = "front", order = 40, effect_slot_budget = 4 },
    { key = "sticker", order = 50, effect_slot_budget = 4 },
    { key = "floating", order = 60, effect_slot_budget = 4 },
    { key = "ui", order = 100, effect_slot_budget = 0 },
}

-- Mmm chunky state, just how I like it.
function state.new()
    return {
        enabled = false,
        frame_id = 0,

        stats = {
            intents = 0,
            batch = 0,
            overlay = 0,
            immediate = 0,
            compat_discards = 0,
            batches = 0,
            cards_rendered = 0,
            param_rows = 0,
            param_intents = 0,
            layers = {},
        },

        intents = {},
        intent_count = 0,
        intent_pool = {},
        intent_pool_count = 0,
        drawhash_queue = {},
        ui_queue = {},

        lanes = {
            batch = {},
            overlay = {},
            immediate = {},
        },

        layer_batches = {},
        layer_last_cleared = {},
        layer_sort_name = {},
        layer_sorted_keys = {},
        layer_sorted_dirty = {},
        layer_instances = {},
        layer_atlas_image = {},
        layer_atlas_tile = {},
        layer_atlas_dims = {},
        layer_shaders = {},
        layer_shader_last_key = {},
        layer_uber_enabled = {},
        active_shader = nil,
        ubershader = {
            cache = {},
            hash = {},
            errors = {},
            module_errors = {},
            layer_modules_cache = {},
        },
        instancing = {
            cache = {},
            hash = {},
            errors = {},
            module_errors = {},
        },

        registry = {
            version = 0,
            layers = {},
            layer_order = {},
            modules = {},
            module_order = {},
            next_module_id = 1,
            textures = {},
            overlays = {},
            overlay_order = {},
        },
        default_effect_slot_budget = 4,
        texture_slots_used = {},
        texture_array_sizes = {},
        default_texture_slot_budget = 2,

        declared_cards = {},
        card_defaults_queue = {},

        param_buffer = {
            rows = {},
            row_count = 0,
            slot_count = 1,
            effect_slot_stride = 0,
            stride = 4,
            -- TODO: Experiment with color formats
            format = "rgba16f",
            width = 0,
            height = 0,
            max_rows = 0,
            image_data = nil,
            image = nil,
            active = false,
        },
        occlusion_cache = {},
        occlusion_debug = {
            list = {},
            map = {},
        },
        order_map = {
            enabled = true,
            canvas = nil,
            shader = nil,
            mask_shader = nil,
            width = 0,
            height = 0,
            logical_width = 0,
            logical_height = 0,
            scale = 1,
            epsilon = 1 / 512,
            mask_layers = {
                back = true,
                center = true,
                front = true,
                sticker = true,
            },
            map_layers = {
                back = true,
                center = true,
                front = true,
            },
        },
        layer_order_values = {},
        layer_order_meshes = {},
        layer_order_vertices = {},
        layer_order_buffers = {},

        compat = {
            mode = "allow",
            cards = {},
            queue = {},
        },
    }
end

function state.ensure_layer_tables(br, layer)
    if not br.layer_batches[layer] then
        br.layer_batches[layer] = {}
    end
    if not br.layer_last_cleared[layer] then
        br.layer_last_cleared[layer] = {}
    end
    if not br.layer_sort_name[layer] then
        br.layer_sort_name[layer] = {}
    end
    if not br.layer_sorted_keys[layer] then
        br.layer_sorted_keys[layer] = {}
    end
    if br.layer_sorted_dirty[layer] == nil then
        br.layer_sorted_dirty[layer] = true
    end
    if not br.layer_atlas_image[layer] then
        br.layer_atlas_image[layer] = {}
    end
    if not br.layer_atlas_tile[layer] then
        br.layer_atlas_tile[layer] = {}
    end
    if not br.layer_atlas_dims[layer] then
        br.layer_atlas_dims[layer] = {}
    end
    if br.layer_shader_last_key[layer] == nil then
        br.layer_shader_last_key[layer] = nil
    end
    if not br.layer_order_values[layer] then
        br.layer_order_values[layer] = {}
    end
    if not br.layer_order_meshes[layer] then
        br.layer_order_meshes[layer] = {}
    end
    if not br.layer_order_vertices[layer] then
        br.layer_order_vertices[layer] = {}
    end
    if not br.layer_order_buffers[layer] then
        br.layer_order_buffers[layer] = {}
    end
end

function state.ensure_instance_tables(br, layer)
    if not br.layer_instances[layer] then
        br.layer_instances[layer] = {}
    end
    if not br.layer_sort_name[layer] then
        br.layer_sort_name[layer] = {}
    end
    if not br.layer_sorted_keys[layer] then
        br.layer_sorted_keys[layer] = {}
    end
    if br.layer_sorted_dirty[layer] == nil then
        br.layer_sorted_dirty[layer] = true
    end
    if not br.layer_atlas_image[layer] then
        br.layer_atlas_image[layer] = {}
    end
    if not br.layer_atlas_tile[layer] then
        br.layer_atlas_tile[layer] = {}
    end
    if not br.layer_atlas_dims[layer] then
        br.layer_atlas_dims[layer] = {}
    end
    if br.layer_shader_last_key[layer] == nil then
        br.layer_shader_last_key[layer] = nil
    end
end

return state
