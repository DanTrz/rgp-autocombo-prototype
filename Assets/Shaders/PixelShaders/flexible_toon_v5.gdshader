
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

// ========================= Material & Texture =========================
group_uniforms color_and_textures;
uniform vec4  albedo_color : source_color = vec4(1.0);
uniform bool  use_texture = true; // if false, ALBEDO uses only albedo_color
uniform float roughness = 1.0;

uniform bool use_repeat_nearest_texture = true;
uniform sampler2D albedo_texture_repeat_nearest : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D albedo_texture_clamp_linear  : source_color, filter_linear,         repeat_disable;

// Ambient light
uniform bool disable_ambient_light = true; //play with this to check color/shadow accuracy
uniform bool Use_fake_ambient_light = false;
uniform vec3 fake_ambient_light : source_color = vec3(1.0);

// Emission (additive)
uniform bool use_emission = false;
uniform vec3 emission_color : source_color = vec3(1.0);

// ========================= Controls & Switches ========================
group_uniforms cel_shading_options;
uniform bool  clamp_diffuse_to_max = false;  // brightest-wins across lights (graphic) vs additive
uniform bool  use_attenuation = true;        // respect Godot light attenuation

// Toon band shaping
uniform int   cuts : hint_range(1, 20) = 2;         // number of bands (2 = classic)
uniform float wrap : hint_range(-2.0, 2.0) = 0.0;   // shifts light around terminator
uniform float steepness : hint_range(1.0, 8.0) = 1.0; // widens/narrows lit region

// Rim (graphic edge light)
uniform bool  use_rim = false;
uniform float rim_bias : hint_range(0.0, 1.0) = 0.10;   // threshold before rim appears (≈ SIMPLE’s 0.1)
uniform float rim_strength : hint_range(0.0, 2.0) = 1.0;

// Specular (toon 1-bit)
uniform bool  use_specular = false;
uniform float specular_strength : hint_range(0.0, 1.0) = 1.0;
uniform float specular_shininess : hint_range(0.0, 32.0) = 16.0;
uniform sampler2D specular_map : source_color;

// Ramp & Borders
uniform bool use_ramp = false;
uniform sampler2D ramp : source_color;

uniform bool  use_borders = false;
uniform float border_width = 0.05;

uniform bool billboard = false;

// ========================= UV and Normals ========================
group_uniforms uv_and_normals;
// UV transform
uniform vec2 albedo_uv_scale  = vec2(1.0, 1.0);
uniform vec2 albedo_uv_offset = vec2(0.0, 0.0);

uniform float normal_rotation_pitch : hint_range(-180.0, 180.0) = 0.0;
uniform float normal_rotation_yaw   : hint_range(-180.0, 180.0) = 0.0;
uniform float normal_rotation_roll  : hint_range(-180.0, 180.0) = 0.0;

// ========================= Varyings ==================================
varying vec3 vertex_pos;
varying vec3 normal;

// ========================= Helpers ===================================
float deg_to_rad(float d) { return d * PI / 180.0; }

vec4 euler_yxz_to_quat(vec3 euler) {
    float yaw   = euler.x;
    float pitch = euler.y;
    float roll  = euler.z;

    float cy = cos(yaw * 0.5);   float sy = sin(yaw * 0.5);
    float cp = cos(pitch * 0.5); float sp = sin(pitch * 0.5);
    float cr = cos(roll * 0.5);  float sr = sin(roll * 0.5);

    vec4 q;
    q.x = cy * sp * cr + sy * cp * sr;
    q.y = sy * cp * cr - cy * sp * sr;
    q.z = cy * cp * sr - sy * sp * cr;
    q.w = cy * cp * cr + sy * cp * sr;
    return q;
}

vec3 rotate_by_quat(vec3 v, vec4 q) {
    vec3 q_xyz = q.xyz;
    float q_w = q.w;
    return v + 2.0 * cross(q_xyz, cross(q_xyz, v) + q_w * v);
}

float split_specular(float s) { return step(0.5, s); } // toon 1-bit specular

