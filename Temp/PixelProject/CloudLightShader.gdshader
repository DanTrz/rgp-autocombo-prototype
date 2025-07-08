shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_lambert;

// Base visual
uniform vec4 base_color : source_color = vec4(1.0);

// Cloud attenuation texture (white = full sun, black = full shadow)
uniform sampler2D cloud_shadow_texture;
uniform vec2 cloud_shadow_tiling = vec2(0.01, 0.01);
uniform vec2 cloud_shadow_offset = vec2(0.0, 0.0);
uniform float cloud_shadow_softness : hint_range(0.001, 1.0) = 0.2;
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;

// Light direction (world-space, normalized, must match DirectionalLight3D)
uniform vec3 light_direction = vec3(0.0, -1.0, 0.0);

// Cloud height (Y position of cloud layer in world space)
uniform float cloud_plane_y = 100.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = base_color.rgb;
}

void light() {
	// Project from world_pos to cloud layer along light dir
	vec3 ray_origin = world_pos;
	vec3 ray_dir = -normalize(light_direction);
	float t = (cloud_plane_y - ray_origin.y) / ray_dir.y;
	vec3 intersection = ray_origin + ray_dir * t;

	vec2 uv = intersection.xz * cloud_shadow_tiling + cloud_shadow_offset;
	float cloud_mask = texture(cloud_shadow_texture, uv).r;

	// Invert and soften
	float density = 1.0 - cloud_mask;
	density = smoothstep(0.0, cloud_shadow_softness, density);

	// Attenuate light
	float attenuation = mix(1.0, 1.0 - shadow_strength, density);

	// Apply light modulated by cloud shadow
	DIFFUSE_LIGHT = ALBEDO * LIGHT_COLOR * attenuation * max(dot(NORMAL, LIGHT), 0.0);
}
