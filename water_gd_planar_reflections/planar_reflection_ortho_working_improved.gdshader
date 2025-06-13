shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_toon,specular_toon;

// Main surface properties
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Reflection properties
uniform sampler2D reflection_screen_texture: source_color,filter_linear_mipmap,repeat_enable;
uniform float reflection_strength: hint_range(0.0, 1.0) = 0.5;

// Normal mapping and distortion
uniform sampler2D texture_normal : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_normal2: source_color,filter_linear_mipmap,repeat_enable;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float normal_uv_mult : hint_range(0.1, 10.0) = 1.0;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.1;

// UV transformation
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset  = vec3(0.0, 0.0, 0.0);

// Refraction (optional - only if you use it)
uniform sampler2D texture_refraction : filter_linear_mipmap,repeat_enable;
uniform float refraction : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 refraction_texture_channel  = vec4(1.0, 0.0, 0.0, 0.0);

// Fade effects
uniform float proximity_fade_distance : hint_range(0.0, 10.0) = 1.0;

// System textures (don't need user modification)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest_mipmap;
uniform sampler2D depth_texture : source_color, hint_depth_texture;

// Camera mode handling (set by script)
uniform bool is_orthogonal_camera = false;
uniform float ortho_uv_scale : hint_range(0.1, 3.0) = 1.0;

// Advanced reflection parameters (NEW)
uniform bool enable_perturb_scale = false;
uniform float perturb_scale : hint_range(0.0, 1.0) = 0.1;
uniform float perturb_frequency : hint_range(0.1, 10.0) = 1.0;
uniform float clip_bias : hint_range(-0.1, 0.1) = 0.01;
uniform vec3 reflection_plane_normal = vec3(0.0, 1.0, 0.0);
uniform float reflection_plane_distance = 0.0;

// Future water features (READY FOR IMPLEMENTATION)
uniform bool enable_wave_displacement = false;
uniform float wave_amplitude : hint_range(0.0, 5.0) = 1.0;
uniform float wave_frequency : hint_range(0.1, 10.0) = 1.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool shoreline_detection = false;
uniform bool caustics_enabled = false;

// Future textures for advanced features (placeholders)
uniform sampler2D foam_texture : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D caustics_texture : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D displacement_texture : source_color,filter_linear_mipmap,repeat_enable;

// Varying variables for advanced calculations
varying vec3 world_position;
varying vec3 world_normal;
varying float vertex_displacement;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	
	// Future wave displacement (ready for implementation)
	vertex_displacement = 0.0;
	if (enable_wave_displacement) {
		// Basic wave displacement calculation (will be enhanced later)
		float wave_time = TIME * wave_frequency;
		float wave_x = sin(world_position.x * 0.1 + wave_time) * wave_amplitude;
		float wave_z = cos(world_position.z * 0.1 + wave_time * 0.7) * wave_amplitude * 0.5;
		vertex_displacement = wave_x + wave_z;
		
		// Apply displacement to vertex
		VERTEX.y += vertex_displacement * 0.1; // Scale down for subtle effect
		
		// Recalculate world position after displacement
		world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
}

void fragment() {
	vec2 base_uv = UV;
	
	// Enhanced normal sampling with perturbation support
	vec2 normal_uv1 = vec2(base_uv.x - TIME*0.002, base_uv.y - TIME*0.002) * normal_uv_mult;
	vec2 normal_uv2 = vec2(base_uv.x + TIME*0.00025, base_uv.y + TIME*0.0005) * normal_uv_mult;
	
	// Apply perturbation frequency if enabled
	if (enable_perturb_scale) {
		normal_uv1 *= perturb_frequency;
		normal_uv2 *= perturb_frequency;
	}
	
	vec3 NORMAL_MAP1 = texture(texture_normal, normal_uv1).rgb;
	vec3 NORMAL_MAP2 = texture(texture_normal2, normal_uv2).rgb;
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	
	// Enhanced distortion calculation with perturb scale
	vec2 distortion = distortion_strength * NORMAL_MAP1.rr - distortion_strength * NORMAL_MAP1.gg;
	
	// Apply perturb scale for more dramatic surface distortion
	if (enable_perturb_scale) {
		distortion *= (1.0 + perturb_scale);
		
		// Add secondary distortion based on vertex displacement
		if (enable_wave_displacement) {
			distortion += vec2(vertex_displacement * perturb_scale * 0.01);
		}
	}
	
	// Apply clip bias for advanced clipping
	vec2 clip_offset = vec2(0.0);
	if (abs(clip_bias) > 0.001) {
		// Calculate distance from reflection plane
		float plane_distance = dot(world_position, reflection_plane_normal) - reflection_plane_distance;
		clip_offset = reflection_plane_normal.xy * clip_bias * sign(plane_distance);
		distortion += clip_offset;
	}
	
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
	
	// Future foam calculation (ready for implementation)
	float foam_factor = 0.0;
	if (shoreline_detection && foam_threshold > 0.0) {
		// Calculate foam based on wave displacement and surface distortion
		float surface_turbulence = length(distortion) + abs(vertex_displacement) * 0.1;
		foam_factor = smoothstep(foam_threshold - 0.1, foam_threshold + 0.1, surface_turbulence);
		
		// Sample foam texture if available
		if (textureSize(foam_texture, 0).x > 1) {
			vec4 foam_color = texture(foam_texture, base_uv * 2.0);
			foam_factor *= foam_color.r;
		}
	}
	
	// Future caustics calculation (ready for implementation)
	vec3 caustics_color = vec3(0.0);
	if (caustics_enabled) {
		// Basic caustics calculation using distorted UVs
		vec2 caustics_uv = base_uv + distortion * 0.5;
		if (textureSize(caustics_texture, 0).x > 1) {
			caustics_color = texture(caustics_texture, caustics_uv * 4.0).rgb;
			caustics_color *= 0.3; // Intensity
		}
	}
	
	// Set base material properties
	vec3 base_albedo = mix(reflection_tex.rgb, albedo_tex.rgb * albedo.rgb, reflection_strength);
	
	// Apply foam if enabled
	if (foam_factor > 0.0) {
		base_albedo = mix(base_albedo, vec3(1.0), foam_factor * 0.8);
	}
	
	// Apply caustics if enabled
	if (caustics_enabled) {
		base_albedo += caustics_color;
	}
	
	ALBEDO = base_albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	
	// Enhanced refraction with advanced features
	if (refraction != 0.0) {
		vec3 unpacked_normal = NORMAL_MAP * 2.0 - 1.0;
		unpacked_normal.z = sqrt(max(0.0, 1.0 - dot(unpacked_normal.xy, unpacked_normal.xy)));
		
		// Apply perturb scale to refraction
		if (enable_perturb_scale) {
			unpacked_normal.xy *= (1.0 + perturb_scale * 0.5);
		}
		
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
		
		// Reduce foam near shore for more realistic effect
		if (shoreline_detection && foam_factor > 0.0) {
			foam_factor *= fade_factor;
		}
		
		ALPHA *= fade_factor;
	}
}