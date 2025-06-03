shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_always; // Using blend_add

uniform sampler2D occlusion_map : hint_default_black;
uniform vec2 screen_resolution; // Keep for potential future use
uniform vec3 base_color : source_color = vec3(1.0, 0.95, 0.8);

uniform vec2 light_screen_pos = vec2(0.5, 0.5); // Normalized (0-1) screen pos of light

// --- Raymarching Parameters ---
uniform int num_steps : hint_range(10, 256) = 96; // Adjusted default
uniform float ray_length_modifier : hint_range(0.1, 2.0) = 0.8; 
uniform float step_base_intensity : hint_range(0.001, 0.2) = 0.03; // Adjusted default
uniform float decay_per_step : hint_range(0.80, 1.0) = 0.96; 
uniform float exposure : hint_range(0.1, 10.0) = 2.0; // Adjusted default

// --- Parameters for Ray Definition ---
uniform float occlusion_contrast_power : hint_range(1.0, 16.0) = 5.0; 
uniform float min_light_pass_threshold : hint_range(0.0, 0.5) = 0.15; // Slightly higher threshold
// New: How many initial steps must be clear for a ray to be strong
uniform int min_clear_initial_steps : hint_range(0, 32) = 7; // Slightly higher


void fragment() {
    vec2 current_pixel_uv = SCREEN_UV;
    bool process_raymarching = true; // Flag to control execution of main logic

    // Initial check: If the current pixel itself is heavily occluded,
    // it's unlikely to be part of a bright God Ray.
    // This helps prevent tinting shadows directly under the overlay.
    float direct_occlusion_at_pixel = texture(occlusion_map, current_pixel_uv).r;
    if (direct_occlusion_at_pixel > (1.0 - min_light_pass_threshold * 0.5)) { // If pixel is mostly occluded
        ALBEDO = vec3(0.0);
        ALPHA = 0.0;
        process_raymarching = false; // Skip raymarching for this pixel
    }

    if (process_raymarching) {
        vec2 vector_to_light = light_screen_pos - current_pixel_uv;
        vec2 uv_step = vector_to_light * ray_length_modifier / float(max(1, num_steps));

        float accumulated_light_value = 0.0;
        float current_ray_strength = 1.0; 
        int clear_steps_count = 0;
        bool initial_path_is_clear = false;

        // If min_clear_initial_steps is 0, we consider the initial path clear by default.
        if (min_clear_initial_steps == 0) {
            initial_path_is_clear = true;
        }

        for (int i = 0; i < num_steps; i++) {
            vec2 sample_uv = current_pixel_uv + uv_step * float(i);

            if (length(uv_step) < 0.00001 && i > 0) {
                 break;
            }
            
            float occlusion_value = texture(occlusion_map, clamp(sample_uv, vec2(0.0), vec2(1.0))).r;
            float light_pass_value = 1.0 - occlusion_value; 

            // Check for initial clear path if not already determined
            if (min_clear_initial_steps > 0 && i < min_clear_initial_steps && !initial_path_is_clear) {
                if (light_pass_value >= min_light_pass_threshold) {
                    clear_steps_count++;
                }
                if (i == min_clear_initial_steps - 1) { // After checking all initial steps
                    if (clear_steps_count >= min_clear_initial_steps) {
                        initial_path_is_clear = true;
                    } else {
                        accumulated_light_value = 0.0; // Ensure no light if initial path fails
                        break; // Stop raymarching for this pixel
                    }
                }
            }
            
            // If we require an initial clear path and it wasn't clear, skip accumulation for this step too
            if (min_clear_initial_steps > 0 && !initial_path_is_clear && i >= min_clear_initial_steps) {
                current_ray_strength *= decay_per_step; 
                if (current_ray_strength < 0.00001) break; 
                continue;
            }

            // Apply thresholding to light_pass_value *after* initial path check for subsequent steps
            if (light_pass_value < min_light_pass_threshold) {
                light_pass_value = 0.0;
            }
            float contrasted_light_pass = pow(light_pass_value, occlusion_contrast_power);

            if (contrasted_light_pass < 0.001 && i >= min_clear_initial_steps) { 
                 current_ray_strength *= decay_per_step; 
                 if (current_ray_strength < 0.00001) break; 
                 continue; 
            }
            
            // Accumulate light
            accumulated_light_value += contrasted_light_pass * current_ray_strength * step_base_intensity;
            
            current_ray_strength *= decay_per_step;

            if (current_ray_strength * step_base_intensity < 0.00001) { 
                break;
            }
        }

        // Final check
        if (min_clear_initial_steps > 0 && !initial_path_is_clear) {
            accumulated_light_value = 0.0;
        }

        float final_exposure = accumulated_light_value * exposure;
        float alpha_value = clamp(final_exposure, 0.0, 1.0); 

        ALBEDO = base_color * final_exposure; 
        ALPHA = alpha_value; 
    }
    // If process_raymarching was false, ALBEDO and ALPHA are already set to 0.0.
}



