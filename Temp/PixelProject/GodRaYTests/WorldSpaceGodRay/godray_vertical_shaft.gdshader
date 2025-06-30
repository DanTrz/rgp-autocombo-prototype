shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

// Core configuration
uniform vec3 sun_direction = vec3(0.5, -0.5, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float ray_intensity : hint_range(0.0, 5.0) = 2.0;

// Shaft configuration - key parameters for control
uniform float shaft_width : hint_range(1.0, 10.0) = 4.0; // Width of individual shafts
uniform float shaft_spacing : hint_range(5.0, 20.0) = 12.0; // Distance between shaft centers
uniform int num_shaft_samples : hint_range(8, 32) = 16; // Quality of volumetric sampling
uniform float shaft_length : hint_range(10.0, 100.0) = 50.0; // How far shafts extend

// Atmospheric properties
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
    model_origin_view = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

// Check if a 3D point is inside a vertical light shaft
float sample_shaft_at_position(vec3 world_pos) {
    // Create coordinate system perpendicular to sun direction
    vec3 sun_dir = normalize(sun_direction);
    vec3 right = normalize(cross(sun_dir, vec3(0.0, 1.0, 0.0)));
    vec3 up = normalize(cross(right, sun_dir));
    
    // Project world position onto the plane perpendicular to sun direction
    vec2 shaft_plane_coords = vec2(
        dot(world_pos, right),
        dot(world_pos, up)
    );
    
    // Determine which shaft grid cell we're in
    vec2 shaft_grid = shaft_plane_coords / shaft_spacing;
    vec2 shaft_cell = round(shaft_grid);
    vec2 shaft_center = shaft_cell * shaft_spacing;
    
    // Distance from nearest shaft center
    float distance_from_shaft = length(shaft_plane_coords - shaft_center);
    
    // Create cylindrical shaft with smooth falloff
    float shaft_mask = 1.0 - smoothstep(shaft_width * 0.6, shaft_width, distance_from_shaft);
    shaft_mask = pow(shaft_mask, 1.5); // Soften edges
    
    return shaft_mask;
}

// Sample atmospheric density with noise variation
float sample_atmosphere_at_position(vec3 world_pos) {
    // Base atmospheric density
    float base_density = atmospheric_density;
    
    // Add 3D noise variation
    vec3 noise_coord = world_pos * noise_scale + TIME * 0.05;
    float noise1 = texture(atmospheric_noise, noise_coord.xy).r;
    float noise2 = texture(atmospheric_noise, noise_coord.xz * 0.7).r;
    
    float combined_noise = (noise1 + noise2) * 0.5;
    float noise_variation = mix(1.0, combined_noise, noise_intensity);
    
    return base_density * noise_variation;
}

// Main volumetric sampling along view ray
float sample_volumetric_shafts() {
    vec3 camera_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 view_dir = normalize(world_position - camera_pos);
    
    float accumulated_light = 0.0;
    float step_size = shaft_length / float(num_shaft_samples);
    
    // March along the view ray
    for (int i = 0; i < num_shaft_samples; i++) {
        float t = float(i) * step_size;
        vec3 sample_pos = camera_pos + view_dir * t;
        
        // Check if this sample point is inside a light shaft
        float shaft_intensity = sample_shaft_at_position(sample_pos);
        
        if (shaft_intensity > 0.0) {
            // Sample atmospheric density at this point
            float atmosphere = sample_atmosphere_at_position(sample_pos);
            
            // Distance-based fade
            float sample_distance = length(sample_pos - camera_pos);
            float distance_fade = 1.0 - smoothstep(fade_start, fade_end, sample_distance);
            
            // Accumulate light contribution
            float contribution = shaft_intensity * atmosphere * distance_fade;
            accumulated_light += contribution * step_size;
        }
    }
    
    // Normalize and apply intensity
    return accumulated_light * ray_intensity * 0.1; // Scale down for reasonable values
}

void fragment() {
    // CRITICAL: Set LIGHT_VERTEX for shadow sampling
    LIGHT_VERTEX = model_origin_view;
    
    // Sample volumetric light shafts
    float volumetric_intensity = sample_volumetric_shafts();
    
    // Store for light function
    ALBEDO = vec3(volumetric_intensity);
    ALPHA = volumetric_intensity;
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