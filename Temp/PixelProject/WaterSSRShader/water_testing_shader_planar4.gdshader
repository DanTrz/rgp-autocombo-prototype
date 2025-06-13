//shader_type spatial;
//render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
//
//uniform sampler2D reflection_texture : hint_default_black;
//uniform sampler2D normal_texture : hint_normal;
//uniform float normal_scale = 0.05;
//uniform vec2 normal_uv_scale = vec2(4.0, 4.0);
//uniform vec3 water_color : source_color = vec3(0.0, 0.1, 0.2);
//uniform float fresnel_power = 3.0;
//uniform float reflection_strength = 1.0;
//
//void fragment() {
    //vec2 time_offset = vec2(TIME, TIME);
    //vec2 normal_uv = UV * normal_uv_scale + time_offset;
    //vec3 normal_map = texture(normal_texture, normal_uv).rgb * 2.0 - 1.0;
//
    //vec3 normal = normalize(NORMAL + normal_map * normal_scale);
    //vec3 view_dir = normalize(-VERTEX);
//
    //float fresnel = pow(1.0 - dot(normal, view_dir), fresnel_power);
//
    //vec2 screen_uv = SCREEN_UV + normal_map.xy * 0.02;
    ////vec3 reflection = texture(reflection_texture, screen_uv).rgb;
    //vec3 reflection = texture(reflection_texture, SCREEN_UV).xyz;
	//
//
    //vec3 base_color = mix(water_color, reflection, fresnel * reflection_strength);
    //ALBEDO = base_color;
//}
shader_type spatial;

uniform sampler2D reflection_texture : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 1.0; // Note: scale is now handled inside the TBN matrix logic
uniform vec2 normal_uv_scale = vec2(4.0, 4.0);
uniform vec3 water_color : source_color = vec3(0.0, 0.1, 0.2);
uniform float fresnel_power = 5.0;
uniform float reflection_strength = 1.0;
uniform mat4 reflection_view_proj;

varying vec3 world_pos;

void vertex() {
	// Pass the world-space vertex position to the fragment shader
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// --- Reflection UV Calculation ---
	vec4 clip_space = reflection_view_proj * vec4(world_pos, 1.0);
	vec2 proj_uv = clip_space.xy / clip_space.w;
	proj_uv = proj_uv * 0.5 + 0.5;
	vec3 reflection_color = texture(reflection_texture, proj_uv).rgb;

	// --- Normal Calculation (The Correct Way) ---
	vec2 time_offset = vec2(TIME * 0.02);
	vec2 normal_uv = UV * normal_uv_scale + time_offset;
	
	// 1. Get the base world-space vectors of the surface
	vec3 N = normalize(NORMAL);
	vec3 T = normalize(TANGENT);
	vec3 B = normalize(BINORMAL);
	mat3 TBN = mat3(T, B, N); // Matrix to convert from tangent-space to world-space

	// 2. Sample the normal map and scale it
	vec3 normal_map_val = texture(normal_texture, normal_uv).rgb * 2.0 - 1.0;
	normal_map_val.xy *= normal_scale;

	// 3. Transform the normal map vector into a true world-space normal
	vec3 world_normal = normalize(TBN * normal_map_val);

	// --- Fresnel Calculation ---
	// Use the known correct world-space normal and world-space view vector
	vec3 V = normalize(CAMERA_POSITION_WORLD - world_pos); // Vector from surface to camera
	float dot_product = dot(V, world_normal);
	float fresnel = pow(1.0 - clamp(dot_product, 0.0, 1.0), fresnel_power);

	// --- Final Color Mix ---
	vec3 final_color = mix(water_color, reflection_color, fresnel * reflection_strength);
	ALBEDO = final_color;
}