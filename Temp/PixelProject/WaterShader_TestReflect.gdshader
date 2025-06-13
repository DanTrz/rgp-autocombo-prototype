shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_toon, specular_toon;

// Orthographic camera support
uniform bool is_orthographic = true;

// Core water colors
uniform vec3 color_shallow : source_color = vec3(0.01, 0.2, 0.3);
uniform vec3 color_deep : source_color = vec3(0.3, 0.5, 0.6);
uniform float transparency : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.35;

// Depth visualization
uniform float max_visible_depth : hint_range(0.1, 100.0, 0.1) = 20.0;

// Wave textures and animation
uniform sampler2D wave_a : filter_nearest;
uniform sampler2D wave_b : filter_nearest;
uniform vec2 wave_move_direction_a = vec2(-1.0, 0.0);
uniform vec2 wave_move_direction_b = vec2(0.0, 1.0);
uniform float wave_noise_scale_a : hint_range(0.1, 20.0, 0.1)  = 5.0;
uniform float wave_noise_scale_b : hint_range(0.1, 20.0, 0.1)  = 5.0;
uniform float wave_time_scale_a : hint_range(0.01, 2.0, 0.01)  = 0.1;
uniform float wave_time_scale_b: hint_range(0.01, 2.0, 0.01)  = 0.1;
uniform float wave_height_scale : hint_range(0.1, 2.5, 0.1)  = 0.4;
uniform float wave_normal_flatness : hint_range(0.1, 100.0, 0.1) = 50.0;

// Surface detail normals
uniform sampler2D surface_normals_a : filter_nearest;
uniform sampler2D surface_normals_b : filter_nearest;
uniform vec2 surface_normals_move_direction_a = vec2(-1.0, 0.2);
uniform vec2 surface_normals_move_direction_b = vec2(0.2, 1.0);
uniform float surface_texture_roughness : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float surface_texture_scale : hint_range(0.001, 2.0, 0.001) = 0.1;
uniform float surface_texture_time_scale : hint_range(0.001, 2.0, 0.001) = 0.06;

// Orthographic-optimized SSR settings
uniform float ssr_resolution   : hint_range(0.01, 10.0, 0.1) = 1.0;
uniform float ssr_max_travel   : hint_range(0.0, 200.0, 0.1) = 30.0;
uniform float ssr_max_diff     : hint_range(0.1, 10.0, 0.1) = 4.0;
uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float ssr_screen_border_fadeout : hint_range(0.0, 1.0, 0.1) = 0.3;

// Pixel art specific
uniform int pixel_snap_resolution : hint_range(1, 8) = 2;
uniform bool enable_pixel_snapping = true;

// Refraction
uniform float refraction_intensity : hint_range(0.0, 1.0, 0.01) = 0.4; 

// Water edge/foam
uniform vec3 border_color : source_color = vec3(1.0);
uniform float border_scale : hint_range(0.0, 5.0, 0.01) = 0.75;
uniform float border_near = 0.5;
uniform float border_far = 300.0;

// Cutout for objects in water
uniform float cut_out_x = 0.0;
uniform float cut_out_z = 0.0;

// Screen textures
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

varying vec2 vertex_uv; 
varying vec3 local_position;

float get_wave_height(vec2 uv_a, vec2 uv_b) {
    float height1 = texture(wave_a, uv_a).y;
    float height2 = texture(wave_b, uv_b).y;
    return (height1 + height2) / 2.0;
}

vec3 get_mixed_normals(vec3 color1, vec3 color2) {
    vec3 normal1 = normalize(color1 * 2.0 - 1.0);
    vec3 normal2 = normalize(color2 * 2.0 - 1.0);
    vec3 up = vec3(0.0, 0.0, 1.0);
    vec3 tangent = normalize(normal1 + normal2);
    vec3 binormal = normalize(cross(up, tangent));
    vec3 mixedNormal = normalize(cross(tangent, binormal));
    return mixedNormal * 0.5;
}

