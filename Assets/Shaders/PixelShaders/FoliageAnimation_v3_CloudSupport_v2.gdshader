//DIRECT CALCULATION SHADER - No Matrix Math
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// SIMPLIFIED Global uniforms - no more matrix!
global uniform sampler2D cloud_shadow_texture;
global uniform float cloud_alpha_scissor : hint_range(0.0, 1.0);
global uniform float cloud_shadow_strength : hint_range(0.0, 1.0);
global uniform vec2 cloud_movement_offset;
global uniform vec3 cloud_area_center;
global uniform float cloud_area_size;

// STEP 2: Proper geometric shadow projection
global uniform vec3 sun_light_direction;
global uniform bool enable_directional_shadows;
global uniform float ground_plane_y;
global uniform float cloud_mesh_y;

// ===== DEBUG CONTROLS =====
uniform bool debug_mode = true;
uniform int debug_test : hint_range(0, 5) = 0;
/* Debug Tests:
   0 = Show world position XZ (should vary across grass)
   1 = Show calculated UV coordinates  
   2 = Show cloud texture sampling
   3 = Show cloud alpha channel
   4 = Show shadow calculation result
   5 = Normal rendering with shadows
*/

// ===== GRANULAR SHADOW CONTROLS =====
uniform bool use_granular_shadows = false;
uniform float white_shadow_intensity : hint_range(0.0, 1.0) = 0.0;  // White = no shadow
uniform float gray_shadow_intensity : hint_range(0.0, 1.0) = 0.5;   // Gray = medium shadow  
uniform float black_shadow_intensity : hint_range(0.0, 1.0) = 1.0;  // Black = full shadow
uniform float color_threshold : hint_range(0.01, 0.5) = 0.2;        // How precise color detection is
// ===================================

uniform bool enable_cloud_shadows = true;
uniform float cloud_shadow_intensity : hint_range(0.0, 2.0) = 1.0;
// ================================

// Basic properties
uniform sampler2D albedo_tex : filter_nearest, source_color;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool billboard = true;

varying vec3 modelOrigin;
varying vec3 world_billboard_normal;
varying vec3 world_position;
varying vec3 grass_center_world;

// ===== DIRECT CALCULATION FUNCTIONS =====
vec2 world_to_uv_direct(vec3 world_pos) {
    // SIMPLE MATH: Convert world XZ coordinates to 0-1 UV range
    
    // 1. Get relative position from area center
    vec2 relative_pos = world_pos.xz - cloud_area_center.xz;
    
    // 2. Normalize to -0.5 to +0.5 range based on area size
    vec2 normalized = relative_pos / cloud_area_size;
    
    // 3. Shift to 0-1 range
    vec2 uv = normalized + vec2(0.5);
    
    // 4. Add movement offset for animation
    uv += cloud_movement_offset;
    
    return uv;
}

