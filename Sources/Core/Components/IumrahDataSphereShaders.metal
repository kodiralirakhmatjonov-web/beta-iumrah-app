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

struct IumrahDataSphereParticleOut {
    float4 position [[position]];
    float2 atlasUV;
    float2 localUV;
    float4 color;
};

struct IumrahDataSphereAtmosphereOut {
    float4 position [[position]];
    float2 uv;
};

static float iumrahHash11(float value) {
    value = fract(value * 0.1031f);
    value *= value + 33.33f;
    value *= value + value;
    return fract(value);
}

static float2 iumrahTriangleCorner(uint vertexID) {
    constexpr float2 corners[6] = {
        float2(0.0f, 0.0f),
        float2(1.0f, 0.0f),
        float2(0.0f, 1.0f),
        float2(0.0f, 1.0f),
        float2(1.0f, 0.0f),
        float2(1.0f, 1.0f)
    };
    return corners[vertexID];
}

static float3 iumrahRotateY(float3 point, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(
        c * point.x + s * point.z,
        point.y,
        -s * point.x + c * point.z
    );
}

static float3 iumrahRotateX(float3 point, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(
        point.x,
        c * point.y - s * point.z,
        s * point.y + c * point.z
    );
}

vertex IumrahDataSphereAtmosphereOut iumrahDataSphereAtmosphereVertex(
    uint vertexID [[vertex_id]]
) {
    float2 local = iumrahTriangleCorner(vertexID);
    IumrahDataSphereAtmosphereOut out;
    out.position = float4(local.x * 2.0f - 1.0f, 1.0f - local.y * 2.0f, 0.0f, 1.0f);
    out.uv = local;
    return out;
}

fragment float4 iumrahDataSphereAtmosphereFragment(
    IumrahDataSphereAtmosphereOut in [[stage_in]],
    constant IumrahDataSphereUniforms &u [[buffer(0)]]
) {
    float2 pixel = in.uv * u.viewportSize;
    float2 q = (pixel - u.center) / max(u.radius, 1.0f);
    float distanceToCenter = length(q);

    // The reference has a thin luminous shell plus a restrained blue interior.
    float shell = exp(-pow((distanceToCenter - 0.965f) / 0.055f, 2.0f));
    float inner = exp(-distanceToCenter * distanceToCenter * 2.45f);
    float rightBias = smoothstep(-0.65f, 0.95f, q.x);
    float lowerBias = smoothstep(-0.75f, 0.85f, q.y);

    float3 deepBlue = float3(0.008f, 0.055f, 0.24f);
    float3 electricBlue = float3(0.015f, 0.20f, 0.92f);
    float3 cyan = float3(0.00f, 0.72f, 1.00f);

    float3 color = mix(deepBlue, electricBlue, rightBias * 0.72f);
    color = mix(color, cyan, rightBias * lowerBias * 0.22f);

    float alpha = (shell * 0.105f + inner * 0.023f) * u.intensity;
    alpha *= 1.0f - smoothstep(0.90f, 1.09f, distanceToCenter);

    return float4(color, alpha);
}

