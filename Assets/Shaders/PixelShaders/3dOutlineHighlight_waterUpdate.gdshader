shader_type spatial;
render_mode unshaded;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

uniform bool shadows_enabled = true;
uniform bool highlights_enabled = true;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.7;
uniform vec3 highlight_color : source_color = vec3(1.0);
uniform vec3 shadow_color  : source_color = vec3(0.0);

// NEW
uniform float water_height : hint_range(-100.0, 100.0) = 0.0;
uniform float water_fade_distance : hint_range(0.01, 5.0) = 0.75;

varying mat4 model_view_matrix;

float getDepth(vec2 screen_uv, sampler2D depth_texture, mat4 inv_projection_matrix){
	float raw_depth = texture(depth_texture, screen_uv)[0];
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw_depth);
	vec4 view_space = inv_projection_matrix * vec4(ndc, 1.0);
	view_space.xyz /= view_space.w;
	return -view_space.z;
}

float normalIndicator(vec3 normalEdgeBias, vec3 baseNormal, vec3 newNormal, float depth_diff){
	float normalDiff = dot(baseNormal - newNormal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
	float depthIndicator = clamp(sign(depth_diff * .25 + .0025), 0.0, 1.0);
	return (1.0 - dot(baseNormal, newNormal)) * depthIndicator * normalIndicator;
}

void vertex(){
	model_view_matrix = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 e = vec2(1.0 / VIEWPORT_SIZE.xy);

	// SHADOWS
	float depth_diff = 0.0;
	float neg_depth_diff = 0.5;
	if (shadows_enabled) {
		float depth = getDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
		float du = getDepth(SCREEN_UV + vec2(0., -1.) * e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
		float dr = getDepth(SCREEN_UV + vec2(1.,  0.) * e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
		float dd = getDepth(SCREEN_UV + vec2(0.,  1.) * e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
		float dl = getDepth(SCREEN_UV + vec2(-1., 0.) * e, DEPTH_TEXTURE, INV_PROJECTION_MATRIX);
		depth_diff += clamp(du - depth, 0., 1.);
		depth_diff += clamp(dd - depth, 0., 1.);
		depth_diff += clamp(dr - depth, 0., 1.);
		depth_diff += clamp(dl - depth, 0., 1.);
		neg_depth_diff += depth - du;
		neg_depth_diff += depth - dd;
		neg_depth_diff += depth - dr;
		neg_depth_diff += depth - dl;
		neg_depth_diff = clamp(neg_depth_diff, 0., 1.);
		neg_depth_diff = clamp(smoothstep(0.5, 0.5, neg_depth_diff) * 10., 0., 1.);
		depth_diff = smoothstep(0.2, 0.3, depth_diff);
	}

	// HIGHLIGHTS
	float normal_diff = 0.0;
	if (highlights_enabled) {
		vec3 normal = texture(NORMAL_TEXTURE, SCREEN_UV).rgb * 2.0 - 1.0;
		vec3 nu = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(0., -1.) * e).rgb * 2.0 - 1.0;
		vec3 nr = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(1.,  0.) * e).rgb * 2.0 - 1.0;
		vec3 nd = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(0.,  1.) * e).rgb * 2.0 - 1.0;
		vec3 nl = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(-1., 0.) * e).rgb * 2.0 - 1.0;
		vec3 normal_edge_bias = vec3(1.0);
		normal_diff += normalIndicator(normal_edge_bias, normal, nu, depth_diff);
		normal_diff += normalIndicator(normal_edge_bias, normal, nr, depth_diff);
		normal_diff += normalIndicator(normal_edge_bias, normal, nd, depth_diff);
		normal_diff += normalIndicator(normal_edge_bias, normal, nl, depth_diff);
		normal_diff = smoothstep(0.2, 0.8, normal_diff);
		normal_diff = clamp(normal_diff - neg_depth_diff, 0.0, 1.0);
	}

	// World Y (moved into fragment for compliance)
	float raw_depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4 world_pos = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	world_pos.xyz /= world_pos.w;
	float world_y = world_pos.y;

	float water_fade = smoothstep(water_height, water_height - water_fade_distance, world_y);

	vec3 original_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 final_highlight_color = mix(original_color, highlight_color, highlight_strength);
	vec3 final_shadow_color = mix(original_color, shadow_color, shadow_strength);
	vec3 final = original_color;
	if (highlights_enabled) final = mix(final, final_highlight_color, normal_diff);
	if (shadows_enabled) final = mix(final, final_shadow_color, depth_diff);

	float alpha_mask = (depth_diff * float(shadows_enabled) + normal_diff * float(highlights_enabled)) * (1.0 - water_fade);

	ALBEDO = final;
	ALPHA = clamp(alpha_mask * 5.0, 0.0, 1.0);
}
