// TREE LEAF SHADER – FULL LIGHTING + CLOUD SHADOW + BILLBOARD + DAY/NIGHT COLOR
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// ===== GLOBAL CLOUD SHADOW UNIFORMS =====
global uniform sampler2D cloud_shadow_texture;
global uniform float cloud_alpha_scissor : hint_range(0.0, 1.0);
global uniform float cloud_shadow_strength : hint_range(0.0, 1.0);
global uniform vec2 cloud_movement_offset;
global uniform vec3 cloud_area_center;
global uniform float cloud_area_size;
global uniform vec3 sun_light_direction;
global uniform bool enable_directional_shadows;
global uniform float cloud_mesh_y;
global uniform float cloud_texture_scale;

// ===== TEXTURE, COLORS AND MATERIAL =====
group_uniforms Texture_and_Colors;
uniform sampler2D albedoTexture : repeat_disable, source_color;
uniform vec4 dayColor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 nightColor : source_color = vec3(0.1, 0.2, 0.4); 
uniform float nightTime : hint_range(0.0, 1.0) = 0.0;
uniform float alphaThreshold : hint_range(0.0, 1.0) = 0.8;
uniform bool billboard = true;

// ===== SHADOW CONTROL =====
group_uniforms Shadows;
uniform bool override_global_shadow = false;
uniform bool enable_cloud_shadows = true;
uniform float cloud_shadow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform bool use_granular_shadows = false;
uniform float white_shadow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float gray_shadow_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float black_shadow_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float color_threshold : hint_range(0.01, 0.5) = 0.5;

// ===== WIND ANIMATION =====
group_uniforms Animations;
uniform float windSpeed : hint_range(0.1, 2.0) = 0.2;
uniform float windStrength : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D windNoise;

// ===== EMISSION, AMBIENT & VERTEX COLOR =====
uniform bool use_vertex_color = true;
uniform bool use_emission = false;
uniform vec3 emission_color : source_color = vec3(1.0);
uniform bool disable_ambient_light = false;
uniform vec3 fake_ambient_light : source_color = vec3(0.8);

// ===== VARYING =====
varying vec3 modelOrigin;
varying vec3 world_billboard_normal;
varying vec3 world_position;
varying vec3 grass_center_world;

// ===== CLOUD SHADOW CALCULATION =====
float calculate_final_shadow() {
	if (override_global_shadow || !enable_cloud_shadows) return 1.0;

	vec2 relative_pos = grass_center_world.xz - cloud_area_center.xz;
	vec2 normalized = relative_pos / cloud_area_size;
	vec2 uv = normalized + vec2(0.5) + cloud_movement_offset;

	if (enable_directional_shadows && sun_light_direction.y < -0.001) {
		float ground_y = grass_center_world.y;
		vec3 cloud_pos = vec3(grass_center_world.x, cloud_mesh_y, grass_center_world.z);
		float t = (ground_y - cloud_pos.y) / sun_light_direction.y;
		vec3 shadow_pos = cloud_pos - sun_light_direction * t;
		relative_pos = shadow_pos.xz - cloud_area_center.xz;
		normalized = relative_pos / cloud_area_size;
		uv = normalized + vec2(0.5) + cloud_movement_offset;
	}

	vec2 scaled_uv = uv * cloud_texture_scale;
	vec4 cloud_sample = texture(cloud_shadow_texture, scaled_uv);

	if (cloud_sample.a < cloud_alpha_scissor) return 1.0;

	float shadow_intensity;
	if (use_granular_shadows) {
		float luminance = (cloud_sample.r + cloud_sample.g + cloud_sample.b) / 3.0;
		if (luminance > (1.0 - color_threshold))
			shadow_intensity = white_shadow_intensity;
		else if (luminance < color_threshold)
			shadow_intensity = black_shadow_intensity;
		else {
			float gray_factor = (luminance - color_threshold) / (1.0 - 2.0 * color_threshold);
			shadow_intensity = mix(black_shadow_intensity, white_shadow_intensity, gray_factor);
		}
	} else {
		shadow_intensity = step(cloud_alpha_scissor, cloud_sample.a) * cloud_shadow_strength;
	}

	return 1.0 - shadow_intensity * cloud_shadow_intensity;
}

// ===== VERTEX FUNCTION =====
void vertex() {
	vec3 mod_vertex = VERTEX;

	vec2 world_uv_x = vec2(VERTEX.x / 20.0 + 0.5 * TIME * windSpeed, 0.5);
	vec2 world_uv_z = vec2(VERTEX.z / 20.0 + 0.5 * TIME * windSpeed, 0.5); 
	float wind_x = texture(windNoise, world_uv_x).x - 0.5;
	float wind_z = texture(windNoise, world_uv_z).z - 0.5;

	mod_vertex.x += wind_x * windStrength * (1.0 - UV.y);
	mod_vertex.z += wind_z * windStrength * (1.0 - UV.x);

	if (billboard) {
		mat4 billboard_modelview = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
		MODELVIEW_MATRIX = billboard_modelview;
	}

	VERTEX = mod_vertex;
	world_billboard_normal = transpose(mat3(MODELVIEW_MATRIX)) * vec3(0.0, 0.0, 1.0);
	modelOrigin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	grass_center_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

// ===== FRAGMENT FUNCTION =====
void fragment() {
	vec4 tex = texture(albedoTexture, UV);

	vec3 day_color = mix(tex.rgb, tex.rgb * dayColor.rgb, 1.0);
	vec3 final_color = mix(day_color, day_color * nightColor, nightTime);

	if (use_vertex_color) {
		final_color *= COLOR.rgb;
		tex.a *= COLOR.a;
	}

	ALBEDO = final_color;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alphaThreshold;
	LIGHT_VERTEX = modelOrigin;
}

// ===== LIGHT FUNCTION =====
void light() {
	vec3 normal = normalize(world_billboard_normal);
	float NdotL = max(dot(normal, LIGHT), 0.0);

	float final_atten = override_global_shadow ? ATTENUATION : ATTENUATION * calculate_final_shadow();

	if (!disable_ambient_light) {
		DIFFUSE_LIGHT += fake_ambient_light * ALBEDO;
	}

	DIFFUSE_LIGHT += NdotL * ALBEDO * LIGHT_COLOR * final_atten;

	if (use_emission) {
		DIFFUSE_LIGHT += emission_color * ALBEDO;
	}
}
