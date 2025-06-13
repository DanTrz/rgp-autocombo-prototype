shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Planar Reflection Parameters (set by C# script)
uniform sampler2D pr_viewport : hint_default_black, filter_linear;
uniform vec4 pr_viewport_rect = vec4(-2.0, -2.0, 4.0, 4.0);
uniform float pr_perturb_scale : hint_range(0.0, 1.0) = 0.1;

// Water appearance
uniform vec3 water_color : source_color = vec3(0.1, 0.3, 0.5);
uniform vec3 deep_water_color : source_color = vec3(0.05, 0.15, 0.25);
uniform float water_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.1;
uniform float water_opacity : hint_range(0.0, 1.0) = 0.8;
uniform float fresnel_power : hint_range(1.0, 8.0) = 2.0;

// Reflection control
uniform vec2 reflection_offset = vec2(0.0, 0.0); // Manual offset for reflection position
uniform vec2 reflection_scale = vec2(1.0, 1.0); // Scale the reflection sampling
uniform float reflection_rotation : hint_range(-3.14159, 3.14159) = 0.0; // Rotate reflection
uniform bool use_fixed_reflection_dir = false; // Use fixed direction instead of view-based
uniform vec3 fixed_reflection_direction = vec3(0.0, -1.0, -1.0); // Fixed reflection direction

// Normal map for water surface
uniform sampler2D normal_texture : hint_normal, filter_linear;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform vec2 normal_uv_scale = vec2(4.0, 4.0);

// Animation
uniform vec2 wave_direction_1 = vec2(1.0, 0.0);
uniform vec2 wave_direction_2 = vec2(0.0, 1.0);
uniform float wave_speed_1 : hint_range(0.0, 1.0) = 0.1;
uniform float wave_speed_2 : hint_range(0.0, 1.0) = 0.15;

// Depth fade for edges
uniform float edge_fade_distance : hint_range(0.1, 10.0) = 2.0;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

// Pixel art specific
uniform bool pixel_snap = true;
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;

// Debug
uniform bool debug_reflection = false;
uniform bool show_reflection_only = false;

varying vec2 world_uv;
varying vec3 world_pos;
varying mat3 tbn_matrix;

// Helper functions
vec3 pr_fresnel(vec3 f0, float cos_theta) {
    return f0 + (vec3(1.0) - f0) * pow(1.0 - abs(cos_theta), 5.0);
}

vec4 pr_cubic(float v) {
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}

vec4 pr_texture_bicubic(sampler2D source_sampler, vec2 tex_coords) {
    ivec2 tex_size = textureSize(source_sampler, 0);
    vec2 inv_tex_size = 1.0 / vec2(tex_size);

    tex_coords = tex_coords * vec2(tex_size) - 0.5;

    vec2 fxy = fract(tex_coords);
    tex_coords -= fxy;

    vec4 xcubic = pr_cubic(fxy.x);
    vec4 ycubic = pr_cubic(fxy.y);

    vec4 c = tex_coords.xxyy + vec2(-0.5, +1.5).xyxy;

    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4(xcubic.yw, ycubic.yw) / s;

    offset *= inv_tex_size.xxyy;

    vec4 sample0 = texture(source_sampler, offset.xz);
    vec4 sample1 = texture(source_sampler, offset.yz);
    vec4 sample2 = texture(source_sampler, offset.xw);
    vec4 sample3 = texture(source_sampler, offset.yw);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec3 pr_line_plane_intersect(vec3 line_origin, vec3 line_dir, vec3 plane_origin, vec3 plane_normal) {
    return line_origin + line_dir * dot(plane_normal, plane_origin - line_origin) / dot(plane_normal, line_dir);
}

vec2 snap_to_pixel_grid(vec2 uv, float grid_size) {
    return floor(uv * grid_size) / grid_size;
}

vec2 rotate_uv(vec2 uv, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    mat2 rotation = mat2(vec2(c, -s), vec2(s, c));
    return rotation * uv;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_uv = world_pos.xz * 0.1; // World space UVs for consistent tiling
    
    // Setup TBN matrix for normal mapping
    vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec3 t = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
    vec3 b = normalize(cross(n, t));
    tbn_matrix = mat3(t, b, n);
}

void fragment() {
    // Animated UVs for water normal
    vec2 time_offset_1 = TIME * wave_speed_1 * wave_direction_1;
    vec2 time_offset_2 = TIME * wave_speed_2 * wave_direction_2;
    
    vec2 normal_uv_1 = world_uv * normal_uv_scale + time_offset_1;
    vec2 normal_uv_2 = world_uv * normal_uv_scale * 0.75 + time_offset_2;
    
    // Sample and blend normal maps
    vec3 normal_1 = texture(normal_texture, normal_uv_1).rgb;
    vec3 normal_2 = texture(normal_texture, normal_uv_2).rgb;
    vec3 normal_map = normalize(normal_1 + normal_2 - vec3(1.0));
    
    // Convert from texture space to world space
    normal_map = normal_map * 2.0 - 1.0;
    normal_map.xy *= normal_scale;
    normal_map = normalize(normal_map);
    
    vec3 world_normal = normalize(tbn_matrix * normal_map);
    
    // Calculate view-dependent values
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
    float fresnel = pow(1.0 - max(0.0, dot(world_normal, view_dir)), fresnel_power);
    
    // Depth fade for edges
    float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    vec4 world_coord = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
    world_coord.xyz /= world_coord.w;
    float depth_diff = distance(world_coord.xyz, VERTEX);
    float depth_fade = exp(-depth_diff / edge_fade_distance);
    depth_fade = clamp(depth_fade, 0.0, 1.0);
    
    // Calculate reflection
    vec3 pr_ray_origin = CAMERA_POSITION_WORLD;
    vec3 pr_plane_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 pr_plane_normal = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz); // Y-up for water
    
    // Choose reflection direction
    vec3 reflected_view;
    if (use_fixed_reflection_dir) {
        // Use fixed direction (useful for stylized reflections)
        reflected_view = normalize(fixed_reflection_direction);
    } else {
        // Use view-based reflection
        reflected_view = reflect(-view_dir, world_normal);
    }
    
    // Perturb reflection based on normal
    vec4 pr_point_on_plane = VIEW_MATRIX * vec4(world_pos + reflected_view * pr_perturb_scale, 1.0);
    pr_point_on_plane.xyz = pr_line_plane_intersect(pr_ray_origin, normalize(pr_point_on_plane.xyz), pr_plane_origin, pr_plane_normal);
    
    vec4 pr_model_pos = inverse(MODEL_MATRIX) * vec4(pr_point_on_plane.xyz, 1.0);
    vec2 pr_uv = (vec2(pr_model_pos.x, -pr_model_pos.z) - pr_viewport_rect.xy) / pr_viewport_rect.zw;
    
    // Apply reflection transformations
    // First, center the UV
    pr_uv -= vec2(0.5);
    
    // Apply rotation
    if (reflection_rotation != 0.0) {
        pr_uv = rotate_uv(pr_uv, reflection_rotation);
    }
    
    // Apply scale
    pr_uv *= reflection_scale;
    
    // Re-center and apply offset
    pr_uv += vec2(0.5) + reflection_offset;
    
    // Pixel snap for pixel art
    if (pixel_snap) {
        pr_uv = snap_to_pixel_grid(pr_uv, pixel_size * 100.0);
    }
    
    // Sample reflection with bounds checking
    vec4 pr_reflection = vec4(0.0);
    if (pr_uv.x >= 0.0 && pr_uv.x <= 1.0 && pr_uv.y >= 0.0 && pr_uv.y <= 1.0) {
        // Check if texture exists by sampling it
        vec4 tex_sample = texture(pr_viewport, pr_uv);
        if (tex_sample.a > 0.0 || tex_sample.r > 0.0 || tex_sample.g > 0.0 || tex_sample.b > 0.0) {
            pr_reflection = pr_texture_bicubic(pr_viewport, pr_uv);
            if (any(isnan(pr_reflection))) {
                pr_reflection = vec4(0.0);
            }
        }
    }
    
    // Sample refracted scene
    vec2 refraction_offset = world_normal.xz * 0.05 * (1.0 - depth_fade);
    vec3 refracted_color = texture(SCREEN_TEXTURE, SCREEN_UV + refraction_offset).rgb;
    
    // Mix water color with depth
    vec3 water_mix = mix(deep_water_color, water_color, depth_fade);
    
    // Combine refraction with water color
    vec3 underwater_color = mix(refracted_color, water_mix, water_opacity);
    
    // Apply reflection based on fresnel
    vec3 final_color = mix(underwater_color, pr_reflection.rgb, fresnel * pr_reflection.a);
    
    // Output
    if (debug_reflection) {
        // Debug visualization
        if (pr_reflection.a > 0.0) {
            ALBEDO = vec3(0.0, 1.0, 0.0); // Green where reflection exists
        } else {
            ALBEDO = vec3(1.0, 0.0, 0.0); // Red where no reflection
        }
    } else if (show_reflection_only) {
        ALBEDO = pr_reflection.rgb;
    } else {
        ALBEDO = final_color;
    }
    
    METALLIC = water_metallic;
    ROUGHNESS = water_roughness;
    NORMAL = world_normal;
    
    // Add slight emission for reflections
    EMISSION = pr_reflection.rgb * fresnel * pr_reflection.a * 0.1;
}