void vertex() {
    local_position = VERTEX;
    vertex_uv = (MODEL_MATRIX * vec4(local_position, 1.0)).xz;
    
    vec2 uv_a = vertex_uv / wave_noise_scale_a + (wave_move_direction_a * TIME * wave_time_scale_a);
    vec2 uv_b = vertex_uv / wave_noise_scale_b + (wave_move_direction_b * TIME * wave_time_scale_b);
    VERTEX.y += get_wave_height(uv_a, uv_b) * wave_height_scale;
    
    float normal_height_scale = wave_height_scale / wave_normal_flatness;
    vec2 e = vec2(0.01, 0.0);
    vec3 normal = normalize(vec3(
        get_wave_height(uv_a - e, uv_b - e) * normal_height_scale - get_wave_height(uv_a + e, uv_a + e) * normal_height_scale, 
        2.0 * e.x, 
        get_wave_height(uv_a - e.yx, uv_b - e.yx) * normal_height_scale - get_wave_height(uv_a + e.yx, uv_b + e.yx) * normal_height_scale
    ));
    NORMAL = normal;
}

bool is_within_screen_boundaries(vec2 position) {
    return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
}

vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m) {
    vec4 position_clip_space = proj_m * vec4(position_view_space, 1.0);
    vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
    return position_ndc * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, is_orthographic ? (depth * 2.0 - 1.0) : depth, 1.0);
    vec4 view_pos = inv_proj_m * ndc;
    return view_pos.xyz / view_pos.w;
}

float linear_depth(float cur_depth) {
    return is_orthographic ? cur_depth : border_far * border_near / (border_near + cur_depth * (border_far - border_near));
}

float normalize_float(float min_v, float max_v, float value) {
    float clamped_value = clamp(value, min_v, max_v);
    return (clamped_value - min_v) / (max_v - min_v);
}

float get_screen_border_alpha(vec2 screen_position) {
    vec2 shifted = 4.0 * screen_position * (1.0 - screen_position);
    float mask = shifted.x * shifted.y;
    float offset = mix(0.0, 0.5, (clamp(ssr_screen_border_fadeout, 0.75, 1.0) - 0.75) / 0.25);
    float alpha = clamp(smoothstep(0.0, 2.0 * ssr_screen_border_fadeout, mask) - offset, 0.0, 1.0);
    return ssr_screen_border_fadeout < 0.001 ? 1.0 : alpha;
}

// Pixel-snapping helper
vec2 snap_to_pixel(vec2 uv, float pixel_size) {
    return floor(uv * pixel_size) / pixel_size;
}

// Optimized SSR for orthographic projection
vec4 get_ssr_color_orthographic(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m) {
    if (ssr_max_travel < 0.001) return vec4(0.0);
    
    vec3 current_position = surface_view_position;
    vec3 reflect_vec = normalize(reflect(-view_view_space, normal_view_space));
    vec3 color = vec3(-1.0);
    vec2 screen_pos = vec2(0.0);
    
    // Simplified stepping for orthographic
    float step_size = ssr_resolution * (is_orthographic ? 2.0 : 1.0);
    int max_steps = int(ssr_max_travel / step_size);
    
    for (int i = 0; i < max_steps && color.x < 0.0; i++) {
        current_position += reflect_vec * step_size;
        screen_pos = get_uv_from_view_position(current_position, proj_m);
        
        // Pixel snap for cleaner reflections
        if (enable_pixel_snapping) {
            screen_pos = snap_to_pixel(screen_pos, float(pixel_snap_resolution) * 640.0);
        }
        
        if (!is_within_screen_boundaries(screen_pos)) break;
        
        float sampled_depth = texture(DEPTH_TEXTURE, screen_pos).x;
        vec3 depth_pos = get_view_position_from_uv(screen_pos, sampled_depth, inv_proj_m);
        
        float diff = is_orthographic ? 
            abs(depth_pos.z - current_position.z) : 
            depth_pos.z - current_position.z;
        
        if (diff >= 0.0 && diff < ssr_max_diff) {
            color = texture(SCREEN_TEXTURE, screen_pos).rgb;
        }
    }
    
    float alpha = color.x >= 0.0 ? get_screen_border_alpha(screen_pos) : 0.0;
    return vec4(max(color, vec3(0.0)), alpha);
}

