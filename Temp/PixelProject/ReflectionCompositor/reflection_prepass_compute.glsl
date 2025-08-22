#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/* ---- Param buffer (unchanged packing from your GDScript) ---- */
layout(set = 0, binding = 0, std430) readonly buffer Params {
    vec2  raster_size;        // 0..1
    float intersect_height;   // 2
    float reflect_gap_fill;   // 3
    mat4  inv_proj_mat;       // 4..19
    mat4  inv_view_mat;       // 20..35
    float fill_enable;        // 36 (0/1)
    float fill_radius_px;     // 37 (we’ll use as max ray steps)
    float fill_aggressiveness;// 38 (0..1)
} P;

/* I/O (same bindings as before) */
layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;

/* ---------- helpers ---------- */
bool is_sky(vec2 uv) {
    return texture(depth_tex, uv).r >= 0.99999;
}

vec3 world_from_uv(vec2 uv) {
    float z = texture(depth_tex, uv).r;
    vec3 ndc = vec3(uv * 2.0 - 1.0, z);
    vec4 view = P.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= max(view.w, 1e-6);
    vec4 world = P.inv_view_mat * vec4(view.xyz, 1.0);
    return world.xyz;
}

bool is_above_water(vec3 w) {
    return w.y >= (P.intersect_height + P.reflect_gap_fill);
}

float hash12(vec2 p) {
    // tiny hash for per-pixel rotation to avoid directional banding
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/* March along a direction up to max_steps (≈ pixels), return first valid donor.
   Valid = not sky AND above water AND alpha>0. */
bool find_donor(vec2 uv, vec2 dir_px, int max_steps, out vec3 rgb, out float a) {
    vec2 texel = 1.0 / P.raster_size;
    vec2 dir_uv = dir_px * texel;

    vec2 cur = uv;
    for (int s = 1; s <= max_steps; ++s) {
        cur += dir_uv;
        if (cur.x <= 0.0 || cur.y <= 0.0 || cur.x >= 1.0 || cur.y >= 1.0)
            break;

        if (is_sky(cur)) continue;

        vec3 w = world_from_uv(cur);
        if (!is_above_water(w)) continue;

        ivec2 ip = ivec2(cur * P.raster_size);
        vec4 src = imageLoad(color_image, ip);
        if (src.a <= 0.001) continue;

        // un-premultiply for averaging
        a   = src.a;
        rgb = src.rgb / max(a, 1e-6);
        return true;
    }
    return false;
}

/* 12 fixed directions + a tiny per-pixel rotation prevents coherent streaks.
   You can raise DIRS to 16 or 24 if you still need more robustness. */
const int DIRS = 12;
vec2 base_dirs[DIRS] = vec2[](
    vec2( 1, 0), vec2( 0, 1), vec2(-1, 0), vec2( 0,-1),
    vec2( 1, 1), vec2(-1, 1), vec2(-1,-1), vec2( 1,-1),
    vec2( 2, 1), vec2(-2, 1), vec2(-2,-1), vec2( 2,-1)
);

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c,-s,s,c);
}

void main() {
    ivec2 ip = ivec2(gl_GlobalInvocationID.xy);
    if (ip.x >= int(P.raster_size.x) || ip.y >= int(P.raster_size.y)) return;

    vec2 uv = (vec2(ip) + vec2(0.5)) / P.raster_size;

    // Keep sky as-is (and premultiply)
    if (is_sky(uv)) {
        vec4 keep = imageLoad(color_image, ip);
        keep.rgb *= keep.a;
        imageStore(color_image, ip, keep);
        return;
    }

    vec3 w0 = world_from_uv(uv);
    bool above = is_above_water(w0);

    vec4 cur = imageLoad(color_image, ip);

    if (above) {
        // Leave above-water untouched (premultiplied)
        cur.rgb *= cur.a;
        imageStore(color_image, ip, cur);
        return;
    }

    // Underwater:
    if (P.fill_enable < 0.5) {
        imageStore(color_image, ip, vec4(0.0));
        return;
    }

    int max_steps = max(1, int(P.fill_radius_px)); // your “radius” now controls reach
    float agg = clamp(P.fill_aggressiveness, 0.0, 1.0);

    // Rotate the direction set a bit per pixel to avoid structured patterns
    float theta = hash12(uv * P.raster_size) * 6.2831853; // 2*pi
    mat2 R = rot(theta);

    vec3 acc_rgb = vec3(0.0);
    float acc_a  = 0.0;
    int   hits   = 0;

    // Try each direction, stop early if we already have several donors
    for (int i = 0; i < DIRS; ++i) {
        vec2 d = normalize(R * base_dirs[i]); // unit in px
        vec3 rgb; float a;
        if (find_donor(uv, d, max_steps, rgb, a)) {
            acc_rgb += rgb;
            acc_a   += a;
            hits++;
            if (hits >= 6) break; // early-out: we have enough donors
        }
    }

    if (hits == 0) {
        // Nothing usable around → leave it transparent (no black edges)
        imageStore(color_image, ip, vec4(0.0));
        return;
    }

    // Average donors (straight space), average alpha
    vec3 avg_rgb = acc_rgb / float(hits);
    float avg_a  = clamp(acc_a / float(hits), 0.0, 1.0);

    // Blend strength controlled by aggressiveness
    vec3 out_rgb = mix(vec3(0.0), avg_rgb, agg);
    float out_a  = mix(0.0,        avg_a,  agg);

    // Premultiply on write
    imageStore(color_image, ip, vec4(out_rgb * out_a, out_a));
}












