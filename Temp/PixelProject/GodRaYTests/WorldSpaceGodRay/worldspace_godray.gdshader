
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

// Core Properties
uniform vec3 sun_direction = vec3(0.5, -0.5, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float ray_intensity : hint_range(0.0, 3.0) = 1.0;

// Shaft Definition (Enhanced from your gradient approach)
uniform sampler2D gradient_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 shaft_scale = vec2(4.0, 0.8); // How many shafts and their width
uniform vec2 shaft_offset = vec2(0.0, 0.0); // Position offset

// Atmospheric Effects
uniform sampler2D noise_texture : repeat_enable;
uniform float noise_scale : hint_range(0.01, 0.2) = 0.05;
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float animation_speed : hint_range(0.0, 2.0) = 0.5;

// Shadow Integration
uniform float shadow_sharpness : hint_range(0.1, 8.0) = 3.0;
uniform float shadow_influence : hint_range(0.0, 1.0) = 0.8;

// Distance Fading
uniform float fade_start : hint_range(5.0, 30.0) = 15.0;
uniform float fade_end : hint_range(20.0, 100.0) = 50.0;

// Fresnel Effect
uniform float rim_power : hint_range(0.0, 5.0) = 1.5;

// Varying variables for shadow sampling
varying vec3 modelOrigin;
varying vec3 world_position;
varying vec3 world_billboard_normal;
varying float view_depth;

void vertex() {
    // Store world position
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // CRITICAL: Model origin for shadow sampling (the key technique!)
    modelOrigin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    
    // Billboard normal for camera-facing effect
    world_billboard_normal = transpose(mat3(MODELVIEW_MATRIX)) * vec3(0.0, 0.0, 1.0);
    
    // View depth for distance fading
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    view_depth = -view_pos.z;
}

void fragment() {
    // CRITICAL: Set LIGHT_VERTEX for shadow sampling
    LIGHT_VERTEX = modelOrigin;
    
    // Create shaft pattern using UV coordinates (simpler than world-space math)
    vec2 shaft_uv = UV * shaft_scale + shaft_offset;
    
    // Add animation - subtle movement along the shafts
    vec2 animated_offset = vec2(TIME * animation_speed * 0.05, 0.0);
    shaft_uv += animated_offset;
    
    // Sample gradient texture for clean shaft definition
    vec4 shaft_pattern = texture(gradient_texture, shaft_uv);
    
    // Add atmospheric noise variation
    vec2 noise_uv = world_position.xz * noise_scale + TIME * animation_speed * 0.1;
    float noise_variation = texture(noise_texture, noise_uv).r;
    noise_variation = mix(1.0, noise_variation, noise_intensity);
    
    // Distance-based fading
    float distance_fade = 1.0 - smoothstep(fade_start, fade_end, view_depth);
    
    // Fresnel effect for rim lighting
    float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);
    float edge_fade = clamp(fresnel, 0.2, 1.0); // Always some visibility
    
    // Combine all effects
    float shaft_intensity = shaft_pattern.r * noise_variation * distance_fade * edge_fade * ray_intensity;
    
    // Store for light function
    ALBEDO = vec3(shaft_intensity);
    ALPHA = shaft_intensity;
}

void light() {
    // Get shadow information (thanks to LIGHT_VERTEX technique)
    float shadow_factor = ATTENUATION;
    
    // Calculate surface orientation effect
    // Option 1: Surface normal
    float NdotL_surface = max(0.0, dot(NORMAL, LIGHT));
    
    // Option 2: Billboard normal (better for camera-facing planes)
    vec3 billboard_normal = normalize(world_billboard_normal);
    float NdotL_billboard = max(0.0, dot(billboard_normal, LIGHT));
    
    // Use billboard normal for camera-facing effect
    float NdotL = NdotL_billboard;
    
    // Create sharp shadow cutoff for defined edges
    float shadow_cutoff = pow(shadow_factor, shadow_sharpness);
    shadow_cutoff = mix(shadow_cutoff, 1.0, 1.0 - shadow_influence);
    
    // Surface contribution (how much the surface orientation matters)
    float surface_contribution = mix(0.4, 1.0, NdotL); // 40% base visibility
    
    // Final intensity calculation
    float final_intensity = ALBEDO.r * shadow_cutoff * surface_contribution;
    
    // Output the godray color
    DIFFUSE_LIGHT += sun_color * final_intensity * LIGHT_COLOR;
}