shader_type spatial;

// Conditional ambient light disable (set via uniform)
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon, ambient_light_disabled;

// Base color of the mesh.
uniform vec4 albedo_color : source_color = vec4(1.0f);

// Toggle simulated ambient manually
uniform bool disable_ambient_light = false;
uniform bool Use_fake_ambient_light = false;

// Allows to compensate adding fake ambient like - I use to add contrast to shadows
uniform vec3 fake_ambient_light: source_color = vec3(1.0f);

uniform bool use_emission = false;
uniform vec3 emission_color : source_color = vec3(1.0);

// Toggle between texture repeat/linear types at runtime
uniform bool use_repeat_nearest_texture = true;

// Two versions of the same texture with different filter/repeat settings
uniform sampler2D albedo_texture_repeat_nearest : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D albedo_texture_clamp_linear : source_color, filter_linear, repeat_disable;

// UV transformation
uniform vec2 albedo_uv_scale = vec2(1.0, 1.0);
uniform vec2 albedo_uv_offset = vec2(0.0, 0.0);

// Recommended if multiple lights: When multiple light sources, the diffuse color will use only the brightest light for better results
uniform bool clamp_diffuse_to_max = true;

// Toon shading controls
uniform int cuts : hint_range(1, 20) = 1; // Use 1 cut for more traditional ToonShading
uniform float wrap : hint_range(-2.0f, 2.0f) = 0.0f;
uniform float steepness : hint_range(1.0f, 8.0f) = 1.0f;
uniform bool use_attenuation = true;

// Specular controls
uniform bool use_specular = false;
uniform float specular_strength : hint_range(0.0f, 1.0f) = 1.0f;
uniform float specular_shininess : hint_range(0.0f, 32.0f) = 16.0f;
uniform sampler2D specular_map : source_color;

// Rim lighting
uniform bool use_rim = false;
uniform float rim_width : hint_range(0.0f, 16.0f) = 8.0f;
uniform vec4 rim_color : source_color = vec4(1.0f);

// Ramp shading
uniform bool use_ramp = false;
uniform sampler2D ramp : source_color;

// Border effect
uniform bool use_borders = false;
uniform float border_width = 0.05f;

uniform bool billboard = false;

// Euler rotation for normals
uniform float normal_rotation_pitch : hint_range(-180.0, 180.0) = 0.0;
uniform float normal_rotation_yaw : hint_range(-180.0, 180.0) = 0.0;
uniform float normal_rotation_roll : hint_range(-180.0, 180.0) = 0.0;

varying vec3 vertex_pos;
varying vec3 normal;
varying vec3 world_billboard_normal;

// Helper: Simulate toon specular edge
float split_specular(float specular) {
	return step(0.5f, specular);
}

// Degrees to radians
float deg_to_rad(float degrees) {
	return degrees * PI / 180.0;
}

// Euler to quaternion conversion
vec4 euler_yxz_to_quat(vec3 euler) {
	float yaw = euler.x;
	float pitch = euler.y;
	float roll = euler.z;

	float cy = cos(yaw * 0.5);
	float sy = sin(yaw * 0.5);
	float cp = cos(pitch * 0.5);
	float sp = sin(pitch * 0.5);
	float cr = cos(roll * 0.5);
	float sr = sin(roll * 0.5);

	vec4 q;
	q.x = cy * sp * cr + sy * cp * sr;
	q.y = sy * cp * cr - cy * sp * sr;
	q.z = cy * cp * sr - sy * sp * cr;
	q.w = cy * cp * cr + sy * sp * sr;

	return q;
}

// Rotate normal by quaternion
vec3 rotate_vector_by_quat(vec3 v, vec4 q) {
	vec3 q_xyz = q.xyz;
	float q_w = q.w;
	return v + 2.0 * cross(q_xyz, cross(q_xyz, v) + q_w * v);
}

void vertex() {
	vertex_pos = VERTEX;
	normal = NORMAL;

		if(billboard)
	{
		mat4 billboard_modelview = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
	    );

		MODELVIEW_MATRIX = billboard_modelview;
	}
}

void fragment() {
	vec2 transformed_uv = UV * albedo_uv_scale + albedo_uv_offset;

	// Select texture based on repeat/filter setting
	vec4 tex_color = !use_repeat_nearest_texture
		? texture(albedo_texture_clamp_linear, transformed_uv)
		: texture(albedo_texture_repeat_nearest, transformed_uv);

	ALBEDO = albedo_color.rgb * tex_color.rgb;
}

void light() {
	vec2 transformed_uv = UV * albedo_uv_scale + albedo_uv_offset;

	vec3 euler_rad = vec3(
		deg_to_rad(normal_rotation_yaw),
		deg_to_rad(normal_rotation_pitch),
		deg_to_rad(normal_rotation_roll)
	);
	vec4 rotation_quat = euler_yxz_to_quat(euler_rad);
	vec3 transformed_normal = rotate_vector_by_quat(NORMAL, rotation_quat);

	// Light attenuation
	float attenuation = 1.0;
	if (use_attenuation) {
		attenuation = ATTENUATION;
	}

	// Diffuse lighting
	float NdotL = dot(transformed_normal, LIGHT);
	float diffuse_amount = NdotL + (attenuation - 1.0) + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0 / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0 - diffuse_amount, cuts_inv), 0.0, 1.0);

	// Band borders
	float border = 0.0;
	if (use_borders) {
		float corr_border_width = length(cross(transformed_normal, LIGHT)) * border_width * steepness;
		border = step(diffuse_stepped - corr_border_width, diffuse_amount)
				 - step(1.0 - corr_border_width, diffuse_amount);
	}

	// Apply diffuse
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	if (use_ramp) {
		diffuse *= texture(ramp, vec2(diffuse_stepped * (1.0 - border), 0.0)).rgb;
	} else {
		diffuse *= diffuse_stepped * (1.0 - border);
	}

	// Add ambient manually if render_mode ambient_light_disabled is used
	vec3 ambient = vec3(1.0);
	//ambient = disable_ambient_light ? vec3(0.0) : vec3(fake_ambient_light); // ORITINAL => Replace with desired ambient color
	if(Use_fake_ambient_light)
	{
		ambient = fake_ambient_light; // Replace with desired ambient color
	}

	if(disable_ambient_light)
	{
		ambient =  vec3(0.0) ; // Replace with desired ambient color
	}

	if(Use_fake_ambient_light == false && disable_ambient_light == false)
	{
		ambient = albedo_color.rgb;
	}

	diffuse += ambient;

	if (clamp_diffuse_to_max) {
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
	} else {
		DIFFUSE_LIGHT += diffuse;
	}

	if(use_emission)
	{
		DIFFUSE_LIGHT +=  ALBEDO * emission_color * LIGHT_COLOR * ATTENUATION * diffuse; // DIFFUSE_LIGHT += NdotL * ALBEDO * LIGHT_COLOR * ATTENUATION;
	}

	// Specular
	if (use_specular) {
		vec3 H = normalize(LIGHT + VIEW);
		float NdotH = dot(transformed_normal, H);
		float specular_amount = max(pow(NdotH, specular_shininess * specular_shininess), 0.0)
								* texture(specular_map, transformed_uv).r
								* attenuation;
		specular_amount = split_specular(specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}

	// Rim lighting
	if (use_rim) {
		float NdotV = dot(transformed_normal, VIEW);
		float rim_light = pow(1.0 - NdotV, rim_width);
		SPECULAR_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
	}
}
