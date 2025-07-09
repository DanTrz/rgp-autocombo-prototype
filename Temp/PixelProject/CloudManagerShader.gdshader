// Cloud Mesh Custom Shader - Perfect Synchronization with Grass Shader
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Global uniforms (same as grass shader)
global uniform vec3 cloud_area_center;
global uniform float cloud_area_size;
global uniform float cloud_texture_scale;
global uniform vec2 cloud_movement_offset;

// Cloud-specific uniforms
uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float cloud_alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.55;
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Basic material properties
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Debug controls
uniform bool debug_show_uv = false;
uniform bool debug_show_scaled_uv = false;

varying vec3 world_position;

void vertex() {
    // Calculate world position for UV projection
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Use WORLD PROJECTION UV (same as grass shader) instead of mesh UV
    vec2 relative_pos = world_position.xz - cloud_area_center.xz;
    vec2 normalized = relative_pos / cloud_area_size;
    vec2 uv = normalized + vec2(0.5);
    uv += cloud_movement_offset;
    
    // Apply texture scaling (same as grass shader)
    vec2 scaled_uv = uv * cloud_texture_scale;
    
    // Sample cloud texture
    vec4 cloud_sample = texture(cloud_texture, scaled_uv);
    
    // Debug visualizations or normal rendering
    if (debug_show_uv) {
        ALBEDO = vec3(fract(uv), 0.0);
        ALPHA = 1.0;
    } else if (debug_show_scaled_uv) {
        ALBEDO = vec3(fract(scaled_uv), 0.0);
        ALPHA = 1.0;
    } else {
        // Normal cloud rendering
        ALBEDO = cloud_sample.rgb * cloud_color.rgb;
        ALPHA = cloud_sample.a * cloud_color.a;
    }
    
    // Apply alpha scissor threshold
    ALPHA_SCISSOR_THRESHOLD = cloud_alpha_scissor_threshold;
    
    // Material properties
    METALLIC = metallic;
    ROUGHNESS = roughness;
    SPECULAR = specular;
}