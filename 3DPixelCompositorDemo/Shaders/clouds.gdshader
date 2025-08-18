shader_type spatial;
uniform vec4 color : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform float lightSteps = 2.0;
uniform sampler2D noise;


void vertex(){
	vec4 worldUV = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float n = texture(noise, TIME * 0.01 + (worldUV.xz * 0.25)).r;
	vec4 direction = inverse(MODEL_MATRIX) * (worldUV - vec4(NODE_POSITION_WORLD, 1.0));
	VERTEX += direction.xyz * (n * 1.5);
}

void fragment() {
ALBEDO = color.rgb;
ROUGHNESS = roughness;
}

void light() {
//Diffuse lighting
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float NdotLRound = (round(NdotL * lightSteps)/ lightSteps);
	float shadows = 0.0;
	if(LIGHT_IS_DIRECTIONAL){
		shadows += floor(ATTENUATION);
		DIFFUSE_LIGHT +=  NdotLRound * ALBEDO * (LIGHT_COLOR) * shadows + 0.4;
	}
	else{
		shadows += round(ATTENUATION * float(lightSteps)) / float(lightSteps);
		DIFFUSE_LIGHT += (LIGHT_COLOR / PI) * shadows;
	}

	//DIFFUSE_LIGHT = NdotLRound * ALBEDO * (LIGHT_COLOR) * ATTENUATION + 0.4;
}