vec2 get_refracted_uv(vec2 raw_uv, float depth, vec3 view, vec3 normal, mat4 proj, mat4 inv_proj) {
    vec3 view_pos = get_view_position_from_uv(raw_uv, depth, inv_proj);
    float dist = clamp(length(raw_uv - vec2(0.5)) * 2.0, 0.0, 1.0);
    float refract_factor = mix(1.0 - refraction_intensity, 1.0, dist);
    vec3 refract_pos = view_pos + normalize(refract(view, -normal, refract_factor));
    vec2 refracted = get_uv_from_view_position(refract_pos, proj);
    
    // Pixel snap refraction for consistency
    if (enable_pixel_snapping) {
        refracted = snap_to_pixel(refracted, float(pixel_snap_resolution) * 640.0);
    }
    
    return refracted;
}

void fragment() {
    vec3 normal = NORMAL;
    float screen_depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).x;
    
    vec2 refraction_uv = SCREEN_UV;
    if (refraction_intensity > 0.0 && !is_orthographic) {
        refraction_uv = get_refracted_uv(SCREEN_UV, screen_depth_raw, VIEW, normal, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
    } else if (is_orthographic && refraction_intensity > 0.0) {
        // Simplified refraction for orthographic
        vec2 distortion = normal.xz * refraction_intensity * 0.05;
        refraction_uv = SCREEN_UV + distortion;
        if (enable_pixel_snapping) {
            refraction_uv = snap_to_pixel(refraction_uv, float(pixel_snap_resolution) * 640.0);
        }
    }
    
    float screen_depth = texture(DEPTH_TEXTURE, refraction_uv).x;
    float surface_depth = FRAGCOORD.z;
    
    float border_diff = linear_depth(screen_depth_raw) - linear_depth(surface_depth);
    
    vec2 time_vector = (TIME * surface_normals_move_direction_a) * surface_texture_time_scale;
    vec2 time_vector2 = (TIME * surface_normals_move_direction_b) * surface_texture_time_scale;
    
    vec3 normal_tex = get_mixed_normals(
        texture(surface_normals_a, vertex_uv * surface_texture_scale + time_vector).xyz,
        texture(surface_normals_b, vertex_uv * surface_texture_scale + time_vector2).xyz
    );
    vec3 normal_blend = mix(normal, normal_tex, surface_texture_roughness);
    
    vec3 screen_pos = get_view_position_from_uv(refraction_uv, screen_depth, INV_PROJECTION_MATRIX);
    vec3 surface_pos = get_view_position_from_uv(SCREEN_UV, surface_depth, INV_PROJECTION_MATRIX);
    
    float depth_visibility = 1.0 - normalize_float(0.0, max_visible_depth, length(surface_pos - screen_pos));
    
    vec3 screen_color = texture(SCREEN_TEXTURE, refraction_uv).rgb;
    vec4 ssr_color = get_ssr_color_orthographic(surface_pos, normal, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
    
    vec3 surface_trans = mix(color_shallow, screen_color, transparency);
    vec3 surface_depth_mix = mix(color_deep, surface_trans, depth_visibility);
    vec3 ssr_mix = (ssr_color.r >= 0.0) ? mix(surface_depth_mix, ssr_color.rgb, ssr_mix_strength * ssr_color.a) : surface_depth_mix;
    vec3 water_color = (is_orthographic && ssr_color.r >= 0.0) ? ssr_mix : surface_depth_mix;
    
    vec3 final_color = mix(border_color, water_color, step(border_scale, border_diff));
    
    // Cutout logic
    if (cut_out_x > 0.0 && cut_out_z > 0.0) {
        float half_x = cut_out_x / 2.0;
        float half_z = cut_out_z / 2.0;
        if (abs(local_position.x) < half_x && abs(local_position.z) < half_z) discard;
    }
    
    ALBEDO = final_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL = normal_blend;
}