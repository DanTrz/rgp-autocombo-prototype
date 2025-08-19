// PolyBlocks vegetation shader — enhanced
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// ===== WIND =====
uniform float windSpeed : hint_range(0.1, 2.0) = 0.2;
uniform float windStrength : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D windNoise;

// ===== TEXTURE & COLOR =====
uniform sampler2D albedoTexture : repeat_disable, source_color;
uniform vec2 albedo_uv_scale= vec2(1.0);
uniform vec4 dayColor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 nightColor : source_color = vec3(0.1, 0.2, 0.4);
uniform float nightTime : hint_range(0.0, 1.0) = 0.0;
uniform bool use_vertex_color = false;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;

// ===== EMISSION =====
uniform bool use_emission = false;
uniform vec3 emission_color : source_color = vec3(1.0);

// ===== LIGHTING MODE =====
uniform bool per_pixel_lighting = true;

// ===== ALPHA SCISSOR =====
uniform bool use_alpha_scissors = false;
uniform float alpha_scissors : hint_range(0.0, 1.0) = 0.5;

// ===== VARYING FOR LIGHT VERTEX =====
varying vec3 model_origin;

void vertex() {
    // Wind sway
    vec2 world_uv_x = vec2(VERTEX.x / 20.0 + 0.5 * TIME * windSpeed, 0.5);
    vec2 world_uv_z = vec2(VERTEX.z / 20.0 + 0.5 * TIME * windSpeed, 0.5);

    float wind_x = texture(windNoise, world_uv_x).x - 0.5;
    float wind_z = texture(windNoise, world_uv_z).z - 0.5;

    VERTEX.x += wind_x * windStrength * (1.0 - UV.y);
    VERTEX.z += wind_z * windStrength * (1.0 - UV.x);

    model_origin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    //model_origin = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;


		////Shadow per model center - One shadow value per object
    //grass_center_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	//
	////Shadow per vertex - Partial shadows
	//if(use_per_vertex_shadows)
		//grass_center_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 scaled_uv = UV * albedo_uv_scale;
    vec4 tex = texture(albedoTexture, scaled_uv);

    // Optional vertex color
    if (use_vertex_color) {
        tex *= COLOR;
    }

    // Night/day blending
    vec3 day_colored = mix(tex.rgb, tex.rgb * dayColor.rgb, 1.0);
    vec3 final_colored = mix(day_colored, day_colored * nightColor, nightTime);

	ROUGHNESS    = roughness;
    ALBEDO = final_colored;
    ALPHA = tex.a;

		//if (!use_alpha_scissors && ALPHA < 0.5) {
    //discard;
//}

    if (use_alpha_scissors) {
        ALPHA_SCISSOR_THRESHOLD = alpha_scissors;
    }

}