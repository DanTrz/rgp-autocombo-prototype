#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/* ===== Params (unchanged packing) ===== */
layout(set = 0, binding = 0, std430) readonly buffer Params {
    vec2 raster_size;     // 0..1
    float water_height;   // 2
    float pad0;           // 3
    mat4 inv_proj_mat;    // 4..19
    mat4 inv_view_mat;    // 20..35
} params;

/* I/O */
layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;
layout(set = 0, binding = 2) uniform sampler2D depth_texture;

/* --- Helpers --- */
vec3 reconstruct_world(vec2 uv) {
    float z = texture(depth_texture, uv).r;
    vec3 ndc = vec3(uv * 2.0 - 1.0, z);
    vec4 view = params.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= max(view.w, 1e-6);
    vec4 world = params.inv_view_mat * vec4(view.xyz, 1.0);
    return world.xyz;
}

bool below_plane(vec2 uv, float y_cut, float eps) {
    vec3 w = reconstruct_world(uv);
    return (w.y < y_cut + eps);
}

void main() {
    ivec2 ip = ivec2(gl_GlobalInvocationID.xy);
    vec2 size = params.raster_size;
    if (ip.x >= int(size.x) || ip.y >= int(size.y)) return;

    vec2 uv        = (vec2(ip) + vec2(0.5)) / size;
    vec2 texel     = 1.0 / size;
    const float EPS_WORLD = 0.0025; // small world-space tolerance
    const float BAND_PX   = 1.0;    // 1-texel screen-space safety band

    // Early out if no geometry here (keeps clear color/alpha intact)
    float raw_depth = texture(depth_texture, uv).r;
    if (raw_depth >= 0.99999) {
        vec4 keep = imageLoad(color_image, ip);
        // PREMULTIPLY in pass-through too (important for later sampling)
        keep.rgb *= keep.a;
        imageStore(color_image, ip, keep);
        return;
    }

    // Screen-space safety neighborhood (N,S,E,W at 1 texel distance)
    bool under =
        below_plane(uv,                    params.water_height, EPS_WORLD) ||
        below_plane(uv + vec2( 0.0,  BAND_PX) * texel, params.water_height, EPS_WORLD) ||
        below_plane(uv + vec2( 0.0, -BAND_PX) * texel, params.water_height, EPS_WORLD) ||
        below_plane(uv + vec2( BAND_PX, 0.0) * texel,  params.water_height, EPS_WORLD) ||
        below_plane(uv + vec2(-BAND_PX, 0.0) * texel,  params.water_height, EPS_WORLD);

    if (under) {
        // Mask: fully transparent black (prevents bleeding in mips/linear)
        imageStore(color_image, ip, vec4(0.0, 0.0, 0.0, 0.0));
    } else {
        // Keep pixel, but PREMULTIPLY the color by alpha so sampling later
        // won't leak RGB from transparent neighbors.
        vec4 keep = imageLoad(color_image, ip);
        keep.rgb *= keep.a;
        imageStore(color_image, ip, keep);
    }
}








