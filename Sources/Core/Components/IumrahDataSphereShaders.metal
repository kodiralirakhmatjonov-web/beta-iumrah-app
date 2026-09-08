#include <metal_stdlib>
using namespace metal;

struct IumrahDataSphereUniformsV4 {
    float2 viewportSize;
    float2 center;
    float time;
    float intensity;
    float speed;
    float radius;
    float energy;
    float motionAmount;
    float referenceScale;
    float padding;
};

struct IumrahDataSphereParticleSeedV4 {
    float4 positionAndClass;
    float4 attributes;
    float4 variation;
};

struct IumrahDataSphereAtmosphereOutV4 {
    float4 position [[position]];
    float2 uv;
};

struct IumrahDataSphereParticleOutV4 {
    float4 position [[position]];
    float2 localUV;
    float4 color;
    float digit;
    float glow;
    float sparkle;
};

static float2 iumrahSphereQuadCornerV4(uint vertexID) {
    constexpr float2 corners[6] = {
        float2(0.0f, 0.0f), float2(1.0f, 0.0f), float2(0.0f, 1.0f),
        float2(0.0f, 1.0f), float2(1.0f, 0.0f), float2(1.0f, 1.0f)
    };
    return corners[vertexID];
}

static float3 iumrahSphereRotateXV4(float3 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

static float3 iumrahSphereRotateYV4(float3 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

static float3 iumrahSphereRotateZV4(float3 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

vertex IumrahDataSphereAtmosphereOutV4 iumrahDataSphereAtmosphereVertexV4(
    uint vertexID [[vertex_id]]) {
    float2 local = iumrahSphereQuadCornerV4(vertexID);
    IumrahDataSphereAtmosphereOutV4 out;
    out.position = float4(local.x * 2.0f - 1.0f, 1.0f - local.y * 2.0f, 0.0f, 1.0f);
    out.uv = local;
    return out;
}

fragment float4 iumrahDataSphereAtmosphereFragmentV4(
    IumrahDataSphereAtmosphereOutV4 in [[stage_in]],
    constant IumrahDataSphereUniformsV4 &u [[buffer(0)]]) {
    float2 pixel = in.uv * u.viewportSize;
    float2 q = (pixel - u.center) / max(u.radius, 1.0f);
    float d = length(q);

    // Almost-black volume. The reference never reads as a filled blue disc.
    float inside = 1.0f - smoothstep(0.94f, 1.035f, d);
    float body = exp(-d * d * 1.75f) * inside;

    // Very thin optical rim, strongest on lower/right portions.
    float rim = exp(-pow((d - 0.997f) / 0.018f, 2.0f));
    float lower = smoothstep(-0.30f, 0.95f, q.y);
    float right = smoothstep(-0.70f, 0.95f, q.x);
    float crescent = rim * (0.28f + 0.72f * lower) * (0.40f + 0.60f * right);

    // Dim cyan haze lives inside the globe, left of the physical centre.
    float2 coreQ = (q - float2(-0.47f, 0.015f)) / float2(0.42f, 0.57f);
    float core = exp(-dot(coreQ, coreQ) * 1.65f) * inside;

    float3 deepNavy = float3(0.005f, 0.040f, 0.23f);
    float3 rimBlue = float3(0.004f, 0.105f, 0.58f);
    float3 coreCyan = float3(0.000f, 0.50f, 0.56f);

    float3 color = deepNavy;
    color = mix(color, rimBlue, saturate(rim * 0.54f + crescent * 0.40f));
    color = mix(color, coreCyan, core * 0.40f);

    float alpha = body * 0.48f;
    alpha += rim * 0.100f;
    alpha += crescent * 0.130f;
    alpha += core * 0.130f;
    alpha *= u.intensity;
    alpha *= 1.0f - smoothstep(1.015f, 1.075f, d);

    return float4(color, alpha);
}

vertex IumrahDataSphereParticleOutV4 iumrahDataSphereParticleVertexV4(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant IumrahDataSphereUniformsV4 &u [[buffer(0)]],
    const device IumrahDataSphereParticleSeedV4 *seeds [[buffer(1)]]) {
    IumrahDataSphereParticleSeedV4 seed = seeds[instanceID];

    float3 p = seed.positionAndClass.xyz;
    float particleClass = seed.positionAndClass.w;
    float referenceSize = seed.attributes.x;
    float luminance = seed.attributes.y;
    float phase = seed.attributes.z;
    float digit = seed.attributes.w;
    float filamentPhase = seed.variation.x;
    float colourSeed = seed.variation.y;
    float sparkle = seed.variation.z;
    float opacitySeed = seed.variation.w;

    float t = u.time * u.speed;
    float motion = u.motionAmount;

    // Motion measured from the supplied clip is dominated by a gentle upward
    // surface flow with a smaller leftward component. A coherent 3D rotation
    // preserves the feeling of one physical globe rather than independent dust.
    p = iumrahSphereRotateYV4(p, -t * 0.070f * motion);
    p = iumrahSphereRotateXV4(p,  t * 0.235f * motion);
    p = iumrahSphereRotateZV4(p, sin(t * 0.075f) * 0.014f * motion);

    float radial = max(length(p), 0.0001f);
    float3 normal = p / radial;

    // Sub-percent coherent displacement keeps the surface alive without the
    // noisy boiling seen in the rejected implementation.
    float warpA = sin(normal.y * 17.0f + normal.z * 8.0f + t * 0.24f + phase);
    float warpB = sin(normal.x * 12.0f - normal.z * 13.0f - t * 0.17f + filamentPhase);
    float warp = (warpA + warpB) * 0.0018f * u.energy * motion;
    p *= 1.0f + warp;

    // Near-orthographic projection: enough depth to distinguish foreground
    // glyphs while keeping the silhouette circular like the reference.
    float perspective = 1.0f + p.z * 0.052f;
    float2 projected = p.xy * perspective;
    float2 pixelCenter = u.center + projected * u.radius;

    float depth = saturate((p.z + 1.05f) / 2.10f);
    float foreground = smoothstep(0.20f, 0.98f, depth);
    float shell = 1.0f - step(0.5f, particleClass);
    float stray = step(1.5f, particleClass);
    float volume = saturate(1.0f - shell - stray);

    // Irregular moving filaments add the fine network texture visible inside
    // the reference globe. They alter light only, not topology.
    float fieldA = 0.5f + 0.5f * sin(p.y * 15.0f + p.x * 5.0f + p.z * 3.0f + t * 0.12f + filamentPhase);
    float fieldB = 0.5f + 0.5f * sin(p.x * 11.0f - p.z * 8.0f - t * 0.09f + phase * 0.7f);
    float fieldC = 0.5f + 0.5f * sin((p.x + p.y) * 9.0f + p.z * 5.0f + t * 0.07f + colourSeed * 6.2831853f);
    float filament = max(pow(fieldA, 13.0f), max(pow(fieldB, 15.0f), pow(fieldC, 17.0f)));

    // Shell silhouette remains visible even on the darker back half.
    float rim = pow(saturate(1.0f - abs(normal.z)), 3.2f) * shell;

    // Cyan energy is localised around x≈-0.47 of the sphere, matching the
    // reference's inner turquoise core rather than washing the whole globe cyan.
    float2 coreDelta = (projected - float2(-0.47f, 0.015f)) / float2(0.37f, 0.54f);
    float coreField = exp(-dot(coreDelta, coreDelta) * 1.45f);
    float rightField = smoothstep(-0.15f, 0.90f, projected.x);

    float3 deepBlue = float3(0.002f, 0.008f, 0.085f);
    float3 cobalt = float3(0.002f, 0.090f, 0.76f);
    float3 electricBlue = float3(0.005f, 0.24f, 1.00f);
    float3 coreCyan = float3(0.000f, 0.66f, 0.74f);
    float3 iceBlue = float3(0.26f, 0.67f, 1.00f);

    float blueMix = saturate(0.08f + foreground * 0.74f + rightField * 0.15f + colourSeed * 0.05f);
    float3 color = mix(deepBlue, cobalt, blueMix);
    color = mix(color, electricBlue, saturate(rightField * foreground * 0.28f));

    float cyanAmount = coreField * (volume * 0.70f + shell * 0.19f) * (0.96f - foreground * 0.43f);
    cyanAmount += filament * coreField * 0.15f;
    color = mix(color, coreCyan, saturate(cyanAmount));

    // Very rare bright glyphs reproduce the isolated luminous points without
    // turning the sphere into a solid turquoise mass.
    float sparkleWave = 0.5f + 0.5f * sin(t * (0.92f + colourSeed * 0.58f) + phase * 1.9f);
    float sparklePulse = sparkle * pow(sparkleWave, 8.0f);
    color = mix(color, iceBlue, sparklePulse * 0.42f);

    float twinkle = 0.88f + 0.12f * sin(t * (0.72f + colourSeed * 0.78f) + phase);
    twinkle = mix(1.0f, twinkle, motion);

    float alpha = mix(0.035f, 0.50f, pow(foreground, 1.55f));
    alpha *= mix(0.74f, 1.0f, shell);
    alpha *= mix(0.88f, 1.0f, volume);
    alpha *= opacitySeed;
    alpha *= luminance;
    alpha *= (0.76f + filament * 0.78f);
    alpha += rim * 0.110f;
    alpha *= twinkle;
    alpha *= u.intensity;
    alpha *= mix(1.0f, 0.30f, stray);
    alpha *= 1.0f + sparklePulse * 0.82f;

    // Deep/back particles are intentionally quiet; black space is part of the
    // composition and is what separates this from a noisy particle ball.
    alpha *= mix(0.58f, 1.0f, foreground) * 1.12f;

    float sizePx = referenceSize * u.referenceScale;
    sizePx *= mix(0.82f, 1.18f, foreground);
    sizePx *= 1.0f + sparklePulse * 0.28f;
    sizePx = clamp(sizePx, 0.82f, 12.0f * u.referenceScale);

    float2 local = iumrahSphereQuadCornerV4(vertexID);
    float2 centered = local - 0.5f;
    float2 glyphSize = float2(sizePx * 0.66f, sizePx);
    float2 vertexPixel = pixelCenter + centered * glyphSize;
    float2 ndc = float2(
        vertexPixel.x / u.viewportSize.x * 2.0f - 1.0f,
        1.0f - vertexPixel.y / u.viewportSize.y * 2.0f
    );

    IumrahDataSphereParticleOutV4 out;
    out.position = float4(ndc, 0.0f, 1.0f);
    out.localUV = local;
    out.color = float4(color, saturate(alpha));
    out.digit = digit;
    out.glow = saturate(0.14f + foreground * 0.30f + sparklePulse * 0.72f + filament * 0.08f);
    out.sparkle = sparklePulse;
    return out;
}

fragment float4 iumrahDataSphereParticleFragmentV4(
    IumrahDataSphereParticleOutV4 in [[stage_in]],
    texture2d<float> digitAtlas [[texture(0)]],
    sampler digitSampler [[sampler(0)]]) {
    float digit = clamp(round(in.digit), 0.0f, 9.0f);
    float2 atlasUV = float2((digit + in.localUV.x) * 0.1f, in.localUV.y);
    float glyph = digitAtlas.sample(digitSampler, atlasUV).a;

    float2 centered = in.localUV - 0.5f;
    float r2 = dot(centered, centered);
    float halo = exp(-r2 * 13.5f) * 0.16f * in.glow;

    // Mipmapped SF monospaced digits naturally collapse into luminous points
    // at micro scale, while the larger foreground particles reveal 0–9.
    float coverage = saturate(glyph * 1.06f + halo);
    float alpha = coverage * in.color.a;
    if (alpha < 0.0035f) {
        discard_fragment();
    }

    float highlight = 0.90f + glyph * 0.36f + halo * 0.24f;
    return float4(in.color.rgb * highlight, alpha);
}


fragment float4 iumrahDataSphereGlintFragmentV4(
    IumrahDataSphereParticleOutV4 in [[stage_in]],
    texture2d<float> digitAtlas [[texture(0)]],
    sampler digitSampler [[sampler(0)]]) {
    if (in.sparkle < 0.010f) {
        discard_fragment();
    }

    float digit = clamp(round(in.digit), 0.0f, 9.0f);
    float2 atlasUV = float2((digit + in.localUV.x) * 0.1f, in.localUV.y);
    float glyph = digitAtlas.sample(digitSampler, atlasUV).a;

    float2 centered = in.localUV - 0.5f;
    float r2 = dot(centered, centered);
    float halo = exp(-r2 * 7.5f);
    float coverage = saturate(glyph * 0.74f + halo * 0.42f);
    float alpha = coverage * in.sparkle * (0.44f + in.color.a * 0.36f);
    if (alpha < 0.003f) {
        discard_fragment();
    }

    float3 luminousBlue = float3(0.025f, 0.32f, 1.00f);
    float3 color = mix(in.color.rgb, luminousBlue, 0.58f);
    return float4(color * 1.20f, alpha);
}
