shader_type spatial;
//uncomment line below to remove ambient light effect on object (Optional)
//render_mode ambient_light_disabled;

//Base color of the mesh.
uniform vec4 albedo : source_color = vec4(1.0f);
//Use a texture for the base color (will be multiplied with albedo).
uniform sampler2D albedo_texture : source_color;
uniform vec2 albedo_uv_scale = vec2(1.0, 1.0);
uniform vec2 albedo_uv_offset = vec2(0.0, 0.0);

//Recommended if multiple lights: When  multiple light sources, the diffuse color will use only the brightest light for better results
uniform bool clamp_diffuse_to_max = true;

//The number of cuts used for toon shading. Set to 1 for "classical" toon shading with a single hard border.
uniform int cuts : hint_range(1, 20) = 3;
//Adds a bias to the calculation for diffuse shading, essentially moving the halfway point between the lit and dark sides of an object.
uniform float wrap : hint_range(-2.0f, 2.0f) = 0.0f;
//Controls how steep the transition from lit to dark areas should be, essentially shrinking the widths of all bands. (Has no effect when cuts is set to 1).
uniform float steepness : hint_range(1.0f, 8.0f) = 1.0f;
//Allows objects to cast shadows on the mesh. Also needed for proper attenuation when using OmniLight nodes in your scene.
uniform bool use_attenuation = true;

//Adds a specular reflection blob based on Blinn-Phong shading.
uniform bool use_specular = false;
uniform float specular_strength : hint_range(0.0f, 1.0f) = 1.0f;
uniform float specular_shininess : hint_range(0.0f, 32.0f) = 16.0f;
//Use a texture for specular reflection.
uniform sampler2D specular_map : source_color;

//Enables simple rim lighting.
uniform bool use_rim = false;
uniform float rim_width : hint_range(0.0f, 16.0f) = 8.0f;
uniform vec4 rim_color : source_color = vec4(1.0f);

uniform bool use_ramp = false;
//Use a custom ramp texture for coloring each band (Allow use of color palette for the bands).
uniform sampler2D ramp : source_color;

//adds a border at the end of each band
uniform bool use_borders = false;
uniform float border_width = 0.05f;

// Uniforms for Euler angle rotation control
uniform float normal_rotation_pitch : hint_range(-180.0, 180.0) = 0.0; // Rotation around X (in degrees)
uniform float normal_rotation_yaw : hint_range(-180.0, 180.0) = 0.0;   // Rotation around Y (in degrees)
uniform float normal_rotation_roll : hint_range(-180.0, 180.0) = 0.0;  // Rotation around Z (in degrees)


varying vec3 vertex_pos;
varying vec3 normal;

// Definition of the split_specular function - ensure this is present!
float split_specular(float specular) {
	return step(0.5f, specular);
}

// Function to convert degrees to radians
float deg_to_rad(float degrees) {
    return degrees * PI / 180.0;
}

// Function to convert Euler angles (YXZ order) to a quaternion (represented as vec4)
vec4 euler_yxz_to_quat(vec3 euler) {
    float yaw = euler.x;   // Y
    float pitch = euler.y; // X
    float roll = euler.z;  // Z

    float cy = cos(yaw * 0.5);
    float sy = sin(yaw * 0.5);
    float cp = cos(pitch * 0.5);
    float sp = sin(pitch * 0.5);
    float cr = cos(roll * 0.5);
    float sr = sin(roll * 0.5);

    vec4 q;
    q.x = cy * sp * cr + sy * cp * sr; // X
    q.y = sy * cp * cr - cy * sp * sr; // Y
    q.z = cy * cp * sr - sy * sp * cr; // Z
    q.w = cy * cp * cr + sy * sp * sr; // W

    return q;
}

// Function to rotate a vector by a quaternion (represented as vec4)
vec3 rotate_vector_by_quat(vec3 v, vec4 q) {
    vec3 q_xyz = q.xyz;
    float q_w = q.w;
    return v + 2.0 * cross(q_xyz, cross(q_xyz, v) + q_w * v);
}


void vertex() {
	vertex_pos = VERTEX;
	normal = NORMAL; // Store original normal
}

void fragment() {
	// Apply UV scale and offset to the texture sampling
	vec2 transformed_uv = UV * albedo_uv_scale + albedo_uv_offset;
	ALBEDO = albedo.rgb * texture(albedo_texture, transformed_uv).rgb;
}

void light() {
	// Calculate the transformed UV coordinates again for use in light calculations
	vec2 transformed_uv = UV * albedo_uv_scale + albedo_uv_offset;

	// Convert Euler angles to quaternion (represented as vec4) and apply to normal
	vec3 euler_rad = vec3(deg_to_rad(normal_rotation_yaw), deg_to_rad(normal_rotation_pitch), deg_to_rad(normal_rotation_roll));
	vec4 rotation_quat = euler_yxz_to_quat(euler_rad);

	vec3 transformed_normal = rotate_vector_by_quat(NORMAL, rotation_quat);

	// Attenuation.
	float attenuation = 1.0f;
	if (use_attenuation) {
		attenuation = ATTENUATION;
	}

	// Diffuse lighting.
	// Use the transformed normal for the NdotL calculation to influence banding direction
	float NdotL = dot(transformed_normal, LIGHT);
	float diffuse_amount = NdotL + (attenuation - 1.0) + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0f / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0f - diffuse_amount, cuts_inv), 0.0f, 1.0f);

	// Calculate borders.
	float border = 0.0f;
	if (use_borders) {
		float corr_border_width = length(cross(transformed_normal, LIGHT)) * border_width * steepness;
		border = step(diffuse_stepped - corr_border_width, diffuse_amount)
				 - step(1.0 - corr_border_width, diffuse_amount);
	}

	// Apply diffuse result to different styles.
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	if (use_ramp) {
		diffuse *= texture(ramp, vec2(diffuse_stepped * (1.0f - border), 0.0f)).rgb;
	} else {
		diffuse *= diffuse_stepped * (1.0f - border);
	}

	if (clamp_diffuse_to_max) {
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
	} else {
		DIFFUSE_LIGHT += diffuse;
	}

	// Specular lighting.
	if (use_specular) {
		vec3 H = normalize(LIGHT + VIEW);
		// Use the transformed normal for specular calculation as well
		float NdotH = dot(transformed_normal, H);
		float specular_amount = max(pow(NdotH, specular_shininess*specular_shininess), 0.0f)
								* texture(specular_map, transformed_uv).r
								* attenuation;
		// Call the split_specular function - ensure it's defined above!
		specular_amount = split_specular(specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}

	// Simple rim lighting.
	if (use_rim) {
		// Rim lighting also typically uses the normal, so use the transformed normal
		float NdotV = dot(transformed_normal, VIEW);
		float rim_light = pow(1.0 - NdotV, rim_width);
		SPECULAR_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
	}
}