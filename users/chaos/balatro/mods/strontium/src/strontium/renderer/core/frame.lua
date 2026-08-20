--- Frame management: reset_frame, occlusion helpers, intent pool

local util = require('strontium.renderer.util')

local frame = {}

function frame.attach(br)
    -- Reset per-frame state and clear batch buffers.
    function br:reset_frame()
        self.frame_id = (self.frame_id or 0) + 1
        self.stats.intents = 0
        self.stats.batch = 0
        self.stats.overlay = 0
        self.stats.immediate = 0
        self.stats.compat_discards = 0
        self.stats.batches = 0
        self.stats.cards_rendered = 0
        self.stats.param_rows = 0
        self.stats.param_intents = 0

        -- Recycle used intents back into the pool before clearing
        local pool = self.intent_pool
        local pool_count = self.intent_pool_count
        for i = 1, self.intent_count do
            local intent = self.intents[i]
            if not intent then goto continue end
            -- Clear fields but keep table for reuse
            for k in pairs(intent) do intent[k] = nil end
            pool_count = pool_count + 1
            pool[pool_count] = intent
            ::continue::
        end
        self.intent_pool_count = pool_count

        self.intent_count = 0
        util.clear_array(self.intents)
        util.clear_array(self.drawhash_queue)
        util.clear_array(self.ui_queue)
        self.queue_sorted_by_x = false

        util.clear_array(self.lanes.batch)
        util.clear_array(self.lanes.overlay)
        util.clear_array(self.lanes.immediate)
        if self.card_defaults_queue then
            util.clear_array(self.card_defaults_queue)
        end
        for layer, slots in pairs(self.texture_slots_used) do
            for k in pairs(slots) do
                slots[k] = nil
            end
        end
        for k in pairs(self.texture_array_sizes) do
            self.texture_array_sizes[k] = nil
        end

        self.param_buffer.row_count = 0
        self.param_buffer.active = false
        util.clear_array(self.compat.queue)
        for k in pairs(self.compat.cards) do
            self.compat.cards[k] = nil
        end
        for k in pairs(self.occlusion_cache) do
            self.occlusion_cache[k] = nil
        end
        if self.occlusion_debug then
            util.clear_array(self.occlusion_debug.list)
            for k in pairs(self.occlusion_debug.map) do
                self.occlusion_debug.map[k] = nil
            end
        end
        for layer, batches in pairs(self.layer_order_values) do
            for key, list in pairs(batches) do
                util.clear_array(list)
            end
        end

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

    -- Track occlusion decisions for debug visualization.
    function br:record_occlusion(card, reason)
        if not G.STRONTIUM_DEBUG_OCCLUSION then return end
        if not (card and self.occlusion_debug) then return end

        local id = card.ID or tostring(card)
        local map = self.occlusion_debug.map
        if not map[id] then
            local entry = { card = card, reason = reason }
            map[id] = entry
            self.occlusion_debug.list[#self.occlusion_debug.list + 1] = entry
        end
    end

    -- Compute visibility counts for non-occluded cards, like fans, etc.
    function br:get_visible_card_counts(area)
        if not (area and area.config) then return 999, 999, 999 end

        local cached = self.occlusion_cache[area]
        if cached then return cached.fully, cached.sticker, cached.face end

        local area_type = area.config.type
        if area_type ~= "joker" and area_type ~= "consumeable" and area_type ~= "title_2" and area_type ~= "hand" then
            self.occlusion_cache[area] = { fully = 999, sticker = 999, face = 999 }
            return 999, 999, 999
        end

        local card_count = #area.cards
        if card_count <= 2 then
            self.occlusion_cache[area] = { fully = card_count, sticker = card_count, face = card_count }
            return card_count, card_count, card_count
        end

        local area_w = (area.T and area.T.w) or 6
        local card_w = area.card_w or G.CARD_W or 1
        local spacing = (area_w - card_w) / (card_count - 1)
        local visible_ratio = spacing / card_w

        if visible_ratio >= 1.0 then
            self.occlusion_cache[area] = { fully = card_count, sticker = card_count, face = card_count }
            return card_count, card_count, card_count
        end

        local min_visible_ratio = G.STRONTIUM_MIN_VISIBLE_RATIO or 0.0
        local fully_visible_count = card_count
        if visible_ratio < min_visible_ratio then
            fully_visible_count = 1
        end

        -- Face culling uses a softer falloff so min_visible_ratio doesn't zero everything at once.
        local face_visible_count = card_count
        if min_visible_ratio > 0 and visible_ratio < min_visible_ratio then
            if visible_ratio <= 0 then
                face_visible_count = 1
            else
                local scale = visible_ratio / min_visible_ratio
                face_visible_count = math.max(1, math.floor(card_count * scale + 0.5))
            end
        end
        if face_visible_count > card_count then
            face_visible_count = card_count
        end

        local sticker_visible_count = fully_visible_count
        if visible_ratio < 0.25 then
            sticker_visible_count = 1
        elseif visible_ratio < 0.75 then
            sticker_visible_count = math.max(1, math.ceil(0.25 / (1 - visible_ratio)))
        end

        self.occlusion_cache[area] = {
            fully = fully_visible_count,
            sticker = sticker_visible_count,
            face = face_visible_count,
        }
        return fully_visible_count, sticker_visible_count, face_visible_count
    end

    -- Determine if the sticker region is hidden. Relevant for card fans.
    function br:is_sticker_region_covered(card)
        if G.STRONTIUM_CULL_COVERED == false then return false end
        if not (card and card.area and card.area.cards) then return false end

        local card_index = card._area_index
        if not (card_index and card.area.cards[card_index] == card) then
            for i, c in ipairs(card.area.cards) do
                if c == card then
                    card._area_index = i
                    card_index = i
                    break
                end
            end
        end

        if not card_index then return false end

        local _, sticker_visible_count = self:get_visible_card_counts(card.area)
        local card_count = #card.area.cards
        local position_from_right = card_count - card_index + 1
        local covered = position_from_right > sticker_visible_count
        if covered then
            self:record_occlusion(card, "sticker")
        end
        return covered
    end

    -- Determine if the face region is hidden.
    function br:is_face_region_covered(card)
        if G.STRONTIUM_CULL_COVERED == false then return false end
        if not (card and card.area and card.area.cards) then return false end

        local card_index = card._area_index
        if not (card_index and card.area.cards[card_index] == card) then
            for i, c in ipairs(card.area.cards) do
                if c == card then
                    card._area_index = i
                    card_index = i
                    break
                end
            end
        end

        if not card_index then return false end

        local _, _, face_visible_count = self:get_visible_card_counts(card.area)
        local card_count = #card.area.cards
        local position_from_right = card_count - card_index + 1
        local covered = position_from_right > face_visible_count
        if covered then
            self:record_occlusion(card, "face")
        end
        return covered
    end
end

return frame
