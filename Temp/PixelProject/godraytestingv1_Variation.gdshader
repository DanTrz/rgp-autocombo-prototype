shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_burley, shadows_disabled;

uniform float alpha : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(0.0, 5.0) = 1.0;
uniform float speed : hint_range(0.5, 10.0) = 8.0;
uniform float noise_movement : hint_range(0.0, 0.5) = 0.1;

uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;

uniform vec4 emission : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 1.0) = 0.5;
uniform vec2 uv1_scale = vec2(5.0, 1.0);
uniform vec2 uv1_offset = vec2(0.0, 1.0);

void vertex() {
	// Rotate UVs to align U with world-space horizontal
	float angle = -3.14159265 / 4.0; // -45 degrees
	// Corrected rotation matrix using vec2 columns
	mat2 rotation = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0)); // mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	UV = rotation * (UV - 0.5) + 0.5; // Rotate around UV center
	UV = UV * uv1_scale + uv1_offset;
}

void fragment() {
	// Horizontal movement along U-axis
	vec2 movingNoiseUV = UV + vec2(TIME * speed * 0.1, 0.0);
	
	// Sample noise texture
	vec4 noiseValue = texture(noise_texture, movingNoiseUV);
	
	// Horizontal noise-based offset for gradient
	vec2 noiseOffset = vec2(noiseValue.r * noise_movement, 0.0);
	vec2 gradientUV = UV + noiseOffset;
	
	// Sample gradient texture
	vec4 finalGradient = texture(gradient, gradientUV);
	
	// Fresnel for rim effect
	float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);
	float fade = fresnel;
	
	// Compute alpha
	float noiseAlpha = noiseValue.r * finalGradient.a * alpha;
	
	// Compute final color
	vec4 finalColor = vec4(finalGradient.rgb * emission.rgb, noiseAlpha);
	
	// Compute emission
	EMISSION = finalColor.rgb * emission_energy;
	
	// Set material properties
	ALBEDO = clamp(finalColor.rgb, vec3(0.0), vec3(1.0));
	ALPHA = clamp(fade * noiseAlpha, 0.0, 1.0);
	ROUGHNESS = 0.0;
	SPECULAR = 0.0;
	
	// Debug mode to visualize UVs
	// ALBEDO = vec3(UV.x, UV.y, 0.0);
	// ALPHA = 1.0;
}