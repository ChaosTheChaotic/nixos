--- Instanced draw pass: render instance batches by layer.

local draw = {}

-- Resort instance keys when layer is dirty.
local function ensure_sorted_keys(br, layer, batches)
    if not br.layer_sorted_dirty[layer] then return end

    local sorted = br.layer_sorted_keys[layer]
    local n = 0
    for key in pairs(batches) do
        n = n + 1
        sorted[n] = key
    end
    for j = n + 1, #sorted do sorted[j] = nil end

    local sort_names = br.layer_sort_name[layer]
    table.sort(sorted, function(a, b)
        return (sort_names[a] or a) < (sort_names[b] or b)
    end)
    br.layer_sorted_dirty[layer] = false
end

function draw.attach(br)
    function br:draw_instances()
        -- Ensure order map shaders are compiled once
        if self.ensure_order_map_instanced_shaders then
            self:ensure_order_map_instanced_shaders()
        end

        local count = 0
        local layers = self.registry.layer_order
        love.graphics.setColor(1, 1, 1, 1)
        for i = 1, #layers do
            local layer = layers[i]
            local batches = self.layer_instances[layer]
            if not batches then
                goto continue_layer
            end
            local shader_obj = self:apply_layer_shader(layer)
            ensure_sorted_keys(self, layer, batches)

            local keys = self.layer_sorted_keys[layer]
            for j = 1, #keys do
                local k = keys[j]
                local batch = batches and batches[k] or nil
                if not (batch and batch.count and batch.count > 0) then
                    goto continue_batch
                end

                if shader_obj then
                    self:send_layer_atlas_uniforms(layer, shader_obj, k)
                end
                love.graphics.drawInstanced(batch.mesh, batch.count)
                count = count + 1
                ::continue_batch::
            end
            ::continue_layer::
        end

        self:clear_layer_shader()
        self.stats.batches = count
    end

    function br:draw_order_map_instanced()
        local om = self.order_map
        if om and G.STRONTIUM_ORDER_MAP ~= nil then
            om.enabled = (G.STRONTIUM_ORDER_MAP ~= false)
        end
        if not (om and om.enabled) then return end
        if not self.ensure_order_map_instanced_shaders then return end

        local shader_obj = self:ensure_order_map_instanced_shaders()
        if not shader_obj then return end

        local w, h
        if G and G.CANVAS and G.CANVAS.getDimensions then
            w, h = G.CANVAS:getDimensions()
        else
            local active = love.graphics.getCanvas()
            if active and active.getDimensions then
                w, h = active:getDimensions()
            else
                w, h = love.graphics.getDimensions()
            end
        end

        local scale = (G and G.STRONTIUM_ORDER_MAP_SCALE) or om.scale or 1
        scale = math.max(0.25, math.min(scale, 2.0))
        om.scale = scale

        local cw = math.max(1, math.floor(w * scale + 0.5))
        local ch = math.max(1, math.floor(h * scale + 0.5))

        if not (om.canvas and om.width == cw and om.height == ch) then
            local ok, canvas = pcall(love.graphics.newCanvas, cw, ch, { format = "rg8" })
            if not ok then
                canvas = love.graphics.newCanvas(cw, ch)
            end
            canvas:setFilter("nearest", "nearest")
            om.canvas = canvas
            om.width = cw
            om.height = ch
        end

        om.logical_width = w
        om.logical_height = h

        love.graphics.push("all")
        love.graphics.setCanvas(om.canvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(shader_obj)
        love.graphics.setBlendMode("lighten", "premultiplied")

        if om.scale and om.scale ~= 1 then
            love.graphics.push()
            love.graphics.scale(om.scale, om.scale)
        end

        local layers = self.registry.layer_order
        for i = 1, #layers do
            local layer = layers[i]
            if not (om.map_layers and om.map_layers[layer]) then
                goto continue
            end

            local batches = self.layer_instances[layer]
            if not batches then
                goto continue
            end

            ensure_sorted_keys(self, layer, batches)
            local keys = self.layer_sorted_keys[layer]
            for j = 1, #keys do
                local k = keys[j]
                local batch = batches[k]
                if batch and batch.count and batch.count > 0 then
                    love.graphics.drawInstanced(batch.mesh, batch.count)
                end
            end
            ::continue::
        end

        if om.scale and om.scale ~= 1 then
            love.graphics.pop()
        end

        love.graphics.pop()
    end
end

return draw
