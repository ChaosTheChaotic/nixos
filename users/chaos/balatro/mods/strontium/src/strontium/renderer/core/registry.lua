--- Registry management: register layers, effects, overlays, textures

local state = require('strontium.renderer.state')

local registry = {}

local function bump_registry_version(br)
    if not (br and br.registry) then return end
    br.registry.version = (br.registry.version or 0) + 1
    if br.ubershader and br.ubershader.layer_modules_cache then
        br.ubershader.layer_modules_cache = {}
    end
    if br.instancing then
        br.instancing.cache = {}
        br.instancing.hash = {}
        br.instancing.errors = {}
        br.instancing.module_errors = {}
    end
end

local function normalize_effect_def(def)
    if def.glsl and not def.glsl_body then
        def.glsl_body = def.glsl
    end
    if def.params and not def.params_layout then
        def.params_layout = def.params
    end
    if def.layers and type(def.layers) == "string" then
        def.layers = { def.layers }
    end
    if def.phase == nil then
        def.phase = "color"
    end
    if def.params_layout and not def.params_index then
        local index = {}
        for i = 1, #def.params_layout do
            index[def.params_layout[i]] = i
        end
        def.params_index = index
    end
    if def.params_count == nil and def.params_layout then
        def.params_count = #def.params_layout
    end
    if def.params_count == nil and def.params_defaults then
        def.params_count = #def.params_defaults
    end
    if def.params_slots == nil and def.params_count then
        def.params_slots = math.max(1, math.ceil(def.params_count / 4))
    end
    if def.flags == nil and def.batch_safe ~= nil then
        def.flags = { batch_safe = def.batch_safe }
    end
    if def.params_layout and def.params_defaults then
        local defaults = def.params_defaults
        local has_named = false
        for k in pairs(defaults) do
            if type(k) == "string" then
                has_named = true
                break
            end
        end
        if has_named then
            local mapped = {}
            for i = 1, #def.params_layout do
                local name = def.params_layout[i]
                mapped[i] = defaults[name]
            end
            def.params_defaults = mapped
        end
    end
    if def.params_count and def.params_count > 0 and def.params_defaults then
        for i = #def.params_defaults + 1, def.params_count do
            def.params_defaults[i] = 0
        end
        for i = def.params_count + 1, #def.params_defaults do
            def.params_defaults[i] = nil
        end
    end
    if def.params_count and def.params_count > 4 then
        local flags = def.flags
        if not (flags and flags.allow_multi_slot) then
            def.flags = flags or {}
            def.flags.batch_safe = false
            def.contract_error = "params_count_exceeds_limit"
        end
    end
end

function registry.attach(br)
    -- Register render layer and init cache tables.
    function br:register_layer(def)
        if not def or not def.key then return end
        if self.registry.layers[def.key] then return end

        local key = def.key
        self.registry.layers[key] = def

        if def.shader or def.shader_key then
            self.layer_shaders[key] = def.shader or def.shader_key
        end

        self.registry.layer_order[#self.registry.layer_order + 1] = key
        table.sort(self.registry.layer_order, function(a, b)
            return (self.registry.layers[a].order or 0) < (self.registry.layers[b].order or 0)
        end)

        state.ensure_layer_tables(self, key)
        bump_registry_version(self)
    end

    -- Register shader module def for composition.
    function br:register_effect(def)
        if not def or not def.key then return end
        local existing = self.registry.modules[def.key]
        if existing then
            def.id = def.id or existing.id
            normalize_effect_def(def)
            self.registry.modules[def.key] = def
            if def.layer and self.invalidate_ubershader then
                self:invalidate_ubershader(def.layer)
            end
            if def.layer and self.invalidate_instanced_shader then
                self:invalidate_instanced_shader(def.layer)
            end
            bump_registry_version(self)
            return
        end
        if not def.id then
            def.id = self.registry.next_module_id or 1
            self.registry.next_module_id = def.id + 1
        end
        normalize_effect_def(def)
        self.registry.modules[def.key] = def
        self.registry.module_order[#self.registry.module_order + 1] = def.key
        if def.layer and self.invalidate_ubershader then
            self:invalidate_ubershader(def.layer)
        end
        if def.layer and self.invalidate_instanced_shader then
            self:invalidate_instanced_shader(def.layer)
        end
        bump_registry_version(self)
    end

    -- Register optional overlay draw hook.
    function br:register_overlay(def)
        if not def or not def.key then return end
        local overlays = self.registry.overlays
        local order = self.registry.overlay_order
        local key = def.key
        if not overlays[key] then
            order[#order + 1] = key
        end
        overlays[key] = def
        table.sort(order, function(a, b)
            local da = overlays[a]
            local db = overlays[b]
            local oa = (da and da.order) or 0
            local ob = (db and db.order) or 0
            if oa == ob then
                return tostring(a) < tostring(b)
            end
            return oa < ob
        end)
        bump_registry_version(self)
    end

    -- Register a batch-safe texture contract.
    -- TODO: Implement batched integration, current only overlays can use this.
    function br:register_texture(def)
        if not def or not def.key then return end
        self.registry.textures[def.key] = def
        bump_registry_version(self)
    end

    -- Register default layers in canonical order.
    function br:register_defaults()
        for i = 1, #state.DEFAULT_LAYERS do
            self:register_layer(state.DEFAULT_LAYERS[i])
        end
    end
end

-- Expose helpers for other modules
registry.bump_registry_version = bump_registry_version
registry.normalize_effect_def = normalize_effect_def

return registry
