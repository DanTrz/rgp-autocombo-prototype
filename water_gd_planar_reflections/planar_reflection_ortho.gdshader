shader_type spatial;
render_mode blend_mix,depth_draw_always,cull_back,diffuse_burley,specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float proximity_fade_distance;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float specular;
uniform float metallic;
uniform sampler2D texture_refraction : filter_linear_mipmap_anisotropic,repeat_enable;
uniform float refraction : hint_range(-16,16);
uniform vec4 refraction_texture_channel;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : source_color, hint_depth_texture;
uniform sampler2D texture_normal : hint_roughness_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D texture_normal2 : hint_roughness_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D reflection_screen_texture: source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float normal_scale : hint_range(-16,16);
uniform float normal_uv_mult : hint_range(-16,16);
uniform float distortion_strength;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform float reflection_strength: hint_range(0.001, 1.0) = 0.5;

// New uniforms for camera mode handling
uniform bool is_orthogonal_camera = false;
uniform float ortho_uv_scale : hint_range(0.1, 10.0) = 1.0;
uniform float camera_size = 10.0;
uniform float camera_fov = 70.0;

void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV;
	
	// Sample all textures at once to reduce texture cache misses
	vec2 normal_uv1 = vec2(base_uv.x - TIME*0.002, base_uv.y - TIME*0.002)*normal_uv_mult;
	vec2 normal_uv2 = vec2(base_uv.x + TIME*0.00025, base_uv.y + TIME*0.0005)*normal_uv_mult;
	
	vec3 NORMAL_MAP1 = texture(texture_normal, normal_uv1).rgb;
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	
	// Calculate warped UV with camera mode consideration
	vec2 distortion = distortion_strength * (NORMAL_MAP1.rg - 0.5) * 2.0; // More efficient than .rr - .gg
	
	// Adjust distortion based on camera mode
	if (is_orthogonal_camera) {
		distortion *= ortho_uv_scale;
	}
	
	vec2 warped_uv = SCREEN_UV + distortion;
	
	// Handle UV mapping for orthogonal cameras
	if (is_orthogonal_camera) {
		vec2 center = vec2(0.5, 0.5);
		warped_uv = center + (warped_uv - center) * ortho_uv_scale;
	}
	
	warped_uv = clamp(warped_uv, 0.0, 1.0);
	
	vec4 reflection_tex = texture(reflection_screen_texture, warped_uv);
	
	// Sample other textures only if needed
	vec3 NORMAL_MAP2 = texture(texture_normal2, normal_uv2).rgb;
	vec4 metallic_tex_sample = texture(texture_metallic, base_uv);
	vec4 roughness_tex_sample = texture(texture_roughness, base_uv);
	vec4 refraction_tex_sample = texture(texture_refraction, base_uv);
	
	// Combine calculations
	ALBEDO = mix(reflection_tex.rgb, albedo_tex.rgb * albedo.rgb, reflection_strength);
	METALLIC = dot(metallic_tex_sample, metallic_texture_channel) * metallic;
	ROUGHNESS = roughness_tex_sample.r * roughness; // Assuming red channel
	SPECULAR = specular;
	
	// Optimize normal map blending
	NORMAL_MAP = mix(NORMAL_MAP1, NORMAL_MAP2, 0.5);
	NORMAL_MAP_DEPTH = normal_scale;
	
	// Simplified normal unpacking
	vec3 unpacked_normal = NORMAL_MAP * 2.0 - 1.0;
	unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));
	
	vec3 ref_normal = normalize(mix(NORMAL, TANGENT * unpacked_normal.x + BINORMAL * unpacked_normal.y + NORMAL * unpacked_normal.z, NORMAL_MAP_DEPTH));
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * dot(refraction_tex_sample, refraction_texture_channel) * refraction;
	
	float ref_amount = 1.0 - mix(reflection_tex.a, albedo.a * albedo_tex.a, reflection_strength);
	EMISSION += textureLod(screen_texture, ref_ofs, ROUGHNESS * 8.0).rgb * ref_amount * EXPOSURE;
	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
	
	// Depth-based proximity fade
	float depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
	world_pos.xyz /= world_pos.w;
	ALPHA *= clamp(1.0 - smoothstep(world_pos.z + proximity_fade_distance, world_pos.z, VERTEX.z), 0.0, 1.0);
}