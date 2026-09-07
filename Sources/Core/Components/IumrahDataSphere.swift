import MetalKit
import SwiftUI
import UIKit

/// Reusable GPU-rendered data sphere for iumrah.
///
/// The component intentionally contains no product copy, labels, identifiers or
/// security-specific UI. Screens own their text and layout so the same native
/// animation can be reused in Security, AI, search and processing states.
struct IumrahDataSphere: View {
    enum MotionState: Equatable {
        case idle
        case thinking
        case processing

        fileprivate var speed: Float {
            switch self {
            case .idle: return 0.82
            case .thinking: return 1.35
            case .processing: return 1.72
            }
        }

        fileprivate var energy: Float {
            switch self {
            case .idle: return 0.92
            case .thinking: return 1.08
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
            intensity: Float(max(0.0, min(intensity, 1.35))),
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

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        view.colorPixelFormat = .bgra8Unorm_srgb
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
            assertionFailure("IumrahDataSphere Metal renderer failed: \(error)")
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
        if reduceMotion { return 15 }
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

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let particlesPipeline: MTLRenderPipelineState
    private let atmospherePipeline: MTLRenderPipelineState
    private let glyphAtlas: MTLTexture
    private let startUptime = ProcessInfo.processInfo.systemUptime

    private var speed: Float = 0.82
    private var energy: Float = 0.92
    private var intensity: Float = 1.0
    private var reduceMotion = false

    init(device: MTLDevice) throws {
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueue
        }
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary() else {
            throw RendererError.defaultLibrary
        }

        self.atmospherePipeline = try Self.makePipeline(
            device: device,
            library: library,
            vertex: "iumrahDataSphereAtmosphereVertex",
            fragment: "iumrahDataSphereAtmosphereFragment",
            pixelFormat: .bgra8Unorm_srgb,
            additive: false
        )

        self.particlesPipeline = try Self.makePipeline(
            device: device,
            library: library,
            vertex: "iumrahDataSphereParticleVertex",
            fragment: "iumrahDataSphereParticleFragment",
            pixelFormat: .bgra8Unorm_srgb,
            additive: true
        )

        self.glyphAtlas = try Self.makeDigitAtlas(device: device)
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
            let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        let width = Float(max(view.drawableSize.width, 1))
        let height = Float(max(view.drawableSize.height, 1))
        let shortest = min(width, height)

        let elapsed = Float(ProcessInfo.processInfo.systemUptime - startUptime)
        let resolvedTime = reduceMotion ? 1.85 : elapsed

        var uniforms = Uniforms(
            viewportSize: SIMD2(width, height),
            center: SIMD2(width * 0.50, height * 0.51),
            time: resolvedTime,
            intensity: intensity,
            speed: speed,
            radius: shortest * 0.465,
            energy: energy,
            motionAmount: reduceMotion ? 0.0 : 1.0
        )

        encoder.label = "iumrah.data-sphere.encoder"

        // A very restrained cyan/blue atmosphere gives the particle cloud a
        // spherical silhouette and depth without turning the component into a
        // pre-rendered image or a fake UI material.
        encoder.setRenderPipelineState(atmospherePipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.setRenderPipelineState(particlesPipeline)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(glyphAtlas, index: 0)

        let pixelArea = width * height
        let adaptiveCount = Int(pixelArea / 36.0)
        let particleCount = min(22_000, max(9_000, adaptiveCount))

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

    private static func makeDigitAtlas(device: MTLDevice) throws -> MTLTexture {
        let cell = CGSize(width: 128, height: 128)
        let size = CGSize(width: cell.width * 10.0, height: cell.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let font = UIFont.monospacedDigitSystemFont(ofSize: 76, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]

            for digit in 0..<10 {
                let originX = CGFloat(digit) * cell.width
                let text = String(digit) as NSString
                let measured = text.size(withAttributes: attributes)
                let rect = CGRect(
                    x: originX,
                    y: (cell.height - measured.height) * 0.5 - 2,
                    width: cell.width,
                    height: measured.height + 8
                )
                text.draw(in: rect, withAttributes: attributes)
            }
        }

        guard let cgImage = image.cgImage else {
            throw RendererError.glyphAtlas
        }

        let loader = MTKTextureLoader(device: device)
        return try loader.newTexture(
            cgImage: cgImage,
            options: [
                .SRGB: false,
                .generateMipmaps: true,
                .origin: MTKTextureLoader.Origin.topLeft.rawValue,
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
            ]
        )
    }

    private enum RendererError: LocalizedError {
        case commandQueue
        case defaultLibrary
        case missingFunction(String)
        case glyphAtlas

        var errorDescription: String? {
            switch self {
            case .commandQueue:
                return "Metal command queue is unavailable."
            case .defaultLibrary:
                return "The app Metal shader library is unavailable."
            case .missingFunction(let name):
                return "Metal function \(name) is missing."
            case .glyphAtlas:
                return "Digit glyph atlas could not be generated."
            }
        }
    }
}
