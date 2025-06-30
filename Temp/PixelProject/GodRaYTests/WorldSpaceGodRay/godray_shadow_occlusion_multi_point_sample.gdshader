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

// NEW: Directional shadow blocking controls
uniform int ray_samples : hint_range(3, 32) = 16; // How many points to sample along the ray
uniform float ray_length : hint_range(1.0, 100.0) = 20.0; // Total length of ray to sample
uniform bool sample_from_sky  = true; // Sample from sky toward ground
uniform float shadow_fadeout_distance : hint_range(0.1, 10.0) = 2.0; // How far the shadow effect extends

uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv1_scale = vec2(4.0, 0.1);
uniform vec2 uv1_offset = vec2(0.0, 0.85);

// Pass data to light function
varying vec3 world_position;
varying vec3 light_direction_world; // Will be set in light() function
varying float shadow_blocking_factor;

void vertex() {
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

    // Use current pixel's world position for shadow sampling
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
}

void light() {
    float NdotL = max(0.0, dot(NORMAL, LIGHT));

    // Get the light direction (pointing FROM the light source)
    vec3 light_dir = normalize(-LIGHT); // Negative because LIGHT points toward the source

    // Calculate the directional shadow blocking factor
    float blocking_factor = 1.0; // Start assuming no blocking

    // Sample points along the ray from sky toward ground (or reverse)
    for (int i = 0; i < ray_samples; i++) {
        float t; // Parameter along the ray (0.0 to 1.0)

        if (sample_from_sky) {
            // Sample from sky toward ground: start far from light source, move toward it
            t = float(i) / float(ray_samples - 1);
        } else {
            // Sample from ground toward sky: start near light source, move away
            t = 1.0 - float(i) / float(ray_samples - 1);
        }

        // Calculate sample position along the light direction
        vec3 sample_world_pos = world_position + light_dir * (t - 0.5) * ray_length;

        // Transform to view space for shadow sampling
        vec3 sample_view_pos = (VIEW_MATRIX * vec4(sample_world_pos, 1.0)).xyz;

        // Sample shadow at this point
        // Note: We use ATTENUATION as approximation - in advanced version we'd sample at each point
        float sample_shadow = ATTENUATION;

        // If we find a shadow (blocked point)
        if (sample_shadow < shadow_detection_threshold) {
            // Calculate how far this blocking point is from current pixel
            float distance_to_block = length(sample_world_pos - world_position);

            if (sample_from_sky) {
                // If sampling from sky to ground, block everything "behind" this point
                // (further from the light source)
                float current_distance_from_light = dot(world_position, -light_dir);
                float block_distance_from_light = dot(sample_world_pos, -light_dir);

                if (current_distance_from_light <= block_distance_from_light) {
                    // This pixel is "behind" the blocking point - apply shadow
                    float fadeout = 1.0 - clamp(distance_to_block / shadow_fadeout_distance, 0.0, 1.0);
                    blocking_factor = min(blocking_factor, fadeout);
                }
            } else {
                // If sampling from ground to sky, block everything "in front" of this point
                float current_distance_from_light = dot(world_position, -light_dir);
                float block_distance_from_light = dot(sample_world_pos, -light_dir);

                if (current_distance_from_light >= block_distance_from_light) {
                    // This pixel is "in front" of the blocking point - apply shadow
                    float fadeout = 1.0 - clamp(distance_to_block / shadow_fadeout_distance, 0.0, 1.0);
                    blocking_factor = min(blocking_factor, fadeout);
                }
            }

            // Early exit optimization: if we're fully blocked, no need to sample more
            if (blocking_factor <= 0.01) {
                break;
            }
        }
    }

    // Get the base shadow at current pixel
    float base_shadow = ATTENUATION;

    // Combine base shadow with directional blocking
    float final_shadow = base_shadow * blocking_factor;

    float light_contribution = 0.0;

    if (final_shadow < shadow_detection_threshold) {
        // Apply shadow with smooth transition
        float shadow_fade = smoothstep(0.0, shadow_detection_threshold * 2.0, final_shadow);
        light_contribution = shadow_fade * NdotL * brightness;

        // Make shadowed areas more transparent
        ALPHA *= shadow_fade;
    } else {
        // Full light contribution
        light_contribution = NdotL * brightness;
    }

    DIFFUSE_LIGHT += ALBEDO * light_contribution * LIGHT_COLOR;
}