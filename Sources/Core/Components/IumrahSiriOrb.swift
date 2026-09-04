import SwiftUI

/// Reusable native iumrah Siri-style fluid orb.
///
/// The visual is intentionally built from broad translucent sheets that travel
/// through the whole sphere, change front/back order, twist, pinch and relax.
/// Nothing grows radially from the centre, which avoids the flower/petal look.
/// When `audioLevel` is supplied the same geometry becomes voice-reactive.
struct IumrahSiriOrb: View {
    struct Palette {
        let violet: Color
        let indigo: Color
        let cyan: Color
        let aqua: Color
        let magenta: Color
        let deep: Color

        /// iumrah voice palette — blue and violet are dominant; orange is the
        /// only warm accent. The cyan values are deliberately blue-leaning.
        static let advisor = Palette(
            violet: Color(red: 0.47, green: 0.17, blue: 1.00),
            indigo: Color(red: 0.12, green: 0.23, blue: 0.98),
            cyan: Color(red: 0.02, green: 0.63, blue: 1.00),
            aqua: Color(red: 0.08, green: 0.40, blue: 1.00),
            magenta: Color(red: 1.00, green: 0.34, blue: 0.055),
            deep: Color(red: 0.004, green: 0.006, blue: 0.022)
        )
    }

    var isActive: Bool = true
    var intensity: Double = 1.0
    var showsCoreHighlight: Bool = true

    /// Normalized real playback energy (0...1). Passing a value makes the orb
    /// react to the actual AVAudioPlayer metering used by Umrah Flow.
    var audioLevel: Double? = nil

    var palette: Palette = .advisor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let phase = resolvedPhase(seconds)
                let energy = resolvedAudioEnergy
                let reactive = audioLevel != nil

                // Spoken syllables visibly move the whole object, while the
                // internal sheets receive an even stronger deformation below.
                let idleScale = 0.992 + 0.008 * sin(phase * .pi * 2.0)
                let voiceScale = 0.958
                    + 0.012 * sin(phase * .pi * 4.0)
                    + 0.155 * energy
                let orbScale = reactive ? voiceScale : idleScale

