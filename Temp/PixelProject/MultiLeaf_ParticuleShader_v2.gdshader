shader_type particles;
render_mode disable_velocity;

// Uniforms for color and position control
group_uniforms ColorAndPosition;
uniform sampler2D color_ramp_texture : source_color; // Color ramp for particle colors
uniform vec3 target_color_direction = vec3(0.0, 1.0, 0.0); // Direction for darkest color (default: Y-up)
uniform float color_spread : hint_range(0.0, 1.0, 0.01) = 0.5; // How spread out colors are (0.0 = tight, 1.0 = full sphere)
uniform float color_noise : hint_range(0.0, 1.0, 0.01) = 0.1; // Random noise for color variation
uniform float emission_sphere_radius = 1.0; // Radius of the emission sphere (fixed)
uniform float position_bias_strength : hint_range(0.0, 1.0, 0.01) = 0.3; // Fine-tune position clustering strength

// Standard particle uniforms
group_uniforms ParticleDynamics;
uniform vec3 direction = vec3(0.0, 0.0, 0.0); // No preferred direction for full sphere
uniform float spread = 180.0; // Spread angle in degrees (180 for full sphere emission)
uniform float initial_linear_velocity_min = 0.0;
uniform float initial_linear_velocity_max = 1.0;
uniform float lifetime_randomness = 0.0;
uniform vec4 color_value : source_color = vec4(1.0); // Fallback color
uniform vec3 gravity = vec3(0.0, -2.0, 0.0); // Reduced gravity to minimize downward pull

// Random number generation
float rand_from_seed(inout uint seed) {
    seed = seed * 1103515245u + 12345u;
    return float(seed % 0x7fffffffu) / float(0x7fffffff);
}

float rand_from_seed_m1_p1(inout uint seed) {
    return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
    x = ((x >> uint(16)) ^ x) * uint(73244475);
    x = ((x >> uint(16)) ^ x) * uint(73244475);
    x = (x >> uint(16)) ^ x;
    return x;
}

// Calculate initial position based on color, ensuring full spherical distribution
vec3 calculate_initial_position(inout float ramp_uv, inout uint alt_seed) {
    float pi = 3.14159;
    
    float s = rand_from_seed(alt_seed) * 2.0 - 1.0; // Z-coordinate factor (-1 to 1)
    float t = rand_from_seed(alt_seed) * 2.0 * pi; // Azimuthal angle (0 to 2pi)
    float radius = emission_sphere_radius * sqrt(max(0.0, 1.0 - s * s)); // XY-plane radius
    vec3 pos = vec3(radius * cos(t), radius * sin(t), emission_sphere_radius * s);
    
    // Ensure position is on sphere surface
    pos = normalize(pos) * emission_sphere_radius;
    
    // Calculate color ramp UV based on direction
    vec3 particle_dir = normalize(pos);
    vec3 target_dir = length(target_color_direction) > 0.0 ? normalize(target_color_direction) : vec3(0.0, 1.0, 0.0); // Fallback for zero-length direction
    
    // Calculate dot product to determine alignment with target direction
    float dot_p = dot(particle_dir, target_dir);
    float influence = (dot_p + 1.0) * 0.5; // Map -1..1 to 0..1
    
    // Adjust ramp UV based on direction and color_spread
    ramp_uv = mix(0.0, 1.0, influence); // 0.0 at opposite, 1.0 at target direction
    ramp_uv = mix(0.5, ramp_uv, color_spread); // Center at 0.5 if spread is low
    ramp_uv += (rand_from_seed(alt_seed) - 0.5) * color_noise; // Add noise
    ramp_uv = clamp(ramp_uv, 0.0, 1.0); // Ensure UV stays in bounds
    
    // Reposition particles based on color, using weighted interpolation to avoid gaps
    if (color_spread < 1.0 && position_bias_strength > 0.0) {
        float bias = (1.0 - ramp_uv) * (1.0 - color_spread) * position_bias_strength; // Bias strength based on color
        vec3 target_pos = target_dir * emission_sphere_radius;
        
        // Interpolate between original position and target direction, preserving sphere surface
        pos = normalize(mix(pos, target_pos, bias)) * emission_sphere_radius;
    }
    
    return pos;
}

// Calculate initial velocity
vec3 calculate_initial_velocity(inout uint alt_seed) {
    float pi = 3.14159;
    float degree_to_rad = pi / 180.0;
    float spread_rad = spread * degree_to_rad;
    
    float u = rand_from_seed(alt_seed);
    float v = rand_from_seed(alt_seed);
    float theta = 2.0 * pi * u;
    float phi = acos(2.0 * v - 1.0);
    vec3 spread_direction = vec3(
        sin(phi) * cos(theta),
        sin(phi) * sin(theta),
        cos(phi)
    );
    
    vec3 dir_nrm = length(direction) > 0.0 ? normalize(direction) : vec3(0.0, 0.0, 1.0);
    vec3 binormal = cross(vec3(0.0, 1.0, 0.0), dir_nrm);
    if (length(binormal) < 0.0001) {
        binormal = vec3(0.0, 0.0, 1.0);
    }
    binormal = normalize(binormal);
    vec3 normal = cross(binormal, dir_nrm);
    spread_direction = binormal * spread_direction.x + normal * spread_direction.y + dir_nrm * spread_direction.z;
    
    float velocity = mix(initial_linear_velocity_min, initial_linear_velocity_max, rand_from_seed(alt_seed));
    return normalize(spread_direction) * velocity;
}

void start() {
    uint alt_seed = hash(NUMBER + RANDOM_SEED);
    
    // Calculate color ramp UV and position
    float ramp_uv = 0.0;
    vec3 pos = calculate_initial_position(ramp_uv, alt_seed);
    
    // Set position
    TRANSFORM[3].xyz = pos;
    TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
    
    // Set color from ramp
    vec4 base_color = texture(color_ramp_texture, vec2(ramp_uv, 0.0));
    COLOR = base_color * color_value;
    
    // Set velocity
    VELOCITY = calculate_initial_velocity(alt_seed);
    VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
    
    // Set lifetime
    CUSTOM.w = 1.0 - lifetime_randomness * rand_from_seed(alt_seed);
    
    // Check if particle is active
    if (rand_from_seed(alt_seed) > AMOUNT_RATIO) {
        ACTIVE = false;
    }
}

void process() {
    uint alt_seed = hash(NUMBER + RANDOM_SEED);
    
    // Update lifetime
    CUSTOM.y += DELTA / LIFETIME;
    
    // Check if particle lifetime has expired
    if (CUSTOM.y > CUSTOM.w) {
        ACTIVE = false;
    } else {
        // Apply gravity
        VELOCITY += gravity * DELTA;
        
        // Update position
        TRANSFORM[3].xyz += VELOCITY * DELTA;
    }
}