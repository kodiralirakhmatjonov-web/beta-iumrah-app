import MetalKit
import SwiftUI
import UIKit

/// Reusable native GPU-rendered iumrah data sphere.
///
/// The component intentionally contains no product copy, IDs, buttons or
/// screen-specific layout. Screens decide where the sphere lives and what text
/// sits beside it. Rendering is performed by Metal; SwiftUI is only the host.
struct IumrahDataSphere: View {
    enum MotionState: Equatable {
        case idle
        case thinking
        case processing

        fileprivate var speed: Float {
            switch self {
            case .idle: return 1.00
            case .thinking: return 1.55
            case .processing: return 2.05
            }
        }

        fileprivate var energy: Float {
            switch self {
            case .idle: return 1.00
            case .thinking: return 1.10
            case .processing: return 1.18
            }
        }
    }

    var state: MotionState = .idle
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        IumrahDataSphereMetalView(
            state: state,
            intensity: Float(max(0.0, min(intensity, 1.25))),
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

        let view = IumrahDataSphereMTKView(frame: .zero, device: device)
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
        if reduceMotion { return 24 }
        return min(UIScreen.main.maximumFramesPerSecond, 120)
    }

    final class Coordinator {
        var renderer: IumrahDataSphereRenderer?
    }
}

private final class IumrahDataSphereMTKView: MTKView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        isPaused = window == nil
    }
}

private final class IumrahDataSphereRenderer: NSObject, MTKViewDelegate {
    /// Geometry is calibrated against the supplied 512×512 reference clip.
    /// Reference circle fit: center ≈ (474.4, 254.6), radius ≈ 279.5 px.
    private static let referenceSide: Float = 512.0
    private static let referenceCenterInset: Float = 37.6 / 512.0
    private static let referenceCenterY: Float = 254.6 / 512.0
    private static let referenceRadius: Float = 279.5 / 512.0
    private static let referenceRadiusPixels: Float = 279.5
    private static let particleCount = 18_400

    private struct Uniforms {
        var viewportSize: SIMD2<Float>
        var center: SIMD2<Float>
        var time: Float
        var intensity: Float
        var speed: Float
        var radius: Float
        var energy: Float
        var motionAmount: Float
        var referenceScale: Float
        var padding: Float
    }

    /// 48-byte layout mirrored exactly in IumrahDataSphereShaders.metal.
    private struct ParticleSeed {
        /// xyz = rest position, w = class (0 shell / 1 volume / 2 stray)
        var positionAndClass: SIMD4<Float>
        /// x = reference-pixel glyph height, y = luminance, z = phase, w = digit
        var attributes: SIMD4<Float>
        /// x = filament phase, y = colour seed, z = sparkle, w = opacity seed
        var variation: SIMD4<Float>
    }

    private let commandQueue: MTLCommandQueue
    private let particlesPipeline: MTLRenderPipelineState
    private let glintsPipeline: MTLRenderPipelineState
    private let atmospherePipeline: MTLRenderPipelineState
    private let particleBuffer: MTLBuffer
    private let digitAtlas: MTLTexture
    private let digitSampler: MTLSamplerState
    private let startUptime = ProcessInfo.processInfo.systemUptime

    private var speed: Float = 1.0
    private var energy: Float = 1.0
    private var intensity: Float = 1.0
    private var reduceMotion = false

