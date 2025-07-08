shader_type spatial;

uniform sampler2D canopy_texture : source_color;
uniform float dither_size : hint_range(0.01, 8.0) = 4.0;
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;
uniform float blur_amount : hint_range(0.0, 0.01) = 0.002;

// 4x4 Bayer dithering matrix
const float dither_matrix[16] = {
    0.0/16.0,  8.0/16.0,  2.0/16.0,  10.0/16.0,
    12.0/16.0, 4.0/16.0,  14.0/16.0, 6.0/16.0,
    3.0/16.0,  11.0/16.0, 1.0/16.0,  9.0/16.0,
    15.0/16.0, 7.0/16.0,  13.0/16.0, 5.0/16.0
};

void fragment() {
    // Sample texture with blur
    vec4 tex = vec4(0.0);
    
    // Simple 3x3 blur using fixed offset
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x), float(y)) * blur_amount;
            tex += texture(canopy_texture, UV + offset);
        }
    }
    tex /= 9.0; // Average the 9 samples
    
    // Calculate shadow intensity from blurred texture
    float shadow_intensity = (1.0 - tex.a) * shadow_strength;
    shadow_intensity *= (1.0 - (tex.r + tex.g + tex.b) / 3.0);
    
    // Calculate dither pattern
    vec2 screen_pos = FRAGCOORD.xy / dither_size;
    int x = int(mod(screen_pos.x, 4.0));
    int y = int(mod(screen_pos.y, 4.0));
    float dither_value = dither_matrix[y * 4 + x];
    
    // Apply dithering
    float alpha = shadow_intensity > dither_value ? 1.0 : 0.0;
    
    ALBEDO = vec3(0.0);
    ALPHA = alpha;
    ALPHA_SCISSOR_THRESHOLD = 0.1;
}