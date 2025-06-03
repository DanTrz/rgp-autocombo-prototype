shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, depth_test_disabled, blend_mix;

// Main Ray Controls
uniform float ray_intensity : hint_range(0.0, 5.0) = 0.5;
uniform vec3 ray_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float ray_opacity : hint_range(0.0, 1.0) = 0.8;
uniform float ray_length : hint_range(0.1, 10.0) = 2.0;

// Ray Quality & Density
uniform int ray_steps : hint_range(8, 64) = 32;
uniform float ray_density : hint_range(0.1, 5.0) = 1.0;
uniform float step_base_intensity : hint_range(0.1, 2.0) = 1.0;

// Light Filtering
uniform float min_light_threshold : hint_range(0.0, 1.0) = 0.1;
uniform float decay_step : hint_range(0.01, 0.5) = 0.1;

// Occlusion & Contrast
uniform float occlusion_contrast : hint_range(0.1, 5.0) = 1.5;
uniform float fade_power : hint_range(0.5, 4.0) = 2.0;

// Animation & Noise
uniform float animation_speed : hint_range(0.0, 2.0) = 0.3;
uniform sampler2D noise_texture : hint_default_white;
uniform float noise_scale : hint_range(0.1, 10.0) = 1.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;

// Ray Shape Control
uniform float ray_width : hint_range(0.1, 4.0) = 2.0;
uniform float ray_falloff : hint_range(0.1, 8.0) = 2.0;
uniform vec2 ray_direction = vec2(0.0, -1.0);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = VERTEX;
    world_normal = NORMAL;
}

// Optimized noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Volumetric ray marching function
float calculate_god_ray(vec2 uv, vec2 ray_dir) {
    float ray_strength = 0.0;
    vec2 current_pos = uv;
    float step_size = ray_length / float(ray_steps);
    
    // Animated noise offset
    vec2 noise_offset = vec2(TIME * animation_speed * 0.5, TIME * animation_speed * 0.3);
    
    for (int i = 0; i < ray_steps; i++) {
        float step_factor = float(i) / float(ray_steps);
        
        // Sample noise for ray variation
        vec2 noise_uv = (current_pos + noise_offset) * noise_scale;
        float noise_val = texture(noise_texture, noise_uv).r;
        
        // Apply noise distortion to ray position
        vec2 distorted_pos = current_pos + (noise_val - 0.5) * noise_strength * 0.1;
        
        // Calculate distance from ray center
        float dist_from_center = length(distorted_pos - vec2(0.5));
        
        // Ray shape calculation with falloff
        float ray_mask = 1.0 - smoothstep(0.0, ray_width, dist_from_center);
        ray_mask = pow(ray_mask, ray_falloff);
        
        // Light decay over distance
        float decay_factor = exp(-step_factor * decay_step * float(ray_steps));
        
        // Step intensity with noise variation
        float step_intensity = step_base_intensity * decay_factor * ray_mask;
        step_intensity *= (0.7 + 0.3 * noise_val); // Noise variation
        
        // Accumulate ray strength
        if (step_intensity > min_light_threshold) {
            ray_strength += step_intensity * (1.0 / float(ray_steps));
        }
        
        // Move along ray direction
        current_pos += ray_dir * step_size * 0.1;
    }
    
    return ray_strength;
}

void fragment() {
    vec2 centered_uv = UV - 0.5;
    
    // Normalize ray direction
    vec2 norm_ray_dir = normalize(ray_direction);
    
    // Calculate main god ray
    float ray_value = calculate_god_ray(UV, norm_ray_dir);
    
    // Apply density multiplier
    ray_value *= ray_density;
    
    // Edge fade for seamless blending
    float edge_fade = 1.0 - pow(length(centered_uv * 2.0), fade_power);
    edge_fade = clamp(edge_fade, 0.0, 1.0);
    
    // Vertical gradient for natural light falloff
    float vertical_gradient = 1.0 - pow(abs(UV.y), 1.5);
    
    // Occlusion contrast enhancement
    ray_value = pow(ray_value, 1.0 / occlusion_contrast);
    
    // Combine all factors
    float final_alpha = ray_value * edge_fade * vertical_gradient * ray_opacity;
    final_alpha = clamp(final_alpha, 0.0, 1.0);
    
    // Apply minimum threshold
    if (final_alpha < min_light_threshold) {
        final_alpha = 0.0;
    }
    
    // Enhanced ray color with intensity
    vec3 enhanced_color = ray_color * ray_intensity;
    enhanced_color *= (1.0 + ray_value * 0.5); // Brighten intense areas
    
    // Final output
    ALBEDO = enhanced_color;
    ALPHA = final_alpha;
    EMISSION = enhanced_color * final_alpha * 0.8; // Strong emission for god rays
    
    // Disable shadows for light rays
    METALLIC = 0.0;
    ROUGHNESS = 1.0;
}