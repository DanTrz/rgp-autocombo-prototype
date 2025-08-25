shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

/* =================== Constants =================== */
const float SMOOTHSTEP_AA = 0.01;

/* =================== Toon Water Core =================== */
group_uniforms toon_water;
uniform vec4 depth_gradient_shallow: source_color = vec4(0.325, 0.807, 0.971, 0.725);
uniform vec4 depth_gradient_deep:    source_color = vec4(0.086, 0.407, 1, 0.749);
uniform float depth_max_distance: hint_range(0, 50) = 1.0;
uniform float depth_factor:       hint_range(0.1, 5.0) = 1.0;
uniform float beer_factor:        hint_range(0.1, 5.0) = 1.5;

/* =================== Foam =================== */
group_uniforms foam;
uniform vec4  foam_color: source_color = vec4(1.0);
uniform float foam_distance:      hint_range(0.001, 0.1) = 0.01;
uniform float foam_max_distance:  hint_range(0.1, 1.0)   = 0.4;
uniform float foam_min_distance:  hint_range(0.01, 0.5)  = 0.04;

/* =================== Surface Noise =================== */
group_uniforms surface_effects;
uniform sampler2D surface_noise:  filter_linear_mipmap, repeat_enable;
uniform sampler2D distort_noise:  filter_linear_mipmap, repeat_enable;
uniform vec2  surface_noise_tiling = vec2(1.0, 4.0);
uniform vec3  surface_noise_scroll = vec3(0.03, 0.03, 0.0);
uniform float surface_noise_cutoff:      hint_range(0, 1) = 0.777;
uniform float surface_distortion_amount: hint_range(0, 2) = 0.27;

/* =================== Material =================== */
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float specular  : hint_range(0.0, 1.0, 0.01) = 0.25;

/* =================== Animation Speeds =================== */
group_uniforms animation_speeds;
uniform float master_time_scale:       hint_range(0.0, 2.0) = 1.0;
uniform float wave_animation_speed:    hint_range(0.0, 2.0) = 1.0;
uniform float reflection_wobble_speed: hint_range(0.0, 2.0) = 1.0;
uniform float foam_animation_speed:    hint_range(0.0, 2.0) = 1.0;

/* =================== Planar Reflection (Multipass) =================== */
group_uniforms planar_reflection;
/* Old single-pass (kept for compatibility, unused here) */
uniform sampler2D reflection_screen_texture : source_color, filter_linear_mipmap, repeat_enable;
/* New multipass inputs */
uniform sampler2D reflection_fg_above_texture : source_color, filter_linear_mipmap, repeat_enable; // masked (alpha=0 underwater)
uniform sampler2D reflection_fg_full_texture  : source_color, filter_linear_mipmap, repeat_enable; // full FG (no mask)
uniform sampler2D reflection_bg_texture       : source_color, filter_linear_mipmap, repeat_enable; // background/sky/terrain

uniform float reflection_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool  reflection_on_top = true; // draw reflection after water if true
uniform bool  is_orthogonal_camera = false;
uniform float ortho_uv_scale       : hint_range(0.1, 3.0) = 1.0;
uniform float reflection_distortion_scale : hint_range(0.0, 2.0, 0.01) = 1.0;

/* Optional extra depth mask (unchanged) */
uniform bool  enable_reflection_depth_mask = false;
uniform float reflection_depth_threshold : hint_range(0.0, 2.0, 0.01) = 0.1;
uniform float reflection_depth_fade      : hint_range(0.0, 2.0, 0.01) = 0.25;

/* =================== Ortho fixes =================== */
group_uniforms orthogonal_fixes;
uniform float ortho_depth_scale       : hint_range(0.1, 10.0, 0.1) = 1.0;
uniform float ortho_foam_compensation : hint_range(0.5, 2.0, 0.1)  = 1.0;

/* =================== Required screen textures =================== */
uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture:  hint_depth_texture,  filter_linear_mipmap, repeat_disable;

/* =================== Varyings =================== */
varying vec2 noise_uv;
varying vec2 distort_uv;
varying vec3 view_normal;
varying vec3 global_position;
varying float vertex_wave_amount;

