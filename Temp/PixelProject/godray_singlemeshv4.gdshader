shader_type spatial;
// blend_mix is versatile. For classic god rays, blend_add is often used.
// depth_draw_opaque helps with sorting but rays are often not opaque.
// Consider depth_draw_never if they shouldn't write to depth, or adjust as needed.
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// --- Core Ray Properties ---
uniform vec3 ray_color : source_color = vec3(1.0, 1.0, 0.8); // Color of the rays
uniform float opacity : hint_range(0.0, 1.0) = 0.75;      // Overall transparency
uniform float base_intensity : hint_range(0.0, 10.0) = 1.5; // Base brightness of the ray

// --- Ray Shape & Falloff ---
// Texture for the ray's cross-sectional shape (e.g., soft dot, streak). Should vary along its U (horizontal) coord.
uniform sampler2D cross_section_gradient;
// Texture for the ray's falloff along its length (e.g., linear fade). Should vary along its U (horizontal) coord.
uniform sampler2D length_falloff_gradient;

uniform float density : hint_range(0.1, 5.0) = 1.0; // Controls the "solidity" or sharpness of the ray's form via gradients
uniform float ray_length_factor : hint_range(0.1, 3.0) = 1.0; // Adjusts effective length for falloff; 1.0 means UV.y=1 is full length

// --- Animation & Noise ---
uniform float noise_speed : hint_range(0.0, 10.0) = 1.0;    // How fast the noise animates
uniform sampler2D noise_texture;          // Noise texture for volumetric effect and breakup
uniform float noise_influence : hint_range(0.0, 1.0) = 0.5; // How much noise distorts the ray's alpha
uniform float noise_scale : hint_range(0.1, 20.0) = 5.0;   // Tiling/scale of the noise texture
uniform vec2 noise_pan_speed = vec2(0.02, 0.03);         // Additional directional panning for noise

// --- Thresholding & Edge Control ---
uniform float min_intensity_threshold : hint_range(0.0, 1.0) = 0.01; // Light below this intensity is cut off
uniform float falloff_sharpness : hint_range(0.1, 20.0) = 2.0; // Sharpness of the fade/cutoff at the threshold (like contrast)

// --- Advanced Animation (Growth/Pulsing) ---
uniform float pulse_frequency : hint_range(0.0, 10.0) = 0.0; // Frequency of pulsing effect (0 to disable)
uniform float pulse_min_intensity : hint_range(0.0, 1.0) = 0.5; // Minimum intensity during a pulse

// uniform vec2 overall_uv_pan_speed = vec2(0.0, 0.0); // For slight movement of the entire ray texture

void fragment() {
    // --- 1. UV Calculations & Animation ---
    // Base UVs for shape and length
    vec2 shape_uv = vec2(UV.x, 0.5); // Sample cross_section_gradient with UV.x
    vec2 length_uv = vec2(clamp(UV.y / ray_length_factor, 0.0, 1.0), 0.5); // Sample length_falloff_gradient with UV.y, scaled by ray_length_factor

    // Animated UVs for noise
    vec2 time_offset = TIME * noise_speed * noise_pan_speed;
    vec2 noise_uv_animated = UV * noise_scale + time_offset;

    // --- 2. Calculate Base Ray Intensity from Gradients ---
    float cross_section_val = texture(cross_section_gradient, shape_uv).r;
    float length_falloff_val = texture(length_falloff_gradient, length_uv).r;

    // Combine gradients and apply density
    // pow(value, density) makes the gradient steeper (denser look) if density > 1, or softer if < 1
    float combined_gradient_intensity = pow(cross_section_val * length_falloff_val, density);

    // --- 3. Apply Noise ---
    float noise_val = texture(noise_texture, noise_uv_animated).r;
    // Modulate the ray's alpha/intensity with noise.
    // This can make rays look dusty, smoky, or just break them up.
    float intensity_with_noise = combined_gradient_intensity * (1.0 - noise_influence + noise_influence * noise_val);

    // --- 4. Apply Base Intensity & Pulsing Animation ---
    float current_intensity = intensity_with_noise * base_intensity;

    if (pulse_frequency > 0.0) {
        float pulse_factor = (sin(TIME * pulse_frequency) * 0.5 + 0.5); // Oscillates 0-1
        pulse_factor = mix(pulse_min_intensity, 1.0, pulse_factor);
        current_intensity *= pulse_factor;
    }

    // --- 5. Calculate Final Alpha (Visibility) ---
    // Apply thresholding: light below min_intensity_threshold is faded out.
    // falloff_sharpness controls how sharp this cutoff is.
    float final_alpha = smoothstep(
        min_intensity_threshold,
        min_intensity_threshold + (1.0 / falloff_sharpness), // Zone of transition
        current_intensity
    );
    final_alpha *= opacity; // Apply overall opacity

    // Clamp alpha to ensure it's valid
    final_alpha = clamp(final_alpha, 0.0, 1.0);

    // --- 6. Set Output Colors ---
    // For god rays, ALBEDO is often the ray's color, and EMISSION boosts its glow.
    // Or, ALBEDO can be black if using additive blending primarily via EMISSION.
    // Your original had ALBEDO = color, EMISSION = color * 0.1. This is a good starting point.
    
    vec3 final_rgb_color = ray_color * current_intensity; // Modulate color by final calculated intensity (pre-alpha-cutoff)

    ALBEDO = ray_color; // Base color of the ray material
    ALPHA = final_alpha;
    // Emission makes the ray glow, especially in darker environments or with bloom.
    // Scale emission by the calculated intensity to make brighter parts of the ray glow more.
    EMISSION = ray_color * current_intensity * 0.5; // Adjust the 0.5 factor as needed for desired glow

    // --- For distinct lines vs. smooth blending ---
    // Distinct Lines:
    // - Use cross_section_gradient and length_falloff_gradient textures with sharp transitions.
    // - Higher 'density' value.
    // - Lower 'noise_influence' or use high-frequency, subtle noise.
    // - Higher 'falloff_sharpness'.
    // Smooth Blending:
    // - Use smooth (e.g., Gaussian) gradient textures.
    // - Lower 'density' value.
    // - Higher 'noise_influence' with softer, larger-scale noise.
    // - Lower 'falloff_sharpness'.
}  
