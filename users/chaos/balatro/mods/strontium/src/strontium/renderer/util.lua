--- Utils, mostly renderer-related.

local util = {}

-- Cached sort comparator for X-position sorting
function util.sort_by_x(a, b)
    local ax = a.VT and a.VT.x or (a.T and a.T.x or 0)
    local bx = b.VT and b.VT.x or (b.T and b.T.x or 0)
    return ax < bx
end

-- Clear an array-like table without reallocating.
function util.clear_array(t)
    local n = #t
    for i = n, 1, -1 do
        rawset(t, i, nil)
    end
end

-- Apply container transform chain to a world-space position/rotation.
-- This was mostly ported from the base-game Node:translate_container()
function util.apply_container_transform(obj, x, y, r)
    local container = obj.container
    if not container or container == obj then return x, y, r end

    local ct = container.T
    local scale_px = G.TILESCALE * G.TILESIZE

    local w2 = (ct.w or 0) * scale_px * 0.5
    local h2 = (ct.h or 0) * scale_px * 0.5
    local cx = (ct.x or 0) * scale_px
    local cy = (ct.y or 0) * scale_px
    local cr = ct.r or 0

    -- Convert into container space with the container center as the pivot.
    -- This mirrors Node:translate_container() so batched sprites align with vanilla draws.
    local px = x - w2 + cx
    local py = y - h2 + cy

    if cr ~= 0 then
        -- Rotate around the container center.
        local cos_r = math.cos(cr)
        local sin_r = math.sin(cr)
        local rx = px * cos_r - py * sin_r
        local ry = px * sin_r + py * cos_r
        px, py = rx, ry
    end

    x, y, r = px + w2, py + h2, r + cr
    return util.apply_container_transform(container, x, y, r)
end

function util.apply_all_container_transforms(obj, x, y, r)
    -- Walk up container/area/parent to match nested UI/CardArea transforms.
    -- I still have a hard time understanding why this works or is necessary.
    if not obj then return x, y, r end
    if obj.container then
        return util.apply_container_transform(obj, x, y, r)
    end
    return util.apply_all_container_transforms(obj.area or obj.parent, x, y, r)
end

-- Normalize lane policy to a known value.
function util.normalize_lane_policy(policy)
    if policy == "force_batch" or policy == "force_overlay" or policy == "force_immediate" then
        return policy
    end
    return "allow_fallback"
end

return util
