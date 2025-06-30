// PASS 3: Final Render Shader  
// This shader renders the final ray, using shadow analysis result to hide/show entire ray
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// Visual uniforms (same as your original)
uniform vec4 ray_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(0.0, 5.0) = 0.5;
uniform float speed : hint_range(0.1, 10.0) = 1.0;
uniform float noise_movement : hint_range(0.0, 0.5) = 0.5;

// Multi-pass uniforms
uniform sampler2D shadow_analysis_texture : source_color, filter_nearest; // Result from Pass 2
uniform bool force_hide_ray= false; // Manual override for testing

uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv1_scale = vec2(4.0, 0.1);
uniform vec2 uv1_offset = vec2(0.0, 0.85);

varying vec3 world_position;

void vertex() {
    UV = UV * uv1_scale + uv1_offset;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Check shadow analysis result (from Pass 2)
    // We sample at UV (0.5, 0.5) since Pass 2 writes the result as a single value
    vec4 shadow_analysis = texture(shadow_analysis_texture, vec2(0.5, 0.5));
    
    // shadow_analysis.r > 0.5 means "shadow detected anywhere in ray"
    bool ray_should_be_hidden = (shadow_analysis.r > 0.5) || force_hide_ray;
    
    // --- Calculate normal ray rendering values ---
    vec2 moving_noise_uv = UV + vec2(TIME * speed * 0.1, 0.0);
    vec4 noise_value = texture(noise_texture, moving_noise_uv);
    vec2 noise_offset = vec2(noise_value.r * noise_movement, 0.0);
    vec2 gradient_uv = UV + noise_offset;
    vec4 final_gradient = texture(gradient, gradient_uv);
    
    float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);
    float noise_alpha = noise_value.r * final_gradient.a * alpha;
    
    // Apply hiding logic using conditional assignment
    if (ray_should_be_hidden) {
        // Hide entire ray
        ALBEDO = vec3(0.0);
        ALPHA = 0.0;
        EMISSION = vec3(0.0);
    } else {
        // Normal ray rendering
        ALBEDO = ray_color.rgb;
        ALPHA = clamp(fresnel * noise_alpha, 0.0, 1.0);
        EMISSION = vec3(0.0);
    }
    
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    
    // Use world position for lighting
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
}

void light() {
    // Standard lighting (since we already handled shadow hiding in fragment)
    float NdotL = max(0.0, dot(NORMAL, LIGHT));
    float light_contribution = NdotL * brightness;
    DIFFUSE_LIGHT += ALBEDO * light_contribution * LIGHT_COLOR;
}