--- Base game effects and shader glue.

local effects = {}

local CARD_LAYERS = { "shadow", "back", "center", "front", "sticker", "floating" }

local DISSOLVE_GLSL = [[
vec4 mod_dissolve(vec4 color, vec2 uv, vec4 params) {
    float dissolve = clamp(params.x, 0.0, 1.0);
    float burn_alpha = max(max(params.y, params.z), params.w);
    vec4 burn_colour_1 = vec4(params.y, params.z, params.w, burn_alpha);
    vec4 burn_colour_2 = vec4(0.0);
    float shadow = 0.0;

    vec2 ts = max(tile_size, vec2(1.0));
    vec2 local_uv = sr_local_uv(uv);
    vec2 floored_uv = sr_floored_uv(local_uv, ts);

    if (dissolve < 0.001) {
        return vec4(shadow > 0.5 ? vec3(0.0) : color.rgb, shadow > 0.5 ? color.a * 0.3 : color.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;

    float t = time * 10.0 + 2003.0;
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(ts.x, ts.y);

    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos( t / 53.1532), cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.0 + (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92))) / 2.0;
    vec2 borders = vec2(0.2, 0.8);

    float res = (0.5 + 0.5 * cos((adjusted_dissolve) / 82.612 + (field - 0.5) * 3.14))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;

    vec4 tex = color;
    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && shadow < 0.5 && res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
            tex = burn_colour_1;
        } else if (burn_colour_2.a > 0.01) {
            tex = burn_colour_2;
        }
    }

    float out_a = res > adjusted_dissolve ? (shadow > 0.5 ? tex.a * 0.3 : tex.a) : 0.0;
    vec3 out_rgb = shadow > 0.5 ? vec3(0.0) : tex.rgb;
    return vec4(out_rgb, out_a);
}
]]

local VOUCHER_GLSL = [[
vec4 mod_voucher(vec4 color, vec2 uv, vec4 params) {
    vec2 voucher = params.xy;
    vec2 local_uv = sr_local_uv(uv);
    float phase = time / 18.0 + voucher.x * 10.0;
    float phase2 = time + voucher.y * 10.0;

    float low = min(color.r, min(color.g, color.b));
    float high = max(color.r, max(color.g, color.b));
    float delta = high - low;

    float fac = 0.8 + 0.9 * sin(13.0 * local_uv.x + 5.32 * local_uv.y + phase * 12.0 + cos(phase * 5.3 + local_uv.y * 4.2 - local_uv.x * 4.0));
    float fac2 = 0.5 + 0.5 * sin(10.0 * local_uv.x + 2.32 * local_uv.y + phase2 * 5.0 - cos(phase2 * 2.3 + local_uv.x * 8.2));
    float fac3 = 0.5 + 0.5 * sin(12.0 * local_uv.x + 6.32 * local_uv.y + phase * 6.111 + sin(phase2 * 5.3 + local_uv.y * 3.2));
    float fac4 = 0.5 + 0.5 * sin(4.0 * local_uv.x + 2.32 * local_uv.y + phase2 * 8.111 + sin(phase * 1.3 + local_uv.y * 13.2));
    float fac5 = sin(0.5 * 16.0 * local_uv.x + 5.32 * local_uv.y + phase * 12.0 + cos(phase2 * 5.3 + local_uv.y * 4.2 - local_uv.x * 4.0));

    float maxfac = 0.6 * max(max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.0);

    vec4 tex = color;
    tex.rgb = tex.rgb * 0.5 + vec3(0.4, 0.4, 0.8);

    tex.r = tex.r - delta + delta * maxfac * (0.7 + fac5 * 0.07) - 0.1;
    tex.g = tex.g - delta + delta * maxfac * (0.7 - fac5 * 0.17) - 0.1;
    tex.b = tex.b - delta + delta * maxfac * 0.7 - 0.1;
    tex.a = tex.a * (0.8 * max(min(1.0, max(0.0, 0.3 * max(low * 0.2, delta) + min(max(maxfac * 0.1, 0.0), 0.4))), 0.0) + 0.15 * maxfac * (0.1 + delta));

    return tex;
}
]]

