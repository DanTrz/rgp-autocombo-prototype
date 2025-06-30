shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

// Simple approach - just make atmospheric light work
uniform vec3 sun_direction = vec3(0.5, -0.5, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float ray_intensity : hint_range(0.0, 5.0) = 2.0;

// Basic atmospheric effects
uniform float atmospheric_density : hint_range(0.1, 2.0) = 1.0;
uniform sampler2D atmospheric_noise : repeat_enable;
uniform float noise_scale : hint_range(0.01, 0.2) = 0.05;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.3;

// Shadow integration
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.8;

// Distance fade
uniform float fade_start : hint_range(5.0, 30.0) = 15.0;
uniform float fade_end : hint_range(20.0, 80.0) = 60.0;

// Varying for shadow sampling
varying vec3 model_origin_view;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // CRITICAL: Model origin for shadow sampling
    model_origin_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
    // CRITICAL: Set LIGHT_VERTEX for shadow sampling
    LIGHT_VERTEX = model_origin_view;
    
    // Simple atmospheric calculation
    vec3 camera_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 view_dir = normalize(world_position - camera_pos);
    
    // How aligned is the view direction with sun direction?
    float sun_alignment = max(0.0, dot(view_dir, normalize(sun_direction)));
    
    // NEW: Create distinct light shafts using world position
    vec2 shaft_coords = world_position.xz; // Use XZ plane for shaft positioning
    float shaft_spacing = 8.0; // Distance between shaft centers
    float shaft_width = 3.0; // Width of each shaft
    
    // Calculate which shaft this pixel belongs to
    vec2 shaft_grid = shaft_coords / shaft_spacing;
    vec2 shaft_center = round(shaft_grid) * shaft_spacing;
    float distance_from_shaft = length(shaft_coords - shaft_center);
    
    // Create circular shaft mask
    float shaft_mask = 1.0 - smoothstep(shaft_width * 0.7, shaft_width, distance_from_shaft);
    shaft_mask = pow(shaft_mask, 2.0); // Sharpen edges
    
    // Combine atmospheric scattering with shaft definition
    float scattering = pow(sun_alignment, 2.0) * atmospheric_density * shaft_mask;
    
    // Add noise variation
    vec2 noise_uv = world_position.xz * noise_scale + TIME * 0.1;
    float noise = texture(atmospheric_noise, noise_uv).r;
    scattering *= mix(1.0, noise, noise_intensity);
    
    // Distance fade
    float distance = length(world_position - camera_pos);
    float fade = 1.0 - smoothstep(fade_start, fade_end, distance);
    scattering *= fade;
    
    // Apply intensity
    scattering *= ray_intensity;
    
    // Store for light function
    ALBEDO = vec3(scattering);
    ALPHA = scattering;
}

void light() {
    // Shadow sampling
    float shadow_factor = ATTENUATION;
    
    // Surface contribution
    float NdotL = max(0.2, dot(NORMAL, LIGHT));
    
    // Apply shadow
    float shadow_contribution = mix(1.0, shadow_factor, shadow_strength);
    
    // Final intensity
    float final_intensity = ALBEDO.r * shadow_contribution * NdotL;
    
    // Output godray color
    DIFFUSE_LIGHT += sun_color * final_intensity * LIGHT_COLOR;
}