--- Batch draw pass: render SpriteBatches by layer.

local draw = {}

function draw.attach(br)
    -- Draw all layers in order.
    function br:draw_layers()
        local count = 0
        local layers = self.registry.layer_order
        for i = 1, #layers do
            local layer = layers[i]
            local batches = self.layer_batches[layer]
            local shader_obj = self:apply_layer_shader(layer)
            if self.layer_sorted_dirty[layer] then
                local sorted = self.layer_sorted_keys[layer]
                -- GC_HACK: Reuse existing sorted table
                local n = 0
                for key in pairs(batches) do
                    n = n + 1
                    sorted[n] = key
                end
                for j = n + 1, #sorted do sorted[j] = nil end
                local sort_names = self.layer_sort_name[layer]
                table.sort(sorted, function(a, b)
                    return (sort_names[a] or a) < (sort_names[b] or b)
                end)
                self.layer_sorted_dirty[layer] = false
            end

            local keys = self.layer_sorted_keys[layer]
            for j = 1, #keys do
                local k = keys[j]
                local batch_obj = batches[k]

                if not (batch_obj and batch_obj:getCount() > 0) then
                    goto continue
                end

                if shader_obj then
                    self:send_layer_atlas_uniforms(layer, shader_obj, k)
                end
                love.graphics.draw(batch_obj, 0, 0)
                count = count + 1
                ::continue::
            end
        end
        self:clear_layer_shader()
        self.stats.batches = count
    end
end

return draw
