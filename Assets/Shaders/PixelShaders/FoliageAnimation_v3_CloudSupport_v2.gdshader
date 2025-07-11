//COMPLETE FOLIAGE AND GRASS SHADER - Cloud Features + Original Animations
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Global uniforms (CLOUD SYSTEM - PROTECTED)
global uniform sampler2D cloud_shadow_texture;
global uniform float cloud_alpha_scissor : hint_range(0.0, 1.0);
global uniform float cloud_shadow_strength : hint_range(0.0, 1.0);
global uniform vec2 cloud_movement_offset;
global uniform vec3 cloud_area_center;
global uniform float cloud_area_size;
global uniform vec3 sun_light_direction;
global uniform bool enable_directional_shadows;
global uniform float cloud_mesh_y;
global uniform float cloud_texture_scale;



// ===== ORIGINAL FOLIAGE FEATURES (RESTORED) =====
group_uniforms Texture_and_colors;
// Basic properties
uniform sampler2D albedo_tex : filter_nearest, source_color;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool billboard = true;
// Vertex colors and emission (RESTORED)
uniform bool use_vertex_color = true;
uniform bool use_emission = false;
uniform vec3 emission_color : source_color = vec3(1.0);
// Ambient light controls (RESTORED)
uniform bool disable_ambient_light = false;
uniform vec3 fake_ambient_light : source_color = vec3(0.8);

// ===== SINGLE SHADOW CONTROL SYSTEM (CLOUD - PROTECTED) =====
group_uniforms Shadows;
uniform bool override_global_shadow = false;
uniform float real_shadow_threshold : hint_range(0.0, 1.0) = 0.99;
// Cloud shadow controls (ONLY used when override_global_shadow = false) (CLOUD - PROTECTED)
uniform bool enable_cloud_shadows = true;
uniform float cloud_shadow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform bool use_granular_shadows = false;
uniform float white_shadow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float gray_shadow_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float black_shadow_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float color_threshold : hint_range(0.01, 0.5) = 0.5;

// Wind Animation (RESTORED)
group_uniforms Animations;
uniform float wind_sway_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wind_sway_speed : hint_range(0.1, 10.0) = 1.0;
uniform float wind_time_scale : hint_range(0.0, 5.0) = 1.0;
uniform float wind_time_offset = 0.0;
uniform bool sway_from_bottom = false;

// ===== DEBUG CONTROLS (CLOUD - PROTECTED) =====
group_uniforms Debug;
uniform bool debug_mode = false;
uniform int debug_test : hint_range(0, 5) = 0;
/* Debug Tests:
   0 = Show world position XZ
   1 = Show calculated UV coordinates
   2 = Show cloud texture sampling
   3 = Show final shadow result
   4 = Show scaled UV coordinates
   5 = Normal rendering
*/

// Varying variables (CLOUD + ORIGINAL)
varying vec3 modelOrigin;
varying vec3 world_billboard_normal;
varying vec3 world_position;
varying vec3 grass_center_world;

// ===== CLOUD SHADOW CALCULATION (PROTECTED - UNCHANGED) =====
float calculate_final_shadow() {
    // OVERRIDE CHECK FIRST - if true, ignore ALL cloud parameters
    if (override_global_shadow) {
        return 1.0; // Return neutral value - real shadows handled in light()
    }

    // Only calculate cloud shadows if override is OFF
    if (!enable_cloud_shadows) {
        return 1.0;
    }

    // World to UV calculation (UNCHANGED - preserves all coordinate logic)
    vec2 relative_pos = grass_center_world.xz - cloud_area_center.xz;
    vec2 normalized = relative_pos / cloud_area_size;
    vec2 uv = normalized + vec2(0.5);
    uv += cloud_movement_offset;

    // Directional shadow offset - FIXED DIRECTION (UNCHANGED)
    if (enable_directional_shadows && sun_light_direction.y < -0.001) {
        float grass_ground_y = grass_center_world.y;
        vec3 cloud_pos = vec3(grass_center_world.x, cloud_mesh_y, grass_center_world.z);
        float t = (grass_ground_y - cloud_pos.y) / sun_light_direction.y;

        // FIXED: Invert the shadow direction calculation
        vec3 shadow_pos = cloud_pos - sun_light_direction * t;

        // Use shadow position for UV calculation
        relative_pos = shadow_pos.xz - cloud_area_center.xz;
        normalized = relative_pos / cloud_area_size;
        uv = normalized + vec2(0.5);
        uv += cloud_movement_offset;
    }

    // Apply texture scaling to UV coordinates
    vec2 scaled_uv = uv * cloud_texture_scale;

    // Sample cloud texture with scaled UV
    vec4 cloud_sample = texture(cloud_shadow_texture, scaled_uv);

    // Dissolve check using scaled texture sample
    if (cloud_sample.a < cloud_alpha_scissor) {
        return 1.0; // Cloud dissolved here - use global shadows only
    }

    float shadow_intensity;

    if (use_granular_shadows) {
        float luminance = (cloud_sample.r + cloud_sample.g + cloud_sample.b) / 3.0;

        if (luminance > (1.0 - color_threshold)) {
            shadow_intensity = white_shadow_intensity;
        }
        else if (luminance < color_threshold) {
            shadow_intensity = black_shadow_intensity;
        }
        else {
            float gray_factor = (luminance - color_threshold) / (1.0 - 2.0 * color_threshold);
            shadow_intensity = mix(black_shadow_intensity, white_shadow_intensity, gray_factor);
        }
    }
    else {
        float cloud_mask = step(cloud_alpha_scissor, cloud_sample.a);
        shadow_intensity = cloud_mask * cloud_shadow_strength;
    }

    float final_intensity = shadow_intensity * cloud_shadow_intensity;
    return 1.0 - final_intensity;
}

