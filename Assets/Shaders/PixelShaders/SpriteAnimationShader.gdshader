shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// --- BILLBOARD CONTROLS ---
uniform bool billboard_all_axis = false;
uniform bool billboard_y_only = false;

// --- ANIMATION GRID PARAMETERS ---
uniform int columns : hint_range(1, 64) = 1; // Horizontal grid size
uniform int rows : hint_range(1, 64) = 1;    // Vertical grid size
// The actual number of sprite frames before the empty space starts
uniform int total_valid_frames : hint_range(1, 4096) = 1; 

uniform float animationDuration = 1.0;
uniform float timeOffset = 0.0;
uniform float timeScale = 1.0;

// --- TEXTURE & COLOR ---
uniform sampler2D albedor_tex : filter_nearest, source_color;
uniform vec3 albedor_color : source_color = vec3(1.0);

varying vec3 modelOrigin;

void vertex() {
	// 1. Billboard Logic
	if (billboard_all_axis) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],	INV_VIEW_MATRIX[2],	MODEL_MATRIX[3]
		);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	else if (billboard_y_only) {
		vec3 v0 = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 v2 = normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(v0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(v2, 0.0), MODEL_MATRIX[3]
		);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}

	// 2. Lighting Origin Info
	modelOrigin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
	// 3. Grid Animation Math
	float time = TIME + timeOffset;
	float effective_duration = animationDuration / max(timeScale, 0.000001);
	
	// Instead of simple progress 0-1, we calculate the exact frame index
	// and use modulo (mod) to loop it based on total_valid_frames only.
	float time_based_frame_index = floor(time / effective_duration * float(total_valid_frames));
	int current_frame = int(mod(time_based_frame_index, float(total_valid_frames)));
	
	// Calculate current Row and Column based on the grid structure
	// (We still need the grid dimensions to find where frame N lives)
	int row = current_frame / columns;
	int col = current_frame % columns;
	
	// Shrink UV to fit exactly one frame
	vec2 frameUV = UV / vec2(float(columns), float(rows));
	
	// Offset UV to the correct frame
	frameUV.x += float(col) / float(columns);
	// Note: Godot V-coordinates usually go down, so adding is correct for standard sheets
	frameUV.y += float(row) / float(rows); 

	// 4. Assign Texture
	vec4 textureColor = texture(albedor_tex, frameUV);
	ALBEDO = textureColor.rgb * albedor_color;
	ALPHA = textureColor.a;
	
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	LIGHT_VERTEX = modelOrigin;
}