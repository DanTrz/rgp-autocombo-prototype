shader_type spatial;
// Updated render_mode for proper blending and depth handling
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform float speed : hint_range(0.5, 10.0) = 8.0;
uniform sampler2D windNoise;
uniform sampler2D hGradient : repeat_disable;
uniform sampler2D vGradient : repeat_disable;
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float alpha_factor : hint_range(0.0, 1.0) = 0.1;

// Occlusion Mask (expects black occluders on a white background)
uniform sampler2D occlusion_mask; // Using a hint for clarity
uniform vec2 occlusion_uv_scale = vec2(1.0, 1.0);     // Adjust if mask Viewport size/aspect differs
uniform vec2 occlusion_uv_offset = vec2(0.0, 0.0);    // Adjust if mask Viewport position differs
uniform float occlusion_strength : hint_range(0.0, 5.0) = 2.0;
uniform bool use_occlusion = false;

void fragment() {
    vec2 movingNoiseUV = vec2(UV.x, UV.y * 0.0 + (TIME * speed * 0.01));

    vec4 noiseValue = texture(windNoise, movingNoiseUV);
    vec4 loadGradient = texture(hGradient, vec2(UV.y, UV.x)); // Your custom gradient sampling
    vec4 finalGradient = loadGradient * texture(vGradient, UV);

    // This is the ray's alpha based on its own visual pattern (noise, gradients)
    float ray_pattern_alpha = noiseValue.r * finalGradient.r * alpha_factor;

    float visibility_from_occlusion = 1.0; // Assume fully visible by default
    if (use_occlusion) {
        // Sample the occlusion mask using SCREEN_UV for per-screen-pixel occlusion
        vec2 mask_sample_uv = SCREEN_UV * occlusion_uv_scale + occlusion_uv_offset;
        
        // Optional: Clamp UVs if your mask doesn't tile or to prevent issues with scaling
        // mask_sample_uv = clamp(mask_sample_uv, vec2(0.0), vec2(1.0)); 

        float mask_value = texture(occlusion_mask, mask_sample_uv).r; // .r for grayscale

        // Corrected logic:
        // mask_value = 0 for black occluders (should mean visibility = 0)
        // mask_value = 1 for white background (should mean visibility = 1)
        // mix(1.0 (no occlusion), mask_value (visibility from mask), how_strong_is_the_mask_effect)
        visibility_from_occlusion = mix(1.0, mask_value, occlusion_strength);
    }

    // Final alpha is the ray's own pattern alpha multiplied by the visibility from screen-space occlusion
    float finalAlpha = ray_pattern_alpha * visibility_from_occlusion;
    finalAlpha = clamp(finalAlpha, 0.0, 1.0); // Ensure alpha is in valid range

    vec4 finalColor = vec4(finalGradient.rgb * tint_color, finalAlpha);

    ALBEDO = finalColor.rgb;
    ALPHA = finalColor.a;
    EMISSION = finalColor.rgb * 0.1; // Emission will also be affected by the final ALPHA
}