    init(device: MTLDevice) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueue
        }
        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.defaultLibrary
        }

        self.commandQueue = commandQueue
        self.atmospherePipeline = try Self.makePipeline(
            device: device,
            library: library,
            vertex: "iumrahDataSphereAtmosphereVertexV4",
            fragment: "iumrahDataSphereAtmosphereFragmentV4",
            blending: .normal
        )
        self.particlesPipeline = try Self.makePipeline(
            device: device,
            library: library,
            vertex: "iumrahDataSphereParticleVertexV4",
            fragment: "iumrahDataSphereParticleFragmentV4",
            blending: .normal
        )
        self.glintsPipeline = try Self.makePipeline(
            device: device,
            library: library,
            vertex: "iumrahDataSphereParticleVertexV4",
            fragment: "iumrahDataSphereGlintFragmentV4",
            blending: .additive
        )

        let seeds = Self.makeParticleSeeds(count: Self.particleCount)
        let buffer: MTLBuffer? = seeds.withUnsafeBufferPointer { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }
            return device.makeBuffer(
                bytes: baseAddress,
                length: rawBuffer.count * MemoryLayout<ParticleSeed>.stride,
                options: .storageModeShared
            )
        }
        guard let buffer else {
            throw RendererError.particleBuffer
        }
        buffer.label = "iumrah.data-sphere.particles"
        self.particleBuffer = buffer

        self.digitAtlas = try Self.makeDigitAtlas(device: device)
        self.digitAtlas.label = "iumrah.data-sphere.digit-atlas"

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.normalizedCoordinates = true
        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw RendererError.sampler
        }
        self.digitSampler = sampler

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
        let side = min(width, height)
        let elapsed = Float(ProcessInfo.processInfo.systemUptime - startUptime)
        let resolvedTime = reduceMotion ? 1.35 : elapsed

        // The reference animation is composed as a mostly off-screen sphere:
        // the centre sits close to the right edge and ~55% of the square side
        // defines the radius. Keeping this geometry inside the renderer means
        // the same component has the same visual character wherever it is used.
        let radius = side * Self.referenceRadius
        let center = SIMD2<Float>(
            width - side * Self.referenceCenterInset,
            (height - side) * 0.5 + side * Self.referenceCenterY
        )

        var uniforms = Uniforms(
            viewportSize: SIMD2(width, height),
            center: center,
            time: resolvedTime,
            intensity: intensity,
            speed: speed,
            radius: radius,
            energy: energy,
            motionAmount: reduceMotion ? 0.0 : 1.0,
            referenceScale: max(0.55, radius / Self.referenceRadiusPixels),
            padding: 0
        )

        encoder.label = "iumrah.data-sphere.encoder.v4"

        encoder.setRenderPipelineState(atmospherePipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.setRenderPipelineState(particlesPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(digitAtlas, index: 0)
        encoder.setFragmentSamplerState(digitSampler, index: 0)
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: Self.particleCount
        )

        // A second, very sparse additive pass is limited to the rare glint
        // particles in the shader. This restores the reference's isolated
        // high-luminance points without making the whole sphere additive.
        encoder.setRenderPipelineState(glintsPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(digitAtlas, index: 0)
        encoder.setFragmentSamplerState(digitSampler, index: 0)
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: Self.particleCount
        )

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private enum BlendMode {
        case normal
        case additive
    }

    private static func makePipeline(
        device: MTLDevice,
        library: MTLLibrary,
        vertex: String,
        fragment: String,
        blending: BlendMode
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
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        if let attachment = descriptor.colorAttachments[0] {
            attachment.isBlendingEnabled = true
            switch blending {
            case .normal:
                attachment.rgbBlendOperation = .add
                attachment.alphaBlendOperation = .add
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            case .additive:
                attachment.rgbBlendOperation = .add
                attachment.alphaBlendOperation = .add
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .one
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw RendererError.pipeline(error.localizedDescription)
        }
    }

    private static func makeDigitAtlas(device: MTLDevice) throws -> MTLTexture {
        let cellWidth: CGFloat = 64
        let cellHeight: CGFloat = 88
        let atlasSize = CGSize(width: cellWidth * 10, height: cellHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: atlasSize, format: format)
        let image = renderer.image { context in
            context.cgContext.clear(CGRect(origin: .zero, size: atlasSize))

            let font = UIFont.monospacedDigitSystemFont(ofSize: 64, weight: .medium)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]

            let y = (cellHeight - font.lineHeight) * 0.5 - 1
            for digit in 0..<10 {
                let rect = CGRect(
                    x: CGFloat(digit) * cellWidth,
                    y: y,
                    width: cellWidth,
                    height: font.lineHeight + 4
                )
                NSString(string: String(digit)).draw(in: rect, withAttributes: attributes)
            }
        }

        guard let cgImage = image.cgImage else {
            throw RendererError.digitAtlas
        }

        let loader = MTKTextureLoader(device: device)
        do {
            return try loader.newTexture(
                cgImage: cgImage,
                options: [
                    .SRGB: false,
                    .generateMipmaps: true,
                    .origin: MTKTextureLoader.Origin.topLeft.rawValue,
                    .textureUsage: MTLTextureUsage.shaderRead.rawValue
                ]
            )
        } catch {
            throw RendererError.texture(error.localizedDescription)
        }
    }

    private static func makeParticleSeeds(count: Int) -> [ParticleSeed] {
        var rng = SplitMix64(seed: 0x49_55_4D_52_41_48_32_36)
        var seeds: [ParticleSeed] = []
        seeds.reserveCapacity(count)

        for _ in 0..<count {
            let z = rng.unit() * 2.0 - 1.0
            let azimuth = rng.unit() * Float.pi * 2.0
            let planar = sqrt(max(0.0, 1.0 - z * z))
            let direction = SIMD3<Float>(
                planar * cos(azimuth),
                z,
                planar * sin(azimuth)
            )

            let classRoll = rng.unit()
            let particleClass: Float
            let radial: Float
            if classRoll < 0.68 {
                particleClass = 0
                radial = 0.925 + 0.075 * pow(rng.unit(), 0.62)
            } else if classRoll < 0.988 {
                particleClass = 1
                radial = 0.16 + 0.76 * pow(rng.unit(), 1.0 / 3.0)
            } else {
                particleClass = 2
                radial = 1.015 + 0.13 * pow(rng.unit(), 1.7)
            }

            let sizeRoll = rng.unit()
            let sizeRefPixels: Float
            let sparkle: Float
            if sizeRoll < 0.58 {
                sizeRefPixels = 0.72 + 0.66 * rng.unit()
                sparkle = 0
            } else if sizeRoll < 0.90 {
                sizeRefPixels = 1.25 + 1.05 * rng.unit()
                sparkle = 0.04 * rng.unit()
            } else if sizeRoll < 0.982 {
                sizeRefPixels = 2.05 + 1.80 * pow(rng.unit(), 0.72)
                sparkle = 0.18 + 0.32 * rng.unit()
            } else {
                sizeRefPixels = 3.65 + 2.55 * rng.unit()
                sparkle = 0.68 + 0.32 * rng.unit()
            }

            let luminance = 0.54 + 0.66 * pow(rng.unit(), 0.72)
            let phase = rng.unit() * Float.pi * 2.0
            let digit = Float(min(9, Int(rng.unit() * 10.0)))
            let filamentPhase = rng.unit() * Float.pi * 2.0
            let colourSeed = rng.unit()
            let opacitySeed = 0.56 + 0.44 * rng.unit()
            let position = direction * radial

            seeds.append(
                ParticleSeed(
                    positionAndClass: SIMD4(position.x, position.y, position.z, particleClass),
                    attributes: SIMD4(sizeRefPixels, luminance, phase, digit),
                    variation: SIMD4(filamentPhase, colourSeed, sparkle, opacitySeed)
                )
            )
        }

        return seeds
    }

    private struct SplitMix64 {
        var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }

        mutating func unit() -> Float {
            let value = next() >> 40
            return Float(value) / Float(1 << 24)
        }
    }

    private enum RendererError: LocalizedError {
        case commandQueue
        case defaultLibrary
        case missingFunction(String)
        case pipeline(String)
        case particleBuffer
        case digitAtlas
        case texture(String)
        case sampler

        var errorDescription: String? {
            switch self {
            case .commandQueue:
                return "Metal command queue is unavailable."
            case .defaultLibrary:
                return "The app Metal library is unavailable."
            case .missingFunction(let name):
                return "Missing Metal shader function: \(name)."
            case .pipeline(let message):
                return "Metal pipeline failed: \(message)"
            case .particleBuffer:
                return "Could not allocate the data-sphere particle buffer."
            case .digitAtlas:
                return "Could not create the digit atlas image."
            case .texture(let message):
                return "Could not create the digit atlas texture: \(message)"
            case .sampler:
                return "Could not create the digit atlas sampler."
            }
        }
    }
}
