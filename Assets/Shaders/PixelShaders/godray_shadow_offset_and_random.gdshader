shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;


// Uniforms for controlling the look of the rays
group_uniforms CoreSetup;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;


uniform float brightness : hint_range(0.0, 5.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.5;
// Where the fade begins (0.0 = bottom, 1.0 = top of the mesh)
uniform float fadeout_start_point : hint_range(0.0, 1.00, 0.001) = 0.95;
// How long the fade is. 0.1 is a short, sharp fade. 1.0 is a full, soft fade.
uniform float fadeout_length : hint_range(0.00, 0.2, 0.001) = 0.008;
// A switch to decide if we fade from the bottom up, or the top down.
uniform bool fade_from_bottom = false;
uniform float rim_power : hint_range(0.0, 5.0) = 1.0;

group_uniforms Animation;
uniform float speed : hint_range(0.1, 10.0) = 0.5;
uniform float shadow_detection_threshold : hint_range(0.01, 1.0) = 0.2;
uniform float noise_movement : hint_range(0.0, 0.5) = 0.2;
uniform bool random_noise_movement = true;



group_uniforms Occlusion;
// SIMPLE BUT EFFECTIVE: Multi-point shadow sampling
uniform bool enable_distributed_sampling = true;
uniform bool use_custom_data_position = true;

//uniform float sampling_offset_x : hint_range(-20.0, 20.0) = 0.0; // Offset sample point in X
//uniform float sampling_offset_y : hint_range(-20.0, 20.0) = 0.0; // Offset sample point in Y
//uniform float sampling_offset_z : hint_range(-20.0, 20.0) = 0.0; // Offset sample point in Z
uniform vec3 sampling_offset= vec3(.0,.0,.0); // Offset sample point in Z
uniform bool hide_entire_ray_on_shadow = true; // Hide entire ray if ANY shadow detected

group_uniforms Textures;
uniform sampler2D noise_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;

// Control parameter
uniform float selected_gradient : hint_range(0.0, 0.4, 0.1) = 0.0;
uniform bool random_gradient = true;
//uniform sampler2D gradient : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient0 : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient1 : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient2 : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient3 : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;

group_uniforms OtherandUtil;
uniform vec2 uv1_scale = vec2(4.0, 0.1);
uniform vec2 uv1_offset = vec2(0.0, 0.95);
uniform vec3 min_world_bounds = vec3(-500, -500, -500);
uniform vec3 max_world_bounds = vec3(500, 500, 500);

varying vec3 world_position;
varying vec3 sample_position;
varying vec3 sample_position_custom_data;
varying vec3 object_center;
varying vec3 world_position_rand;
varying float position_seed_rand;
varying float gradient_seed_rand;
varying float custom_data_alpha;




float rand (vec2 uv) {
    return fract(sin(dot(uv.xy,
        vec2(12.9898,78.233))) * 43758.5453123);
}

void vertex() {

	custom_data_alpha = INSTANCE_CUSTOM.a;
	//These are going to be used for Randomization of NoiseValue and GradientTexture
	world_position_rand = NODE_POSITION_WORLD * vec3(1.05, 1.14, 1.33) * 10.0;
	position_seed_rand = fract(world_position_rand.x + world_position_rand.y + world_position_rand.z); // Get a value between 0 and 1.0f

    UV = UV * uv1_scale + uv1_offset;

    // Calculate world position of this vertex // Could also just use NODE_POSITION_WORLD
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    if (enable_distributed_sampling) {
        // Calculate a strategic sample position
        object_center = MODEL_MATRIX[3].xyz;
        vec3 offset = sampling_offset;
        // You can experiment with different sampling strategies:
        // Option 1: Fixed offset from center
        sample_position = object_center + offset;

        // Option 2: Use vertex position with offset (distributed across ray)
        //sample_position = world_position + offset;

        // Option 3: Sample at edges of the ray object
        // vec3 to_vertex = world_position - object_center;
        // sample_position = object_center + normalize(to_vertex) * length(offset);

    } else {
        // Use vertex position directly
        sample_position = world_position;
    }

	if(use_custom_data_position)
	{
		//Option 1: Fixed world position
		vec3 packed_position = INSTANCE_CUSTOM.rgb;
		sample_position_custom_data = mix(min_world_bounds, max_world_bounds, packed_position);

		////Option 2: Fixed offset from object center
		//vec3 offset = sample_position_custom_data;
		//sample_position_custom_data = object_center + offset;
	}

}

vec4 select_gradient_texture(vec2 uv) {
    if (gradient_seed_rand <= 0.1) return texture(gradient0, uv);
    if (gradient_seed_rand <= 0.2) return texture(gradient1, uv);
    if (gradient_seed_rand <= 0.3) return texture(gradient2, uv);
    return texture(gradient3, uv);
}

void fragment() {
    // --- Calculate the visual texture and transparency of the ray ---
	vec2 base_uv = UV;
    vec2 moving_noise_uv = UV + vec2(TIME * speed * 0.1, 0.0);
    vec4 noise_value = texture(noise_texture, moving_noise_uv);
    vec2 noise_offset = vec2(noise_value.r * noise_movement, 0.0);
	if(random_noise_movement)
	{
		noise_offset = vec2(noise_value.r * (position_seed_rand * 0.5), 0.0); //multiple position_seed by a value below 1 to set it's max
	}

	//Define the Gradient to use or a random one
	vec2 gradient_uv = UV + noise_offset;
	gradient_seed_rand = selected_gradient;
	if(random_gradient)
	{
		gradient_seed_rand = position_seed_rand * 0.4; //Limits to 0.4 (as we will use 4 gradients)
	}
	vec4 final_gradient = select_gradient_texture(gradient_uv);   //vec4 final_gradient = texture(gradient, gradient_uv);

    // Use Fresnel to fade the ray at sharp angles to the camera
    //float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), rim_power);
    float fresnel = rim_power;

    // The base transparency from your noise and gradient textures

    float noise_alpha = noise_value.r * final_gradient.a * alpha; //custom_data_alpha
    //float noise_alpha = noise_value.r * final_gradient.a * custom_data_alpha;


    // --- NEW FADEOUT CALCULATION ---
    float fade_uv = fade_from_bottom ? UV.y : 1.0 - UV.y;
    float fade_start = fadeout_start_point;
    float fade_end = fade_start + fadeout_length;
    float fadeout_multiplier = smoothstep(fade_start, fade_end, fade_uv);

	vec4 albedo_tex = texture(texture_albedo, base_uv);
    // --- DEFINE THE MATERIAL'S PROPERTIES ---

    albedo_tex *= COLOR;
	//vec4 fake_color = vec4(0.0);
    //albedo_tex *= fake_color * COLOR;

	ALBEDO = albedo_color.rgb * final_gradient.rgb * albedo_tex.rgb; // I've also multiplied by the gradient color here for more visual variety
	//ALBEDO = albedo_color.rgb * final_gradient.rgb; // I've also multiplied by the gradient color here for more visual variety
	EMISSION = vec3(0.0);

    // --- MODIFIED ALPHA CALCULATION ---
    // We take the original alpha and multiply it by our new fadeout_multiplier.
    // If the pixel is outside the fade area, the multiplier is 1.0, having no effect.
    // If it's inside the fade area, the multiplier will be between 0.0 and 1.0, causing it to fade.
    ALPHA = clamp(fresnel * noise_alpha * fadeout_multiplier, 0.0, 1.0);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;


    // Use our calculated sample position for shadow detection
	if(use_custom_data_position)
	{
		LIGHT_VERTEX = (VIEW_MATRIX * vec4(sample_position_custom_data, 1.0)).xyz;
	}
	else
	{
		LIGHT_VERTEX = (VIEW_MATRIX * vec4(sample_position, 1.0)).xyz;
	}


}

void light() {
    float NdotL = max(0.0, dot(NORMAL, LIGHT));

    // Get shadow value at our sample position
    float shadow_sample = ATTENUATION;

    float light_contribution = 0.0;

    if (hide_entire_ray_on_shadow) {
        // SIMPLE STRATEGY: If ANY shadow detected, hide entire ray
        if (shadow_sample < shadow_detection_threshold) {
            // Complete ray hiding
            light_contribution = 0.0;
            ALPHA = 0.0;
        } else {
            // No shadow detected - full brightness
            light_contribution = NdotL * brightness;
        }
    } else {
        // GRADIENT STRATEGY: Apply shadow proportionally
        if (shadow_sample < shadow_detection_threshold) {
            // Partial ray dimming
            light_contribution = shadow_sample * NdotL * brightness;
            ALPHA *= shadow_sample;
        } else {
            light_contribution = NdotL * brightness;
        }
    }

    //Uncomment this light if you want to affect the pixel brightness based on receiving light
    //DIFFUSE_LIGHT += ALBEDO * light_contribution * LIGHT_COLOR;
}