                Canvas(rendersAsynchronously: true) { context, size in
                    drawOrb(
                        context: &context,
                        size: size,
                        phase: phase,
                        side: side,
                        audioEnergy: energy
                    )
                }
                .frame(width: side, height: side)
                .overlay {
                    rim(phase: phase, side: side, energy: energy, reactive: reactive)
                }
                .scaleEffect(orbScale)
                .animation(.linear(duration: 0.055), value: energy)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func rim(phase: Double, side: CGFloat, energy: Double, reactive: Bool) -> some View {
        Circle()
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: palette.indigo.opacity(0.92), location: 0.00),
                        .init(color: palette.cyan.opacity(0.88), location: 0.17),
                        .init(color: palette.violet.opacity(0.96), location: 0.40),
                        .init(color: palette.magenta.opacity(0.90), location: 0.62),
                        .init(color: palette.violet.opacity(0.84), location: 0.78),
                        .init(color: palette.indigo.opacity(0.92), location: 1.00)
                    ]),
                    center: .center,
                    startAngle: .degrees(phase * 86.0),
                    endAngle: .degrees(phase * 86.0 + 360.0)
                ),
                lineWidth: max(0.9, side * (0.0085 + CGFloat(energy) * 0.012))
            )
            .padding(side * 0.038)
            .blur(radius: side * (0.008 + CGFloat(energy) * 0.009))
            .blendMode(.screen)
            .opacity(
                resolvedIntensity
                    * (reactive ? (0.56 + energy * 0.70) : 0.68)
            )
            .allowsHitTesting(false)
    }

    private var resolvedIntensity: Double {
        max(0.0, min(intensity, 1.35))
    }

    private var resolvedAudioEnergy: Double {
        guard let audioLevel else { return 0 }
        let clamped = max(0.0, min(audioLevel, 1.0))
        // Stronger perceptual expansion than a conventional level meter. This
        // makes normal spoken syllables readable at the 100–130pt widget size.
        return min(1.0, pow(clamped, 0.58) * 1.08)
    }

    private var frameInterval: TimeInterval {
        if reduceMotion || !isActive { return 1.0 / 12.0 }
        return 1.0 / 60.0
    }

    private func resolvedPhase(_ seconds: TimeInterval) -> Double {
        guard isActive, !reduceMotion else { return 0.19 }
        // The supplied Siri reference runs through a slow ~9 second morph.
        return seconds.truncatingRemainder(dividingBy: 9.05) / 9.05
    }

    private struct SheetSpec {
        let color: Color
        let angle: Double
        let speed: Double
        let phaseOffset: Double
        let length: CGFloat
        let width: CGFloat
        let bend: CGFloat
        let secondaryBend: CGFloat
        let pinchDepth: CGFloat
        let pinchTravel: CGFloat
        let edgeBias: CGFloat
        let zOffset: Double
    }

    private struct SheetGeometry {
        let body: Path
        let brightEdge: Path
        let softEdge: Path
        let fold: Path
        let gradientStart: CGPoint
        let gradientEnd: CGPoint
        let depth: Double
    }

    private func drawOrb(
        context: inout GraphicsContext,
        size: CGSize,
        phase: Double,
        side: CGFloat,
        audioEnergy: Double
    ) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let reactive = audioLevel != nil
        let energy = CGFloat(audioEnergy)
        let gain = reactive ? (0.88 + audioEnergy * 0.82) : 1.0
        let deformation = reactive ? (0.92 + energy * 0.80) : 1.0
        let widthBoost = reactive ? (0.96 + energy * 0.47) : 1.0
        let radius = side * 0.458
        let circleRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let circle = Path(ellipseIn: circleRect)
        let drift = phase * .pi * 2.0

        drawOuterAtmosphere(
            context: &context,
            center: center,
            circleRect: circleRect,
            side: side,
            phase: drift,
            energy: audioEnergy
        )

        context.drawLayer { orb in
            orb.clip(to: circle)

            // Near-black glass, with just enough blue to preserve depth.
            orb.fill(
                circle,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.018, green: 0.026, blue: 0.070), location: 0.00),
                        .init(color: palette.deep, location: 0.56),
                        .init(color: .black, location: 1.00)
                    ]),
                    center: CGPoint(x: center.x - side * 0.10, y: center.y - side * 0.12),
                    startRadius: 0,
                    endRadius: radius
                )
            )

            drawBackgroundPools(
                context: &orb,
                center: center,
                side: side,
                phase: drift,
                energy: audioEnergy
            )

            let specs = sheetSpecs(side: side)
            var sheets: [(SheetSpec, SheetGeometry)] = []
            sheets.reserveCapacity(specs.count)

            for (index, spec) in specs.enumerated() {
                let geometry = fluidSheetGeometry(
                    spec: spec,
                    index: index,
                    center: center,
                    side: side,
                    phase: drift,
                    deformation: deformation,
                    widthBoost: widthBoost
                )
                sheets.append((spec, geometry))
            }

            // Changing z-order is essential: the reference does not look like
            // fixed petals. Sheets periodically pass in front of each other.
            sheets.sort { $0.1.depth < $1.1.depth }

            for (spec, geometry) in sheets {
                drawSheet(
                    context: &orb,
                    spec: spec,
                    geometry: geometry,
                    side: side,
                    gain: gain,
                    energy: audioEnergy
                )
            }

            if showsCoreHighlight {
                drawMovingNexus(
                    context: &orb,
                    center: center,
                    side: side,
                    phase: drift,
                    energy: audioEnergy,
                    reactive: reactive
                )
            }

            // Very subtle glass reflection — enough to read as a sphere without
            // washing out the translucent sheet geometry.
            orb.drawLayer { reflection in
                reflection.blendMode = .screen
                reflection.addFilter(.blur(radius: side * 0.020))
                reflection.opacity = 0.105 + audioEnergy * 0.025
                reflection.fill(
                    circle,
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.46),
                            Color.white.opacity(0.035),
                            .clear
                        ]),
                        center: CGPoint(x: center.x - side * 0.16, y: center.y - side * 0.19),
                        startRadius: 0,
                        endRadius: side * 0.34
                    )
                )
            }
        }

        context.stroke(
            circle,
            with: .color(Color.white.opacity(0.095 + audioEnergy * 0.04)),
            lineWidth: max(0.45, side * 0.0033)
        )
    }

    private func sheetSpecs(side: CGFloat) -> [SheetSpec] {
        [
            // Dominant cool-blue sheet.
            SheetSpec(
                color: palette.cyan,
                angle: -0.22,
                speed: 0.74,
                phaseOffset: 0.10,
                length: side * 0.405,
                width: side * 0.205,
                bend: side * 0.145,
                secondaryBend: side * 0.045,
                pinchDepth: 0.52,
                pinchTravel: 0.22,
                edgeBias: 0.34,
                zOffset: 0.10
            ),
            // Violet sheet crosses at a different moving location.
            SheetSpec(
                color: palette.violet,
                angle: 1.76,
                speed: 0.61,
                phaseOffset: 1.80,
                length: side * 0.400,
                width: side * 0.190,
                bend: side * 0.132,
                secondaryBend: side * 0.050,
                pinchDepth: 0.48,
                pinchTravel: 0.25,
                edgeBias: -0.30,
                zOffset: 1.85
            ),
            // Deep electric-blue sheet provides the broad rear fold.
            SheetSpec(
                color: palette.indigo,
                angle: 0.88,
                speed: 0.67,
                phaseOffset: 3.55,
                length: side * 0.415,
                width: side * 0.215,
                bend: side * 0.155,
                secondaryBend: side * 0.040,
                pinchDepth: 0.44,
                pinchTravel: 0.19,
                edgeBias: 0.22,
                zOffset: 3.20
            ),
            // Warm orange is intentionally smaller and behaves like the warm
            // ribbon seen in the reference rather than a fourth dominant lobe.
            SheetSpec(
                color: palette.magenta,
                angle: 2.72,
                speed: 0.83,
                phaseOffset: 5.15,
                length: side * 0.370,
                width: side * 0.138,
                bend: side * 0.108,
                secondaryBend: side * 0.038,
                pinchDepth: 0.56,
                pinchTravel: 0.29,
                edgeBias: -0.24,
                zOffset: 4.70
            )
        ]
    }

    private func fluidSheetGeometry(
        spec: SheetSpec,
        index: Int,
        center: CGPoint,
        side: CGFloat,
        phase: Double,
        deformation: CGFloat,
        widthBoost: CGFloat
    ) -> SheetGeometry {
        let localPhase = phase * spec.speed + spec.phaseOffset
        let angle = spec.angle
            + 0.34 * sin(localPhase * 0.72 + Double(index) * 0.40)
            + 0.09 * sin(localPhase * 1.47 + Double(index))

        let dir = vector(angle)
        let normal = CGVector(dx: -dir.dy, dy: dir.dx)

        let halfLength = spec.length
            * (0.96 + 0.055 * CGFloat(sin(localPhase * 0.83 + Double(index))))
        let baseWidth = spec.width * widthBoost
        let bend = spec.bend * deformation
        let secondary = spec.secondaryBend * deformation

        // The narrow point travels through the sheet rather than being fixed at
        // the orb centre. That single change removes the radial flower geometry.
        let pinchT = CGFloat(
            0.50
                + Double(spec.pinchTravel)
                    * sin(localPhase * 0.91 + Double(index) * 1.37)
        )
        let pinchSigma: CGFloat = 0.115 + CGFloat(index) * 0.006

        let count = 42
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        var centerline: [CGPoint] = []
        upper.reserveCapacity(count + 1)
        lower.reserveCapacity(count + 1)
        centerline.reserveCapacity(count + 1)

        for sample in 0...count {
            let t = CGFloat(sample) / CGFloat(count)
            let u = (t - 0.5) * 2.0

            let long = u * halfLength
            let curve = bend
                * CGFloat(sin(Double(t) * .pi + localPhase * 0.41))
                + secondary
                    * CGFloat(sin(Double(t) * .pi * 2.0 + localPhase * 0.88 + Double(index) * 0.7))

            let centerPoint = CGPoint(
                x: center.x + dir.dx * long + normal.dx * curve,
                y: center.y + dir.dy * long + normal.dy * curve
            )

            // Tangent of the analytic centre curve; its perpendicular defines
            // the actual local sheet normal rather than a fixed global normal.
            let dLong = halfLength * 2.0
            let dCurve = bend
                * CGFloat(.pi * cos(Double(t) * .pi + localPhase * 0.41))
                + secondary
                    * CGFloat(2.0 * .pi * cos(Double(t) * .pi * 2.0 + localPhase * 0.88 + Double(index) * 0.7))
            var tx = dir.dx * dLong + normal.dx * dCurve
            var ty = dir.dy * dLong + normal.dy * dCurve
            let tangentLength = max(0.001, sqrt(tx * tx + ty * ty))
            tx /= tangentLength
            ty /= tangentLength
            let nx = -ty
            let ny = tx

            let endpointEnvelope = 0.10
                + 0.90 * pow(max(0, sin(Double(t) * .pi)), 0.62)
            let delta = (t - pinchT) / pinchSigma
            let pinchFalloff = CGFloat(exp(Double(-0.5 * delta * delta)))
            let pinch = 1.0
                - spec.pinchDepth * pinchFalloff
            let breathing = 0.88
                + 0.12
                    * CGFloat(sin(Double(t) * .pi * 2.0 + localPhase * 0.54 + Double(index)))
            let width = baseWidth
                * CGFloat(endpointEnvelope)
                * pinch
                * breathing

            // The upper and lower edges have independent twist. This produces
            // a folded translucent sheet instead of a symmetric ribbon/petal.
            let twist = spec.edgeBias
                * CGFloat(sin(Double(t) * .pi + localPhase * 0.67))
                + 0.18
                    * CGFloat(sin(Double(t) * .pi * 2.0 + localPhase + Double(index)))
            let upperWidth = width * (1.0 + twist * 0.44)
            let lowerWidth = width * (0.82 - twist * 0.34)

            upper.append(CGPoint(
                x: centerPoint.x + nx * upperWidth,
                y: centerPoint.y + ny * upperWidth
            ))
            lower.append(CGPoint(
                x: centerPoint.x - nx * lowerWidth,
                y: centerPoint.y - ny * lowerWidth
            ))
            centerline.append(centerPoint)
        }

        var body = Path()
        if let first = upper.first {
            body.move(to: first)
            for point in upper.dropFirst() { body.addLine(to: point) }
            for point in lower.reversed() { body.addLine(to: point) }
            body.closeSubpath()
        }

        // Which edge is the bright fold changes gradually with the sheet's
        // orientation/depth, matching the white seam that travels across Siri.
        let brightUsesUpper = sin(localPhase * 0.73 + Double(index) * 0.9) > -0.10
        let brightPoints = brightUsesUpper ? upper : lower
        let softPoints = brightUsesUpper ? lower : upper

        let brightEdge = path(points: brightPoints)
        let softEdge = path(points: softPoints)

        // Secondary crease lives inside the membrane and drifts from one edge
        // toward the other; it is deliberately not a radial centreline.
        var foldPoints: [CGPoint] = []
        foldPoints.reserveCapacity(centerline.count)
        for sample in 0..<centerline.count {
            let t = CGFloat(sample) / CGFloat(max(centerline.count - 1, 1))
            let sourceA = upper[sample]
            let sourceB = lower[sample]
            let mix = 0.47
                + 0.18
                    * CGFloat(sin(Double(t) * .pi + localPhase * 0.58 + Double(index) * 0.7))
            foldPoints.append(CGPoint(
                x: sourceA.x + (sourceB.x - sourceA.x) * mix,
                y: sourceA.y + (sourceB.y - sourceA.y) * mix
            ))
        }
        let fold = path(points: foldPoints)

        let gradientStart = offset(center, dir, -halfLength)
        let gradientEnd = offset(center, dir, halfLength)
        let depth = 0.5
            + 0.5 * sin(localPhase * 0.79 + spec.zOffset)

        return SheetGeometry(
            body: body,
            brightEdge: brightEdge,
            softEdge: softEdge,
            fold: fold,
            gradientStart: gradientStart,
            gradientEnd: gradientEnd,
            depth: depth
        )
    }

    private func drawSheet(
        context: inout GraphicsContext,
        spec: SheetSpec,
        geometry: SheetGeometry,
        side: CGFloat,
        gain: Double,
        energy: Double
    ) {
        let depth = geometry.depth
        let color = spec.color

        // Soft body establishes the translucent membrane volume.
        context.drawLayer { body in
            body.blendMode = .screen
            body.addFilter(.blur(radius: side * (0.009 + CGFloat(1.0 - depth) * 0.007)))
            body.opacity = resolvedIntensity
                * gain
                * (0.43 + depth * 0.25)
            body.fill(
                geometry.body,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(0.16), location: 0.00),
                        .init(color: color.opacity(0.56), location: 0.20),
                        .init(color: color.opacity(0.82), location: 0.46),
                        .init(color: Color.white.opacity(0.18), location: 0.55),
                        .init(color: color.opacity(0.64), location: 0.76),
                        .init(color: color.opacity(0.11), location: 1.00)
                    ]),
                    startPoint: geometry.gradientStart,
                    endPoint: geometry.gradientEnd
                )
            )
        }

        // Sharper inner pass preserves the luminous silk character.
        context.drawLayer { silk in
            silk.blendMode = .plusLighter
            silk.opacity = resolvedIntensity
                * gain
                * (0.22 + depth * 0.22 + energy * 0.08)
            silk.fill(
                geometry.body,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(0.04), location: 0.00),
                        .init(color: color.opacity(0.42), location: 0.27),
                        .init(color: Color.white.opacity(0.26), location: 0.51),
                        .init(color: color.opacity(0.40), location: 0.73),
                        .init(color: color.opacity(0.03), location: 1.00)
                    ]),
                    startPoint: geometry.gradientStart,
                    endPoint: geometry.gradientEnd
                )
            )
        }

        // The main white/cyan seam is one edge of the sheet, not a line emitted
        // from the centre. It becomes brighter on spoken transients.
        context.drawLayer { edge in
            edge.blendMode = .plusLighter
            edge.addFilter(.blur(radius: max(0.35, side * 0.0040)))
            edge.opacity = resolvedIntensity
                * gain
                * (0.58 + depth * 0.30 + energy * 0.22)
            edge.stroke(
                geometry.brightEdge,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(0.16), location: 0.00),
                        .init(color: color.opacity(0.76), location: 0.28),
                        .init(color: Color.white.opacity(0.98), location: 0.53),
                        .init(color: color.opacity(0.74), location: 0.72),
                        .init(color: color.opacity(0.10), location: 1.00)
                    ]),
                    startPoint: geometry.gradientStart,
                    endPoint: geometry.gradientEnd
                ),
                style: StrokeStyle(
                    lineWidth: max(0.60, side * (0.0050 + CGFloat(energy) * 0.0048)),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        context.drawLayer { edge in
            edge.blendMode = .screen
            edge.addFilter(.blur(radius: max(0.35, side * 0.0055)))
            edge.opacity = resolvedIntensity * (0.26 + depth * 0.13)
            edge.stroke(
                geometry.softEdge,
                with: .color(color.opacity(0.54)),
                style: StrokeStyle(
                    lineWidth: max(0.45, side * 0.0032),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        context.drawLayer { fold in
            fold.blendMode = .plusLighter
            fold.addFilter(.blur(radius: max(0.30, side * 0.0032)))
            fold.opacity = resolvedIntensity
                * gain
                * (0.30 + depth * 0.22 + energy * 0.16)
            fold.stroke(
                geometry.fold,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: color.opacity(0.52), location: 0.30),
                        .init(color: Color.white.opacity(0.72), location: 0.52),
                        .init(color: color.opacity(0.42), location: 0.72),
                        .init(color: .clear, location: 1.00)
                    ]),
                    startPoint: geometry.gradientStart,
                    endPoint: geometry.gradientEnd
                ),
                style: StrokeStyle(
                    lineWidth: max(0.35, side * (0.0025 + CGFloat(energy) * 0.0020)),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    private func drawBackgroundPools(
        context: inout GraphicsContext,
        center: CGPoint,
        side: CGFloat,
        phase: Double,
        energy: Double
    ) {
        let pools: [(Color, Double, Double, CGFloat, CGFloat, Double)] = [
            (palette.indigo, 0.50, 0.30, 0.205, 0.170, 0.29),
            (palette.violet, 0.43, 2.15, 0.190, 0.180, 0.25),
            (palette.cyan, 0.57, 4.05, 0.175, 0.160, 0.19),
            (palette.magenta, 0.66, 5.40, 0.145, 0.125, 0.14)
        ]

        for (index, item) in pools.enumerated() {
            let (color, speed, offsetPhase, baseRX, baseRY, alpha) = item
            let theta = phase * speed + offsetPhase
            let c = CGPoint(
                x: center.x + side * 0.18 * CGFloat(cos(theta + Double(index) * 0.3)),
                y: center.y + side * 0.16 * CGFloat(sin(theta * 0.86 + Double(index) * 0.5))
            )
            let rx = side * (baseRX + 0.020 * CGFloat(sin(theta * 1.17)))
            let ry = side * (baseRY + 0.018 * CGFloat(cos(theta * 0.91)))

            context.drawLayer { pool in
                pool.blendMode = .screen
                pool.addFilter(.blur(radius: side * 0.026))
                pool.opacity = resolvedIntensity * (alpha + energy * 0.05)
                pool.fill(
                    Path(ellipseIn: CGRect(
                        x: c.x - rx,
                        y: c.y - ry,
                        width: rx * 2,
                        height: ry * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            color.opacity(0.70),
                            color.opacity(0.17),
                            .clear
                        ]),
                        center: c,
                        startRadius: 0,
                        endRadius: max(rx, ry)
                    )
                )
            }
        }
    }

    private func drawMovingNexus(
        context: inout GraphicsContext,
        center: CGPoint,
        side: CGFloat,
        phase: Double,
        energy: Double,
        reactive: Bool
    ) {
        let nexus = CGPoint(
            x: center.x + side * 0.050 * CGFloat(sin(phase * 0.69)),
            y: center.y + side * 0.042 * CGFloat(cos(phase * 0.77 + 0.7))
        )
        let coreRadius = side * (0.034 + CGFloat(energy) * 0.034)

        context.drawLayer { core in
            core.blendMode = .plusLighter
            core.addFilter(.blur(radius: side * (0.011 + CGFloat(energy) * 0.010)))
            core.opacity = resolvedIntensity
                * (reactive ? (0.34 + energy * 0.78) : 0.40)
            core.fill(
                Path(ellipseIn: CGRect(
                    x: nexus.x - coreRadius,
                    y: nexus.y - coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                )),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color.white.opacity(0.95), location: 0.00),
                        .init(color: palette.cyan.opacity(0.68), location: 0.30),
                        .init(color: palette.violet.opacity(0.23), location: 0.68),
                        .init(color: .clear, location: 1.00)
                    ]),
                    center: nexus,
                    startRadius: 0,
                    endRadius: coreRadius
                )
            )
        }
    }

    private func drawOuterAtmosphere(
        context: inout GraphicsContext,
        center: CGPoint,
        circleRect: CGRect,
        side: CGFloat,
        phase: Double,
        energy: Double
    ) {
        context.drawLayer { halo in
            halo.addFilter(.blur(radius: side * (0.048 + CGFloat(energy) * 0.020)))
            halo.opacity = resolvedIntensity * (0.20 + energy * 0.26)
            halo.fill(
                Path(ellipseIn: circleRect.insetBy(dx: -side * 0.020, dy: -side * 0.020)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: palette.indigo.opacity(0.48), location: 0.00),
                        .init(color: palette.violet.opacity(0.27), location: 0.50),
                        .init(color: palette.magenta.opacity(0.09), location: 0.78),
                        .init(color: .clear, location: 1.00)
                    ]),
                    center: CGPoint(
                        x: center.x + side * 0.035 * CGFloat(cos(phase * 0.52)),
                        y: center.y + side * 0.030 * CGFloat(sin(phase * 0.47))
                    ),
                    startRadius: side * 0.14,
                    endRadius: side * 0.56
                )
            )
        }
    }

    private func path(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func vector(_ angle: Double) -> CGVector {
        CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
    }

    private func offset(_ point: CGPoint, _ vector: CGVector, _ distance: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x + vector.dx * distance,
            y: point.y + vector.dy * distance
        )
    }
}
