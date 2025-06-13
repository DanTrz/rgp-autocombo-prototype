shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// This uniform is the reflection texture rendered by the C# script's camera
uniform sampler2D pr_viewport : hint_default_black, filter_linear_mipmap;

// Water appearance
uniform vec3 water_color : source_color = vec3(0.1, 0.3, 0.5);
uniform vec3 deep_water_color : source_color = vec3(0.05, 0.15, 0.25);
uniform float water_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.1;
uniform float fresnel_power : hint_range(1.0, 8.0) = 2.0;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.8; // Now controlled by C# script

// Normal map for water surface
uniform sampler2D normal_texture : hint_normal, filter_linear, repeat_enable;
uniform float normal_scale : hint_range(0.0, 0.2) = 0.05;
uniform vec2 normal_uv_scale = vec2(4.0, 4.0);
uniform vec2 wave_direction_1 = vec2(1.0, 0.0);
uniform vec2 wave_direction_2 = vec2(0.0, 1.0);
uniform float wave_speed_1 = 0.1;
uniform float wave_speed_2 = 0.15;

// Depth fade for edges
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear;
uniform float edge_fade_distance : hint_range(0.1, 10.0) = 2.0;

void fragment() {
	// --- Normal Mapping ---
	vec2 time_offset_1 = TIME * wave_speed_1 * wave_direction_1;
	vec2 time_offset_2 = TIME * wave_speed_2 * wave_direction_2;
	
	vec2 normal_uv = UV * normal_uv_scale;
	vec3 normal_1 = texture(normal_texture, normal_uv + time_offset_1).rgb;
	vec3 normal_2 = texture(normal_texture, normal_uv * 0.75 + time_offset_2).rgb;
	vec3 normal_map_texture = normalize(normal_1 + normal_2 - vec3(1.0));
	
	// --- Screen-Space Calculations ---
	// Project the fragment position to screen space to get UVs for the reflection texture
	vec4 screen_pos = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 screen_uv = screen_pos.xy / screen_pos.w * 0.5 + 0.5;

	// Distort the screen UVs with the normal map to create the ripple effect
	vec2 normal_distortion = (normal_map_texture * 2.0 - 1.0).xy * normal_scale;
	vec2 distorted_screen_uv = screen_uv + normal_distortion;

	// --- Reflection ---
	// Sample the pre-rendered reflection texture using the distorted screen-space UVs.
	// This is the correct way to do it. No complex math needed here.
	vec3 reflection_color = texture(pr_viewport, distorted_screen_uv).rgb;
	
	// --- Depth & Color ---
	float scene_depth = texture(DEPTH_TEXTURE, screen_uv).r;
	float frag_depth = FRAGCOORD.z;
	float depth_diff = scene_depth - frag_depth;
	float depth_fade = smoothstep(0.0, edge_fade_distance, depth_diff);
	
	vec3 final_water_color = mix(deep_water_color, water_color, depth_fade);
	
	// --- Final Composition ---
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	vec3 final_color = mix(final_water_color, reflection_color, fresnel * reflection_strength);
	
	ALBEDO = final_color;
	METALLIC = water_metallic;
	ROUGHNESS = water_roughness;
	NORMAL_MAP = normal_map_texture;
	NORMAL_MAP_DEPTH = 1.0; // Use a fixed depth for the built-in normal mapping
}