local components = {}

local function pick(colors, key, fallback)
    if colors and colors[key] then
        return colors[key]
    end
    return fallback
end

function components.draw_button(x, y, w, h, label, hovered, colors)
    local bg = pick(colors, "button_bg", {0.2, 0.35, 0.5, 0.9})
    local bg_hover = pick(colors, "button_bg_hover", {0.3, 0.5, 0.7, 1.0})
    local text = pick(colors, "button_text", {0.9, 0.95, 1.0, 1.0})

    love.graphics.setColor(hovered and bg_hover or bg)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    love.graphics.setColor(text)
    local font = love.graphics.getFont()
    local text_w = font:getWidth(label)
    local text_h = font:getHeight()
    love.graphics.print(label, x + (w - text_w) / 2, y + (h - text_h) / 2)
end

function components.draw_toggle(x, y, w, h, value, hovered, colors)
    local bg = pick(colors, "toggle_bg", {0.15, 0.15, 0.2, 0.9})
    local border = pick(colors, "toggle_border", {0.3, 0.4, 0.5, 0.8})
    local border_hover = pick(colors, "toggle_border_hover", border)
    local on = pick(colors, "toggle_on", {0.3, 0.8, 0.4, 1.0})
    local off = pick(colors, "toggle_off", {0.4, 0.4, 0.45, 0.8})

    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", x, y, w, h, h / 2, h / 2)

    love.graphics.setColor(hovered and border_hover or border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, h / 2, h / 2)

    local knob_x = value and (x + w - h + 2) or (x + 2)
    local knob_r = h / 2 - 2
    love.graphics.setColor(value and on or off)
    love.graphics.circle("fill", knob_x + knob_r, y + h / 2, knob_r)
end

function components.draw_stepper(x, y, w, h, value, hovered_minus, hovered_plus, colors, fmt)
    local btn_w = h
    local minus_x = x
    local plus_x = x + w - btn_w
    components.draw_button(minus_x, y, btn_w, h, "-", hovered_minus, colors)
    components.draw_button(plus_x, y, btn_w, h, "+", hovered_plus, colors)

    local text = fmt and string.format(fmt, value) or tostring(value)
    love.graphics.setColor(pick(colors, "button_text", {0.9, 0.95, 1.0, 1.0}))
    love.graphics.print(text, x + btn_w + 6, y + 1)
end

return components
