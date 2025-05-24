shader_type spatial;
render_mode blend_mix, cull_back;

//The varying that holds the object center-position data
varying vec3 modelOrigin;
uniform float animationDuration = 1.0; //How long we want our animation to run
uniform int frameCount = 1; //The amount of frames in your spritesheet
uniform float timeOffset = 1.0;
uniform float timeScale = 1.0;
uniform sampler2D tex : filter_nearest, source_color; //"Filter Nearest" makes the pixels from your pixel-art spritesheet nice and crisp

void vertex() {
	//Billboard Logic
	mat4 modified_model_view = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2],
        MODEL_MATRIX[3]
    );
    MODELVIEW_MATRIX = modified_model_view;
	//Model Origin info for consistent lighting across the entire mesh (passed to LIGHT_VERTEX in the Fragment function)
	modelOrigin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

// Called for every pixel the material is visible on.
void fragment() {
	//Frame animation
	float time = TIME + timeOffset;
	float progress = fract(time / (animationDuration / max(timeScale, .000001)));
	int frame = int(floor(progress * float(frameCount)));
	vec2 frameUV = UV / (vec2(float(frameCount), 1.0));
	frameUV.x += float(frame)/float(frameCount);
	
	//Assign the frame to the texture
	vec4 textureColor = texture(tex, frameUV);
	ALBEDO = textureColor.rgb;
	ALPHA = textureColor.a;
	
	//Model Origin info is passed to LIGHT_VERTEX. This is DYLEARN's "VERTEX = MODEL_ORIGIN"
	LIGHT_VERTEX = modelOrigin;
}