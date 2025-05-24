shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float target_resolution : hint_range(1.0, 512.0, 1.0) = 512.0;
//uniform vec2 viewport_size = vec2(512.0, 512.0); // Or dynamically set via C#


// Texture must have 'Filter'-flag enabled!

// Automatic smoothing
// independent of geometry and perspective
vec4 texturePointSmooth(sampler2D smp, vec2 uv, vec2 pixel_size)
{
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	vec2 lxy = sqrt(ddx * ddx + ddy * ddy);

	vec2 uv_pixels = uv / pixel_size;

	vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
	vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;

	uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);

	uv = uv_pixels_floor * pixel_size;

	return textureGrad(smp, uv + uv_dxy_pixels * pixel_size, ddx, ddy);
}


void fragment() {
	//vec2 uv_pixel = floor(UV * viewport_size / pixel_size) * (pixel_size / viewport_size);
	 vec2 uv_pixel = floor(UV * target_resolution) / target_resolution;
	vec4 col = texture(screen_texture, uv_pixel);
	COLOR = vec4(col.rgb, col.a);

	//COLOR = texturePointSmooth(TEXTURE, UV, TEXTURE_PIXEL_SIZE);

}

//void fragment()
//{
//	COLOR = texturePointSmooth(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
//}
