// File: god_ray_final.gdshader
shader_type spatial;
render_mode unshaded, blend_add;

// --- Uniforms ---
uniform vec4 ray_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.5;

// This uniform now takes the ViewportTexture from our custom shadow map.
uniform sampler2D custom_shadow_map;

// We still need the light's projection matrix, which the script on the
// shadow camera can provide (or we can calculate it). For now, let's
// assume the script will set it on this material as well.
uniform mat4 light_projection_matrix;


// A varying to pass the world position from vertex to fragment
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	// Project the current pixel's world position into the light's coordinate space.
	vec4 light_space_pos = light_projection_matrix * vec4(world_pos, 1.0);

    // Normalize clip space coordinates to UV coordinates (0 to 1 range)
	vec2 shadow_uv = light_space_pos.xy / light_space_pos.w * 0.5 + 0.5;

    // Read the depth stored in our custom shadow map at that UV.
	float shadow_depth = texture(custom_shadow_map, shadow_uv).r;

    // Read the current pixel's distance from the light.
	float current_depth = light_space_pos.z / light_space_pos.w;

	// Compare the depths. If the current pixel is further away than what's in
	// the shadow map, it's in shadow. Add a small bias to avoid self-shadowing.
	float shadow_value = (current_depth > shadow_depth + 0.005) ? 0.0 : 1.0;

	// Use the final shadow value to control the alpha.
	float final_alpha = base_alpha * shadow_value;

	ALBEDO = ray_color.rgb * brightness;
	ALPHA = final_alpha;
}