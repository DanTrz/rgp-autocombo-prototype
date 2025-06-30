// PASS 2: Shadow Analysis Shader
// This shader analyzes the shadow detection texture and outputs a single result:
// "Was ANY pixel in shadow?" -> RED channel = 1.0 if yes, 0.0 if no
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled;

uniform sampler2D shadow_detection_texture : source_color, filter_nearest;

void vertex() {
    // Standard full-screen quad vertex shader
    POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
    // Sample all pixels in the shadow detection texture
    vec2 texture_size = vec2(textureSize(shadow_detection_texture, 0));
    
    bool any_shadow_found = false;
    
    // Iterate through all pixels in the shadow detection texture
    for (int x = 0; x < int(texture_size.x); x++) {
        for (int y = 0; y < int(texture_size.y); y++) {
            vec2 sample_uv = (vec2(float(x), float(y)) + 0.5) / texture_size;
            vec4 sample_color = texture(shadow_detection_texture, sample_uv);
            
            // Check if this pixel detected shadow (RED channel > 0.5)
            if (sample_color.r > 0.5) {
                any_shadow_found = true;
                break;
            }
        }
        
        if (any_shadow_found) {
            break;
        }
    }
    
    // Output result
    if (any_shadow_found) {
        ALBEDO = vec3(1.0, 0.0, 0.0); // RED = Shadow found anywhere
    } else {
        ALBEDO = vec3(0.0, 1.0, 0.0); // GREEN = No shadow found
    }
    
    ALPHA = 1.0;
}