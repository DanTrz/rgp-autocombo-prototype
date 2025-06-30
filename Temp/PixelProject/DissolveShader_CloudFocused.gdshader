shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Base color and texture
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color;

// SDF dissolve texture
uniform sampler2D sdf_dissolve_texture : source_color;
uniform float dissolve_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float edge_softness : hint_range(0.001, 0.5, 0.001) = 0.05;

// Animation options
uniform bool enable_animation = false;
uniform float animation_speed = 0.5;
uniform float animation_amount = 0.2;

// Texture UV scaling for sdf
uniform float sdf_uv_scale : hint_range(0.1, 10.0) = 1.0;
uniform vec2 sdf_uv_offset = vec2(0.0, 0.0);

// Varying to carry per-fragment opacity
varying float dissolve_alpha;

void vertex() {
    // Only set up position
}

void fragment() {
    vec2 sdf_uv = UV * sdf_uv_scale + sdf_uv_offset;
    float sdf_value = texture(sdf_dissolve_texture, sdf_uv).r;

    float threshold = dissolve_threshold;
    if (enable_animation) {
        threshold += sin(TIME * animation_speed) * animation_amount;
        threshold = clamp(threshold, 0.0, 1.0);
    }

    float opacity = smoothstep(threshold + edge_softness, threshold - edge_softness, sdf_value);

    // Dithering pattern (applied directly here to access FRAGCOORD)
    ivec2 pixel = ivec2(FRAGCOORD.xy) % 4;
    int index = pixel.x + pixel.y * 4;
    float[16] bayer = float[16](
        0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
        12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
        3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
        15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
    );
    float dither = bayer[index];

    float alpha_clipped = step(dither, opacity);
    dissolve_alpha = alpha_clipped;

    vec4 tex_color = texture(base_texture, UV);
    ALBEDO = tex_color.rgb * base_color.rgb;
    ALPHA = alpha_clipped * base_color.a * tex_color.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
}

void light() {
    ALPHA = dissolve_alpha;
}




















