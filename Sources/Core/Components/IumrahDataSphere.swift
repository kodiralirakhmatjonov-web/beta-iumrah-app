import MetalKit
import SwiftUI
import UIKit

/// Reusable native GPU-rendered data sphere.
///
/// This component contains only rendering. Product copy, identifiers and
/// screen-specific layout must stay outside so the renderer can be reused.
struct IumrahDataSphere: View {
    enum MotionState: Equatable {
        case idle
        case thinking
        case processing

        fileprivate var speed: Float {
            switch self {
            case .idle: return 0.72
            case .thinking: return 1.18
            case .processing: return 1.58
            }
        }

        fileprivate var energy: Float {
            switch self {
            case .idle: return 1.00
            case .thinking: return 1.13
            case .processing: return 1.25
            }
        }
    }

    var state: MotionState = .idle
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        IumrahDataSphereMetalView(
            state: state,
            intensity: Float(max(0.0, min(intensity, 1.45))),
            reduceMotion: reduceMotion
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct IumrahDataSphereMetalView: UIViewRepresentable {
    var state: IumrahDataSphere.MotionState
    var intensity: Float
    var reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            let unavailable = MTKView(frame: .zero)
            unavailable.isOpaque = false
            unavailable.backgroundColor = .clear
            return unavailable
        }

        let view = MTKView(frame: .zero, device: device)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.layer.isOpaque = false
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .invalid
        view.sampleCount = 1
        view.framebufferOnly = true
        view.autoResizeDrawable = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = preferredFrameRate(reduceMotion: reduceMotion)

        do {
            let renderer = try IumrahDataSphereRenderer(device: device)
            renderer.update(
                speed: state.speed,
                energy: state.energy,
                intensity: intensity,
                reduceMotion: reduceMotion
            )
            view.delegate = renderer
            context.coordinator.renderer = renderer
        } catch {
            // Keep the component transparent rather than crashing a production
            // screen. The renderer has an embedded Metal-library fallback, so
            // reaching this branch means Metal itself is unavailable/broken.
            assertionFailure("IumrahDataSphere renderer failed: \(error)")
        }

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.preferredFramesPerSecond = preferredFrameRate(reduceMotion: reduceMotion)
        context.coordinator.renderer?.update(
            speed: state.speed,
            energy: state.energy,
            intensity: intensity,
            reduceMotion: reduceMotion
        )
    }

    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        uiView.delegate = nil
        coordinator.renderer = nil
    }

    private func preferredFrameRate(reduceMotion: Bool) -> Int {
        if reduceMotion { return 20 }
        return min(UIScreen.main.maximumFramesPerSecond, 120)
    }

    final class Coordinator {
        var renderer: IumrahDataSphereRenderer?
    }
}

private final class IumrahDataSphereRenderer: NSObject, MTKViewDelegate {
    private struct Uniforms {
        var viewportSize: SIMD2<Float>
        var center: SIMD2<Float>
        var time: Float
        var intensity: Float
        var speed: Float
        var radius: Float
        var energy: Float
        var motionAmount: Float
    }

    private let commandQueue: MTLCommandQueue
    private let particlesPipeline: MTLRenderPipelineState
    private let atmospherePipeline: MTLRenderPipelineState
    private let startUptime = ProcessInfo.processInfo.systemUptime

    private var speed: Float = 0.72
    private var energy: Float = 1.0
    private var intensity: Float = 1.0
    private var reduceMotion = false