local DEBUFF_GLSL = [[
vec4 mod_debuff(vec4 color, vec2 uv, vec4 params) {
    vec2 debuff = params.xy;
    vec2 local_uv = sr_local_uv(uv);

    vec4 tex = color;
    vec4 sat = sr_HSL(tex * 0.8 + 0.2 * vec4(1.0, 0.0, 0.0, tex.a));
    sat.g = 0.5;

    float width = 0.0;
    if (debuff.y > 0.0 || debuff.y < 0.0) {
        width = 0.1;
    }

    bool test = false;
    if ((local_uv.x + local_uv.y > 1.0 - width && local_uv.x + local_uv.y < 1.0 + width) ||
        ((1.0 - local_uv.x) + local_uv.y > 1.0 - width && (1.0 - local_uv.x) + local_uv.y < 1.0 + width)) {
        test = true;
        sat.r = 1.0;
        sat.g = 0.7;
        sat.b = 0.8 * sat.b;
    } else {
        sat.g = sat.g * 0.5;
        sat.b = sat.b * 0.7;
    }

    tex = sr_RGB(sat);
    if (!test) {
        tex.a = tex.a * 0.3;
    }

    return tex;
}
]]

local PLAYED_GLSL = [[
vec4 mod_played(vec4 color, vec2 uv, vec4 params) {
    vec2 played = params.xy;
    vec4 tex = color;

    vec4 sat = sr_HSL(tex);
    sat.g = sat.g * 0.5 + 0.000001 * played.x;
    sat.b = sat.b * 0.8;

    tex = sr_RGB(sat);
    tex.a = tex.a * 0.5;
    return tex;
}
]]

local FOIL_GLSL = [[
vec4 mod_foil(vec4 color, vec2 uv, vec4 params) {
    vec2 foil = params.xy;
    vec2 ts = max(tile_size, vec2(1.0));
    vec2 local_uv = sr_local_uv(uv);
    float phase = time / 28.0 + foil.x * 10.0;
    float tfast = time + foil.y * 10.0;

    vec2 adjusted_uv = local_uv - vec2(0.5);
    adjusted_uv.x = adjusted_uv.x * (ts.x / ts.y);

    float low = min(color.r, min(color.g, color.b));
    float high = max(color.r, max(color.g, color.b));
    float delta = min(high, max(0.5, 1.0 - low));

    float fac = max(min(2.0 * sin((length(90.0 * adjusted_uv) + phase * 2.0) +
        3.0 * (1.0 + 0.8 * cos(length(113.1121 * adjusted_uv) - phase * 3.121))) - 1.0 -
        max(5.0 - length(90.0 * adjusted_uv), 0.0), 1.0), 0.0);
    vec2 rotater = vec2(cos(phase * 0.1221), sin(phase * 0.3512));
    float angle = dot(rotater, adjusted_uv) / (length(rotater) * max(length(adjusted_uv), 0.0001));
    float fac2 = max(min(5.0 * cos(tfast * 0.3 + angle * 3.14 * (2.2 + 0.9 * sin(phase * 1.65 + 0.2 * tfast))) - 4.0 -
        max(2.0 - length(20.0 * adjusted_uv), 0.0), 1.0), 0.0);
    float fac3 = 0.3 * max(min(2.0 * sin(phase * 5.0 + local_uv.x * 3.0 +
        3.0 * (1.0 + 0.5 * cos(phase * 7.0))) - 1.0, 1.0), -1.0);
    float fac4 = 0.3 * max(min(2.0 * sin(phase * 6.66 + local_uv.y * 3.8 +
        3.0 * (1.0 + 0.5 * cos(phase * 3.414))) - 1.0, 1.0), -1.0);

    float maxfac = max(max(fac, max(fac2, max(fac3, max(fac4, 0.0)))) + 2.2 * (fac + fac2 + fac3 + fac4), 0.0);

    vec4 tex = color;
    tex.r = tex.r - delta + delta * maxfac * 0.3;
    tex.g = tex.g - delta + delta * maxfac * 0.3;
    tex.b = tex.b + delta * maxfac * 1.9;
    tex.a = min(tex.a, 0.3 * tex.a + 0.9 * min(0.5, maxfac * 0.1));

    return tex;
}
]]

