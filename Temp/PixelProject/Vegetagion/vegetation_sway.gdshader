shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// User-friendly billboard toggles
uniform bool billboard_all_axis = true;
uniform bool billboard_y_only = false;

// Wind parameters
uniform float windSpeed : hint_range(0.5, 5.0) = 1.0;
uniform sampler2D albedo : repeat_disable, source_color;

// Colors and night cycle
uniform vec4 dayColor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 nightColor : source_color = vec3(0.1, 0.2, 0.4);
uniform float nightTime : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// 1. Full Billboard (Faces camera lens perfectly)
	if (billboard_all_axis) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	// 2. Y-Only Billboard (Faces camera but stays upright on ground)
	else if (billboard_y_only) {
		vec3 v0 = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 v2 = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));

		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(v0, 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(v2, 0.0),
			MODEL_MATRIX[3]
		);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}

	// Wind Sway logic
	float Y = 1.0 - VERTEX.y;
	VERTEX.x += sin(NODE_POSITION_WORLD.x + TIME * windSpeed + Y) * (1.0 - Y) * 0.1;
}

void fragment() {
	vec4 loadAlbedo = texture(albedo, UV);

	// Day/Night tinting
	vec3 day_tinted = loadAlbedo.rgb * dayColor.rgb;
	vec3 night_tinted = loadAlbedo.rgb * nightColor;

	ALBEDO = mix(day_tinted, night_tinted, nightTime);
	ALPHA = loadAlbedo.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}