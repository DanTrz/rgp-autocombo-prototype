shader_type spatial;

// --- Uniforms ---
// This texture comes from your SubViewport. Drag the ViewportTexture here.
uniform sampler2D shadow_texture;
uniform float shadow_threshold = 0.5; // Black is 0.0, White is 1.0. 0.5 is a good default.

// These matrices are now sent by the shadow_camera_controller.gd script.
uniform mat4 light_view_matrix;
uniform mat4 light_projection_matrix;

void vertex() {
	// We don't need to do anything complex in the vertex shader for this.
}

void fragment() {
	// --- This calculation is now done in the fragment shader ---
	// Get the world position of the current pixel.
	vec3 world_pos = (inverse(VIEW_MATRIX) * vec4(VERTEX, 1.0)).xyz;
	
	// --- This is the key correction ---
	// Transform the world position into the Shadow Camera's clip space.
	vec4 pos_clip_light = light_projection_matrix * light_view_matrix * vec4(world_pos, 1.0);
	
	// Convert from clip space [-1, 1] to UV space [0, 1].
	vec2 shadow_uv = pos_clip_light.xy / pos_clip_light.w * 0.5 + 0.5;
	
	// No need to flip Y, as we are consistently using the same pipeline.

	// Sample our custom shadow texture at the correct coordinate.
	// Since your texture is black (0.0) for shadows and white (1.0) for light:
	float shadow_sample = texture(shadow_texture, shadow_uv).r;

	// Check if the sample is below our threshold.
	if (shadow_sample < shadow_threshold) {
		// The area is dark in the texture, so it's in shadow.
		ALBEDO = vec3(1.0, 0.0, 0.0); // Red
	} else {
		// The area is light in the texture, so it's lit.
		ALBEDO = vec3(0.0, 1.0, 0.0); // Green
	}
}