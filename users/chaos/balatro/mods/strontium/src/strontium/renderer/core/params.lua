--- Parameter packing: pack_params, hash/dedupe helpers

local util = require('strontium.renderer.util')

local params = {}

local function hash_step(h, v)
    local iv = math.floor(v * 10000 + 0.5)
    return (h * 16777619 + iv) % 4294967296
end

function params.attach(br)
    -- Pack per-intent parameters for the ubershader.
    -- TODO: Optimize further, this is a strangely slow hot path. Likely due to pixel setting.
    function br:pack_params()
        local pb = self.param_buffer
        local rows = pb.rows
        local row_count = 0
        local used_params = false
        local effect_slot_stride = pb.effect_slot_stride

        if not effect_slot_stride or effect_slot_stride <= 0 then
            effect_slot_stride = 2
        end

        local prev_row_count = pb.row_count or 0
        local prev_slot_count = pb.slot_count or 0
        local prev_stride = pb.stride or 0
        local prev_slot_stride = pb.effect_slot_stride or 0
        local prev_active = pb.active
        local hash = 2166136261
        local max_effect_slot = -1

        local function hash_value(v)
            hash = hash_step(hash, v)
        end

        local function each_effect(intent, fn)
            local effects = self:resolve_intent_effects(intent)
            if effects and #effects > 0 then
                for i = 1, #effects do
                    local entry = effects[i]
                    fn(entry, entry.effect_slot or 0)
                end
                return
            end
            if effects == nil and intent.effect_key then
                fn(intent, intent.effect_slot or 0)
            end
        end

        for i = 1, #self.lanes.batch do
            local intent = self.lanes.batch[i]
            if not intent then goto continue end

            each_effect(intent, function(entry, slot)
                if slot > max_effect_slot then
                    max_effect_slot = slot
                end
                local key = entry.effect_key
                if key and self.registry.modules[key] then
                    used_params = true
                end
            end)
            ::continue::
        end

        local effect_slots = (max_effect_slot >= 0) and (max_effect_slot + 1) or 0
        local slot_count = (effect_slots > 0) and (effect_slots * effect_slot_stride) or 1

        if slot_count < 1 then
            slot_count = 1
        end

        local stride = slot_count * 4

        local function resolve_effect_params(intent, entry, module)
            local prms = entry.params
            if type(prms) == "function" then
                if entry == intent then
                    prms = prms(intent, module)
                else
                    prms = prms(intent, module, entry)
                end
            end
            if type(prms) ~= "table" then
                prms = nil
            end
            if prms and module and module.params_layout then
                local has_named = false
                for k in pairs(prms) do
                    if type(k) == "string" then
                        has_named = true
                        break
                    end
                end
                if has_named then
                    local mapped = {}
                    for i = 1, #module.params_layout do
                        local name = module.params_layout[i]
                        local v = prms[name]
                        if v == nil then
                            v = prms[i]
                        end
                        mapped[i] = v
                    end
                    prms = mapped
                end
            end
            if not prms and module and module.params_defaults then
                prms = module.params_defaults
            end
            return prms
        end

        -- TODO: Cleanup
        local dedupe_map = pb._dedupe_map
        local dedupe_keys = pb._dedupe_keys
        local dedupe_free = pb._dedupe_free
        if not dedupe_map then
            dedupe_map = {}
            pb._dedupe_map = dedupe_map
        end
        if not dedupe_keys then
            dedupe_keys = {}
            pb._dedupe_keys = dedupe_keys
        end
        if not dedupe_free then
            dedupe_free = {}
            pb._dedupe_free = dedupe_free
        end

        for i = 1, #dedupe_keys do
            local key = dedupe_keys[i]
            local bucket = dedupe_map[key]
            if type(bucket) == "table" then
                util.clear_array(bucket)
                dedupe_free[#dedupe_free + 1] = bucket
            end
            dedupe_map[key] = nil
        end
        util.clear_array(dedupe_keys)

        local function alloc_bucket()
            local bucket = dedupe_free[#dedupe_free]
            if bucket then
                dedupe_free[#dedupe_free] = nil
                return bucket
            end
            return {}
        end

        local function rows_equal(row_a, row_b)
            if not row_a or not row_b then return false end
            for j = 1, stride do
                if row_a[j] ~= row_b[j] then return false end
            end
            return true
        end

        local scratch = pb._row_scratch
        if not scratch then
            scratch = {}
            pb._row_scratch = scratch
        end

        local function copy_row(dst, src)
            for j = 1, stride do
                dst[j] = src[j]
            end
        end

        for i = 1, #self.lanes.batch do
            local intent = self.lanes.batch[i]
            if not intent then goto continue end

            for j = 1, stride do
                scratch[j] = 0
            end

            local row_hash = 2166136261
            each_effect(intent, function(entry, slot)
                local module = entry._module or (entry.effect_key and self.registry.modules[entry.effect_key] or nil)
                if not module then return end

                local base_slot = slot * effect_slot_stride
                local base = base_slot * 4
                if base + 1 > stride then return end

                local module_id = module.id or 0
                scratch[base + 1] = module_id
                row_hash = hash_step(row_hash, slot)
                row_hash = hash_step(row_hash, module_id)

                local prms = resolve_effect_params(intent, entry, module)
                local defaults = module and module.params_defaults or nil

                local function get_param(idx)
                    local v = prms and prms[idx]
                    if v == nil and defaults then v = defaults[idx] end
                    return v or 0
                end

                local p1 = get_param(1)
                local p2 = get_param(2)
                local p3 = get_param(3)
                scratch[base + 2] = p1
                scratch[base + 3] = p2
                scratch[base + 4] = p3
                row_hash = hash_step(row_hash, p1)
                row_hash = hash_step(row_hash, p2)
                row_hash = hash_step(row_hash, p3)

                if effect_slot_stride > 1 and (base + 5) <= stride then
                    local p4 = get_param(4)
                    local p5 = get_param(5)
                    local p6 = get_param(6)
                    local p7 = get_param(7)
                    scratch[base + 5] = p4
                    scratch[base + 6] = p5
                    scratch[base + 7] = p6
                    scratch[base + 8] = p7
                    row_hash = hash_step(row_hash, p4)
                    row_hash = hash_step(row_hash, p5)
                    row_hash = hash_step(row_hash, p6)
                    row_hash = hash_step(row_hash, p7)
                end
            end)

            local bucket = dedupe_map[row_hash]
            local matched = nil
            if bucket ~= nil then
                if type(bucket) == "number" then
                    if rows_equal(scratch, rows[bucket]) then
                        matched = bucket
                    else
                        local list = alloc_bucket()
                        list[1] = bucket
                        row_count = row_count + 1
                        local row = rows[row_count] or {}
                        rows[row_count] = row
                        copy_row(row, scratch)
                        list[2] = row_count
                        dedupe_map[row_hash] = list
                        matched = row_count
                        hash_value(row_count)
                        hash_value(row_hash)
                    end
                else
                    for b = 1, #bucket do
                        local idx = bucket[b]
                        if rows_equal(scratch, rows[idx]) then
                            matched = idx
                            break
                        end
                    end
                    if not matched then
                        row_count = row_count + 1
                        local row = rows[row_count] or {}
                        rows[row_count] = row
                        copy_row(row, scratch)
                        bucket[#bucket + 1] = row_count
                        matched = row_count
                        hash_value(row_count)
                        hash_value(row_hash)
                    end
                end
            else
                row_count = row_count + 1
                local row = rows[row_count] or {}
                rows[row_count] = row
                copy_row(row, scratch)
                dedupe_map[row_hash] = row_count
                dedupe_keys[#dedupe_keys + 1] = row_hash
                matched = row_count
                hash_value(row_count)
                hash_value(row_hash)
            end

            if matched then
                intent.param_index = matched - 1
            else
                intent.param_index = 0
            end
            intent.effect_id = 0
            ::continue::
        end

        pb.row_count = row_count
        pb.slot_count = slot_count
        pb.effect_slot_stride = used_params and effect_slot_stride or 0
        pb.stride = stride
        pb.active = used_params

        if self.stats then
            self.stats.param_rows = row_count
            self.stats.param_intents = #self.lanes.batch
        end

        hash_value(row_count)
        hash_value(slot_count)
        hash_value(pb.effect_slot_stride)
        hash_value(stride)

        local signature = used_params and hash or 0
        local dirty = false
        if row_count ~= prev_row_count or slot_count ~= prev_slot_count or stride ~= prev_stride
            or pb.effect_slot_stride ~= prev_slot_stride or pb.active ~= prev_active then
            dirty = true
        elseif signature ~= (pb.signature or 0) then
            dirty = true
        end
        if used_params and not pb.image then
            dirty = true
        end
        pb.signature = signature
        pb.dirty = used_params and dirty or false
    end
end

return params
