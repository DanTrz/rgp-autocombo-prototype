#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/* Buffer layout mirrors GDScript packing (std430) */
layout(set = 0, binding = 0, std430) readonly buffer Params {
    vec2 raster_size;     // 0..1   : render resolution
    float water_height;   // 2      : Y cutoff
    float pad0;           // 3      : unused
    mat4 inv_proj_mat;    // 4..19  : NDC -> view
    mat4 inv_view_mat;    // 20..35 : view -> world (camera transform)
} params;

/* I/O */
layout(rgba16f, set = 0, binding = 1) uniform image2D color_image; // writable color
layout(set = 0, binding = 2) uniform sampler2D depth_texture;      // hardware depth

/* Reconstruct world position from depth */
vec3 reconstruct_world(vec2 uv) {
    float z = texture(depth_texture, uv).r;
    vec3 ndc = vec3(uv * 2.0 - 1.0, z);
    vec4 view = params.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= max(view.w, 1e-6);
    vec4 world = params.inv_view_mat * vec4(view.xyz, 1.0);
    return world.xyz;
}

void main() {
    ivec2 ip = ivec2(gl_GlobalInvocationID.xy);
    vec2 size = params.raster_size;
    if (ip.x >= int(size.x) || ip.y >= int(size.y)) {
        return;
    }

    vec2 uv = (vec2(ip) + vec2(0.5)) / size;

    // Load current color so we can pass-through unchanged pixels.
    vec4 color = imageLoad(color_image, ip);

    // If no geometry at this pixel (depth ~1.0), keep as-is.
    // Your reflection viewport uses a clear/transparent background anyway.
    float raw_depth = texture(depth_texture, uv).r;
    if (raw_depth >= 0.99999) {
        imageStore(color_image, ip, color);
        return;
    }

    // World-space Y cutoff
    vec3 world_pos = reconstruct_world(uv);
    if (world_pos.y < params.water_height) {
        // Mask: write fully transparent black to avoid bleeding in mips/linear filtering.
        imageStore(color_image, ip, vec4(0.0, 0.0, 0.0, 0.0));
    } else {
        // Pass-through
        imageStore(color_image, ip, color);
    }
}







