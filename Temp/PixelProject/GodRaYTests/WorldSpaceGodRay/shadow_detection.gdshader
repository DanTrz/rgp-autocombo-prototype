// PASS 1: Shadow Detection Shader
// This shader renders the ray to a small texture and outputs ONLY shadow information
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, depth_test_disabled;

uniform float shadow_detection_threshold : hint_range(0.01, 1.0) = 0.2;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Sample shadow at this pixel's world position
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(world_position, 1.0)).xyz;
    
    // Output will be set in light() function
    ALBEDO = vec3(0.0); // Default: no shadow detected
    ALPHA = 1.0;
}

void light() {
    // Get shadow value at this pixel
    float shadow = ATTENUATION;
    
    // Output shadow detection result as color
    if (shadow < shadow_detection_threshold) {
        // SHADOW DETECTED - Mark as RED
        DIFFUSE_LIGHT = vec3(1.0, 0.0, 0.0); // Red = Shadow found
    } else {
        // NO SHADOW - Mark as GREEN  
        DIFFUSE_LIGHT = vec3(0.0, 1.0, 0.0); // Green = No shadow
    }
}