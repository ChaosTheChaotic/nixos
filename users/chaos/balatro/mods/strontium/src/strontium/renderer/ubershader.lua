--- Ubershader

local ubershader = {}

local ALLOWED_EXTERNS = {
    time = true,
    atlas_size = true,
    tile_size = true,
    params_tex = true,
    params_size = true,
    params_stride = true,
    params_slot_stride = true,
    mouse_screen_pos = true,
    hovering = true,
    screen_scale = true,
}

local function sanitize_identifier(name)
    if not name then return "mod_unknown" end
    return (tostring(name):gsub("[^%w_]", "_"))
end

local function parse_externs(body)
    local found = {}
    local list = {}

    for name in body:gmatch("extern%s+[%w_]+%s+[%w_]+%s+([%w_]+)%s*;") do
        if not found[name] then
            found[name] = true
            list[#list + 1] = name
        end
    end

    for name in body:gmatch("extern%s+[%w_]+%s+([%w_]+)%s*;") do
        if not found[name] then
            found[name] = true
            list[#list + 1] = name
        end
    end

    return list
end

local function externs_supported(mod)
    if mod.externs then
        for i = 1, #mod.externs do
            local name = mod.externs[i]
            if not ALLOWED_EXTERNS[name] then
                return false, name
            end
        end
        return true
    end

    local body = mod.glsl_body
    if not body then return true end

    local cache = mod._externs_cache
    if cache and cache.body == body then
        if cache.ok then return true end
        return false, cache.bad
    end

    local externs = parse_externs(body)
    for i = 1, #externs do
        local name = externs[i]
        if not ALLOWED_EXTERNS[name] then
            mod._externs_cache = { body = body, ok = false, bad = name }
            return false, name
        end
    end
    mod._externs_cache = { body = body, ok = true }
    return true
end

local function hash_module_set(mods)
    local parts = {}
    for i = 1, #mods do
        local m = mods[i]
        local h = m.hash or m.version or 0
        parts[#parts + 1] = string.format("%s:%s:%s:%s:%s", m.key, h, m.params_count or 0, m.phase or "", m.priority or 0)
    end
    return table.concat(parts, "|")
end

local function module_supports_layer(mod, layer)
    if not mod then return false end
    if mod.layer == nil and mod.layers == nil then return true end
    if mod.layer == layer then return true end
    local layers = mod.layers
    if layers then
        if layers[layer] then return true end
        for i = 1, #layers do
            if layers[i] == layer then return true end
        end
    end
    return false
end

-- Header that precedes all batched shader modules.
local function build_header()
    return [[
#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

extern MY_HIGHP_OR_MEDIUMP float time;
extern MY_HIGHP_OR_MEDIUMP vec2 atlas_size;
extern MY_HIGHP_OR_MEDIUMP vec2 tile_size;
extern Image params_tex;
extern MY_HIGHP_OR_MEDIUMP vec2 params_size;
extern MY_HIGHP_OR_MEDIUMP float params_stride;
extern MY_HIGHP_OR_MEDIUMP float params_slot_stride;
extern MY_HIGHP_OR_MEDIUMP vec2 mouse_screen_pos;
extern MY_HIGHP_OR_MEDIUMP float hovering;
extern MY_HIGHP_OR_MEDIUMP float screen_scale;
extern Image order_map;
extern MY_HIGHP_OR_MEDIUMP vec2 order_map_size;
extern MY_HIGHP_OR_MEDIUMP float order_epsilon;

#ifdef VERTEX
attribute MY_HIGHP_OR_MEDIUMP float OrderValue;
#endif
varying MY_HIGHP_OR_MEDIUMP float v_order;

MY_HIGHP_OR_MEDIUMP float decode_byte(MY_HIGHP_OR_MEDIUMP float v) {
    return floor(v * 255.0 + 0.5);
}

vec2 sr_local_uv(vec2 uv) {
    vec2 ts = max(tile_size, vec2(1.0));
    vec2 uv_px = uv * atlas_size;
    return fract(uv_px / ts);
}

vec2 sr_floored_uv(vec2 local_uv, vec2 ts) {
    float max_dim = max(ts.x, ts.y);
    return floor(local_uv * ts) / max_dim;
}

MY_HIGHP_OR_MEDIUMP float sr_hue(MY_HIGHP_OR_MEDIUMP float s, MY_HIGHP_OR_MEDIUMP float t, MY_HIGHP_OR_MEDIUMP float h) {
    MY_HIGHP_OR_MEDIUMP float hs = mod(h, 1.0) * 6.0;
    if (hs < 1.0) return (t - s) * hs + s;
    if (hs < 3.0) return t;
    if (hs < 4.0) return (t - s) * (4.0 - hs) + s;
    return s;
}

vec4 sr_RGB(vec4 c) {
    if (c.y < 0.0001) return vec4(vec3(c.z), c.a);
    float t = (c.z < 0.5) ? c.y * c.z + c.z : -c.y * c.z + (c.y + c.z);
    float s = 2.0 * c.z - t;
    return vec4(sr_hue(s, t, c.x + 1.0 / 3.0), sr_hue(s, t, c.x), sr_hue(s, t, c.x - 1.0 / 3.0), c.w);
}

vec4 sr_HSL(vec4 c) {
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float delta = high - low;
    float sum = high + low;
    vec4 hsl = vec4(0.0, 0.0, 0.5 * sum, c.a);
    if (delta == 0.0) return hsl;

    hsl.y = (hsl.z < 0.5) ? delta / sum : delta / (2.0 - sum);
    if (high == c.r) hsl.x = (c.g - c.b) / delta;
    else if (high == c.g) hsl.x = (c.b - c.r) / delta + 2.0;
    else hsl.x = (c.r - c.g) / delta + 4.0;

    hsl.x = mod(hsl.x / 6.0, 1.0);
    return hsl;
}

vec4 read_params(MY_HIGHP_OR_MEDIUMP float row, MY_HIGHP_OR_MEDIUMP float slot) {
    if (params_size.x < 1.0 || params_size.y < 1.0) return vec4(0.0);
    if (slot < 0.0 || slot >= params_size.x) return vec4(0.0);
    MY_HIGHP_OR_MEDIUMP float u = (slot + 0.5) / params_size.x;
    MY_HIGHP_OR_MEDIUMP float v = (row + 0.5) / params_size.y;
    return Texel(params_tex, vec2(u, v));
}

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    v_order = OrderValue;
    return transform_projection * vertex_position;
}
#endif
]]
end

local function build_slot_cache(max_slots)
    local lines = {}
    lines[#lines + 1] = "bool sr_has_params = false;"

    if max_slots <= 0 then
        lines[#lines + 1] = "void sr_prefetch_params(MY_HIGHP_OR_MEDIUMP float row) { sr_has_params = false; }"
        lines[#lines + 1] = "bool fetch_effect_params_cached(MY_HIGHP_OR_MEDIUMP float target_id, out vec4 params0, out vec4 params1) {"
        lines[#lines + 1] = "    params0 = vec4(0.0);"
        lines[#lines + 1] = "    params1 = vec4(0.0);"
        lines[#lines + 1] = "    return false;"
        lines[#lines + 1] = "}"
        return table.concat(lines, "\n")
    end

    for i = 0, max_slots - 1 do
        lines[#lines + 1] = string.format("MY_HIGHP_OR_MEDIUMP vec4 sr_slot0_%d = vec4(0.0);", i)
        lines[#lines + 1] = string.format("MY_HIGHP_OR_MEDIUMP vec4 sr_slot1_%d = vec4(0.0);", i)
        lines[#lines + 1] = string.format("MY_HIGHP_OR_MEDIUMP float sr_id_%d = -1.0;", i)
    end

    lines[#lines + 1] = "void sr_prefetch_params(MY_HIGHP_OR_MEDIUMP float row) {"
    lines[#lines + 1] = "    sr_has_params = (params_size.x > 0.0 && params_size.y > 0.0 && params_stride >= 1.0 && params_slot_stride >= 1.0);"
    for i = 0, max_slots - 1 do
        lines[#lines + 1] = string.format("    sr_slot0_%d = vec4(0.0);", i)
        lines[#lines + 1] = string.format("    sr_slot1_%d = vec4(0.0);", i)
        lines[#lines + 1] = string.format("    sr_id_%d = -1.0;", i)
    end
    lines[#lines + 1] = "    if (!sr_has_params) return;"
    for i = 0, max_slots - 1 do
        lines[#lines + 1] = string.format("    MY_HIGHP_OR_MEDIUMP float sr_base_%d = params_slot_stride * %.1f;", i, i)
        lines[#lines + 1] = string.format("    if (params_stride > sr_base_%d) {", i)
        lines[#lines + 1] = string.format("        sr_slot0_%d = read_params(row, sr_base_%d);", i, i)
        lines[#lines + 1] = string.format("        sr_id_%d = floor(sr_slot0_%d.x + 0.5);", i, i)
        lines[#lines + 1] = string.format("        if (params_slot_stride > 1.0 && params_stride > (sr_base_%d + 1.0)) {", i)
        lines[#lines + 1] = string.format("            sr_slot1_%d = read_params(row, sr_base_%d + 1.0);", i, i)
        lines[#lines + 1] = "        }"
        lines[#lines + 1] = "    }"
    end
    lines[#lines + 1] = "}"

    lines[#lines + 1] = "bool fetch_effect_params_cached(MY_HIGHP_OR_MEDIUMP float target_id, out vec4 params0, out vec4 params1) {"
    lines[#lines + 1] = "    params0 = vec4(0.0);"
    lines[#lines + 1] = "    params1 = vec4(0.0);"
    lines[#lines + 1] = "    if (!sr_has_params) return false;"
    for i = 0, max_slots - 1 do
        lines[#lines + 1] = string.format("    if (sr_id_%d == target_id) {", i)
        lines[#lines + 1] = string.format("        params0 = vec4(sr_slot0_%d.y, sr_slot0_%d.z, sr_slot0_%d.w, sr_slot1_%d.x);", i, i, i, i)
        lines[#lines + 1] = string.format("        params1 = vec4(sr_slot1_%d.y, sr_slot1_%d.z, sr_slot1_%d.w, 0.0);", i, i, i)
        lines[#lines + 1] = "        return true;"
        lines[#lines + 1] = "    }"
    end
    lines[#lines + 1] = "    return false;"
    lines[#lines + 1] = "}"

    return table.concat(lines, "\n")
end

function ubershader.attach(br)
    -- Invalidate cached ubershader for a layer.
    function br:invalidate_ubershader(layer)
        if not layer then return end
        self.ubershader.cache[layer] = nil
        self.ubershader.hash[layer] = nil
        self.ubershader.errors[layer] = nil
        self.layer_uber_enabled[layer] = nil
    end

    -- Force all ubershaders to rebuild.
    function br:invalidate_all_ubershaders()
        local order = self.registry and self.registry.layer_order or nil
        if not order then return end
        for i = 1, #order do
            self:invalidate_ubershader(order[i])
        end
    end

    -- Get a layers batchable modules.
    function br:collect_layer_modules(layer)
        local registry = self.registry
        local version = registry and registry.version or 0
        local cache = self.ubershader and self.ubershader.layer_modules_cache
        local cached = cache and cache[layer]
        if cached and cached.version == version then
            return cached.list
        end

        local list = {}
        for key, mod in pairs(registry.modules) do
            if mod and module_supports_layer(mod, layer) then
                if not (mod.flags and mod.flags.batch_safe == false) then
                    local ok, extern = externs_supported(mod)
                    if ok then
                        self.ubershader.module_errors[key] = nil
                        list[#list + 1] = mod
                    else
                        self.ubershader.module_errors[key] = "extern_not_allowed:" .. tostring(extern)
                    end
                end
            end
        end
        local phase_order = { color = 1, overlay = 2, post = 3 }
        table.sort(list, function(a, b)
            local phase_a = phase_order[a.phase] or 2
            local phase_b = phase_order[b.phase] or 2
            if phase_a ~= phase_b then
                return phase_a < phase_b
            end
            local prio_a = a.priority or 0
            local prio_b = b.priority or 0
            if prio_a == prio_b then
                return (a.key or "") < (b.key or "")
            end
            return prio_a < prio_b
        end)
        if cache then
            cache[layer] = { version = version, list = list }
        end
        return list
    end

    -- Build an ubershader.
    function br:build_ubershader_source(layer, modules)
        local header = build_header()
        local bodies = {}
        local calls = {}
        local slot_budget = 0
        if self.get_effect_slot_budget then
            slot_budget = self:get_effect_slot_budget(layer) or 0
        else
            slot_budget = self.default_effect_slot_budget or 0
        end
        slot_budget = math.max(0, slot_budget or 0)
        local slot_cache = build_slot_cache(slot_budget)

        for i = 1, #modules do
            local mod = modules[i]
            local entry = mod.glsl_entry or mod.fn or ("mod_" .. sanitize_identifier(mod.key))
            mod._glsl_entry = entry

            if mod.glsl_body then
                local body = mod.glsl_body
                body = body:gsub("extern[^\n]*\n", "")
                bodies[#bodies + 1] = body
            end
        end

        for i = 1, #modules do
            local mod = modules[i]
            local entry = mod._glsl_entry
            local id = mod.id or 0
            local has_extended = mod.params and #mod.params > 4
            if has_extended then
                calls[#calls + 1] = string.format("if (fetch_effect_params_cached(%.1f, params0, params1)) { color = %s(color, uv, params0, params1); }", id, entry)
            else
                calls[#calls + 1] = string.format("if (fetch_effect_params_cached(%.1f, params0, params1)) { color = %s(color, uv, params0); }", id, entry)
            end
        end

        local param_block = [[
    MY_HIGHP_OR_MEDIUMP float param_lo = decode_byte(colour.b);
    MY_HIGHP_OR_MEDIUMP float param_hi = decode_byte(colour.a);
    MY_HIGHP_OR_MEDIUMP float param_index = param_lo + param_hi * 256.0;
    sr_prefetch_params(param_index);
]]

        local effect_body = [[
vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec4 color = tex;

    #if !defined(VERTEX)
    if (order_map_size.x > 0.0 && v_order >= 0.0) {
        vec2 om_uv = screen_coords / order_map_size;
        MY_HIGHP_OR_MEDIUMP float front = Texel(order_map, om_uv).r;
        if (front > 0.001 && (front - v_order) > order_epsilon) discard;
    }
    #endif

    vec2 uv = texture_coords;
    vec4 params0 = vec4(0.0);
    vec4 params1 = vec4(0.0);

%s
    %s

    return color;
}
]]

        return table.concat({
            header,
            slot_cache,
            table.concat(bodies, "\n"),
            string.format(effect_body, param_block, table.concat(calls, "\n    ")),
        }, "\n")
    end

    -- Build or fetch an ubershader
    function br:build_layer_shader(layer)
        if G and G.STRONTIUM_UBERSHADER == false then
            if layer then
                self.layer_uber_enabled[layer] = false
            end
            return nil
        end

        local modules = self:collect_layer_modules(layer)
        if #modules == 0 then
            self.layer_uber_enabled[layer] = false
            return nil
        end

        local hash = hash_module_set(modules)
        local cached = self.ubershader.cache[layer]
        if cached and self.ubershader.hash[layer] == hash then
            return cached
        end

        local source = self:build_ubershader_source(layer, modules)
        local ok, shader_obj = pcall(love.graphics.newShader, source)
        if not ok then
            print(string.format("[Strontium] Ubershader compile failed for layer '%s': %s", tostring(layer), tostring(shader_obj)))
            self.ubershader.cache[layer] = nil
            self.ubershader.hash[layer] = hash
            self.ubershader.errors[layer] = shader_obj
            self.layer_uber_enabled[layer] = false
            return nil
        end

        self.ubershader.cache[layer] = shader_obj
        self.ubershader.hash[layer] = hash
        self.ubershader.errors[layer] = nil
        self.layer_uber_enabled[layer] = true
        return shader_obj
    end
end

return ubershader
