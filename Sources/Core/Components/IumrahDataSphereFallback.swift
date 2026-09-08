import SpriteKit
import SwiftUI
import UIKit

/// Deterministic native fallback/base layer for `IumrahDataSphere`.
///
/// Metal remains the high-density renderer, but this SpriteKit layer guarantees
/// that the reusable sphere never collapses to an empty black card if a Metal
/// pipeline or bundled shader fails on a particular TestFlight build/device.
/// SpriteKit is Apple-native and GPU composited. It uses the same geometry,
/// slow coherent rotation and blue/cyan depth model as the Metal renderer.
struct IumrahDataSphereFallbackView: UIViewRepresentable {
    var state: IumrahDataSphere.MotionState
    var intensity: Float
    var reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        view.preferredFramesPerSecond = reduceMotion ? 24 : min(UIScreen.main.maximumFramesPerSecond, 60)

        let scene = IumrahDataSphereFallbackScene(size: CGSize(width: 292, height: 292))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        scene.updateConfiguration(
            speed: state.fallbackSpeed,
            energy: state.fallbackEnergy,
            intensity: intensity,
            reduceMotion: reduceMotion
        )
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        uiView.preferredFramesPerSecond = reduceMotion ? 24 : min(UIScreen.main.maximumFramesPerSecond, 60)
        context.coordinator.scene?.updateConfiguration(
            speed: state.fallbackSpeed,
            energy: state.fallbackEnergy,
            intensity: intensity,
            reduceMotion: reduceMotion
        )
    }

    static func dismantleUIView(_ uiView: SKView, coordinator: Coordinator) {
        uiView.presentScene(nil)
        coordinator.scene = nil
    }

    final class Coordinator {
        var scene: IumrahDataSphereFallbackScene?
    }
}

private extension IumrahDataSphere.MotionState {
    var fallbackSpeed: Float {
        switch self {
        case .idle: return 1.00
        case .thinking: return 1.48
        case .processing: return 1.92
        }
    }

    var fallbackEnergy: Float {
        switch self {
        case .idle: return 1.00
        case .thinking: return 1.10
        case .processing: return 1.18
        }
    }
}

final class IumrahDataSphereFallbackScene: SKScene {
    private static let particleCount = 3_600
    private static let centerInset: CGFloat = 37.6 / 512.0
    private static let centerY: CGFloat = 254.6 / 512.0
    private static let radiusScale: CGFloat = 279.5 / 512.0

    private final class Particle {
        let rest: SIMD3<Float>
        let particleClass: Float
        let baseSize: CGFloat
        let luminance: CGFloat
        let phase: Float
        let colourSeed: CGFloat
        let sparkle: CGFloat
        let opacitySeed: CGFloat
        let node: SKSpriteNode

        init(
            rest: SIMD3<Float>,
            particleClass: Float,
            baseSize: CGFloat,
            luminance: CGFloat,
            phase: Float,
            colourSeed: CGFloat,
            sparkle: CGFloat,
            opacitySeed: CGFloat,
            node: SKSpriteNode
        ) {
            self.rest = rest
            self.particleClass = particleClass
            self.baseSize = baseSize
            self.luminance = luminance
            self.phase = phase
            self.colourSeed = colourSeed
            self.sparkle = sparkle
            self.opacitySeed = opacitySeed
            self.node = node
        }
    }

    private var particles: [Particle] = []
    private var atmosphereNode: SKSpriteNode?
    private var startTime: TimeInterval?

