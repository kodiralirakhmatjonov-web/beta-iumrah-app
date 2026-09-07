#include <metal_stdlib>
using namespace metal;

struct IumrahDataSphereUniforms {
    float2 viewportSize;
    float2 center;
    float time;
    float intensity;
    float speed;
    float radius;
    float energy;
    float motionAmount;
};

struct ParticleOut {
    float4 position [[position]];
    float2 localUV;
    float4 color;
    float digit;
};

struct AtmosphereOut {
    float4 position [[position]];
    float2 uv;
};

static float hash11(float value) {
    value = fract(value * 0.1031f);
    value *= value + 33.33f;
    value *= value + value;
    return fract(value);
}

static float2 quadCorner(uint vertexID) {
    constexpr float2 corners[6] = {
        float2(0.0f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 1.0f),
        float2(0.0f, 1.0f), float2(1.0f, 0.0f), float2(1.0f, 1.0f)
    };
    return corners[vertexID];
}

static float3 rotateY(float3 p, float a) {
    float s = sin(a), c = cos(a);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

static float3 rotateX(float3 p, float a) {
    float s = sin(a), c = cos(a);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

static uint digitMask(uint d) {
    switch (d) {
        case 0u: return 0x7B6Fu;
        case 1u: return 0x2C97u;
        case 2u: return 0x73E7u;
        case 3u: return 0x73CFu;
        case 4u: return 0x5BC9u;
        case 5u: return 0x79CFu;
        case 6u: return 0x79EFu;
        case 7u: return 0x7292u;
        case 8u: return 0x7BEFu;
        default: return 0x7BCFu;
    }
}

static float renderDigit(float2 uv, uint digit) {
    float2 safeUV = clamp(uv, float2(0.0f), float2(0.9999f));
    float2 grid = safeUV * float2(3.0f, 5.0f);
    uint x = uint(floor(grid.x));
    uint y = uint(floor(grid.y));
    uint linear = y * 3u + x;
    uint bit = 14u - linear;
    float enabled = float((digitMask(digit) >> bit) & 1u);

    float2 cell = fract(grid) - 0.5f;
    float rounded = 1.0f - smoothstep(0.31f, 0.49f, max(abs(cell.x), abs(cell.y)));
    return enabled * rounded;
}

vertex AtmosphereOut iumrahDataSphereAtmosphereVertex(uint vertexID [[vertex_id]]) {
    float2 local = quadCorner(vertexID);
    AtmosphereOut out;
    out.position = float4(local.x * 2.0f - 1.0f, 1.0f - local.y * 2.0f, 0.0f, 1.0f);
    out.uv = local;
    return out;
}

fragment float4 iumrahDataSphereAtmosphereFragment(
    AtmosphereOut in [[stage_in]],
    constant IumrahDataSphereUniforms &u [[buffer(0)]]) {
    float2 pixel = in.uv * u.viewportSize;
    float2 q = (pixel - u.center) / max(u.radius, 1.0f);
    float d = length(q);

    float shell = exp(-pow((d - 0.94f) / 0.075f, 2.0f));
    float interior = exp(-d * d * 2.25f);
    float right = smoothstep(-0.75f, 0.92f, q.x);
    float lower = smoothstep(-0.90f, 0.75f, q.y);

    float3 navy = float3(0.008f, 0.035f, 0.20f);
    float3 blue = float3(0.005f, 0.24f, 0.94f);
    float3 cyan = float3(0.00f, 0.82f, 1.00f);
    float3 color = mix(navy, blue, 0.38f + right * 0.55f);
    color = mix(color, cyan, right * lower * 0.24f);

    float alpha = (shell * 0.15f + interior * 0.055f) * u.intensity;
    alpha *= 1.0f - smoothstep(0.94f, 1.10f, d);
    return float4(color, alpha);
}

vertex ParticleOut iumrahDataSphereParticleVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant IumrahDataSphereUniforms &u [[buffer(0)]]) {
    float id = float(instanceID) + 1.0f;
    float h0 = hash11(id * 1.071f + 3.1f);
    float h1 = hash11(id * 1.913f + 11.7f);
    float h2 = hash11(id * 2.417f + 27.9f);
    float h3 = hash11(id * 3.113f + 41.3f);
    float h4 = hash11(id * 4.013f + 59.9f);
    float h5 = hash11(id * 5.021f + 83.1f);

    float z = 1.0f - 2.0f * h0;
    float azimuth = h1 * 6.28318530718f;
    float planar = sqrt(max(0.0f, 1.0f - z * z));

    float volumeRadius = 0.22f + 0.74f * pow(h3, 0.3333333f);
    float shellRadius = 0.84f + 0.16f * h3;
    float shellPopulation = step(0.24f, h2);
    float radial = mix(volumeRadius, shellRadius, shellPopulation);
    float orbitDust = step(0.986f, h4);
    radial = mix(radial, 1.02f + h3 * 0.10f, orbitDust);

    float3 p = float3(planar * cos(azimuth), z, planar * sin(azimuth)) * radial;
    float t = u.time * u.speed;
    float motion = u.motionAmount;

    float twist = t * 0.13f + sin(p.y * 7.2f + t * 0.48f + h4 * 5.0f) * 0.062f * motion;
    p = rotateY(p, twist);
    p = rotateX(p, (0.075f + sin(t * 0.19f) * 0.036f) * motion);
    p *= 1.0f + sin(t * 0.60f + h5 * 9.0f) * 0.010f * u.energy * motion;

    float camera = 3.12f;
    float perspective = camera / max(1.80f, camera - p.z * 0.80f);
    float2 projected = p.xy * perspective;
    float2 pixelCenter = u.center + projected * u.radius;

    float depth = saturate((p.z + 1.05f) / 2.10f);
    float foreground = pow(depth, 1.25f);
    float sparkle = 0.72f + 0.28f * sin(t * (0.75f + h2 * 1.9f) + h4 * 31.0f);
    sparkle = mix(1.0f, sparkle, motion);

    float filamentA = 0.5f + 0.5f * sin(p.y * 11.0f + p.x * 4.2f + t * 0.18f);
    float filamentB = 0.5f + 0.5f * sin(p.x * 8.1f - p.z * 5.2f - t * 0.14f + 1.7f);
    float filament = max(pow(filamentA, 10.0f), pow(filamentB, 12.0f));

    float sizePx = mix(2.7f, 10.8f, foreground);
    sizePx *= mix(0.82f, 1.32f, h3);
    sizePx *= 1.0f + filament * 0.22f;
    float glint = step(0.989f, h5);
    sizePx *= mix(1.0f, 1.60f, glint);

    float2 local = quadCorner(vertexID);
    float2 centered = local - 0.5f;
    float2 vertexPixel = pixelCenter + centered * sizePx * float2(0.72f, 1.16f);
    float2 ndc = float2(
        vertexPixel.x / u.viewportSize.x * 2.0f - 1.0f,
        1.0f - vertexPixel.y / u.viewportSize.y * 2.0f);

    float3 darkBlue = float3(0.01f, 0.12f, 0.78f);
    float3 cyan = float3(0.00f, 0.75f, 1.00f);
    float cyanMix = saturate(0.10f + foreground * 0.56f + h0 * 0.12f);
    float3 color = mix(darkBlue, cyan, cyanMix);

    float alpha = mix(0.18f, 0.98f, foreground);
    alpha *= mix(0.52f, 1.0f, shellPopulation);
    alpha *= (0.82f + filament * 0.72f);
    alpha *= sparkle * u.intensity;
    alpha *= mix(1.0f, 0.58f, orbitDust);
    alpha *= mix(1.0f, 1.34f, glint);

    ParticleOut out;
    out.position = float4(ndc, 0.0f, 1.0f);
    out.localUV = local;
    out.color = float4(color, alpha);
    out.digit = float((instanceID * 7u + uint(h2 * 10.0f)) % 10u);
    return out;
}

fragment float4 iumrahDataSphereParticleFragment(ParticleOut in [[stage_in]]) {
    uint digit = uint(clamp(round(in.digit), 0.0f, 9.0f));
    float glyph = renderDigit(in.localUV, digit);

    float2 c = in.localUV - 0.5f;
    float halo = exp(-dot(c, c) * 11.0f) * 0.28f;
    float coverage = saturate(glyph * 1.25f + halo);
    if (coverage * in.color.a < 0.010f) discard_fragment();

    float brightness = 0.76f + glyph * 1.55f + halo * 0.95f;
    return float4(in.color.rgb * brightness, coverage * in.color.a);
}
