shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Visual uniforms for ray appearance
uniform vec4 ray_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(0.0, 5.0) = 0.5;
uniform float speed : hint_range(0.1, 10.0) = 1.0;
uniform float noise_movement : hint_range(0.0, 0.5) = 0.5;

// Textures for visual effects
uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv1_scale = vec2(4.0, 0.1);
uniform vec2 uv1_offset = vec2(0.0, 0.85);

void vertex() {
    UV = UV * uv1_scale + uv1_offset;
}

void fragment() {
    // --- Calculate the visual texture and transparency of the ray ---
    vec2 moving_noise_uv = UV + vec2(TIME * speed * 0.1, 0.0);
    vec4 noise_value = texture(noise_texture, moving_noise_uv);
    vec2 noise_offset = vec2(noise_value.r * noise_movement, 0.0);
    vec2 gradient_uv = UV + noise_offset;
    vec4 final_gradient = texture(gradient, gradient_uv);
    
    // Use Fresnel to fade the ray at sharp angles to the camera
    float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);
    
    // The base transparency from your noise and gradient textures
    float noise_alpha = noise_value.r * final_gradient.a * alpha;
    
    // --- DEFINE THE MATERIAL'S PROPERTIES ---
    ALBEDO = ray_color.rgb;
    EMISSION = vec3(0.0);
    ALPHA = clamp(fresnel * noise_alpha, 0.0, 1.0);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}

void light() {
    // Simple lighting - no shadow detection in shader
    float NdotL = max(0.0, dot(NORMAL, LIGHT));
    float light_contribution = NdotL * brightness;
    
    DIFFUSE_LIGHT += ALBEDO * light_contribution * LIGHT_COLOR;
}