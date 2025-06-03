shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;

uniform sampler2D windNoise;
uniform sampler2D hGradient : repeat_disable;
uniform sampler2D vGradient : repeat_disable;
uniform sampler2D occlusion_mask;
uniform bool use_occlusion = false;

uniform vec3 tint_color : source_color = vec3(1.0);
uniform float alpha_factor : hint_range(0.0, 1.0) = 0.05;

uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform float flicker_scale : hint_range(0.0, 2.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.2;
uniform float growth_speed : hint_range(0.0, 5.0) = 0.5;
uniform float growth_scale : hint_range(0.0, 5.0) = 1.0;

uniform float sway_amplitude : hint_range(0.0, 1.0) = 0.05;
uniform float sway_speed : hint_range(0.0, 2.0) = 0.5;

uniform bool scroll_vertical = false;

uniform float step_base_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float min_light_threshold = 0.05;
uniform float contrast_power : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    // Horizontal sway (side-to-side)
    float sway_offset = sin(TIME * sway_speed) * sway_amplitude;

    // Conditional vertical scrolling
    float vertical_scroll = scroll_vertical ? TIME * speed * 0.1 : 0.0;
    vec2 movingUV = vec2(UV.x + sway_offset, UV.y + vertical_scroll);

    // Noise flicker
    float noiseValue = texture(windNoise, movingUV).r;
    noiseValue = pow(noiseValue, contrast_power) * flicker_scale;

    // Pulse
    float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;

    // Growth/shrink
    float growFactor = sin(TIME * growth_speed) * 0.5 + 0.5;
    growFactor = mix(1.0, growth_scale, growFactor);
    vec2 grownUV = (UV - 0.5) * growFactor + 0.5;

    // Apply sway again to gradients
    vec2 swayUV = vec2(grownUV.x + sway_offset, grownUV.y);

    // Gradient masks
    vec4 hGrad = texture(hGradient, vec2(swayUV.y, swayUV.x));
    vec4 vGrad = texture(vGradient, swayUV);
    vec4 gradBlend = hGrad * vGrad;

    // Occlusion mask
    float occlusion = use_occlusion ? texture(occlusion_mask, swayUV).r : 1.0;

    // Final alpha
    float alpha = gradBlend.r * noiseValue * pulse * occlusion * alpha_factor;

    if (alpha < min_light_threshold) {
        discard;
    }

    vec3 finalColor = gradBlend.rgb * tint_color * step_base_intensity;

    ALBEDO = finalColor;
    ALPHA = alpha;
    EMISSION = finalColor * 0.25;
}
