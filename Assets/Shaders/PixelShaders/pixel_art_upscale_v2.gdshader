// based on code by t3ssel8r: https://youtu.be/d6tp43wZqps
// adapted to Godot by denovodavid
//Modified by DanTorrez
shader_type canvas_item;
render_mode unshaded;

// User-tweakable uniforms
uniform float shadow_boost : hint_range(1.0, 5.0) = 1.3;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.4;
uniform vec3 shadow_color_override : source_color = vec3(0.0, 0.0, 0.0);
uniform bool use_shadow_color_override = true;
uniform float light_boost : hint_range(1.0, 3.0) = 1.0;

void fragment() {
	// Pixel stability logic
	vec2 box_size = clamp(fwidth(UV) / TEXTURE_PIXEL_SIZE, 1e-5, 1);
	vec2 tx = UV / TEXTURE_PIXEL_SIZE - 0.5 * box_size;
	vec2 tx_offset = smoothstep(vec2(1.0) - box_size, vec2(1.0), fract(tx));
	vec2 uv = (floor(tx) + 0.5 + tx_offset) * TEXTURE_PIXEL_SIZE;

	vec4 col = textureGrad(TEXTURE, uv, dFdx(UV), dFdy(UV));

	// Compute pixel brightness
	float brightness = dot(col.rgb, vec3(0.299, 0.587, 0.114));

	if (brightness < shadow_threshold) {
		// Shadow zone
		if (use_shadow_color_override) {
			col.rgb = shadow_color_override * col.a; // Respect alpha
		} else {
			col.rgb *= 1.0 / shadow_boost;
		}
	} else {
		// Optional light boost (helps pop highlights)
		col.rgb *= light_boost;
		col.rgb = clamp(col.rgb, 0.0, 1.0);
	}

	COLOR = col;
}
