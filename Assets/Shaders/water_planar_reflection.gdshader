//##ENHANCED SHADER CODE##=> Enhanced PlanarReflector with Improved Depth Filtering <=####
shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_toon,specular_toon;

// System textures (don't need user modification)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest_mipmap;

// Main surface properties
group_uniforms Main;  //GROUP
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Planar Reflection properties
group_uniforms PlanarReflection; //GROUP
uniform sampler2D reflection_screen_texture: source_color,filter_linear_mipmap,repeat_enable;
uniform float reflection_strength: hint_range(0.0, 1.0) = 0.5;
// Fade effects
uniform float proximity_fade_distance;
// Camera mode handling (set by script)
uniform bool is_orthogonal_camera = false;
uniform float ortho_uv_scale : hint_range(0.1, 3.0) = 1.0;

// Normal mapping and distortion
uniform sampler2D texture_normal : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_normal2: source_color,filter_linear_mipmap,repeat_enable;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float normal_uv_mult : hint_range(0.1, 10.0) = 1.0;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.1;

// UV transformation
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);

// Refraction (optional - only if you use it)
uniform sampler2D texture_refraction : filter_linear_mipmap,repeat_enable;
uniform float refraction : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 refraction_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);

// Varying variables for advanced calculations
varying vec3 world_position;
varying vec3 world_normal;
varying float vertex_displacement;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vertex_displacement = 0.0;
}

void fragment() {
	vec2 base_uv = UV;
	// Enhanced normal sampling with perturbation support
	vec2 normal_uv1 = vec2(base_uv.x - TIME*0.002, base_uv.y - TIME*0.002) * normal_uv_mult;
	vec2 normal_uv2 = vec2(base_uv.x + TIME*0.00025, base_uv.y + TIME*0.0005) * normal_uv_mult;
	vec3 NORMAL_MAP1 = texture(texture_normal, normal_uv1).rgb;
	vec3 NORMAL_MAP2 = texture(texture_normal2, normal_uv2).rgb;
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	// Enhanced distortion calculation with perturb scale
	vec2 distortion = distortion_strength * NORMAL_MAP1.rr - distortion_strength * NORMAL_MAP1.gg;
	vec2 clip_offset = vec2(0.0);
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
	// Sample reflection texture
	vec4 reflection_tex = texture(reflection_screen_texture, warped_uv);
	// Combine normal maps
	vec3 combined_normal = mix(NORMAL_MAP1, NORMAL_MAP2, 0.5);
	NORMAL_MAP = combined_normal;
	NORMAL_MAP_DEPTH = normal_scale;
	// Set base material properties
	vec3 base_albedo = mix(reflection_tex.rgb, albedo_tex.rgb * albedo.rgb, reflection_strength);
	ALBEDO = base_albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	// Enhanced refraction with advanced features
	if (refraction != 0.0) {
		vec3 unpacked_normal = NORMAL_MAP * 2.0 - 1.0;
		unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));

		vec3 ref_normal = normalize(mix(NORMAL, TANGENT * unpacked_normal.x + BINORMAL * unpacked_normal.y + NORMAL * unpacked_normal.z, NORMAL_MAP_DEPTH));
		vec4 refraction_tex = texture(texture_refraction, base_uv);
		vec2 ref_ofs = SCREEN_UV - ref_normal.xy * dot(refraction_tex, refraction_texture_channel) * refraction;

		float ref_amount = 1.0 - mix(reflection_tex.a, albedo.a * albedo_tex.a, reflection_strength);
		EMISSION += textureLod(screen_texture, ref_ofs, ROUGHNESS * 8.0).rgb * ref_amount * EXPOSURE;
		ALBEDO *= 1.0 - ref_amount;
	}
	ALPHA = 1.0;
	// Enhanced proximity fade with foam consideration
	if (proximity_fade_distance > 0.0) {
		float depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
		world_pos.xyz /= world_pos.w;
		float fade_factor = clamp(1.0 - smoothstep(world_pos.z + proximity_fade_distance, world_pos.z, VERTEX.z), 0.0, 1.0);
		ALPHA *= fade_factor;
	}
}