// ===== DEBUG VISUALIZATION (CLOUD - PROTECTED) =====
vec3 debug_visualization(vec3 world_pos) {
    if (debug_test == 0) {
        vec2 world_xz = world_pos.xz;
        return vec3(fract(world_xz * 0.01), 0.0);
    }
    else if (debug_test == 1) {
        vec2 relative_pos = world_pos.xz - cloud_area_center.xz;
        vec2 normalized = relative_pos / cloud_area_size;
        vec2 uv = normalized + vec2(0.5);
        float out_of_range = (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) ? 1.0 : 0.0;
        return vec3(clamp(uv, 0.0, 1.0), out_of_range);
    }
    else if (debug_test == 2) {
        vec2 relative_pos = world_pos.xz - cloud_area_center.xz;
        vec2 normalized = relative_pos / cloud_area_size;
        vec2 uv = normalized + vec2(0.5);
        return texture(cloud_shadow_texture, uv).rgb;
    }
    else if (debug_test == 3) {
        float shadow = calculate_final_shadow();
        return vec3(shadow);
    }
    else if (debug_test == 4) {
        // Show scaled UV coordinates
        vec2 relative_pos = world_pos.xz - cloud_area_center.xz;
        vec2 normalized = relative_pos / cloud_area_size;
        vec2 uv = normalized + vec2(0.5);
        vec2 scaled_uv = uv * cloud_texture_scale;
        return vec3(fract(scaled_uv), 0.0);
    }

    return vec3(1.0, 0.0, 1.0);
}

void vertex() {
    vec3 mod_vertex = VERTEX;

    // ===== ORIGINAL WIND ANIMATION (RESTORED) =====
    float time = TIME * wind_time_scale + wind_time_offset;
    // Control sway influence origin (top or bottom)
    float sway_influence = sway_from_bottom ? UV.y : (1.0 - UV.y);
    float sway = sin((time + VERTEX.x * 0.5) * wind_sway_speed) * wind_sway_strength * sway_influence;
    mod_vertex.x += sway;

    // ===== BILLBOARD SYSTEM (ORIGINAL + CLOUD COMPATIBLE) =====
    if(billboard) {
        mat4 billboard_modelview = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
        );
        MODELVIEW_MATRIX = billboard_modelview;
    }

    VERTEX = mod_vertex;
    world_billboard_normal = transpose(mat3(MODELVIEW_MATRIX)) * vec3(0.0, 0.0, 1.0);
    modelOrigin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // ===== CLOUD SYSTEM WORLD POSITIONS (PROTECTED) =====
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    grass_center_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
    // ===== CLOUD DEBUG MODE (PROTECTED) =====
    if (debug_mode && debug_test < 5) {
        ALBEDO = debug_visualization(world_position);
        ALPHA = 1.0;
        LIGHT_VERTEX = modelOrigin;
    }
    else {
        // ===== ORIGINAL FRAGMENT LOGIC (RESTORED) =====
        vec4 tex = texture(albedo_tex, UV);

        // Apply vertex colors if enabled (RESTORED)
        if(use_vertex_color) {
            tex *= COLOR;
        }

        ALBEDO = tex.rgb * albedo_color.rgb;
        ALPHA = tex.a * albedo_color.a;

        if (ALPHA < 0.1) {
            discard;
        }

        // Model Origin info for consistent lighting (ORIGINAL + CLOUD COMPATIBLE)
        LIGHT_VERTEX = modelOrigin;
    }
}

void light() {
    // ===== ORIGINAL LIGHTING SETUP (RESTORED) =====
    vec3 normal = normalize(world_billboard_normal);
    float NdotL = max(dot(normal, LIGHT), 0.0); // Clamp to positive values only

    // ===== CLOUD SHADOW INTEGRATION (PROTECTED) =====
    float final_attenuation;

    if (override_global_shadow) {
        // OVERRIDE: Use ONLY real shadows, ignore ALL cloud parameters
        final_attenuation = ATTENUATION;
    }
    else {
        // NORMAL: Apply cloud shadow system
        float cloud_shadow = calculate_final_shadow();
        final_attenuation = ATTENUATION * cloud_shadow;
    }

    // ===== CORRECTED LIGHTING CALCULATION =====

    // 1. AMBIENT LIGHT (not affected by shadows or light direction)
    if (!disable_ambient_light) {
        DIFFUSE_LIGHT += fake_ambient_light * ALBEDO;
    }

    // 2. DIRECTIONAL LIGHT (affected by shadows and light direction)
    DIFFUSE_LIGHT += NdotL * ALBEDO * LIGHT_COLOR * final_attenuation;

    // 3. EMISSION (not affected by shadows)
    if(use_emission) {
        DIFFUSE_LIGHT += emission_color * ALBEDO;
    }
}