float get_cloud_shadow_direct(vec3 world_pos) {
    if (!enable_cloud_shadows) return 1.0;
    
    // STEP 2: Proper geometric shadow projection
    vec3 shadow_sample_pos = world_pos;
    
    if (enable_directional_shadows) {
        // Calculate where cloud shadow falls on ground using ray-plane intersection
        
        // Cloud position (use world_pos XZ, but cloud mesh Y height)
        vec3 cloud_pos = vec3(world_pos.x, cloud_mesh_y, world_pos.z);
        
        // Check if light direction would create valid shadow (not pointing up)
        if (sun_light_direction.y < -0.001) { // Light pointing down
            
            // Calculate intersection parameter t
            // Ray: cloud_pos + sun_light_direction * t
            // Plane: y = ground_plane_y
            float t = (ground_plane_y - cloud_pos.y) / sun_light_direction.y;
            
            // Calculate shadow position on ground
            vec3 shadow_pos = cloud_pos + sun_light_direction * t;
            
            // Use shadow position XZ for sampling cloud texture
            shadow_sample_pos = vec3(shadow_pos.x, world_pos.y, shadow_pos.z);
        }
        // If light pointing up or horizontal, use original position (no shadow offset)
    }
    
    // Get UV coordinates using the (potentially projected) position
    vec2 uv = world_to_uv_direct(shadow_sample_pos);
    
    // Sample cloud texture
    vec4 cloud_sample = texture(cloud_shadow_texture, uv);
    
    float shadow_intensity;
    
    if (use_granular_shadows) {
        // GRANULAR: Map texture colors to shadow intensities
        float luminance = (cloud_sample.r + cloud_sample.g + cloud_sample.b) / 3.0;
        
        if (luminance > (1.0 - color_threshold)) {
            // White/Light areas
            shadow_intensity = white_shadow_intensity;
        }
        else if (luminance < color_threshold) {
            // Black/Dark areas  
            shadow_intensity = black_shadow_intensity;
        }
        else {
            // Gray/Medium areas - interpolate between white and black settings
            float gray_factor = (luminance - color_threshold) / (1.0 - 2.0 * color_threshold);
            shadow_intensity = mix(black_shadow_intensity, white_shadow_intensity, gray_factor);
        }
    }
    else {
        // ORIGINAL: Simple alpha threshold
        float cloud_mask = step(cloud_alpha_scissor, cloud_sample.a);
        shadow_intensity = cloud_mask * cloud_shadow_strength;
    }
    
    // Apply intensity control and return final shadow
    float final_intensity = shadow_intensity * cloud_shadow_intensity;
    return 1.0 - final_intensity;
}

vec3 debug_visualization(vec3 world_pos) {
    if (debug_test == 0) {
        // Test 0: Show world position XZ variation
        // Use fractional part to see if positions are actually different
        vec2 world_xz = world_pos.xz;
        return vec3(fract(world_xz * 0.01), 0.0); // Scale to see variation
    }
    else if (debug_test == 1) {
        // Test 1: Show UV coordinates from direct calculation
        vec2 uv = world_to_uv_direct(world_pos);
        
        // Show UV as red/green, blue indicates out-of-range (>1 or <0)
        float out_of_range = 0.0;
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            out_of_range = 1.0;
        }
        
        return vec3(clamp(uv, 0.0, 1.0), out_of_range);
    }
    else if (debug_test == 2) {
        // Test 2: Show cloud texture sampling (with wrapping for now)
        vec2 uv = world_to_uv_direct(world_pos);
        return texture(cloud_shadow_texture, uv).rgb;
    }
    else if (debug_test == 3) {
        // Test 3: Show cloud alpha channel
        vec2 uv = world_to_uv_direct(world_pos);
        float alpha = texture(cloud_shadow_texture, uv).a;
        return vec3(alpha);
    }
    else if (debug_test == 4) {
        // Test 4: Show final shadow calculation
        float shadow = get_cloud_shadow_direct(world_pos);
        return vec3(shadow);
    }
    
    return vec3(1.0, 0.0, 1.0); // Magenta for error
}

void vertex() {
    vec3 mod_vertex = VERTEX;

    // Billboard
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
    
    // Calculate world position - this is the key!
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Calculate grass center world position for uniform shadow sampling
    grass_center_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
    if (debug_mode && debug_test < 5) {
        ALBEDO = debug_visualization(world_position);
        ALPHA = 1.0;
        LIGHT_VERTEX = modelOrigin;
    }
    else {
        // Normal rendering (debug_test = 5) or debug_mode = false
        vec4 tex = texture(albedo_tex, UV);
        ALBEDO = tex.rgb * albedo_color.rgb;
        ALPHA = tex.a * albedo_color.a;

        if (ALPHA < 0.1) {
            discard;
        }
        
        // Apply cloud shadows using direct calculation
        if (enable_cloud_shadows) {
            float cloud_shadow = get_cloud_shadow_direct(grass_center_world);
            ALBEDO *= cloud_shadow;
        }
        
        LIGHT_VERTEX = modelOrigin;
    }
}

void light() {
    vec3 normal = normalize(world_billboard_normal);
    float NdotL = max(dot(normal, LIGHT), 0.0);
    DIFFUSE_LIGHT += NdotL * ALBEDO * ATTENUATION;
}