// ========================= Vertex ====================================
void vertex() {
    vertex_pos = VERTEX;
    normal = NORMAL;

    if (billboard) {
        // Face the camera while keeping world position
        mat4 billboard_modelview = VIEW_MATRIX * mat4(
            INV_VIEW_MATRIX[0],
            INV_VIEW_MATRIX[1],
            INV_VIEW_MATRIX[2],
            MODEL_MATRIX[3]
        );
        MODELVIEW_MATRIX = billboard_modelview;
    }
}

// ========================= Fragment ==================================
void fragment() {
    vec2 uv = UV * albedo_uv_scale + albedo_uv_offset;

    vec4 tex_color = vec4(1.0);
    if (use_texture) {
        tex_color = use_repeat_nearest_texture
            ? texture(albedo_texture_repeat_nearest, uv)
            : texture(albedo_texture_clamp_linear,  uv);
    }

    ALBEDO    = albedo_color.rgb * tex_color.rgb;
    ROUGHNESS = roughness;
}

// ========================= Light (per light) ==========================
void light() {
    // --- Normal transform (art tweak) ---
    vec3 euler_rad = vec3(
        deg_to_rad(normal_rotation_yaw),
        deg_to_rad(normal_rotation_pitch),
        deg_to_rad(normal_rotation_roll)
    );
    vec4 q = euler_yxz_to_quat(euler_rad);
    vec3 N = rotate_by_quat(NORMAL, q);

    // --- Core light inputs ---
    float NdotL = max(dot(N, LIGHT), 0.0);
    float atten = use_attenuation ? ATTENUATION : 1.0;
    float steps = float(max(cuts, 1));

    // --- Artist shaping (wrap & steepness) ---
    // 1) Shift by wrap (moves the terminator), clamp to [0,1]
    float shaped = clamp(NdotL + wrap, 0.0, 1.0);
    // 2) Widen/narrow with steepness, clamp again to [0,1]
    shaped = clamp(shaped * steepness, 0.0, 1.0);

    // --- Quantize to crisp bands (classic cel; matches SIMPLE feel) ---
    float band = round(shaped * steps) / steps;

    // --- Optional borders between bands (ink-like edges) ---
    float border = 0.0;
    if (use_borders) {
        float corr_border_width = length(cross(N, LIGHT)) * border_width * steepness;
        border = step(band - corr_border_width, shaped) - step(1.0 - corr_border_width, shaped);
    }

    // --- Ramp (palette remap) or direct band scalar ---
    vec3 band_color = vec3(band * (1.0 - border));
    if (use_ramp) {
        band_color = texture(ramp, vec2(band * (1.0 - border), 0.0)).rgb;
    }

    // --- Unified per-light diffuse contribution (same for ALL lights) ---
    vec3 contrib = ALBEDO * LIGHT_COLOR * band_color * atten;

    // --- Ambient (optional; OFF by default to match SIMPLE) ---
    if (!disable_ambient_light) {
        // Subtle fill; multiply by ALBEDO to avoid gray wash.
        vec3 ambient = vec3(0.2);
        if (Use_fake_ambient_light) ambient = fake_ambient_light * 0.3;
        contrib += ambient * ALBEDO;
    }

    // --- Rim (graphic edge; albedo-free like SIMPLE’s rim) ---
    if (use_rim) {
        float rim = 1.0 - dot(N, VIEW);                  // how perpendicular to view
        float rim_term = round(max(rim - rim_bias, 0.0) * NdotL);
        contrib += (rim_term * rim_strength) * (LIGHT_COLOR / PI);
    }

    // --- Emission (optional, additive) ---
    if (use_emission) {
        contrib += ALBEDO * emission_color * LIGHT_COLOR * atten;
    }

    // --- Accumulate (or brightest-wins) ---
    if (clamp_diffuse_to_max) {
        DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, contrib);
    } else {
        DIFFUSE_LIGHT += contrib;
    }

    // --- Specular (optional, 1-bit toon spec) ---
    if (use_specular) {
        vec3 H = normalize(LIGHT + VIEW);
        float NdotH = max(dot(N, H), 0.0);
        float s = pow(NdotH, specular_shininess * specular_shininess)
                * texture(specular_map, UV).r * atten;
        s = split_specular(s);
        SPECULAR_LIGHT += specular_strength * s * LIGHT_COLOR;
    }
}
