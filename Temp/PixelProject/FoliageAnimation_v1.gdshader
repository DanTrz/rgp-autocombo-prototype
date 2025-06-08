shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;//, ambient_light_disabled; //blend_mix, cull_disable; // unshaded, cull_back; //ambient_light_disabled
//render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon, ambient_light_disabled;
//render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon,ambient_light_disabled;

// Toggle simulated ambient manually
uniform bool disable_ambient_light = false;
// Allows to compensate adding fake ambient like - I use to add contrast to shadows
uniform vec3 fake_ambient_light: source_color = vec3(0.4f);

uniform sampler2D albedo_tex : filter_nearest, source_color;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float darkness_variation : hint_range(0.0, 1.0) = 0.3;
uniform bool use_vertex_color = true;
uniform bool use_emission = false;
uniform vec3 emission_color : source_color = vec3(1.0);

uniform bool billboard = true;

// Wind Animation
uniform float wind_sway_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wind_sway_speed : hint_range(0.1, 10.0) = 1.0;
uniform float wind_time_scale : hint_range(0.0, 5.0) = 1.0;
uniform float wind_time_offset = 0.0;
uniform bool sway_from_bottom = false; //

varying vec3 modelOrigin;
varying vec3 world_billboard_normal;
varying vec4 original_vertex_color;
varying float darkness_multiplier;

// Simple hash function for randomization
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
    vec3 mod_vertex = VERTEX;

    float time = TIME * wind_time_scale + wind_time_offset;

    //Control sway influence origin (top or bottom)
    float sway_influence = sway_from_bottom ? UV.y : (1.0 - UV.y);
    float sway = sin((time + VERTEX.x * 0.5) * wind_sway_speed) * wind_sway_strength * sway_influence;
    mod_vertex.x += sway;

    // Billboard facing the camera
	if(billboard)
	{
		mat4 billboard_modelview = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
	    );

		MODELVIEW_MATRIX = billboard_modelview;
	}

    VERTEX = mod_vertex;

    world_billboard_normal = transpose(mat3(MODELVIEW_MATRIX)) * vec3(0.0, 0.0, 1.0);
		//Model Origin info for consistent lighting across the entire mesh (passed to LIGHT_VERTEX in the Fragment function)
	modelOrigin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	if(use_vertex_color)
	{
		original_vertex_color = COLOR;
	}

	//new RANDOMIZER CODE
	  //// Calculate random darkness factor once per instance using model origin
    //float random_factor = hash(modelOrigin.xy + modelOrigin.z * 0.1);
    //
    //// Map random factor to darkness range: 1.0 (no darkness) to (1.0 - darkness_variation)
    //darkness_multiplier = 1.0 - (random_factor * darkness_variation);
}

void fragment() {
	//new RANDOMIZER CODE
   //vec4 tex = texture(albedo_tex, UV);
    //if(use_vertex_color) {
        //tex *= COLOR;
    //}
    //
    //// Apply consistent darkness to entire mesh
    //ALBEDO = tex.rgb * albedo_color.rgb * darkness_multiplier;
    //ALPHA = tex.a * albedo_color.a;
    //
    //if (ALPHA < 0.1) {
        //discard;
    //}
    //
    //// Model Origin info is passed to LIGHT_VERTEX. This is DYLEARN's "VERTEX = MODEL_ORIGIN"
    //LIGHT_VERTEX = modelOrigin;
	//

	//ORIGINAL BELOW
    vec4 tex = texture(albedo_tex, UV);

	if(use_vertex_color)
	{
		tex *= COLOR;
	}
    ALBEDO = tex.rgb * albedo_color.rgb;
    ALPHA = tex.a * albedo_color.a;

    if (ALPHA < 0.1) {
        discard;
    }
		//Model Origin info is passed to LIGHT_VERTEX. This is DYLEARN's "VERTEX = MODEL_ORIGIN"
	LIGHT_VERTEX = modelOrigin;
}

void light() {
    vec3 normal = normalize(world_billboard_normal);
    float NdotL = max(dot(normal, LIGHT), 0.0);
			// Apply diffuse
	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
		// Add ambient manually if render_mode ambient_light_disabled is used
	vec3 ambient = disable_ambient_light ? vec3(0.0) : vec3(fake_ambient_light); // Replace with desired ambient color
	diffuse += ambient;


	if(use_emission)
	{
		DIFFUSE_LIGHT += NdotL * ALBEDO * emission_color * LIGHT_COLOR * ATTENUATION * diffuse; // DIFFUSE_LIGHT += NdotL * ALBEDO * LIGHT_COLOR * ATTENUATION;
	}
	else
	{
		DIFFUSE_LIGHT += NdotL * ALBEDO * ATTENUATION * diffuse ; // DIFFUSE_LIGHT += NdotL * ALBEDO * LIGHT_COLOR * ATTENUATION;
	}

}




