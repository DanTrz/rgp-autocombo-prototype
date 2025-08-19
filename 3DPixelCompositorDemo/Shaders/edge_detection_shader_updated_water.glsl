#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

/*==============================================================================
Buffer layout EXACTLY matches what we pack in GDScript.
- We APPEND inv_view_mat at the end to avoid renumbering your existing fields.
==============================================================================*/
layout(set = 0, binding = 0, std430) readonly buffer Params {
    // 0..1   : internal 3D render resolution
    vec2 raster_size;

    // 2..3   : reserved.x = roughness_show_threshold, reserved.y = (unused)
    vec2 reserved;

    // 4..19  : inverse projection (NDC→view)
    mat4 inv_proj_mat;

    // 20..23 : x=line_highlight, y=line_shadow, z=depth_smooth_low, w=depth_smooth_high
    vec4 tune0;

    // 24..27 : x=inv_depth_step, y=inv_depth_scale, z=normal_threshold, w=offset_uv
    vec4 tune1;

    // 28..31 : x=enabled, y=water_y_height, z=water_feather, w=mode (0=binary,1=fade)
    vec4 water0;

    // 32..47 : inverse view (view→world)  <<< NEW
    mat4 inv_view_mat;
} params;

// I/O
layout(rgba16f, set = 0, binding = 1) uniform image2D color_image;
layout(set = 0, binding = 2) uniform sampler2D depth_texture;
layout(set = 0, binding = 3) uniform sampler2D normal_texture;

/*==============================================================================
Helpers
==============================================================================*/

// Decodes roughness from the alpha channel of the normal texture.
// If you want to change how roughness is encoded, modify this function.
float DecodeRoughness01FromAlpha(float a) {
    float r = a;
    if (r > 0.5) {
        r = 1.0 - r;
    }
    r = r / (127.0 / 255.0);
    return clamp(r, 0.0, 1.0);
}

// Samples the normal texture at a given UV, with a small offset for stability.
// You can adjust the offset via params.tune1.w in GDScript for different effects.
vec4 GetNormalRaw(vec2 uv){
    vec2 offs = vec2(params.tune1.w);
    return texture(normal_texture, uv + offs);
}

// Converts packed normal to -1..1 space for compatibility.
// If you change the normal packing in Godot, update this function accordingly.
vec4 NormalRoughnessCompatibility(vec4 p_normal_roughness) {
    float roughness = p_normal_roughness.w;
    if (roughness > 0.5) roughness = 1.0 - roughness;
    roughness /= (127.0 / 255.0);
    vec4 normal_comp = vec4(normalize(p_normal_roughness.xyz * 2.0 - 1.0) * 0.5 + 0.5, roughness);
    normal_comp = normal_comp * 2.0 - 1.0;
    return normal_comp;
}

// Computes an edge indicator based on normal difference and depth difference.
// You can tweak the normal_edge_bias or the smoothstep parameters for different edge sensitivity.
float NormalEdgeIndicator(vec3 normal_edge_bias, vec3 n0, vec3 n1, float depth_difference){
    float n_diff = dot(n0 - n1, normal_edge_bias);
    float n_indicator = clamp(smoothstep(-.01, .01, n_diff), 0.0, 1.0);
    float d_indicator = clamp(sign(depth_difference * .25 + .0025), 0.0, 1.0);
    return (1.0 - dot(n0, n1)) * d_indicator * n_indicator;
}

// Converts UV and depth to view-space Z.
// If you want to use a different depth encoding, modify this function.
float GetLinearDepth(vec2 uv, float mask_center) {
    float raw_depth = texture(depth_texture, uv).r * mask_center;
    vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
    vec4 view = params.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    return -view.z;
}

/* Reconstruct true world-space position from depth.
   - inv_proj_mat : NDC→view
   - inv_view_mat : view→world  (passed from GDScript)
   If you want to use this for other effects (e.g. fog, water, etc.), you can
   use the world position returned here.
*/
vec3 ReconstructWorld(vec2 uv) {
    float raw_depth = texture(depth_texture, uv).r;
    vec3 ndc  = vec3(uv * 2.0 - 1.0, raw_depth);
    vec4 view = params.inv_proj_mat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    vec4 world = params.inv_view_mat * vec4(view.xyz, 1.0);
    return world.xyz;
}

