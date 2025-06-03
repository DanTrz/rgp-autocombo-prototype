shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

// Uniforms from C# script
uniform vec3 u_light_direction_world; 
uniform vec4 u_light_color; // Changed from vec3 to vec4 to include alpha
uniform float u_light_intensity;
uniform float u_max_ray_length;
uniform float u_ray_base_width;
uniform float u_ray_decay_factor; 

// Camera-related uniforms passed from C#
uniform mat4 u_projection_matrix;
uniform mat4 u_inv_projection_matrix;
uniform mat4 u_view_matrix;
uniform mat4 u_inv_view_matrix; // This is the camera's global transform matrix
uniform vec3 u_camera_pos_world;
uniform vec3 u_camera_right_world; // Camera's world-space right vector

// Standard Godot uniform for depth texture
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

// Varyings
varying float v_distance_along_ray_norm; 
varying vec2 v_uv_local; 
varying vec3 v_world_pos; // World position of the vertex


// Function to reconstruct world position from depth and screen UV
vec3 get_world_pos_from_depth(vec2 screen_uv, float depth_sample) {
    vec4 ndc = vec4(screen_uv * 2.0 - 1.0, depth_sample * 2.0 - 1.0, 1.0);
    vec4 world_pos_h = u_inv_projection_matrix * u_inv_view_matrix * ndc; 
    return world_pos_h.xyz / world_pos_h.w;
}


void vertex() {
    // MODEL_MATRIX holds the transform of the current instance.
    vec3 ray_origin_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    float t = VERTEX.y + 0.5; 
    v_distance_along_ray_norm = t;
    v_uv_local = UV;

    // Billboard the quad
    vec3 view_dir_to_ray_origin = normalize(ray_origin_world - u_camera_pos_world); 
    vec3 billboard_side_vector = normalize(cross(u_light_direction_world, view_dir_to_ray_origin));
    
    if (length(billboard_side_vector) < 0.001) {
        billboard_side_vector = u_camera_right_world; // Use passed camera right vector
    }

    vec3 point_on_ray_axis = ray_origin_world + u_light_direction_world * t * u_max_ray_length;
    v_world_pos = point_on_ray_axis + billboard_side_vector * VERTEX.x * u_ray_base_width;
    
    POSITION = u_projection_matrix * u_view_matrix * vec4(v_world_pos, 1.0);
}

void fragment() {
    float alpha = 1.0;

    vec4 clip_pos = u_projection_matrix * u_view_matrix * vec4(v_world_pos, 1.0);
    vec2 screen_uv = (clip_pos.xy / clip_pos.w) * 0.5 + 0.5;

    if (screen_uv.x < 0.0 || screen_uv.x > 1.0 || screen_uv.y < 0.0 || screen_uv.y > 1.0 || clip_pos.w < 0.0) {
        discard; 
    }
    
    float scene_depth_sample_raw = texture(DEPTH_TEXTURE, screen_uv).r;
    vec3 scene_world_pos_at_frag_uv = get_world_pos_from_depth(screen_uv, scene_depth_sample_raw); 
    
    float fragment_view_depth = -(u_view_matrix * vec4(v_world_pos, 1.0)).z;
    float scene_view_depth_at_frag_uv = -(u_view_matrix * vec4(scene_world_pos_at_frag_uv, 1.0)).z;
    
    float depth_bias = 0.05; 
    if (fragment_view_depth > scene_view_depth_at_frag_uv - depth_bias) {
        alpha = 0.0; 
        discard; 
    }

    float decay = pow(max(0.0, 1.0 - v_distance_along_ray_norm), u_ray_decay_factor); 
    alpha *= decay;

    // Now u_light_color.a is valid as u_light_color is vec4
    alpha = clamp(alpha * u_light_intensity * u_light_color.a, 0.0, 1.0);

    if (alpha < 0.001) { 
        discard;
    }

    ALBEDO = u_light_color.rgb; 
    ALPHA = alpha; 
}