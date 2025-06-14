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

// Advanced reflection parameters
group_uniforms AdvancedControls; //GROUP
uniform bool enable_perturb_scale = false;
uniform float perturb_scale : hint_range(0.0, 1.0) = 0.1;
uniform float perturb_frequency : hint_range(0.1, 10.0) = 1.0;
uniform float clip_bias : hint_range(-0.1, 0.1) = 0.01;
uniform vec3 reflection_plane_normal = vec3(0.0, 1.0, 0.0);
uniform float reflection_plane_distance = 0.0;

// ENHANCED Water Depth Reflection - Improved precision and control
group_uniforms WaterEffects; //GROUP for WaterEffects
uniform bool enable_depth_filtering = false;
uniform float reflection_depth_cutoff : hint_range(0.0, 10.0) = 2.0;
uniform float depth_fade_smoothness : hint_range(0.1, 5.0) = 1.0;
uniform float planar_surface_y = 0.0; // Passed from GDScript

// NEW: Enhanced Depth Detection Controls
uniform bool enable_precise_depth_detection = true; // More accurate depth calculations
uniform float depth_precision_bias : hint_range(-1.0, 1.0) = 0.1; // Adjust for pixel art precision
uniform float underwater_reflection_intensity : hint_range(0.0, 1.0) = 0.2; // Allow some underwater reflection
uniform float above_water_boost : hint_range(1.0, 2.0) = 1.2; // Enhance above-water reflections

// NEW: Gradient-based Detection (for partial objects)
uniform bool enable_gradient_detection = true; // Detect object edges crossing water surface
uniform float gradient_threshold : hint_range(0.1, 2.0) = 0.5; // Sensitivity for detecting water line
uniform float gradient_smooth_range : hint_range(0.1, 1.0) = 0.3; // Smooth transition at water line

// Manual Reflection Clipping Controls (KEEP - useful fallback)
uniform bool enable_reflection_clipping = false;
uniform float reflection_clip_top : hint_range(0.0, 1.0) = 0.0;
uniform float reflection_clip_bottom : hint_range(0.0, 1.0) = 0.0;
uniform float reflection_clip_fade : hint_range(0.0, 0.5) = 0.1;

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

// Color correction uniforms
group_uniforms ColorCorrection;
uniform bool enable_color_correction = false;
uniform float brightness_multiplier : hint_range(0.5, 3.0) = 1.0;
uniform float contrast_adjustment : hint_range(0.5, 2.0) = 1.0;
uniform float saturation_boost : hint_range(0.5, 2.0) = 1.0;
uniform float gamma_correction : hint_range(0.3, 1.5) = 1.0;

// Varying variables for advanced calculations
varying vec3 world_position;
varying vec3 world_normal;
varying float vertex_displacement;

// Color correction function for non-layer-1 fix
vec3 apply_color_correction(vec3 color) {
    if (!enable_color_correction) {
        return color;
    }

    // Gamma correction (applied first for proper color space)
    color = pow(color, vec3(gamma_correction));

    // Brightness adjustment
    color *= brightness_multiplier;

    // Contrast adjustment (around middle gray)
    color = mix(vec3(0.5), color, contrast_adjustment);

    // Saturation boost
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luminance), color, saturation_boost);

    // Clamp to prevent overflow
    color = clamp(color, vec3(0.0), vec3(1.0));

    return color;
}

// Helper function for simple reflection calculations (no matrix access)
float calculate_simple_reflection_factor(float depth_below_water) {
    if (depth_below_water > reflection_depth_cutoff) {
        float fade = smoothstep(reflection_depth_cutoff, reflection_depth_cutoff + depth_fade_smoothness, depth_below_water);
        return mix(1.0, underwater_reflection_intensity, fade);
    }
    return 1.0;
}

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

	// Manual Reflection Clipping (KEPT - useful fallback for uniform scenes)
	if (enable_reflection_clipping) {
		float clip_mask = 1.0;

		// Bottom clipping - useful for hiding underwater reflections
		if (warped_uv.y < reflection_clip_bottom) {
			clip_mask *= smoothstep(reflection_clip_bottom - reflection_clip_fade, reflection_clip_bottom, warped_uv.y);
		}

		// Top clipping - if needed for other effects
		if (warped_uv.y > 1.0 - reflection_clip_top) {
			clip_mask *= smoothstep(1.0 - reflection_clip_top + reflection_clip_fade, 1.0 - reflection_clip_top, warped_uv.y);
		}

		// Apply clipping mask to reflection
		reflection_tex.rgb *= clip_mask;
	}

	// ENHANCED Water Depth Reflection Filtering - Per-pixel precision for partial objects
	if (enable_depth_filtering) {
		// Get the depth of the reflected object
		float depth_raw = texture(depth_texture, warped_uv).r;

		// Convert to world Y position with enhanced precision for pixel art
		vec3 ndc = vec3(warped_uv * 2.0 - 1.0, depth_raw);
		vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		float object_world_y = world.y / world.w;

		// Apply precision bias for pixel art rendering (640x360 optimization)
		object_world_y += depth_precision_bias;

		// Calculate how far below water surface this pixel is
		float depth_below_water = planar_surface_y - object_world_y;

		float reflection_factor = 1.0;

		if (enable_precise_depth_detection) {
			// SIMPLIFIED LOGIC - Test if new parameters work at all
			if (depth_below_water > 0.0) {
				// Object is underwater - apply underwater intensity
				reflection_factor = underwater_reflection_intensity;
			} else {
				// Object is above water - apply boost
				reflection_factor = above_water_boost;
			}
		} else {
			// Original simple method (fallback)
			if (depth_below_water > reflection_depth_cutoff) {
				float fade = smoothstep(reflection_depth_cutoff, reflection_depth_cutoff + depth_fade_smoothness, depth_below_water);
				reflection_factor = (1.0 - fade);
			}
		}

		// Apply the calculated reflection factor
		reflection_factor = clamp(reflection_factor, 0.0, 2.0);
		reflection_tex.rgb *= reflection_factor;
	}

	// APPLY COLOR CORRECTION
	reflection_tex.rgb = apply_color_correction(reflection_tex.rgb);

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