/*==============================================================================
Main
==============================================================================*/
void main() {
    vec2  size = params.raster_size;
    ivec2 uv   = ivec2(gl_GlobalInvocationID.xy);
    // Early exit if outside the render area.
    if (uv.x >= int(size.x) || uv.y >= int(size.y)) {
        return;
    }

    // Normalize UV coordinates for texture sampling.
    vec2 uv_normalized = vec2(uv) / size;
    vec2 texel_size    = 1.0 / size.xy;
    vec2 offset_uv     = vec2(params.tune1.w);

    // 4-neighborhood offsets for edge detection.
    // If you want to use a larger kernel (e.g. 8-neighborhood), add more offsets here.
    const int K = 4;
    vec2 uv_offsets[K];
    uv_offsets[0] = uv_normalized + vec2( 0.0, -1.0) * texel_size + offset_uv;
    uv_offsets[1] = uv_normalized + vec2( 0.0,  1.0) * texel_size + offset_uv;
    uv_offsets[2] = uv_normalized + vec2( 1.0,  0.0) * texel_size + offset_uv;
    uv_offsets[3] = uv_normalized + vec2(-1.0,  0.0) * texel_size + offset_uv;

    // Check if geometry exists at this pixel (based on depth).
    float raw_depth    = texture(depth_texture, uv_normalized).r;
    float present_mask = step(raw_depth, 0.99999);

    // Only show outlines if roughness is above threshold.
    // You can adjust the threshold in GDScript via params.reserved.x.
    float rough_th = params.reserved.x;
    float rough01  = DecodeRoughness01FromAlpha(GetNormalRaw(uv_normalized).a);
    float line_enable = step(rough_th, rough01); // 1 when rough01 >= rough_th
    float mask_center = present_mask * line_enable;

    // If no geometry or roughness below threshold, keep original color.
    if (mask_center <= 0.0) {
        vec4 orig = imageLoad(color_image, uv);
        imageStore(color_image, uv, orig);
        return;
    }

    // Tunable parameters for outline appearance.
    // You can tweak these in GDScript for different visual styles.
    float line_highlight = params.tune0.x;
    float line_shadow    = params.tune0.y;
    float depth_l        = params.tune0.z;
    float depth_h        = params.tune0.w;

    float inv_step       = params.tune1.x;
    float inv_scale      = params.tune1.y;
    float normal_thr     = params.tune1.z;

    // ---------------- Depth-based outlines -----------------------
    // Computes outline strength based on depth differences with neighbors.
    // To change the outline thickness or sensitivity, adjust depth_l and depth_h.
    float depth_difference     = 0.0;
    float inv_depth_difference = 0.5;
    float depth_center         = GetLinearDepth(uv_normalized + offset_uv, mask_center);

    for (int i = 0; i < K; i++){
        float dOff = GetLinearDepth(uv_offsets[i], mask_center);
        depth_difference     += clamp(dOff - depth_center, 0.0, 1.0);
        inv_depth_difference += depth_center - dOff;
    }

    inv_depth_difference = clamp(inv_depth_difference, 0.0, 1.0);
    inv_depth_difference = clamp(smoothstep(inv_step, inv_step, inv_depth_difference) * inv_scale, 0.0, 1.0);
    depth_difference     = smoothstep(depth_l, depth_h, depth_difference);

    // ---------------- Normal-based innerlines  --------------------
    // Computes innerline strength based on normal differences with neighbors.
    // You can adjust normal_thr for more or less sensitivity to normal changes.
    float normal_difference = 0.0;
    vec3  normal_edge_bias  = vec3(1.0, 1.0, 1.0);
    vec3  n_center          = NormalRoughnessCompatibility(GetNormalRaw(uv_normalized)).rgb;

    for (int i = 0; i < K; i++){
        vec3 n_off = NormalRoughnessCompatibility(GetNormalRaw(uv_offsets[i])).rgb;
        normal_difference += NormalEdgeIndicator(normal_edge_bias, n_center, n_off, depth_difference);
    }
    normal_difference = smoothstep(normal_thr, normal_thr, normal_difference);
    normal_difference = clamp(normal_difference - inv_depth_difference, 0.0, 1.0);

    // ---------------- Water cutoff using TRUE WORLD-SPACE Y ------------------
    // Optionally hides or fades outlines below a water plane.
    // You can enable/disable this feature and set the water height/feather in GDScript.
    float water_factor = 1.0;
    if (params.water0.x > 0.5) {
        vec3 world_pos = ReconstructWorld(uv_normalized);
        float world_y  = world_pos.y;

        if (world_y < params.water0.y) {
            if (params.water0.w < 0.5) {
                water_factor = 0.0; // binary hide
            } else {
                // Feathered fade below the plane
                float dist = clamp((params.water0.y - world_y) / max(params.water0.z, 0.0001), 0.0, 1.0);
                water_factor = 1.0 - dist;
            }
        }
    }

    // Apply water cutoff to both outline and innerline.
    depth_difference  *= water_factor;
    normal_difference *= water_factor;

    // ---------------- Composite  ----------------------------------
    // Combines the computed outlines and innerlines with the original color.
    // To add more effects (e.g. color tint, glow), modify this section.
    vec4 color = imageLoad(color_image, uv);
    vec3 outline   = vec3(depth_difference);
    vec3 innerline = vec3(normal_difference) - outline;
    innerline = clamp(innerline, vec3(0.0), vec3(1.0));

    vec4 color_with_lines = vec4(
        color.rgb + (innerline * line_highlight) - (color.rgb * outline * line_shadow),
        1.0
    );
    imageStore(color_image, uv, color_with_lines);
}







