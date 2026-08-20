--- Immediate and overlay draw passes.

local perf = require('strontium.perf')

local draw = {}

local _get_time = (love and love.timer and love.timer.getTime) or os.clock

function draw.attach(br)
    function br:draw_overlays()
        local overlays = self.registry and self.registry.overlays or nil
        for i = 1, #self.lanes.overlay do
            local intent = self.lanes.overlay[i]
            if not intent then goto continue end

            local overlay_def = (intent.overlay_key and overlays and overlays[intent.overlay_key]) or nil
            local draw_fn = intent.draw or (overlay_def and overlay_def.draw)
            if draw_fn then
                draw_fn(intent.card, intent, overlay_def)
                goto continue
            end

            local params = self:compute_draw_params(intent)
            if not params then goto continue end

            local color = intent.color or G.C.WHITE
            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            love.graphics.draw(params.atlas.image, params.quad, params.x, params.y, params.r, params.sx, params.sy, params.ox, params.oy)
            ::continue::
        end
    end

    function br:draw_immediate()
        for i = 1, #self.compat.queue do
            local card = self.compat.queue[i]
            if not (card and card.draw) then goto continue end
            love.graphics.push()
            card:translate_container()
            card:draw()
            love.graphics.pop()
            ::continue::
        end

        for i = 1, #self.lanes.immediate do
            local intent = self.lanes.immediate[i]
            if not intent then goto continue end
            local params = self:compute_draw_params(intent)
            if not params then goto continue end
            local color = intent.color or G.C.WHITE
            love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
            love.graphics.draw(params.atlas.image, params.quad, params.x, params.y, params.r, params.sx, params.sy, params.ox, params.oy)
            ::continue::
        end
    end

    -- Debug overlay for occlusion culling.
    -- TODO: Should be removed, not very useful.
    function br:draw_occlusion_debug()
        if not G.STRONTIUM_DEBUG_OCCLUSION then return end
        local dbg = self.occlusion_debug
        if not (dbg and dbg.list and #dbg.list > 0) then return end

        love.graphics.setLineWidth(1)
        for i = 1, #dbg.list do
            local entry = dbg.list[i]
            local card = entry.card
            local sprite = card and (card.children and (card.children.center or card.children.back)) or nil
            if not sprite then goto continue end
            local params = self:compute_draw_params({ sprite_ref = sprite })
            if not (params and params.atlas and params.atlas.px and params.atlas.py) then
                goto continue
            end

            local w = params.atlas.px * params.sx
            local h = params.atlas.py * params.sy
            local mark_w = w * 0.25
            local mark_h = h * 0.25

            love.graphics.push()
            love.graphics.translate(params.x, params.y)
            if params.r and params.r ~= 0 then
                love.graphics.rotate(params.r)
            end

            love.graphics.setColor(1, 0.2, 0.2, 0.85)
            love.graphics.rectangle("line", -w / 2, -h / 2, w, h)
            love.graphics.setColor(1, 0.1, 0.1, 0.35)
            love.graphics.rectangle("fill", w / 2 - mark_w, -h / 2, mark_w, mark_h)

            love.graphics.pop()
            ::continue::
        end
    end

    -- Top-level draw loop.
    -- TODO: Cleanup profiling code, makes this unreadable
    function br:draw_frame()
        local draw_start = _get_time()
        if self.flush_card_defaults then
            perf.begin("draw.flush_defaults")
            self:flush_card_defaults()
            perf.finish("draw.flush_defaults")
        end

        perf.begin("draw.classify_intents")
        self:classify_intents()
        perf.finish("draw.classify_intents")

        if not G or G.STRONTIUM_UBERSHADER ~= false then
            perf.begin("draw.pack_params")
            self:pack_params()
            perf.finish("draw.pack_params")

            if self.upload_param_buffer then
                perf.begin("draw.upload_params")
                self:upload_param_buffer()
                perf.finish("draw.upload_params")
            end
        end

        local use_instancing = (G and G.STRONTIUM_INSTANCING) == true
        if use_instancing and self.build_instances then
            perf.begin("draw.build_instances")
            self:build_instances()
            perf.finish("draw.build_instances")

            if self.draw_order_map_instanced then
                perf.begin("draw.order_map")
                self:draw_order_map_instanced()
                perf.finish("draw.order_map")
            end

            perf.begin("draw.instances")
            self:draw_instances()
            perf.finish("draw.instances")
        else
            perf.begin("draw.build_batches")
            self:build_batches()
            perf.finish("draw.build_batches")

            if self.build_order_attributes then
                perf.begin("draw.order_attributes")
                self:build_order_attributes()
                perf.finish("draw.order_attributes")
            end

            if self.draw_order_map then
                perf.begin("draw.order_map")
                self:draw_order_map()
                perf.finish("draw.order_map")
            end

            perf.begin("draw.layers")
            self:draw_layers()
            perf.finish("draw.layers")
        end

        perf.begin("draw.drawhash")
        self:draw_drawhash()
        perf.finish("draw.drawhash")

        perf.begin("draw.overlays")
        self:draw_overlays()
        perf.finish("draw.overlays")

        perf.begin("draw.immediate")
        self:draw_immediate()
        perf.finish("draw.immediate")

        perf.begin("draw.ui")
        self:draw_ui()
        perf.finish("draw.ui")

        perf.begin("draw.occlusion_debug")
        self:draw_occlusion_debug()
        perf.finish("draw.occlusion_debug")

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setShader()
        self.active_shader = nil
        if self.stats then
            self.stats.draw_ms = (_get_time() - draw_start) * 1000
        end
    end
end

return draw