local HOLO_GLSL = [[
vec4 mod_holo(vec4 color, vec2 uv, vec4 params) {
    vec2 holo = params.xy;
    vec2 ts = max(tile_size, vec2(1.0));
    vec2 local_uv = sr_local_uv(uv);
    float phase = time / 28.0 + holo.x * 10.0;

    vec4 tex = color;
    vec4 hsl = sr_HSL(0.5 * tex + 0.5 * vec4(0.0, 0.0, 1.0, tex.a));

    float t = time * 8.221 + holo.y * 10.0;
    vec2 floored_uv = floor(local_uv * ts) / ts;
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 250.0;

    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos( t / 53.1532), cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.0 + (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92))) / 2.0;

    float res = (0.5 + 0.5 * cos(phase * 2.612 + (field - 0.5) * 3.14));

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = 0.2 + 0.3 * (high - low) + 0.1 * high;

    float gridsize = 0.79;
    float fac = 0.5 * max(
        max(max(0.0, 7.0 * abs(cos(local_uv.x * gridsize * 20.0)) - 6.0),
            max(0.0, 7.0 * cos(local_uv.y * gridsize * 45.0 + local_uv.x * gridsize * 20.0) - 6.0)),
        max(0.0, 7.0 * cos(local_uv.y * gridsize * 45.0 - local_uv.x * gridsize * 20.0) - 6.0)
    );

    hsl.x = hsl.x + res + fac;
    hsl.y = hsl.y * 1.3;
    hsl.z = hsl.z * 0.6 + 0.4;

    tex = (1.0 - delta) * tex + delta * sr_RGB(hsl) * vec4(0.9, 0.8, 1.2, tex.a);
    if (tex.a < 0.7) {
        tex.a = tex.a / 3.0;
    }
    return tex;
}
]]

local POLYCHROME_GLSL = [[
vec4 mod_polychrome(vec4 color, vec2 uv, vec4 params) {
    vec2 polychrome = params.xy;
    vec2 ts = max(tile_size, vec2(1.0));
    vec2 local_uv = sr_local_uv(uv);
    float phase = time / 28.0 + polychrome.x * 10.0;

    float low = min(color.r, min(color.g, color.b));
    float high = max(color.r, max(color.g, color.b));
    float delta = high - low;

    float saturation_fac = 1.0 - max(0.0, 0.05 * (1.1 - delta));
    vec4 hsl = sr_HSL(vec4(color.r * saturation_fac, color.g * saturation_fac, color.b, color.a));

    float t = time * 3.221 + polychrome.y * 10.0;
    vec2 floored_uv = sr_floored_uv(local_uv, ts);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 50.0;

    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos( t / 53.1532), cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.0 + (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92))) / 2.0;

    float res = (0.5 + 0.5 * cos(phase * 2.612 + (field - 0.5) * 3.14));
    hsl.x = hsl.x + res + time * 0.04 + polychrome.y * 0.04;
    hsl.y = min(0.6, hsl.y + 0.5);

    vec4 tex = color;
    tex.rgb = sr_RGB(hsl).rgb;
    if (tex.a < 0.7) {
        tex.a = tex.a / 3.0;
    }
    return tex;
}
]]