vertex IumrahDataSphereParticleOut iumrahDataSphereParticleVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant IumrahDataSphereUniforms &u [[buffer(0)]]
) {
    float id = float(instanceID) + 1.0f;
    float h0 = iumrahHash11(id * 1.071f + 3.1f);
    float h1 = iumrahHash11(id * 1.913f + 11.7f);
    float h2 = iumrahHash11(id * 2.417f + 27.9f);
    float h3 = iumrahHash11(id * 3.113f + 41.3f);
    float h4 = iumrahHash11(id * 4.013f + 59.9f);
    float h5 = iumrahHash11(id * 5.021f + 83.1f);

    // Uniform spherical distribution. Most glyphs live close to the shell,
    // while a smaller population fills the interior to reproduce the dense
    // volumetric depth of the reference instead of a flat dotted globe.
    float z = 1.0f - 2.0f * h0;
    float azimuth = h1 * 6.28318530718f;
    float planar = sqrt(max(0.0f, 1.0f - z * z));

    float volumeRadius = 0.18f + 0.78f * pow(h3, 0.3333333f);
    float shellRadius = 0.82f + 0.18f * h3;
    float shellPopulation = step(0.27f, h2);
    float radial = mix(volumeRadius, shellRadius, shellPopulation);

    // A few sparse points live just beyond the main silhouette, matching the
    // stray particles visible around the reference sphere.
    float orbitDust = step(0.982f, h4);
    radial = mix(radial, 1.02f + h3 * 0.12f, orbitDust);

    float3 p = float3(
        planar * cos(azimuth),
        z,
        planar * sin(azimuth)
    ) * radial;

    float t = u.time * u.speed;
    float motion = u.motionAmount;

    // Slow continuous rotation plus a tiny non-rigid torsion prevents the
    // cloud from reading as a rigid stock 3D model.
    float twist = (t * 0.115f)
        + sin(p.y * 7.4f + t * 0.46f + h4 * 5.0f) * 0.058f * motion;
    p = iumrahRotateY(p, twist);
    p = iumrahRotateX(
        p,
        (0.075f + sin(t * 0.19f) * 0.035f) * motion
    );

    float breath = 1.0f
        + sin(t * 0.57f + h5 * 9.0f) * 0.0085f * u.energy * motion;
    p *= breath;

    // Perspective is deliberately mild: enough for foreground digits to grow
    // and shimmer, but not enough to distort the globe into a fisheye shape.
    float camera = 3.15f;
    float perspective = camera / max(1.8f, camera - p.z * 0.78f);
    float2 projected = p.xy * perspective;
    float2 pixelCenter = u.center + projected * u.radius;

    float depth01 = saturate((p.z + 1.05f) / 2.10f);
    float surface01 = saturate(radial);
    float foreground = pow(depth01, 1.35f);

    float sparkleSpeed = 0.72f + h2 * 1.95f;
    float sparkle = 0.70f
        + 0.30f * sin(t * sparkleSpeed + h4 * 31.0f);
    sparkle = mix(1.0f, sparkle, motion);

    float sizePixels = mix(1.10f, 6.40f, foreground);
    sizePixels *= mix(0.76f, 1.34f, h3);
    sizePixels *= mix(0.90f, 1.08f, u.energy - 0.82f);

    // Rare larger glints create the bright blue foreground points seen on the
    // right edge of the source animation.
    float glint = step(0.988f, h5);
    sizePixels *= mix(1.0f, 1.70f, glint);

    float2 local = iumrahTriangleCorner(vertexID);
    float2 centeredCorner = local - 0.5f;
    float2 glyphAspect = float2(0.70f, 1.12f);
    float2 vertexPixel = pixelCenter + centeredCorner * sizePixels * glyphAspect;

    float2 ndc = float2(
        vertexPixel.x / u.viewportSize.x * 2.0f - 1.0f,
        1.0f - vertexPixel.y / u.viewportSize.y * 2.0f
    );

    uint glyphIndex = (instanceID * 7u + uint(h2 * 10.0f)) % 10u;
    float glyphWidth = 0.1f;
    float2 atlasUV = float2(
        float(glyphIndex) * glyphWidth + local.x * glyphWidth,
        local.y
    );

    float cyanMix = saturate(0.05f + foreground * 0.46f + h0 * 0.12f);
    float3 darkBlue = float3(0.012f, 0.10f, 0.66f);
    float3 cyan = float3(0.00f, 0.66f, 1.00f);
    float3 particleColor = mix(darkBlue, cyan, cyanMix);

    // Far and interior glyphs collapse perceptually into small points; nearby
    // glyphs become readable digits. This preserves the reference at a glance
    // while rewarding a closer look.
    float silhouette = smoothstep(0.06f, 0.34f, surface01);
    float filamentA = 0.5f + 0.5f * sin(p.y * 11.0f + p.x * 4.2f + t * 0.18f);
    float filamentB = 0.5f + 0.5f * sin(p.x * 8.1f - p.z * 5.2f - t * 0.14f + 1.7f);
    float filament = max(pow(filamentA, 10.0f), pow(filamentB, 12.0f));

    sizePixels *= 1.0f + filament * 0.16f;

    float alpha = mix(0.09f, 0.84f, foreground);
    alpha *= mix(0.42f, 1.0f, shellPopulation);
    alpha *= (0.72f + filament * 0.78f);
    alpha *= sparkle * silhouette * u.intensity;
    alpha *= mix(1.0f, 0.52f, orbitDust);
    alpha *= mix(1.0f, 1.35f, glint);

    IumrahDataSphereParticleOut out;
    out.position = float4(ndc, 0.0f, 1.0f);
    out.atlasUV = atlasUV;
    out.localUV = local;
    out.color = float4(particleColor, alpha);
    return out;
}

fragment float4 iumrahDataSphereParticleFragment(
    IumrahDataSphereParticleOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]]
) {
    constexpr sampler glyphSampler(
        mag_filter::linear,
        min_filter::linear,
        mip_filter::linear,
        address::clamp_to_edge
    );

    float glyph = atlas.sample(glyphSampler, in.atlasUV).a;
    float2 centered = in.localUV - 0.5f;
    float distanceSquared = dot(centered, centered);

    // Very small quads need a compact bloom envelope or they read as dead LCD
    // pixels. The atlas still determines the digit shape on larger foreground
    // particles, while the halo lets sub-pixel digits resolve as luminous dots.
    float halo = exp(-distanceSquared * 10.5f) * 0.34f;
    float core = glyph * 1.18f;
    float coverage = saturate(core + halo);

    if (coverage * in.color.a < 0.008f) {
        discard_fragment();
    }

    float brightness = 0.68f + core * 1.22f + halo * 0.70f;
    return float4(in.color.rgb * brightness, coverage * in.color.a);
}
