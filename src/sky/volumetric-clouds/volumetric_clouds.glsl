#[compute]
#version 450

// Adapted from Clay John's godot-volumetric-cloud-demo-v2.
// See LICENSES/volumetric-clouds-MIT.txt.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D current_image;
layout(set = 1, binding = 0) uniform sampler3D large_scale_noise;
layout(set = 1, binding = 1) uniform sampler3D small_scale_noise;
layout(set = 1, binding = 2) uniform sampler2D weather_noise;

// 128-byte push-constant limit.
layout(push_constant, std430) uniform Params {
    vec2 texture_size;
    vec2 update_position;
    vec2 cloud_pos;
    vec2 detailed_pos;
    vec2 weather_pos;
    vec2 pad1;
    vec3 ground_color;
    float ground_light_multiplier;
    vec3 light_direction;
    float light_energy;
    vec3 light_color;
    float direct_light_multiplier;
    vec3 ambient_color;
    float ambient_light_multiplier;
    float density;
    float cloud_coverage;
    float time;
    float pad2;
} params;

const float GROUND_RADIUS = 6000000.0;
const float CLOUD_BOTTOM_RADIUS = 6001500.0;
const float CLOUD_TOP_RADIUS = 6004000.0;

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float remap(float value, float old_min, float old_max, float new_min, float new_max) {
    return new_min + (((value - old_min) / (old_max - old_min)) * (new_max - new_min));
}

float henyey_greenstein(float cos_theta, float g) {
    const float INV_4PI = 0.0795774715459;
    return INV_4PI * (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5);
}

float height_fraction(float radius) {
    return clamp(
        (radius - CLOUD_BOTTOM_RADIUS) / (CLOUD_TOP_RADIUS - CLOUD_BOTTOM_RADIUS),
        0.0,
        1.0
    );
}

vec4 mix_gradients(float cloud_type) {
    const vec4 STRATUS = vec4(0.02, 0.05, 0.09, 0.11);
    const vec4 STRATOCUMULUS = vec4(0.02, 0.2, 0.48, 0.625);
    const vec4 CUMULUS = vec4(0.01, 0.0625, 0.78, 1.0);
    float stratus = 1.0 - clamp(cloud_type * 2.0, 0.0, 1.0);
    float stratocumulus = 1.0 - abs(cloud_type - 0.5) * 2.0;
    float cumulus = clamp(cloud_type - 0.5, 0.0, 1.0) * 2.0;
    return STRATUS * stratus + STRATOCUMULUS * stratocumulus + CUMULUS * cumulus;
}

float density_height_gradient(float height_frac, float cloud_type) {
    vec4 gradient = mix_gradients(cloud_type);
    return smoothstep(gradient.x, gradient.y, height_frac)
        - smoothstep(gradient.z, gradient.w, height_frac);
}

float intersect_sphere(vec3 pos, vec3 dir, float radius) {
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, pos);
    float c = dot(pos, pos) - radius * radius;
    float discriminant = max(0.0, b * b - 4.0 * a * c);
    return max(-b - sqrt(discriminant), -b + sqrt(discriminant)) / (2.0 * a);
}

float sample_density(vec3 point, vec3 weather, float mip) {
    vec3 p = point;
    float height_frac = height_fraction(length(p));

    p.xz += 20.0 * params.cloud_pos * 0.6;
    vec4 noise = textureLod(large_scale_noise, p * 0.00008, mip - 2.0);
    float fbm = noise.g * 0.625 + noise.b * 0.25 + noise.a * 0.125;

    float gradient = density_height_gradient(height_frac, weather.r);
    float base_cloud = remap(noise.r, -(1.0 - fbm), 1.0, 0.0, 1.0);
    float weather_coverage = params.cloud_coverage * weather.b;
    base_cloud = remap(base_cloud * gradient, 1.0 - weather_coverage, 1.0, 0.0, 1.0);
    base_cloud *= weather_coverage;

    p.xz -= params.detailed_pos * 40.0;
    p.y -= params.time * 40.0;
    vec3 high_frequency_noise = textureLod(small_scale_noise, p * 0.001, mip).rgb;
    float high_frequency_fbm = high_frequency_noise.r * 0.625
            + high_frequency_noise.g * 0.25
            + high_frequency_noise.b * 0.125;
    high_frequency_fbm = mix(
            high_frequency_fbm,
            1.0 - high_frequency_fbm,
            clamp(height_frac * 4.0, 0.0, 1.0)
        );
    base_cloud = remap(base_cloud, high_frequency_fbm * 0.4 * height_frac, 1.0, 0.0, 1.0);
    return pow(clamp(base_cloud, 0.0, 1.0), (1.0 - height_frac) * 0.8 + 0.5);
}

