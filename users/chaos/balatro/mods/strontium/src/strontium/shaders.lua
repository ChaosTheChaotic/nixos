-- Vanilla ubershader for the batched renderer.
-- Keeping this around for reference (and without it the br would break).
-- Strontium under the hood does this with registered effect shader modules..

local shaders = {}

shaders.EDITION_INTEGRATED_GLSL = [[
    #if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
        #define MY_HIGHP_OR_MEDIUMP highp
    #else
        #define MY_HIGHP_OR_MEDIUMP mediump
    #endif

    extern MY_HIGHP_OR_MEDIUMP float time;
    extern MY_HIGHP_OR_MEDIUMP vec2 atlas_size;
    extern MY_HIGHP_OR_MEDIUMP vec2 tile_size;
    extern Image order_map;
    extern MY_HIGHP_OR_MEDIUMP vec2 order_map_size;
    extern MY_HIGHP_OR_MEDIUMP float order_epsilon;
    
    #ifdef VERTEX
    attribute MY_HIGHP_OR_MEDIUMP float OrderValue;
    #endif
    varying MY_HIGHP_OR_MEDIUMP float v_order;
    
    // Seal UV offsets in the centers atlas (tile coordinates)
    // Gold: (2,0), Purple: (4,4), Red: (5,4), Blue: (6,4)
    extern MY_HIGHP_OR_MEDIUMP vec4 seal_uvs[4]; // Each vec4 = (tile_x, tile_y, 0, 0)

    float hue(float s, float tt, float h)
    {
        float hs = mod(h, 1.0)*6.0;
        if (hs < 1.0) return (tt-s) * hs + s;
        if (hs < 3.0) return tt;
        if (hs < 4.0) return (tt-s) * (4.0-hs) + s;
        return s;
    }

    vec4 RGB(vec4 c)
    {
        if (c.y < 0.0001) return vec4(vec3(c.z), c.a);
        float tt = (c.z < 0.5) ? c.y*c.z + c.z : -c.y*c.z + (c.y+c.z);
        float s = 2.0*c.z - tt;
        return vec4(hue(s,tt,c.x + 1.0/3.0), hue(s,tt,c.x), hue(s,tt,c.x - 1.0/3.0), c.w);
    }

    vec4 HSL(vec4 c)
    {
        float low = min(c.r, min(c.g, c.b));
        float high = max(c.r, max(c.g, c.b));
        float delta = high - low;
        float sum = high + low;
        vec4 hsl = vec4(0.0, 0.0, 0.5*sum, c.a);
        if (delta == 0.0) return hsl;

        hsl.y = (hsl.z < 0.5) ? delta / sum : delta / (2.0 - sum);
        if (high == c.r) hsl.x = (c.g - c.b) / delta;
        else if (high == c.g) hsl.x = (c.b - c.r) / delta + 2.0;
        else hsl.x = (c.r - c.g) / delta + 4.0;

        hsl.x = mod(hsl.x / 6.0, 1.0);
        return hsl;
    }
    
    // Sample seal texture from atlas
    vec4 sampleSeal(Image texture, vec2 local_uv, int seal_idx) {
        if (seal_idx < 0 || seal_idx > 3) return vec4(0.0);
        vec2 seal_tile = seal_uvs[seal_idx].xy;
        vec2 seal_uv = (seal_tile + local_uv) * tile_size / atlas_size;
        return Texel(texture, seal_uv);
    }

    vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
        vec4 tex = Texel(texture, texture_coords);
        if (tex.a < 0.01) return tex;
        #if !defined(VERTEX)
        if (order_map_size.x > 0.0 && v_order >= 0.0) {
            vec2 om_uv = screen_coords / order_map_size;
            MY_HIGHP_OR_MEDIUMP float front = Texel(order_map, om_uv).r;
            if (front > 0.001 && (front - v_order) > order_epsilon) discard;
        }
        #endif

        float id_byte = floor(colour.r*255.0 + 0.5);
        float seal_val = colour.a;
        
        // Determine seal index from alpha: 0=none, 0.25=Gold(0), 0.5=Purple(1), 0.75=Red(2), 1.0=Blue(3)
        int seal_idx = -1;
        if (seal_val > 0.2 && seal_val < 0.3) seal_idx = 0; // Gold
        else if (seal_val > 0.45 && seal_val < 0.55) seal_idx = 1; // Purple
        else if (seal_val > 0.7 && seal_val < 0.8) seal_idx = 2; // Red
        else if (seal_val > 0.95) seal_idx = 3; // Blue

        float seed1 = colour.g;
        float seed2 = colour.b;

        vec2 ts = max(tile_size, vec2(1.0));
        vec2 uv = fract((texture_coords * atlas_size) / ts);
        vec2 adjusted_uv = uv - vec2(0.5, 0.5);
        adjusted_uv.x = adjusted_uv.x * (ts.x / ts.y);

        // Shared contrast metrics
        float low = min(tex.r, min(tex.g, tex.b));
        float high = max(tex.r, max(tex.g, tex.b));

        // Slow phase similar to Card:draw send_to_shader[1]
        float phase = seed1*10.0 + time/28.0;
        float tfast = (time + seed2*10.0);
        
        vec4 result = tex;
        
        // Apply edition effect if present
        if (id_byte >= 1.0) {
            // FOIL (64)
            if (id_byte < 96.0) {
                float delta = min(high, max(0.5, 1.0 - low));

                float fac1 = max(min(2.0*sin((length(90.0*adjusted_uv) + phase*2.0) + 3.0*(1.0+0.8*cos(length(113.1121*adjusted_uv) - phase*3.121))) - 1.0 - max(5.0-length(90.0*adjusted_uv), 0.0), 1.0), 0.0);
                vec2 rotater = vec2(cos(phase*0.1221), sin(phase*0.3512));
                float angle = dot(rotater, adjusted_uv)/(length(rotater)*max(length(adjusted_uv), 0.0001));
                float fac2 = max(min(5.0*cos(tfast*0.3 + angle*3.14*(2.2+0.9*sin(phase*1.65 + 0.2*tfast))) - 4.0 - max(2.0-length(20.0*adjusted_uv), 0.0), 1.0), 0.0);
                float fac3 = 0.3*max(min(2.0*sin(phase*5.0 + uv.x*3.0 + 3.0*(1.0+0.5*cos(phase*7.0))) - 1.0, 1.0), -1.0);
                float fac4 = 0.3*max(min(2.0*sin(phase*6.66 + uv.y*3.8 + 3.0*(1.0+0.5*cos(phase*3.414))) - 1.0, 1.0), -1.0);
                float maxfac = max(max(fac1, max(fac2, max(fac3, max(fac4, 0.0)))) + 2.2*(fac1+fac2+fac3+fac4), 0.0);

                vec4 foil_tex = tex;
                foil_tex.r = tex.r - delta + delta*maxfac*0.3;
                foil_tex.g = tex.g - delta + delta*maxfac*0.3;
                foil_tex.b = tex.b + delta*maxfac*1.9;
                foil_tex.a = min(tex.a, 0.3*tex.a + 0.9*min(0.5, maxfac*0.1));

                float a = clamp(foil_tex.a, 0.0, 1.0);
                result.rgb = mix(tex.rgb, foil_tex.rgb, a);
            }
            // HOLO (128)
            else if (id_byte < 160.0) {
                vec4 hsl = HSL(0.5*tex + 0.5*vec4(0.0, 0.0, 1.0, tex.a));

                float t = tfast*7.221 + time;
                vec2 floored_uv = floor((uv*ts)) / ts;
                vec2 uv_scaled_centered = (floored_uv - 0.5) * 250.0;
                vec2 fp1 = uv_scaled_centered + 50.0*vec2(sin(-t / 143.6340), cos(-t / 99.4324));
                vec2 fp2 = uv_scaled_centered + 50.0*vec2(cos( t / 53.1532),  cos( t / 61.4532));
                vec2 fp3 = uv_scaled_centered + 50.0*vec2(sin(-t / 87.53218), sin(-t / 49.0000));
                float field = (1.0 + (cos(length(fp1) / 19.483) + sin(length(fp2) / 33.155)*cos(fp2.y / 15.73) + cos(length(fp3) / 27.193)*sin(fp3.x / 21.92))) / 2.0;
                float res = (0.5 + 0.5*cos(phase*2.612 + (field - 0.5)*3.14));

                float delta = 0.2 + 0.3*(high - low) + 0.1*high;
                float gridsize = 0.79;
                float fac = 0.5*max(max(max(0.0, 7.0*abs(cos(uv.x*gridsize*20.0))-6.0), max(0.0, 7.0*cos(uv.y*gridsize*45.0 + uv.x*gridsize*20.0)-6.0)), max(0.0, 7.0*cos(uv.y*gridsize*45.0 - uv.x*gridsize*20.0)-6.0));

                hsl.x = hsl.x + res + fac;
                hsl.y = hsl.y*1.3;
                hsl.z = hsl.z*0.6 + 0.4;

                vec4 holo_tex = (1.0-delta)*tex + delta*RGB(hsl)*vec4(0.9, 0.8, 1.2, tex.a);
                if (holo_tex.a < 0.7) holo_tex.a = holo_tex.a/3.0;

                float a = clamp(holo_tex.a, 0.0, 1.0);
                result.rgb = mix(tex.rgb, holo_tex.rgb, a);
            }
            // POLYCHROME (192)
            else if (id_byte < 224.0) {
                float delta0 = high - low;
                float saturation_fac = 1.0 - max(0.0, 0.05*(1.1-delta0));
                vec4 hsl = HSL(vec4(tex.r*saturation_fac, tex.g*saturation_fac, tex.b, tex.a));

                float t = tfast*2.221 + time;
                vec2 floored_uv = floor((uv*ts)) / ts;
                vec2 uv_scaled_centered = (floored_uv - 0.5) * 50.0;
                vec2 fp1 = uv_scaled_centered + 50.0*vec2(sin(-t / 143.6340), cos(-t / 99.4324));
                vec2 fp2 = uv_scaled_centered + 50.0*vec2(cos( t / 53.1532),  cos( t / 61.4532));
                vec2 fp3 = uv_scaled_centered + 50.0*vec2(sin(-t / 87.53218), sin(-t / 49.0000));
                float field = (1.0 + (cos(length(fp1) / 19.483) + sin(length(fp2) / 33.155)*cos(fp2.y / 15.73) + cos(length(fp3) / 27.193)*sin(fp3.x / 21.92))) / 2.0;
                float res = (0.5 + 0.5*cos(phase*2.612 + (field - 0.5)*3.14));

                hsl.x = hsl.x + res + tfast*0.04;
                hsl.y = min(0.6, hsl.y + 0.5);

                vec4 poly_tex = tex;
                poly_tex.rgb = RGB(hsl).rgb;
                if (poly_tex.a < 0.7) poly_tex.a = poly_tex.a/3.0;

                float a = clamp(poly_tex.a, 0.0, 1.0);
                result.rgb = mix(tex.rgb, poly_tex.rgb, a);
            }
            // NEGATIVE (255): base negative + negative_shine overlay
            else {
                // Base negative
                vec4 SAT = HSL(tex);
                SAT.z = (1.0 - SAT.z);
                SAT.x = -SAT.x + 0.2;
                vec4 neg_tex = RGB(SAT) + 0.8*vec4(79.0/255.0, 99.0/255.0, 103.0/255.0, 0.0);
                if (neg_tex.a < 0.7) neg_tex.a = neg_tex.a/3.0;

                // Shine overlay (based on original texture)
                float delta = (high - low - 0.1);

                float fac1 = 0.8 + 0.9*sin(11.0*uv.x + 4.32*uv.y + phase*12.0 + cos(phase*5.3 + uv.y*4.2 - uv.x*4.0));
                float fac2 = 0.5 + 0.5*sin(8.0*uv.x + 2.32*uv.y + phase*5.0 - cos(phase*2.3 + uv.x*8.2));
                float fac3 = 0.5 + 0.5*sin(10.0*uv.x + 5.32*uv.y + phase*6.111 + sin(phase*5.3 + uv.y*3.2));
                float fac4 = 0.5 + 0.5*sin(3.0*uv.x + 2.32*uv.y + phase*8.111 + sin(phase*1.3 + uv.y*11.2));
                float fac5 = sin(0.9*16.0*uv.x + 5.32*uv.y + phase*12.0 + cos(phase*5.3 + uv.y*4.2 - uv.x*4.0));
                float maxfac = 0.7*max(max(fac1, max(fac2, max(fac3, 0.0))) + (fac1 + fac2 + fac3*fac4), 0.0);

                vec4 shine = tex;
                shine.rgb = shine.rgb*0.5 + vec3(0.4, 0.4, 0.8);
                shine.r = shine.r - delta + delta*maxfac*(0.7 + fac5*0.27) - 0.1;
                shine.g = shine.g - delta + delta*maxfac*(0.7 - fac5*0.27) - 0.1;
                shine.b = shine.b - delta + delta*maxfac*0.7 - 0.1;
                shine.a = shine.a * (0.5*max(min(1.0, max(0.0, 0.3*max(low*0.2, delta) + min(max(maxfac*0.1, 0.0), 0.4))), 0.0) + 0.15*maxfac*(0.1+delta));

                float a = clamp(shine.a, 0.0, 1.0);
                result.rgb = mix(neg_tex.rgb, shine.rgb, a);
                result.a = neg_tex.a + a*(1.0 - neg_tex.a);
            }
        }
        
        // Composite seal on top if present
        if (seal_idx >= 0) {
            vec4 seal_tex = sampleSeal(texture, uv, seal_idx);
            // Standard alpha blending
            result.rgb = mix(result.rgb, seal_tex.rgb, seal_tex.a);
            result.a = max(result.a, seal_tex.a);
        }
        
        return result;
    }
    
    // Tilt/hover vertex shader - matches vanilla dissolve.fs behavior
    extern MY_HIGHP_OR_MEDIUMP vec2 mouse_screen_pos;
    extern MY_HIGHP_OR_MEDIUMP float hovering;
    extern MY_HIGHP_OR_MEDIUMP float screen_scale;

    #ifdef VERTEX
    vec4 position( mat4 transform_projection, vec4 vertex_position )
    {
        v_order = OrderValue;
        if (hovering <= 0.){
            return transform_projection * vertex_position;
        }
        MY_HIGHP_OR_MEDIUMP float mid_dist = length(vertex_position.xy - 0.5*love_ScreenSize.xy)/length(love_ScreenSize.xy);
        MY_HIGHP_OR_MEDIUMP vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy)/screen_scale;
        MY_HIGHP_OR_MEDIUMP float scale = 0.2*(-0.03 - 0.3*max(0., 0.3-mid_dist))
                    *hovering*(length(mouse_offset)*length(mouse_offset))/(2. -mid_dist);

        return transform_projection * vertex_position + vec4(0,0,0,scale);
    }
    #endif
]]

function shaders.init()
    if G.SHADERS and not G.SHADERS['edition_integrated'] then
        G.SHADERS['edition_integrated'] = love.graphics.newShader(shaders.EDITION_INTEGRATED_GLSL)
        
        -- Default seal UVs (tile coords in the centers atlas).
        G.SHADERS['edition_integrated']:send('seal_uvs', {2, 0, 0, 0}, {4, 4, 0, 0}, {5, 4, 0, 0}, {6, 4, 0, 0})
        
        G.SHADERS['edition_integrated']:send('hovering', 0)
        G.SHADERS['edition_integrated']:send('mouse_screen_pos', {0, 0})
        G.SHADERS['edition_integrated']:send('screen_scale', 1)
        
        -- Order map defaults (disabled until bound properly)
        G.SHADERS['edition_integrated']:send('order_map_size', {0, 0})
        G.SHADERS['edition_integrated']:send('order_epsilon', 1/512)
    end
end

return shaders