local NEGATIVE_GLSL = [[
vec4 mod_negative(vec4 color, vec2 uv, vec4 params) {
    vec4 tex = color;
    vec4 sat = sr_HSL(tex);

    sat.b = (1.0 - sat.b);
    sat.r = -sat.r + 0.2;

    tex = sr_RGB(sat) + 0.8 * vec4(79.0 / 255.0, 99.0 / 255.0, 103.0 / 255.0, 0.0);
    if (tex.a < 0.7) {
        tex.a = tex.a / 3.0;
    }
    return tex;
}
]]

local NEGATIVE_SHINE_GLSL = [[
vec4 mod_negative_shine(vec4 color, vec2 uv, vec4 params) {
    vec2 negative_shine = params.xy;
    vec2 local_uv = sr_local_uv(uv);
    float phase = time / 28.0 + negative_shine.x * 10.0;

    float low = min(color.r, min(color.g, color.b));
    float high = max(color.r, max(color.g, color.b));
    float delta = high - low - 0.1;

    float fac = 0.8 + 0.9 * sin(11.0 * local_uv.x + 4.32 * local_uv.y + phase * 12.0 + cos(phase * 5.3 + local_uv.y * 4.2 - local_uv.x * 4.0));
    float fac2 = 0.5 + 0.5 * sin(8.0 * local_uv.x + 2.32 * local_uv.y + phase * 5.0 - cos(phase * 2.3 + local_uv.x * 8.2));
    float fac3 = 0.5 + 0.5 * sin(10.0 * local_uv.x + 5.32 * local_uv.y + phase * 6.111 + sin(phase * 5.3 + local_uv.y * 3.2));
    float fac4 = 0.5 + 0.5 * sin(3.0 * local_uv.x + 2.32 * local_uv.y + phase * 8.111 + sin(phase * 1.3 + local_uv.y * 11.2));
    float fac5 = sin(0.9 * 16.0 * local_uv.x + 5.32 * local_uv.y + phase * 12.0 + cos(phase * 5.3 + local_uv.y * 4.2 - local_uv.x * 4.0));

    float maxfac = 0.7 * max(max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.0);

    vec4 tex = color;
    tex.rgb = tex.rgb * 0.5 + vec3(0.4, 0.4, 0.8);

    tex.r = tex.r - delta + delta * maxfac * (0.7 + fac5 * 0.27) - 0.1;
    tex.g = tex.g - delta + delta * maxfac * (0.7 - fac5 * 0.27) - 0.1;
    tex.b = tex.b - delta + delta * maxfac * 0.7 - 0.1;
    tex.a = tex.a * (0.5 * max(min(1.0, max(0.0, 0.3 * max(low * 0.2, delta) + min(max(maxfac * 0.1, 0.0), 0.4))), 0.0) + 0.15 * maxfac * (0.1 + delta));

    return tex;
}
]]

