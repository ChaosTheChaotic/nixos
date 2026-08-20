--- Base adapter for drawhash ordering and card UI children.
local util = require('strontium.renderer.util')

local adapter = {}

local SKIP_CHILD_KEYS = {
    focused_ui = true,
    front = true,
    back = true,
    soul_parts = true,
    center = true,
    floating_sprite = true,
    shadow = true,
    use_button = true,
    buy_button = true,
    buy_and_use_button = true,
    debuff = true,
    price = true,
    particles = true,
    h_popup = true,
}

local function draw_child(child)
    if not child then return end
    love.graphics.push()
    child:translate_container()
    child:draw()
    love.graphics.pop()
end

function adapter.attach(br)

    local function draw_card_ui(card)
        if not (card and card.states and card.states.visible and card.children) then return end
        if card.area and card.area.config and card.area.config.type == "deck" then return end

        local children = card.children
        -- Sync child scale only when the card scale changes to avoid frame churn
        -- TODO: Might desync if child scales are adjusted
        local scale = card.VT.scale
        if card._strontium_ui_scale ~= scale then
            card._strontium_ui_scale = scale
            for _, v in pairs(children) do
                if not v.VT then goto continue end
                v.VT.scale = scale
                ::continue::
            end
        end

        draw_child(children.particles)
        draw_child(children.price)

        local is_highlighted = card.highlighted
        local is_focused = card.states and card.states.focus and card.states.focus.is
        local show_interactive = is_highlighted or is_focused

        if children.buy_button then
            if is_highlighted then
                children.buy_button.states.visible = true
                draw_child(children.buy_button)
                if children.buy_and_use_button then
                    draw_child(children.buy_and_use_button)
                end
            else
                children.buy_button.states.visible = false
            end
        end

        if not br.ui_layered_buttons then
            if children.use_button and is_highlighted then
                draw_child(children.use_button)
            end
        end

        for k, v in pairs(children) do
            if SKIP_CHILD_KEYS[k] then goto continue end
            draw_child(v)
            ::continue::
        end

        if show_interactive and card.area == G.hand and children.focused_ui then
            draw_child(children.focused_ui)
        end
    end

    -- Attempt to keep drawhash ordering stable with render order for hovers.
    function br:draw_drawhash()
        local queue = self.drawhash_queue
        if not queue then return end
        if G.STRONTIUM_SORT_X ~= false and not self.queue_sorted_by_x and #queue > 1 then
            table.sort(queue, util.sort_by_x)
        end
        for i = 1, #queue do
            if _G.add_to_drawhash then _G.add_to_drawhash(queue[i]) end
        end
    end

    -- Draw card UI elements after the main passes.
    -- HACK: I think that the entire draw_ui system needs to be rethought. Maybe a dedicated UI occlusion pass?
    function br:draw_ui()
        local queue = self.ui_queue
        if not queue then return end
        if G.STRONTIUM_SORT_X ~= false and not self.queue_sorted_by_x and #queue > 1 then
            table.sort(queue, util.sort_by_x)
        end
        for i = 1, #queue do
            draw_card_ui(queue[i])
        end
    end
end

return adapter
