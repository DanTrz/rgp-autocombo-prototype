#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/* ===== Params (match GDScript) ===== */
layout(set = 0, binding = 0, std430) readonly buffer Params {
    vec2  raster_size;        // [0..1]
    float intersect_height;   // [2]
    float eps_world;          // [3]
    mat4  inv_proj_mat;       // [4..19]
    mat4  inv_view_mat;       // [20..35]
    float fill_enable;        // [36]
    float fill_radius_px;     // [37]
    float fill_aggr;          // [38]
} params;

/* I/O */
layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;   // write target
layout(set = 0, binding = 2) uniform sampler2D depth_texture;        // read depth
layout(set = 0, binding = 3) uniform sampler2D color_src;            // read-only snapshot of color

/* ---------- helpers ---------- */

vec3 world_from_uv(vec2 uv) {
    float z = texture(depth_texture, uv).r;
    // If there is no geometry here, treat as sky (never under water)
    if (z >= 0.99999) return vec3(0.0,  1e9, 0.0);

    vec3 ndc = vec3(uv * 2.0 - 1.0, z);
    vec4 v = params.inv_proj_mat * vec4(ndc, 1.0);
    v.xyz /= max(v.w, 1e-6);
    vec4 w = params.inv_view_mat * vec4(v.xyz, 1.0);
    return w.xyz;
}

bool is_under(vec2 uv) {
    vec3 w = world_from_uv(uv);
    return (w.y < params.intersect_height - params.eps_world);
}

/* ---------- main ---------- */

void main() {
    ivec2 ip   = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(color_image);
    if (ip.x >= size.x || ip.y >= size.y) return;

    vec2 uv = (vec2(ip) + vec2(0.5)) / vec2(size);

    // If above water, leave pixel untouched (no premul change here).
    if (!is_under(uv)) {
        vec4 keep = texelFetch(color_src, ip, 0);
        imageStore(color_image, ip, keep);
        return;
    }

    // Underwater: either clear or fill.
    if (params.fill_enable < 0.5) {
        imageStore(color_image, ip, vec4(0.0));
        return;
    }

    // --- isotropic, depth-gated neighborhood average from READ-ONLY color_src ---
    int   R        = int(max(1.0, params.fill_radius_px));
    float softK    = clamp(params.fill_aggr, 0.0, 1.0);

    float sigma    = mix(float(R)*0.35, float(R)*0.55, softK);
    float inv2sig2 = 1.0 / (2.0 * sigma * sigma);
    float gate_m   = mix(0.05, 0.35, softK);  // meters (depth gate)

    bool  haveRef  = false;
    float refY     = 0.0;

    vec3  acc  = vec3(0.0);
    float wsum = 0.0;

    for (int dy = -R; dy <= R; ++dy) {
        for (int dx = -R; dx <= R; ++dx) {
            float r2 = float(dx*dx + dy*dy);
            if (r2 > float(R*R)) continue;

            ivec2 jp = ip + ivec2(dx,dy);
            if (jp.x < 0 || jp.y < 0 || jp.x >= size.x || jp.y >= size.y) continue;

            vec2 juv = (vec2(jp) + vec2(0.5)) / vec2(size);
            if (is_under(juv)) continue;

            vec3 wpos = world_from_uv(juv);
            if (!haveRef) { refY = wpos.y; haveRef = true; }
            if (abs(wpos.y - refY) > gate_m) continue;

            // Read ORIGINAL color (snapshot) and weight by Gaussian * alpha
            vec4 c = texelFetch(color_src, jp, 0);
            if (c.a <= 1e-4) continue;

            float w = exp(-r2 * inv2sig2) * c.a; // alpha-aware
            acc   += c.rgb * w;
            wsum  += w;
        }
    }

    if (wsum <= 0.0) {
        imageStore(color_image, ip, vec4(0.0));
        return;
    }

    vec3 fill_rgb = acc / max(wsum, 1e-8);
    // Write opaque premultiplied fill so the hole is really covered.
    imageStore(color_image, ip, vec4(fill_rgb, 1.0));
}