local HOLOGRAM_GLSL = [[
vec4 mod_hologram(vec4 color, vec2 uv, vec4 params) {
    vec2 hologram = params.xy;
    vec2 local_uv = sr_local_uv(uv);

    float offset_l = 0.0;
    float offset_r = 0.0;
    float timefac = time + hologram.y * 10.0;
    float phase = time / 28.0 + hologram.x * 10.0;

    offset_l = -10.0 * (-0.5 + sin(timefac * 0.512 + uv.y * 14.0)
        + sin(-timefac * 0.8233 + uv.y * 11.532)
        + sin(timefac * 0.333 + uv.y * 13.3)
        + sin(-timefac * 0.1112331 + uv.y * 4.044343));
    offset_r = -10.0 * (-0.5 + sin(timefac * 0.6924 + uv.y * 19.0)
        + sin(-timefac * 0.9661 + uv.y * 21.532)
        + sin(timefac * 0.4423 + uv.y * 30.3)
        + sin(-timefac * 0.13321312 + uv.y * 3.011));

    if (offset_r >= 1.5 || offset_r <= 0.0) { offset_r = 0.0; }
    if (offset_l >= 1.5 || offset_l <= 0.0) { offset_l = 0.0; }

    if (local_uv.x > 0.95 || local_uv.x < 0.05 || local_uv.y > 0.95 || local_uv.y < 0.05) {
        return vec4(0.0);
    }

    vec4 tex = color;
    if (tex.a > 0.999) { tex = vec4(0.0); }
    if (tex.a < 0.001) { tex.rgb = vec3(0.0, 1.0, 1.0); }

    float glow = clamp(1.0 - tex.a, 0.0, 1.0);
    float light_strength = 0.4 * (0.3 * sin(2.0 * timefac) + 0.6 + 0.3 * sin(phase * 3.0) + 0.9);
    float glitch = 1.0 + abs(offset_l) + abs(offset_r);

    vec4 final_col;
    if (tex.a < 0.001) {
        final_col = tex + vec4(0.0, 1.0, 0.5, 0.6) * light_strength * glitch * glow;
    } else {
        final_col = tex + vec4(0.0, 0.3, 0.2, 0.3) * light_strength * glitch * glow;
    }

    return final_col;
}
]]

local function register_effect(br, def)
    if br and br.register_effect then
        br:register_effect(def)
    end
end

local function register_builtin_effects(br)
    register_effect(br, {
        key = "dissolve",
        layers = CARD_LAYERS,
        phase = "post",
        priority = 5,
        params = { "dissolve", "burn_r", "burn_g", "burn_b" },
        params_defaults = { 0, 0, 0, 0 },
        glsl_body = DISSOLVE_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "voucher",
        layers = CARD_LAYERS,
        phase = "overlay",
        priority = 20,
        params = { "voucher_x", "voucher_y" },
        params_defaults = { 0, 0 },
        glsl_body = VOUCHER_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "debuff",
        layers = CARD_LAYERS,
        phase = "post",
        priority = 60,
        params = { "debuff_x", "debuff_y" },
        params_defaults = { 0, 0 },
        glsl_body = DEBUFF_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "played",
        layers = CARD_LAYERS,
        phase = "post",
        priority = 70,
        params = { "played_x", "played_y" },
        params_defaults = { 0, 0 },
        glsl_body = PLAYED_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "foil",
        layers = CARD_LAYERS,
        phase = "color",
        priority = 15,
        params = { "foil_x", "foil_y" },
        params_defaults = { 0, 0 },
        glsl_body = FOIL_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "holo",
        layers = CARD_LAYERS,
        phase = "color",
        priority = 20,
        params = { "holo_x", "holo_y" },
        params_defaults = { 0, 0 },
        glsl_body = HOLO_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "polychrome",
        layers = CARD_LAYERS,
        phase = "color",
        priority = 30,
        params = { "polychrome_x", "polychrome_y" },
        params_defaults = { 0, 0 },
        glsl_body = POLYCHROME_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "negative",
        layers = CARD_LAYERS,
        phase = "color",
        priority = 35,
        params = { "negative_x", "negative_y" },
        params_defaults = { 0, 0 },
        glsl_body = NEGATIVE_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "negative_shine",
        layers = CARD_LAYERS,
        phase = "overlay",
        priority = 40,
        params = { "negative_shine_x", "negative_shine_y" },
        params_defaults = { 0, 0 },
        glsl_body = NEGATIVE_SHINE_GLSL,
        flags = { batch_safe = true },
    })

    register_effect(br, {
        key = "hologram",
        layers = CARD_LAYERS,
        phase = "overlay",
        priority = 25,
        params = { "hologram_x", "hologram_y" },
        params_defaults = { 0, 0 },
        glsl_body = HOLOGRAM_GLSL,
        flags = { batch_safe = true },
    })
end

function effects.attach(br)
    function br:register_builtin_effects()
        register_builtin_effects(self)
    end
end

return effects
