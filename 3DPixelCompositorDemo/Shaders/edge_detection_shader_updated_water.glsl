#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) readonly buffer Params {
    vec2 raster_size;
    vec2 reserved;
    mat4 inv_proj_mat;

    // tune0: x=line_highlight, y=line_shadow, z=depth_smooth_low, w=depth_smooth_high
    vec4 tune0;

    // tune1: x=inv_depth_step_thresh, y=inv_depth_scale, z=normal_threshold, w=offset_scale
    vec4 tune1;

    // water0: x=enabled, y=water_y_height, z=water_feather, w=mode (0=binary,1=fade)
    vec4 water0;
} params;

layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;
layout(set = 0, binding = 2) uniform sampler2D depth_texture;
layout(set = 0, binding = 3) uniform sampler2D normal_texture;

// ---- Helpers ----------------------------------------------------------------
float GetLinearDepth(vec2 uv, float mask) {
    float raw_depth = texture(depth_texture, uv).r * mask;
    vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
    vec4 view = params.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    return -view.z;
}

vec4 GetNormal(vec2 uv, float mask){
    vec2 offset = vec2(params.tune1.w);
    vec4 normal = texture(normal_texture, uv + offset) * mask;
    return normal;
}

vec4 NormalRoughnessCompatibility(vec4 p_normal_roughness) {
    float roughness = p_normal_roughness.w;
    if (roughness > 0.5) {
        roughness = 1.0 - roughness;
    }
    roughness /= (127.0 / 255.0);
    vec4 normal_comp = vec4(normalize(p_normal_roughness.xyz * 2.0 - 1.0) * 0.5 + 0.5, roughness);
    normal_comp = normal_comp * 2.0 - 1.0;
    return normal_comp;
}

float NormalEdgeIndicator(vec3 normal_edge_bias, vec3 normal, vec3 neighbor_normal, float depth_difference){
    float normal_difference = dot(normal - neighbor_normal, normal_edge_bias);
    float normal_indicator = clamp(smoothstep(-.01, .01, normal_difference), 0.0, 1.0);
    float depth_indicator  = clamp(sign(depth_difference * .25 + .0025), 0.0, 1.0);
    return (1.0 - dot(normal, neighbor_normal)) * depth_indicator * normal_indicator;
}

// ---- Main -------------------------------------------------------------------
void main() {
    vec2  size = params.raster_size;
    ivec2 uv   = ivec2(gl_GlobalInvocationID.xy);

    if (uv.x >= int(size.x) || uv.y >= int(size.y)) {
        return;
    }

    vec2 uv_normalized = vec2(uv) / size;
    vec2 texel_size    = 1.0 / size.xy;
    vec2 offset        = vec2(params.tune1.w);

    const int K = 4;
    vec2 uv_offsets[K];
    uv_offsets[0] = uv_normalized + vec2( 0.0, -1.0) * texel_size + offset;
    uv_offsets[1] = uv_normalized + vec2( 0.0,  1.0) * texel_size + offset;
    uv_offsets[2] = uv_normalized + vec2( 1.0,  0.0) * texel_size + offset;
    uv_offsets[3] = uv_normalized + vec2(-1.0,  0.0) * texel_size + offset;

    float mask = texture(normal_texture, uv_normalized + offset).a;
    mask = ceil(mask);

    // Tunables
    float line_highlight = params.tune0.x;
    float line_shadow    = params.tune0.y;
    float depth_l        = params.tune0.z;
    float depth_h        = params.tune0.w;

    float inv_step       = params.tune1.x;
    float inv_scale      = params.tune1.y;
    float normal_thr     = params.tune1.z;

    // Depth-based outlines
    float depth_difference     = 0.0;
    float inv_depth_difference = 0.5;
    float depth                = GetLinearDepth(uv_normalized + offset, mask);

    for (int i = 0; i < K; i++){
        float dOff = GetLinearDepth(uv_offsets[i], mask);
        depth_difference     += clamp(dOff - depth, 0.0, 1.0);
        inv_depth_difference += depth - dOff;
    }

    inv_depth_difference = clamp(inv_depth_difference, 0.0, 1.0);
    inv_depth_difference = clamp(smoothstep(inv_step, inv_step, inv_depth_difference) * inv_scale, 0.0, 1.0);
    depth_difference     = smoothstep(depth_l, depth_h, depth_difference);

    // Normal-based innerlines
    float normal_difference = 0.0;
    vec3  normal_edge_bias  = vec3(1.0, 1.0, 1.0);
    vec3  normal            = NormalRoughnessCompatibility(GetNormal(uv_normalized, mask)).rgb;

    for (int i = 0; i < K; i++){
        vec3 n_offset = NormalRoughnessCompatibility(GetNormal(uv_offsets[i], mask)).rgb;
        normal_difference += NormalEdgeIndicator(normal_edge_bias, normal, n_offset, depth_difference);
    }
    normal_difference = smoothstep(normal_thr, normal_thr, normal_difference);
    normal_difference = clamp(normal_difference - inv_depth_difference, 0.0, 1.0);

    // ---------------- Water cutoff ----------------
    float water_factor = 1.0;
    if (params.water0.x > 0.5) {
        // Reconstruct view pos to get Y
        vec3 ndc = vec3(uv_normalized * 2.0 - 1.0, texture(depth_texture, uv_normalized).r);
        vec4 view = params.inv_proj_mat * vec4(ndc, 1.0);
        view.xyz /= view.w;
        float world_y = view.y;

        if (world_y < params.water0.y) {
            if (params.water0.w < 0.5) {
                water_factor = 0.0; // binary hide
            } else {
                // fade with feather distance
                float dist = clamp((params.water0.y - world_y) / max(params.water0.z, 0.0001), 0.0, 1.0);
                water_factor = 1.0 - dist;
            }
        }
    }

    depth_difference  *= water_factor;
    normal_difference *= water_factor;

    // Composite
    vec4 color = imageLoad(color_image, uv);

    vec3 outline   = vec3(depth_difference);
    vec3 innerline = vec3(normal_difference) - outline;
    innerline = clamp(innerline, vec3(0.0), vec3(1.0));

    vec4 color_with_lines = vec4(color.rgb + (innerline * line_highlight) - (color.rgb * outline * line_shadow), 1.0);
    imageStore(color_image, uv, color_with_lines);
}





