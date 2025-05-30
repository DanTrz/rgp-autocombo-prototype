shader_type spatial;
render_mode blend_mix, cull_back; //blend_mix, cull_back; // unshaded, cull_back;

uniform sampler2D albedo_tex : filter_nearest, source_color;
uniform vec4 albedo_color : source_color = vec4(1.0);
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
}

void fragment() {
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
	if(use_emission)
	{
		DIFFUSE_LIGHT += NdotL * ALBEDO * emission_color * LIGHT_COLOR * ATTENUATION; // DIFFUSE_LIGHT += NdotL * ALBEDO * LIGHT_COLOR * ATTENUATION;
	}
	else
	{
		DIFFUSE_LIGHT += NdotL * ALBEDO  * ATTENUATION; // DIFFUSE_LIGHT += NdotL * ALBEDO * LIGHT_COLOR * ATTENUATION; 
	}

}