/* =================== Helpers =================== */
vec4 alpha_blend(vec4 top, vec4 bottom) {
	vec3 color = (top.rgb * top.a) + (bottom.rgb * (1.0 - top.a));
	float alpha = top.a + bottom.a * (1.0 - top.a);
	return vec4(color, alpha);
}

vec3 over_premul(vec3 fg_rgb_premul, float fg_a, vec3 bg_rgb_premul) {
	return fg_rgb_premul + bg_rgb_premul * (1.0 - fg_a);
}

void vertex() {
	global_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_normal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	noise_uv = UV * surface_noise_tiling;
	distort_uv = UV;

	float animated_time = TIME * master_time_scale * wave_animation_speed;
	float wave = sin(global_position.x * 2.0 + animated_time * 2.0) * 0.05;
	wave += cos(global_position.z * 2.0 + animated_time * 1.5) * 0.05;
	VERTEX.y += wave;
	vertex_wave_amount = wave;
}

void fragment() {
	/* ===== depth / world-space ===== */
	float depth_tex = texture(depth_texture, SCREEN_UV).r;
	vec3  ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_tex);
	vec4  world_pos = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	world_pos.xyz /= world_pos.w;

	float vertex_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float depth = vertex_y - world_pos.y;

	if (is_orthogonal_camera) {
		depth *= ortho_depth_scale;
	}

	float depth_fade = 1.0 - exp(-abs(depth) * beer_factor);
	depth_fade = clamp(depth_fade, 0.0, 1.0);

	/* ===== foam edge measure ===== */
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
	view_pos /= view_pos.w;
	vec3 existing_normal = normalize(cross(dFdx(view_pos.xyz), dFdy(view_pos.xyz)));

	float normal_dot = clamp(dot(existing_normal.xyz, view_normal), 0.0, 1.0);
	float foam_distance_calc = mix(foam_max_distance, foam_min_distance, normal_dot);
	if (is_orthogonal_camera) {
		foam_distance_calc *= ortho_foam_compensation;
	}

	float foam_depth = clamp(depth / foam_distance_calc, 0.0, 1.0);
	float surface_noise_cutoff_value = foam_depth * surface_noise_cutoff;

	/* ===== surface distortion ===== */
	vec4 distort_noise_sample = texture(distort_noise, distort_uv);
	vec2 distort_amount = (distort_noise_sample.xy * 2.0 - 1.0) * surface_distortion_amount;

	float surface_time = TIME * master_time_scale;
	vec2 noise_uv_animated = vec2(
		(noise_uv.x + surface_time * surface_noise_scroll.x) + distort_amount.x,
		(noise_uv.y + surface_time * surface_noise_scroll.y + distort_amount.y)
	);

	float surface_noise_sample = texture(surface_noise, noise_uv_animated).r;
	float surface_noise_amount = smoothstep(
		surface_noise_cutoff_value - SMOOTHSTEP_AA,
		surface_noise_cutoff_value + SMOOTHSTEP_AA,
		surface_noise_sample
	);

	/* ===== water base color ===== */
	float water_depth = clamp(depth / depth_max_distance, 0.0, 1.0) * depth_factor;
	vec4 water_color = mix(depth_gradient_shallow, depth_gradient_deep, water_depth);
	water_color.a = mix(water_color.a, 1.0, depth_fade);

	vec4 surface_noise_color = foam_color;
	surface_noise_color.a *= surface_noise_amount;

	vec4 color = alpha_blend(surface_noise_color, water_color);

	/* ===== build reflection UV AFTER distortion (this fixes your error) ===== */
	vec2 reflection_distortion = vec2(0.0);
	vec2 warped_uv = SCREEN_UV;

	if (reflection_strength > 0.0) {
		reflection_distortion = distort_amount * 0.02 * reflection_distortion_scale;
		reflection_distortion += vec2(vertex_wave_amount) * 0.1 * reflection_distortion_scale;

		float wobble_time = TIME * master_time_scale * reflection_wobble_speed;
		reflection_distortion += vec2(
			sin(wobble_time * 2.0 + global_position.x * 0.5),
			cos(wobble_time * 1.5 + global_position.z * 0.5)
		) * 0.003 * reflection_distortion_scale;

		if (surface_noise_amount > 0.0) {
			float foam_time = TIME * master_time_scale * foam_animation_speed;
			reflection_distortion += vec2(surface_noise_amount * 0.02) * sin(foam_time * 8.0);
		}

		warped_uv = SCREEN_UV + reflection_distortion;

		if (is_orthogonal_camera) {
			vec2 center = vec2(0.5);
			warped_uv = center + (warped_uv - center) * ortho_uv_scale;
		}
		warped_uv = clamp(warped_uv, 0.0, 1.0);
	}

	/* ===== multipass reflection sampling & no-hole composite ===== */
	vec3 reflection_rgb = vec3(0.0);
	if (reflection_strength > 0.0) {
		// Sample
		vec4 fg_above = texture(reflection_fg_above_texture, warped_uv); // masked (alpha=0 underwater)
		vec4 fg_full  = texture(reflection_fg_full_texture,  warped_uv); // full FG
		vec4 bg_tex   = texture(reflection_bg_texture,       warped_uv); // background

		// Premultiply to avoid fringes
		vec3 fg_above_rgb = fg_above.rgb * fg_above.a;
		vec3 fg_full_rgb  = fg_full.rgb  * fg_full.a;
		vec3 bg_rgb       = bg_tex.rgb   * bg_tex.a; // if bg is opaque this is just bg_tex.rgb

		// If nothing survived the cut at this pixel (fg_above.a==0), fall back to fg_full
		float coverage = fg_above.a;
		vec3  fg_fixed_rgb = mix(fg_full_rgb, fg_above_rgb, coverage);
		float fg_fixed_a   = mix(fg_full.a,  fg_above.a,   coverage);

		// Composite FG over BG (premultiplied “over”)
		vec3 composed = over_premul(fg_fixed_rgb, fg_fixed_a, bg_rgb);

		// Optional extra depth gating (your original mask)
		float reflection_mask = 1.0;
		if (enable_reflection_depth_mask) {
			if (depth < reflection_depth_threshold) {
				reflection_mask = smoothstep(0.0, reflection_depth_fade, depth / reflection_depth_threshold);
			}
			float reflection_depth_tex = texture(depth_texture, warped_uv).r;
			vec3 reflection_ndc = vec3(warped_uv * 2.0 - 1.0, reflection_depth_tex);
			vec4 reflection_world_pos = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(reflection_ndc, 1.0);
			reflection_world_pos.xyz /= reflection_world_pos.w;
			float reflection_point_depth = vertex_y - reflection_world_pos.y;
			if (reflection_point_depth < reflection_depth_threshold) {
				float point_mask = smoothstep(0.0, reflection_depth_fade, reflection_point_depth / reflection_depth_threshold);
				reflection_mask *= point_mask;
			}
		}

		// Strength modulation similar to your original
		float reflection_factor =
			reflection_strength *
			(1.0 - surface_noise_amount * 0.5) *
			(1.0 - water_depth * 0.3) *
			reflection_mask;

		reflection_rgb = composed * clamp(reflection_factor, 0.0, 1.0);
	}

	/* ===== refraction of underwater scene ===== */
	if (depth > 0.01) {
		vec2 refraction_offset = distort_amount * 0.01 * (1.0 - water_depth);
		vec2 refracted_uv = clamp(SCREEN_UV + refraction_offset, 0.0, 1.0);
		vec3 screen_color = texture(screen_texture, refracted_uv).rgb;

		float underwater_visibility = 1.0 - depth_fade;
		screen_color = mix(screen_color, water_color.rgb, depth_fade * 0.8);
		color.rgb = mix(screen_color * underwater_visibility, color.rgb, color.a * (0.3 + depth_fade * 0.7));
	}

	/* ===== final apply reflection ===== */
	if (reflection_strength > 0.0) {
		if (reflection_on_top) {
			// Overlay reflection last
			color.rgb = mix(color.rgb, reflection_rgb, 1.0);
		} else {
			// Blend into water earlier
			color.rgb = mix(color.rgb, reflection_rgb, 1.0);
		}
	}

	ALBEDO = color.rgb;
	ALPHA  = color.a;
	ROUGHNESS = roughness;
	SPECULAR  = specular;
}

