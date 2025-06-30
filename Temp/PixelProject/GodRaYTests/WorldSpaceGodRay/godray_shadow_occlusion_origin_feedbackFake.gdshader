shader_type spatial;
// - 'blend_add': Correct for a light ray effect.
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;
// Uniforms for controlling the look of the rays
uniform vec4 ray_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.5;
uniform float rim_power : hint_range(0.0, 5.0) = 0.5;
uniform float speed : hint_range(0.1, 10.0) = 1.0;
uniform float shadow_detection_threshold  : hint_range(0.01, 1.0) = 0.2;
uniform float noise_movement : hint_range(0.0, 0.5) = 0.5;
uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv1_scale = vec2(4.0, 0.1);
uniform vec2 uv1_offset = vec2(0.0, 0.85);
void vertex() {
    // Your existing UV logic for visual style
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
    // Set the base color of the ray. The light() function will control its brightness.
    ALBEDO = ray_color.rgb;
    // Set EMISSION to zero. We don't want the ray to glow on its own;
    // its light should come from the main light source (e.g., the sun).
    EMISSION = vec3(0.0);
    // The final transparency is a mix of the fresnel fade and the textured alpha.
    ALPHA = clamp(fresnel * noise_alpha, 0.0, 1.0);
    ROUGHNESS = 1.0; // Non-reflective
    SPECULAR = 0.0;  // No specular highlights
        // 2. Transform that point into view space for the lighting calculation.

    // 1. Get the object's origin in world space from the MODEL_MATRIX.
    vec3 world_origin = MODEL_MATRIX[3].xyz;
    LIGHT_VERTEX = (VIEW_MATRIX * vec4(world_origin, 1.0)).xyz;
}
void light() {
    // This function runs for each light affecting the object (e.g., your DirectionalLight3D).
    // 1. Get the shadow value from the shadow map.
    //    Because we set LIGHT_VERTEX, this value is correctly sampled at the object's origin.
    //    It will be 1.0 in direct light and ~0.0 in shadow.
    float shadow = ATTENUATION;
        // 2. Calculate the "N-dot-L", which measures how much the quad is facing the light.
    //    This helps fade the ray when it's perpendicular to the light direction.
    float NdotL = max(0.0, dot(NORMAL, LIGHT));

    float light_contribution = 0.0;

     //3. The final contribution of light is determined by BOTH shadow and orientation.
    if (shadow < shadow_detection_threshold)
    {
        //If we are in the shadow, we make the ray less visible. 
        light_contribution = shadow * NdotL * brightness;
        ALPHA = 0.0;
        //light_contribution = 0.0;
    }
    else
    {
        //The 'brightness' uniform acts as a light multiplier.
        light_contribution = NdotL * brightness;
    }

    // 4. Add the calculated light to the final render.
    //    This uses the ALBEDO color we set in fragment() and tints it with the light's color.
    //    If 'light_contribution' is zero (because the ray is in shadow), nothing is added,
    //    and the ray effectively disappears.
    DIFFUSE_LIGHT += ALBEDO * light_contribution * LIGHT_COLOR;
}