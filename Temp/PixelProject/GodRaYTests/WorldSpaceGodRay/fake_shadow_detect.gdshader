shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Shadow detection uniforms
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.4;
uniform float search_radius : hint_range(1.0, 10.0) = 3.0;
uniform int sample_quality : hint_range(1, 3) = 2;

// Advanced shadow detection using depth and normal information
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform bool use_depth_shadow_detection = true;
uniform bool use_ambient_occlusion_detection = true;
uniform float ao_radius : hint_range(0.5, 5.0) = 2.0;
uniform float ao_intensity : hint_range(0.1, 2.0) = 1.0;

// Manual shadow direction (approximate sun direction)
uniform bool use_manual_shadow_direction = true;
uniform vec3 shadow_direction : source_color = vec3(-0.5, -1.0, -0.3); // Normalized sun direction
uniform float shadow_angle_threshold : hint_range(0.0, 1.0) = 0.3;

// Debug visualization
uniform bool show_debug_visualization = false;
uniform vec3 shadow_color : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 lit_color : source_color = vec3(0.0, 1.0, 0.0);
uniform vec3 base_albedo : source_color = vec3(0.5, 0.5, 0.5);

// Varying to pass shadow detection result
varying bool found_shadow;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 view_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Convert depth to world position (matrices must be passed from fragment)
vec3 depth_to_world_position(vec2 screen_uv, float depth, mat4 inv_view, mat4 inv_proj) {
    vec4 ndc = vec4(screen_uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 world_pos = inv_view * inv_proj * ndc;
    return world_pos.xyz / world_pos.w;
}

// Ambient Occlusion-based shadow detection
float calculate_ambient_occlusion(vec2 screen_uv, vec3 world_pos, vec3 normal, mat4 inv_view, mat4 inv_proj) {
    vec2 screen_size = vec2(textureSize(depth_texture, 0));
    vec2 pixel_size = 1.0 / screen_size;

    float occlusion = 0.0;
    int samples = 8;
    if (sample_quality == 2) samples = 12;
    if (sample_quality == 3) samples = 16;

    for (int i = 0; i < samples; i++) {
        float angle = (float(i) / float(samples)) * 6.28318;
        vec2 offset = vec2(cos(angle), sin(angle)) * ao_radius * pixel_size;
        vec2 sample_uv = screen_uv + offset;

        if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 &&
            sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {

            float sample_depth = texture(depth_texture, sample_uv).r;
            vec3 sample_world_pos = depth_to_world_position(sample_uv, sample_depth, inv_view, inv_proj);

            vec3 sample_dir = normalize(sample_world_pos - world_pos);
            float sample_distance = length(sample_world_pos - world_pos);

            // Check if sample is above current surface (potential occluder)
            float normal_dot = dot(normal, sample_dir);
            if (normal_dot > 0.1 && sample_distance < ao_radius) {
                occlusion += normal_dot * (1.0 - sample_distance / ao_radius);
            }
        }
    }

    return occlusion / float(samples);
}

// Directional shadow detection using surface normal and shadow direction
bool detect_directional_shadow(vec3 normal, vec3 shadow_dir) {
    // Normalize shadow direction
    vec3 norm_shadow_dir = normalize(shadow_dir);

    // Calculate how much the surface faces away from light
    float facing_light = dot(normal, -norm_shadow_dir);

    // If surface faces away from light direction, it's likely in shadow
    return facing_light < shadow_angle_threshold;
}

// Screen-space shadow detection using depth differences
bool detect_screen_space_shadows(vec2 screen_uv, vec3 world_pos, vec3 normal, mat4 proj, mat4 view, mat4 inv_view, mat4 inv_proj) {
    vec2 screen_size = vec2(textureSize(depth_texture, 0));
    vec2 pixel_size = 1.0 / screen_size;

    // Sample in the direction opposite to surface normal (into potential shadow)
    vec3 shadow_sample_dir = normalize(shadow_direction);

    int shadow_samples = 0;
    int total_samples = 0;

    // Cast rays in shadow direction to detect occlusion
    for (float step = 1.0; step <= search_radius; step += 1.0) {
        // Project shadow direction to screen space
        vec3 sample_world_pos = world_pos + shadow_sample_dir * step * 0.1;

        // Convert to screen space (simplified projection)
        vec4 clip_pos = proj * view * vec4(sample_world_pos, 1.0);
        vec2 sample_screen_uv = (clip_pos.xy / clip_pos.w) * 0.5 + 0.5;

        if (sample_screen_uv.x >= 0.0 && sample_screen_uv.x <= 1.0 &&
            sample_screen_uv.y >= 0.0 && sample_screen_uv.y <= 1.0) {

            float sample_depth = texture(depth_texture, sample_screen_uv).r;
            vec3 depth_world_pos = depth_to_world_position(sample_screen_uv, sample_depth, inv_view, inv_proj);

            // Check if there's geometry between us and the light
            float our_distance = length(sample_world_pos - world_pos);
            float depth_distance = length(depth_world_pos - world_pos);

            total_samples++;

            // If depth geometry is closer than our sample point, we're occluded
            if (depth_distance < our_distance * 0.9) {
                shadow_samples++;
            }
        }
    }

    if (total_samples > 0) {
        float shadow_ratio = float(shadow_samples) / float(total_samples);
        return shadow_ratio > 0.3; // 30% or more samples show occlusion
    }

    return false;
}

void fragment() {
    bool shadow_detected = false;

    // Method 1: Ambient Occlusion-based detection
    if (use_ambient_occlusion_detection) {
        float ao_factor = calculate_ambient_occlusion(SCREEN_UV, world_position, world_normal, INV_VIEW_MATRIX, INV_PROJECTION_MATRIX);
        if (ao_factor * ao_intensity > shadow_threshold) {
            shadow_detected = true;
        }
    }

    // Method 2: Manual shadow direction detection
    if (use_manual_shadow_direction && !shadow_detected) {
        shadow_detected = detect_directional_shadow(world_normal, shadow_direction);
    }

    // Method 3: Screen-space depth-based shadow detection
    if (use_depth_shadow_detection && !shadow_detected) {
        shadow_detected = detect_screen_space_shadows(SCREEN_UV, world_position, world_normal, PROJECTION_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, INV_PROJECTION_MATRIX);
    }

    // Set the final result
    found_shadow = shadow_detected;

    // Base material
    ALBEDO = base_albedo;

    // Debug visualization
    if (show_debug_visualization) {
        if (found_shadow) {
            ALBEDO = mix(base_albedo, shadow_color, 0.8);
        } else {
            ALBEDO = mix(base_albedo, lit_color, 0.6);
        }
    } else {
        // Final shadow visualization
        if (found_shadow) {
            ALBEDO = vec3(1.0, 0.0, 0.0); // Red for shadow
        } else {
            ALBEDO = vec3(0.0, 1.0, 0.0); // Green for lit
        }
    }

    ROUGHNESS = 0.5;
    METALLIC = 0.0;
}