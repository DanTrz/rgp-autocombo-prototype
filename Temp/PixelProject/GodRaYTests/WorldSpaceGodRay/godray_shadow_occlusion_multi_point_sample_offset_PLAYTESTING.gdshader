shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Ray visual controls
uniform vec4 ray_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(0.0, 5.0) = 0.5;
uniform float speed : hint_range(0.1, 10.0) = 1.0;
uniform float noise_movement : hint_range(0.0, 0.5) = 0.5;

// Shadow logic
uniform float shadow_detection_threshold : hint_range(0.01, 1.0) = 0.2;
uniform float shadow_sensitivity : hint_range(0.0, 1.0) = 0.3;
uniform bool hide_entire_ray_on_shadow = true;

// Distributed sampling
uniform bool enable_distributed_sampling = true;
uniform float sampling_offset_x : hint_range(-20.0, 20.0) = 0.0;
uniform float sampling_offset_y : hint_range(-20.0, 20.0) = 0.0;
uniform float sampling_offset_z : hint_range(-20.0, 20.0) = 0.0;
uniform int sample_count : hint_range(1, 8) = 4;
uniform vec3 sample_offsets[8];

// Textures
uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv1_scale = vec2(4.0, 0.1);
uniform vec2 uv1_offset = vec2(0.0, 0.85);

// Varyings
varying vec3 world_position;
varying vec3 sample_position;
varying vec3 object_center;
varying vec3 world_samples[8];
//varying int actual_count;
varying vec3 light_direction_ws;

void vertex() {
    UV = UV * uv1_scale + uv1_offset;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    object_center = MODEL_MATRIX[3].xyz;

    //actual_count = sample_count;
    for (int i = 0; i < sample_count; i++) {
        world_samples[i] = object_center + sample_offsets[i];
    }

    // Simulate light direction in world space
    vec3 light_ws = (INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz;
    light_direction_ws = normalize(light_ws);

    sample_position = object_center; // Used by LIGHT_VERTEX
}

void fragment() {
    // Noise + gradient coloring
    vec2 moving_noise_uv = UV + vec2(TIME * speed * 0.1, 0.0);
    vec4 noise_value = texture(noise_texture, moving_noise_uv);
    vec2 noise_offset = vec2(noise_value.r * noise_movement, 0.0);
    vec2 gradient_uv = UV + noise_offset;
    vec4 final_gradient = texture(gradient, gradient_uv);

    float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);
    float noise_alpha = noise_value.r * final_gradient.a * alpha;

    ALBEDO = ray_color.rgb;
    EMISSION = vec3(0.0);
    ALPHA = clamp(fresnel * noise_alpha, 0.0, 1.0);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;

    // --- Multi-point shadow simulation ---
    bool shadowed = false;

    for (int i = 0; i < sample_count; i++) {
        vec3 to_sample_dir = normalize(world_samples[i] - world_position);
        float alignment = dot(to_sample_dir, light_direction_ws);

        // If too misaligned with light, treat as shadowed
        if (alignment < shadow_sensitivity) {
            shadowed = true;
            break;
        }
    }

    if (shadowed && hide_entire_ray_on_shadow) {
        ALPHA = 0.0;
    }

    // Use sample position for built-in shadow query
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(sample_position, 1.0)).xyz;
}

void light() {
    float NdotL = max(0.0, dot(NORMAL, LIGHT));
    float shadow_sample = ATTENUATION;
    float light_contribution = 0.0;

    if (hide_entire_ray_on_shadow) {
        if (shadow_sample < shadow_detection_threshold) {
            light_contribution = 0.0;
            ALPHA = 0.0;
        } else {
            light_contribution = NdotL * brightness;
        }
    } else {
        if (shadow_sample < shadow_detection_threshold) {
            light_contribution = shadow_sample * NdotL * brightness;
            ALPHA *= shadow_sample;
        } else {
            light_contribution = NdotL * brightness;
        }
    }

    DIFFUSE_LIGHT += ALBEDO * light_contribution * LIGHT_COLOR;
}
