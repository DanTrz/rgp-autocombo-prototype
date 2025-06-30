shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Uniforms for controlling the look of the rays
uniform vec4 ray_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(0.0, 5.0) = 0.5;
uniform float speed : hint_range(0.1, 10.0) = 1.0;
uniform float shadow_detection_threshold : hint_range(0.01, 1.0) = 0.2;
uniform float noise_movement : hint_range(0.0, 0.5) = 0.5;

// Collective shadow detection parameters
uniform float shadow_influence_radius : hint_range(0.1, 10.0) = 3.0; // How far shadow influence spreads
uniform float shadow_propagation_speed : hint_range(0.1, 5.0) = 1.0; // How fast shadow spreads across ray
uniform bool use_aggressive_hiding  = true; // Hide entire ray aggressively

uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv1_scale = vec2(4.0, 0.1);
uniform vec2 uv1_offset = vec2(0.0, 0.85);

varying vec3 world_position;
varying vec2 local_uv; // UV within the ray object

void vertex() {
    local_uv = UV; // Store original UV before transformation
    UV = UV * uv1_scale + uv1_offset;

    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // --- Calculate the visual texture and transparency of the ray ---
    vec2 moving_noise_uv = UV + vec2(TIME * speed * 0.1, 0.0);
    vec4 noise_value = texture(noise_texture, moving_noise_uv);
    vec2 noise_offset = vec2(noise_value.r * noise_movement, 0.0);
    vec2 gradient_uv = UV + noise_offset;
    vec4 final_gradient = texture(gradient, gradient_uv);

    // Use Fresnel to fade the ray at sharp angles to the camera
    float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);

    // The base transparency from your noise and gradient textures
    float noise_alpha = noise_value.r * final_gradient.a * alpha;

    // --- DEFINE THE MATERIAL'S PROPERTIES ---
    ALBEDO = ray_color.rgb;
    EMISSION = vec3(0.0);
    ALPHA = clamp(fresnel * noise_alpha, 0.0, 1.0);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;

    // Each pixel samples shadow at its own world position
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
}

void light() {
    float NdotL = max(0.0, dot(NORMAL, LIGHT));

    // This pixel's shadow value
    float my_shadow = ATTENUATION;

    float light_contribution = 0.0;

    if (use_aggressive_hiding) {
        // AGGRESSIVE METHOD: Each pixel decides for itself but with "collective awareness"

        // If this pixel is in shadow, it affects the entire ray
        if (my_shadow < shadow_detection_threshold) {
            // This pixel detected shadow - hide aggressively
            light_contribution = 0.0;
            ALPHA = 0.0;
        } else {
            // This pixel is not in shadow
            // But we can make the ray "fade out" near shadow boundaries

            // Calculate distance-based falloff to create shadow influence
            // Pixels near the edges of the object are more likely to be affected
            float edge_distance = min(
                min(local_uv.x, 1.0 - local_uv.x),
                min(local_uv.y, 1.0 - local_uv.y)
            );

            // Create shadow influence based on proximity to edges
            float shadow_influence = smoothstep(0.0, 0.3, edge_distance);

            light_contribution = shadow_influence * NdotL * brightness;
            ALPHA *= shadow_influence;
        }

    } else {
        // STANDARD METHOD: Each pixel responds only to its own shadow
        if (my_shadow < shadow_detection_threshold) {
            light_contribution = my_shadow * NdotL * brightness;
            ALPHA *= my_shadow;
        } else {
            light_contribution = NdotL * brightness;
        }
    }

    DIFFUSE_LIGHT += ALBEDO * light_contribution * LIGHT_COLOR;
}