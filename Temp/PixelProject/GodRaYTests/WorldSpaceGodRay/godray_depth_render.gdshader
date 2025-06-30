// File: depth_render.gdshader
shader_type canvas_item;


void fragment() {
    // The DEPTH_TEXTURE contains the depth information from the camera's perspective.
    // We simply read it and output it as a color.
    float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
    COLOR = vec4(depth, depth, depth, 1.0);
}