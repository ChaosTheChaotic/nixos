--- Parameter buffer management for effect data.

local params = {}

function params.attach(br)
    local function ensure_fallback_image(pb)
        if pb.fallback_image then return pb.fallback_image end
        local ok, image_data = pcall(love.image.newImageData, 1, 1, "rgba8")
        if not ok then return nil end
        image_data:setPixel(0, 0, 0, 0, 0, 0)
        pb.fallback_image_data = image_data
        pb.fallback_image = love.graphics.newImage(image_data)
        pb.fallback_image:setFilter("nearest", "nearest")
        return pb.fallback_image
    end

    -- Alloc or resize the param buffer.
    function br:ensure_param_buffer(row_count, slot_count)
        local pb = self.param_buffer
        if not (pb and pb.active) then return nil end
        if not (love and love.image and love.image.newImageData) then return nil end
        if row_count <= 0 then return nil end

        local width = math.max(1, slot_count or pb.slot_count or 1)
        local height = pb.max_rows or 0
        if height < row_count then height = row_count end

        local needs_rebuild = (not pb.image_data) or pb.width ~= width or pb.height ~= height
        if needs_rebuild then
            local format = pb.format or "rgba16f"
            local ok, image_data = pcall(love.image.newImageData, width, height, format)
            if not ok then
                format = "rgba8"
                image_data = love.image.newImageData(width, height, format)
            end
            pb.image_data = image_data
            pb.image = love.graphics.newImage(image_data)
            pb.image:setFilter("nearest", "nearest")
            pb.format = format
            pb.width = width
            pb.height = height
        elseif not pb.image then
            pb.image = love.graphics.newImage(pb.image_data)
            pb.image:setFilter("nearest", "nearest")
        end

        pb.max_rows = height
        return pb.image_data
    end

    -- Submit package param to image buffer.
    function br:upload_param_buffer()
        local pb = self.param_buffer
        if not (pb and pb.active) then return end
        if pb.row_count <= 0 then return end
        if not pb.dirty then return end

        local image_data = self:ensure_param_buffer(pb.row_count, pb.slot_count)
        if not image_data then return end

        local stride = pb.stride or (pb.slot_count * 4)
        local slot_count = pb.slot_count or 1

        for row = 1, pb.row_count do
            local data = pb.rows[row]
            local base = 0
            for slot = 1, slot_count do
                local r = data and data[base + 1] or 0
                local g = data and data[base + 2] or 0
                local b = data and data[base + 3] or 0
                local a = data and data[base + 4] or 0
                image_data:setPixel(slot - 1, row - 1, r, g, b, a)
                base = base + 4
                if base >= stride then break end
            end
        end

        if pb.image and pb.image.replacePixels then
            pb.image:replacePixels(image_data)
        end
        pb.dirty = false
    end

    -- Bind the param buffer to a shader.
    function br:bind_param_buffer(shader)
        if not (shader and shader.hasUniform) then return end
        local pb = self.param_buffer
        if pb and pb.active and pb.image then
            if shader:hasUniform("params_tex") then
                shader:send("params_tex", pb.image)
            end
            if shader:hasUniform("params_size") then
                shader:send("params_size", { pb.width or 0, pb.height or 0 })
            end
            if shader:hasUniform("params_stride") then
                shader:send("params_stride", pb.slot_count or 1)
            end
            if shader:hasUniform("params_slot_stride") then
                shader:send("params_slot_stride", pb.effect_slot_stride or 0)
            end
            return
        end

        local fallback = pb and ensure_fallback_image(pb)
        if fallback and shader:hasUniform("params_tex") then
            shader:send("params_tex", fallback)
        end
        if shader:hasUniform("params_size") then
            shader:send("params_size", { 0, 0 })
        end
        if shader:hasUniform("params_stride") then
            shader:send("params_stride", 0)
        end
        if shader:hasUniform("params_slot_stride") then
            shader:send("params_slot_stride", 0)
        end
    end
end

return params