vec4 march_clouds(vec3 start, vec3 ray_step, int step_count) {
    const vec3 RANDOM_VECTORS[6] = {
            vec3(0.38051305, 0.92453449, -0.02111345),
            vec3(-0.50625799, -0.03590792, -0.86163418),
            vec3(-0.32509218, -0.94557439, 0.01428793),
            vec3(0.09026238, -0.27376545, 0.95755165),
            vec3(0.28128598, 0.42443639, -0.86065785),
            vec3(-0.16852403, 0.14748697, 0.97460106)
        };

    float step_size = length(ray_step);
    vec3 direction = normalize(ray_step);
    vec3 p = start + direction * hash(start * 10.0) * step_size;
    float light_step_size = (CLOUD_TOP_RADIUS - CLOUD_BOTTOM_RADIUS) / 64.0;
    vec3 light_direction = normalize(params.light_direction);

    float transmittance = 1.0;
    float alpha = 0.0;
    vec3 luminance = vec3(0.0);
    float cos_theta = dot(light_direction, direction);
    float phase = max(
            max(
                henyey_greenstein(cos_theta, 0.6),
                henyey_greenstein(cos_theta, 0.4 - 1.4 * light_direction.y)
            ),
            henyey_greenstein(cos_theta, -0.2)
        );

    vec3 direct_light = params.light_color
            * params.light_energy
            * params.direct_light_multiplier;
    vec3 ambient_light = params.ambient_color * params.ambient_light_multiplier;
    vec3 ground_light = params.ground_color * params.ground_light_multiplier;
    const float WEATHER_SCALE = 0.00006;

    for (int i = 0; i < step_count; i++) {
        p += direction * step_size;
        vec3 weather = texture(weather_noise, p.xz * WEATHER_SCALE + 0.5 + params.weather_pos).xyz;
        float height_frac = height_fraction(length(p));
        float cloud_density = sample_density(p, weather, 0.0);
        float step_transmittance = exp(-params.density * cloud_density * step_size);

        if (cloud_density > 0.0) {
            vec3 light_point = p;
            float accumulated_density = 0.0;
            for (int j = 0; j < 6; j++) {
                light_point += (light_direction + RANDOM_VECTORS[j] * float(j)) * light_step_size;
                vec3 light_weather = texture(
                        weather_noise,
                        light_point.xz * WEATHER_SCALE + 0.5 + params.weather_pos
                    ).xyz;
                accumulated_density += sample_density(light_point, light_weather, float(j));
            }

            light_point = p + light_direction * 18.0 * light_step_size;
            float light_height_frac = height_fraction(length(light_point));
            vec3 distant_weather = texture(
                    weather_noise,
                    light_point.xz * WEATHER_SCALE + 0.5 + params.weather_pos
                ).xyz;
            accumulated_density += pow(
                    sample_density(light_point, distant_weather, 5.0),
                    (1.0 - light_height_frac) * 0.8 + 0.5
                );

            float beers = exp(-params.density * accumulated_density * light_step_size * 3.0);
            float powder = 1.0 - exp(
                        -params.density * accumulated_density * light_step_size * 6.0
                    );
            float direct_scattering = 2.0 * beers * powder;
            vec3 ambient = mix(ground_light, ambient_light, smoothstep(0.0, 1.0, height_frac));
            alpha += (1.0 - step_transmittance) * (1.0 - alpha);
            vec3 radiance = (ambient + direct_scattering * direct_light * phase) * cloud_density;
            luminance += transmittance
                    * (radiance - radiance * step_transmittance)
                    / max(0.0000001, cloud_density);
            transmittance *= step_transmittance;
        }
    }

    return vec4(luminance, clamp(alpha, 0.0, 1.0));
}

vec4 render_sky_direction(vec3 direction) {
    if (direction.y <= 0.0) {
        return vec4(0.0);
    }

    vec3 camera_position = vec3(0.0, GROUND_RADIUS, 0.0);
    vec3 start = camera_position
            + direction * intersect_sphere(camera_position, direction, CLOUD_BOTTOM_RADIUS);
    vec3 end = camera_position
            + direction * intersect_sphere(camera_position, direction, CLOUD_TOP_RADIUS);
    const float STEP_COUNT = 128.0;
    vec3 ray_step = direction * length(end - start) / STEP_COUNT;
    return march_clouds(start, ray_step, int(STEP_COUNT));
}

vec2 oct_wrap(vec2 value) {
    vec2 signs = vec2(value.x >= 0.0 ? 1.0 : -1.0, value.y >= 0.0 ? 1.0 : -1.0);
    return (1.0 - abs(value.yx)) * signs;
}

vec3 oct_to_direction(vec2 encoded) {
    vec3 direction;
    direction.x = encoded.x - encoded.y;
    direction.y = encoded.x + encoded.y - 1.0;
    direction.z = 1.0 - abs(direction.x) - abs(direction.y);
    direction.xy = direction.z >= 0.0 ? direction.xy : oct_wrap(direction.xy);
    return normalize(direction);
}

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy) + ivec2(params.update_position);
    if (pixel.x >= int(params.texture_size.x) || pixel.y >= int(params.texture_size.y)) {
        return;
    }
    vec2 uv = vec2(pixel) / params.texture_size;
    vec3 direction = oct_to_direction(uv).xzy;
    imageStore(current_image, pixel, render_sky_direction(direction));
}