    init(device: MTLDevice) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueue
        }
        self.commandQueue = commandQueue

        // First use the app's precompiled .metallib. If Xcode/project generation
        // ever omits the .metal file, compile the exact same native shader from
        // the embedded source. This avoids the silent empty-card failure.
        let library = try Self.resolveLibrary(device: device)

        self.atmospherePipeline = try Self.makePipeline(
            device: device,
            library: library,
            vertex: "iumrahDataSphereAtmosphereVertex",
            fragment: "iumrahDataSphereAtmosphereFragment",
            pixelFormat: .bgra8Unorm,
            additive: false
        )

        self.particlesPipeline = try Self.makePipeline(
            device: device,
            library: library,
            vertex: "iumrahDataSphereParticleVertex",
            fragment: "iumrahDataSphereParticleFragment",
            pixelFormat: .bgra8Unorm,
            additive: true
        )

        super.init()
    }

    func update(speed: Float, energy: Float, intensity: Float, reduceMotion: Bool) {
        self.speed = speed
        self.energy = energy
        self.intensity = intensity
        self.reduceMotion = reduceMotion
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            view.drawableSize.width > 1,
            view.drawableSize.height > 1,
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        let width = Float(view.drawableSize.width)
        let height = Float(view.drawableSize.height)
        let shortest = min(width, height)
        let elapsed = Float(ProcessInfo.processInfo.systemUptime - startUptime)
        let resolvedTime = reduceMotion ? 2.0 : elapsed

        var uniforms = Uniforms(
            viewportSize: SIMD2(width, height),
            center: SIMD2(width * 0.50, height * 0.50),
            time: resolvedTime,
            intensity: intensity,
            speed: speed,
            radius: shortest * 0.455,
            energy: energy,
            motionAmount: reduceMotion ? 0.0 : 1.0
        )

        encoder.label = "iumrah.data-sphere.encoder"

        encoder.setRenderPipelineState(atmospherePipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.setRenderPipelineState(particlesPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        // drawableSize is physical pixels. The first version sized glyphs as if
        // these were points, making them sub-pixel on Retina iPhones. Keep a
        // dense cloud, but give foreground digits enough physical pixels to be
        // visible and recognisable on a real device.
        let pixelArea = width * height
        let adaptiveCount = Int(pixelArea / 31.0)
        let particleCount = min(24_000, max(11_500, adaptiveCount))

        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: particleCount
        )

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static func resolveLibrary(device: MTLDevice) throws -> MTLLibrary {
        if let library = device.makeDefaultLibrary(),
           library.makeFunction(name: "iumrahDataSphereAtmosphereVertex") != nil,
           library.makeFunction(name: "iumrahDataSphereAtmosphereFragment") != nil,
           library.makeFunction(name: "iumrahDataSphereParticleVertex") != nil,
           library.makeFunction(name: "iumrahDataSphereParticleFragment") != nil {
            return library
        }

        do {
            let options = MTLCompileOptions()
            options.fastMathEnabled = true
            return try device.makeLibrary(source: embeddedMetalSource, options: options)
        } catch {
            throw RendererError.shaderCompilation(error.localizedDescription)
        }
    }

    private static func makePipeline(
        device: MTLDevice,
        library: MTLLibrary,
        vertex: String,
        fragment: String,
        pixelFormat: MTLPixelFormat,
        additive: Bool
    ) throws -> MTLRenderPipelineState {
        guard let vertexFunction = library.makeFunction(name: vertex) else {
            throw RendererError.missingFunction(vertex)
        }
        guard let fragmentFunction = library.makeFunction(name: fragment) else {
            throw RendererError.missingFunction(fragment)
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "iumrah.data-sphere.\(fragment)"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        if let attachment = descriptor.colorAttachments[0] {
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add

            if additive {
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .one
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            } else {
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private enum RendererError: LocalizedError {
        case commandQueue
        case missingFunction(String)
        case shaderCompilation(String)

        var errorDescription: String? {
            switch self {
            case .commandQueue:
                return "Metal command queue is unavailable."
            case .missingFunction(let name):
                return "Metal function \(name) is missing."
            case .shaderCompilation(let message):
                return "Metal shader compilation failed: \(message)"
            }
        }
    }

    // Runtime fallback for the precompiled .metal file. Keeping this source in
    // the renderer means the component cannot silently disappear when project
    // generation fails to attach the shader to the target.
    private static let embeddedMetalSource = #"""
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
"""#
}