    private var motionSpeed: Float = 1
    private var motionEnergy: Float = 1
    private var sphereIntensity: Float = 1
    private var reduceMotion = false

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0, y: 0)
        buildScene()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildScene()
    }

    func updateConfiguration(speed: Float, energy: Float, intensity: Float, reduceMotion: Bool) {
        motionSpeed = speed
        motionEnergy = energy
        sphereIntensity = max(0, min(intensity, 1.25))
        self.reduceMotion = reduceMotion
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutAtmosphere()
    }

    override func update(_ currentTime: TimeInterval) {
        if startTime == nil { startTime = currentTime }
        let elapsed = Float(currentTime - (startTime ?? currentTime))
        let t: Float = reduceMotion ? 1.35 : elapsed * motionSpeed

        let side = min(size.width, size.height)
        guard side > 2 else { return }

        let radius = side * Self.radiusScale
        let centerTop = CGPoint(
            x: size.width - side * Self.centerInset,
            y: (size.height - side) * 0.5 + side * Self.centerY
        )
        let center = CGPoint(x: centerTop.x, y: size.height - centerTop.y)

        let rotY = -t * 0.070
        let rotX =  t * 0.235
        let rotZ = sin(t * 0.075) * 0.014

        for particle in particles {
            var p = particle.rest
            if !reduceMotion {
                p = rotateY(p, angle: rotY)
                p = rotateX(p, angle: rotX)
                p = rotateZ(p, angle: rotZ)

                let radial = max(simdLength(p), 0.0001)
                let normal = p / radial
                let warpA = sin(normal.y * 17 + normal.z * 8 + t * 0.24 + particle.phase)
                let warpB = sin(normal.x * 12 - normal.z * 13 - t * 0.17 + Float(particle.colourSeed) * 6.2831853)
                let warp = (warpA + warpB) * 0.0018 * motionEnergy
                p *= (1 + warp)
            }

            let perspective = 1 + CGFloat(p.z) * 0.052
            let projectedX = CGFloat(p.x) * perspective
            let projectedY = CGFloat(p.y) * perspective

            let px = center.x + projectedX * radius
            let py = center.y - projectedY * radius
            let node = particle.node
            node.position = CGPoint(x: px, y: py)
            node.zPosition = CGFloat(p.z) * 20

            let depth = clamp01((CGFloat(p.z) + 1.05) / 2.10)
            let foreground = smoothstep(0.20, 0.98, depth)
            let shell: CGFloat = particle.particleClass < 0.5 ? 1 : 0
            let stray: CGFloat = particle.particleClass > 1.5 ? 1 : 0
            let volume = max(0, 1 - shell - stray)

            let radial = max(simdLength(p), 0.0001)
            let normalZ = CGFloat(p.z / radial)
            let rim = pow(clamp01(1 - abs(normalZ)), 3.2) * shell

            let dx = (projectedX + 0.47) / 0.37
            let dy = (projectedY - 0.015) / 0.54
            let coreField = exp(-(dx * dx + dy * dy) * 1.45)
            let rightField = smoothstep(-0.15, 0.90, projectedX)

            let fieldA = 0.5 + 0.5 * CGFloat(sin(p.y * 15 + p.x * 5 + p.z * 3 + t * 0.12 + particle.phase))
            let fieldB = 0.5 + 0.5 * CGFloat(sin(p.x * 11 - p.z * 8 - t * 0.09 + particle.phase * 0.7))
            let filament = max(pow(fieldA, 12), pow(fieldB, 14))

            var blueAmount = clamp01(0.08 + foreground * 0.74 + rightField * 0.16 + particle.colourSeed * 0.05)
            blueAmount = clamp01(blueAmount)
            let cyanAmount = clamp01(coreField * (volume * 0.72 + shell * 0.20) * (0.98 - foreground * 0.38) + filament * coreField * 0.14)

            let deepBlue = UIColor(red: 0.005, green: 0.020, blue: 0.17, alpha: 1)
            let cobalt = UIColor(red: 0.005, green: 0.16, blue: 0.88, alpha: 1)
            let electricBlue = UIColor(red: 0.01, green: 0.34, blue: 1.00, alpha: 1)
            let cyan = UIColor(red: 0.00, green: 0.73, blue: 0.78, alpha: 1)

            var color = mixColor(deepBlue, cobalt, blueAmount)
            color = mixColor(color, electricBlue, clamp01(rightField * foreground * 0.30))
            color = mixColor(color, cyan, cyanAmount)
            node.color = color
            node.colorBlendFactor = 1

            let twinkle: CGFloat
            if reduceMotion {
                twinkle = 1
            } else {
                twinkle = 0.88 + 0.12 * CGFloat(sin(t * Float(0.72 + particle.colourSeed * 0.78) + particle.phase))
            }
            let sparkleWave = 0.5 + 0.5 * CGFloat(sin(t * Float(0.92 + particle.colourSeed * 0.58) + particle.phase * 1.9))
            let sparklePulse = particle.sparkle * pow(max(0, sparkleWave), 8)

            var alpha = mix(0.14, 0.82, pow(foreground, 1.46))
            alpha *= mix(0.78, 1.0, shell)
            alpha *= mix(0.90, 1.0, volume)
            alpha *= particle.opacitySeed * particle.luminance
            alpha *= (0.78 + filament * 0.60)
            alpha += rim * 0.14
            alpha *= twinkle
            alpha *= CGFloat(sphereIntensity)
            alpha *= mix(1.0, 0.30, stray)
            alpha *= 1 + sparklePulse * 0.70
            alpha *= mix(0.66, 1.0, foreground)
            alpha *= 0.84 + rightField * foreground * 0.46
            // The SpriteKit layer is intentionally strong enough to stand alone
            // on TestFlight, while still leaving headroom for Metal detail.
            alpha *= 0.90
            node.alpha = min(0.92, max(0.012, alpha))

            var glyphHeight = particle.baseSize * mix(0.82, 1.18, foreground)
            glyphHeight *= 1 + sparklePulse * 0.22
            glyphHeight = min(max(glyphHeight, 0.85), 6.8)
            node.size = CGSize(width: glyphHeight * 0.66, height: glyphHeight)
            node.isHidden = px < -10 || px > size.width + 10 || py < -10 || py > size.height + 10
        }
    }

    private func buildScene() {
        removeAllChildren()
        particles.removeAll(keepingCapacity: true)

        let atmosphere = SKSpriteNode(texture: Self.makeAtmosphereTexture())
        atmosphere.blendMode = .alpha
        atmosphere.alpha = 0.92
        atmosphere.zPosition = -100
        addChild(atmosphere)
        atmosphereNode = atmosphere
        layoutAtmosphere()

        let textures = Self.makeDigitTextures()
        var rng = SplitMix64(seed: 0x49_55_4D_52_41_48_32_36)
        particles.reserveCapacity(Self.particleCount)

        for _ in 0..<Self.particleCount {
            let z = rng.unit() * 2 - 1
            let azimuth = rng.unit() * Float.pi * 2
            let planar = sqrt(max(0, 1 - z * z))
            let direction = SIMD3<Float>(
                planar * cos(azimuth),
                z,
                planar * sin(azimuth)
            )

            let classRoll = rng.unit()
            let particleClass: Float
            let radial: Float
            if classRoll < 0.70 {
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
            let baseSize: CGFloat
            let sparkle: CGFloat
            if sizeRoll < 0.56 {
                baseSize = CGFloat(0.90 + 0.85 * rng.unit())
                sparkle = 0
            } else if sizeRoll < 0.88 {
                baseSize = CGFloat(1.55 + 1.10 * rng.unit())
                sparkle = CGFloat(0.04 * rng.unit())
            } else if sizeRoll < 0.97 {
                baseSize = CGFloat(2.50 + 1.80 * pow(rng.unit(), 0.72))
                sparkle = CGFloat(0.16 + 0.34 * rng.unit())
            } else {
                baseSize = CGFloat(4.15 + 2.25 * rng.unit())
                sparkle = CGFloat(0.70 + 0.30 * rng.unit())
            }

            let luminance = CGFloat(0.58 + 0.56 * pow(rng.unit(), 0.72))
            let phase = rng.unit() * Float.pi * 2
            let digit = min(9, Int(rng.unit() * 10))
            let colourSeed = CGFloat(rng.unit())
            let opacitySeed = CGFloat(0.62 + 0.38 * rng.unit())
            let rest = direction * radial

            let node = SKSpriteNode(texture: textures[digit])
            node.colorBlendFactor = 1
            node.blendMode = sparkle > 0.68 ? .add : .alpha
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.alpha = 0
            addChild(node)

            particles.append(
                Particle(
                    rest: rest,
                    particleClass: particleClass,
                    baseSize: baseSize,
                    luminance: luminance,
                    phase: phase,
                    colourSeed: colourSeed,
                    sparkle: sparkle,
                    opacitySeed: opacitySeed,
                    node: node
                )
            )
        }
    }

    private func layoutAtmosphere() {
        guard let atmosphereNode else { return }
        let side = min(size.width, size.height)
        let radius = side * Self.radiusScale
        let centerTop = CGPoint(
            x: size.width - side * Self.centerInset,
            y: (size.height - side) * 0.5 + side * Self.centerY
        )
        atmosphereNode.position = CGPoint(x: centerTop.x, y: size.height - centerTop.y)
        atmosphereNode.size = CGSize(width: radius * 2.16, height: radius * 2.16)
    }

    private static func makeDigitTextures() -> [SKTexture] {
        (0...9).map { digit in
            let canvas = CGSize(width: 28, height: 40)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
            let image = renderer.image { context in
                context.cgContext.clear(CGRect(origin: .zero, size: canvas))
                let font = UIFont.monospacedDigitSystemFont(ofSize: 32, weight: .medium)
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                NSString(string: String(digit)).draw(
                    in: CGRect(x: 0, y: 1, width: canvas.width, height: canvas.height),
                    withAttributes: attrs
                )
            }
            let texture = SKTexture(image: image)
            texture.filteringMode = .linear
            return texture
        }
    }

    private static func makeAtmosphereTexture() -> SKTexture {
        let canvas = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        let image = renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: canvas)
            cg.clear(bounds)
            cg.saveGState()
            cg.addEllipse(in: bounds.insetBy(dx: 8, dy: 8))
            cg.clip()

            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.002, green: 0.018, blue: 0.13, alpha: 0.10).cgColor,
                    UIColor(red: 0.003, green: 0.075, blue: 0.42, alpha: 0.16).cgColor,
                    UIColor(red: 0.005, green: 0.20, blue: 0.78, alpha: 0.055).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 0.52, 0.84, 1.0]
            ) {
                cg.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: 280, y: 256),
                    startRadius: 8,
                    endCenter: CGPoint(x: 280, y: 256),
                    endRadius: 252,
                    options: []
                )
            }

            if let core = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.00, green: 0.70, blue: 0.74, alpha: 0.22).cgColor,
                    UIColor(red: 0.00, green: 0.33, blue: 0.68, alpha: 0.08).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 0.55, 1.0]
            ) {
                cg.drawRadialGradient(
                    core,
                    startCenter: CGPoint(x: 145, y: 258),
                    startRadius: 0,
                    endCenter: CGPoint(x: 145, y: 258),
                    endRadius: 142,
                    options: []
                )
            }
            cg.restoreGState()
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private func rotateX(_ p: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3<Float>(p.x, p.y * c - p.z * s, p.y * s + p.z * c)
    }

    private func rotateY(_ p: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3<Float>(p.x * c + p.z * s, p.y, -p.x * s + p.z * c)
    }

    private func rotateZ(_ p: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let c = cos(angle), s = sin(angle)
        return SIMD3<Float>(p.x * c - p.y * s, p.x * s + p.y * c, p.z)
    }

    private func simdLength(_ p: SIMD3<Float>) -> Float {
        sqrt(p.x * p.x + p.y * p.y + p.z * p.z)
    }

    private func clamp01(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = clamp01((x - edge0) / max(edge1 - edge0, 0.0001))
        return t * t * (3 - 2 * t)
    }

    private func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * clamp01(t)
    }

    private func mixColor(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let k = clamp01(t)
        return UIColor(
            red: ar + (br - ar) * k,
            green: ag + (bg - ag) * k,
            blue: ab + (bb - ab) * k,
            alpha: aa + (ba - aa) * k
        )
    }

    private struct SplitMix64 {
        var state: UInt64

        init(seed: UInt64) { state = seed }

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
}
