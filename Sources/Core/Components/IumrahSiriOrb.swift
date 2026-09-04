import SwiftUI

/// Reusable native iumrah voice/system orb.
///
/// The motion is drawn in real time with SwiftUI Canvas. It is intentionally
/// self-contained (no video, GIF, Lottie or business state) so it can be reused
/// for Advisor, package generation and other live iumrah system states.
struct IumrahSiriOrb: View {
    struct Palette {
        let violet: Color
        let indigo: Color
        let cyan: Color
        let aqua: Color
        let magenta: Color
        let deep: Color

        static let advisor = Palette(
            violet: Color(red: 0.48, green: 0.18, blue: 1.00),
            indigo: Color(red: 0.20, green: 0.30, blue: 1.00),
            cyan: Color(red: 0.05, green: 0.82, blue: 1.00),
            aqua: Color(red: 0.12, green: 0.96, blue: 0.85),
            magenta: Color(red: 0.92, green: 0.18, blue: 0.78),
            deep: Color(red: 0.012, green: 0.012, blue: 0.032)
        )
    }

    var isActive: Bool = true
    var intensity: Double = 1.0
    var showsCoreHighlight: Bool = true

    /// Optional normalized real-audio energy (0...1). When supplied, the same
    /// liquid Siri geometry opens, brightens and contracts with the spoken
    /// waveform instead of playing as a purely decorative loop.
    var audioLevel: Double? = nil

    var palette: Palette = .advisor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let phase = resolvedPhase(seconds)
                let audioEnergy = resolvedAudioEnergy
                let idleBreath = 0.985 + 0.015 * sin(phase * .pi * 2.0)
                let voiceBreath = 0.985
                    + 0.010 * sin(phase * .pi * 4.0)
                    + 0.045 * audioEnergy
                let breath = audioLevel == nil ? idleBreath : voiceBreath

                Canvas(rendersAsynchronously: true) { context, size in
                    drawOrb(
                        context: &context,
                        size: size,
                        phase: phase,
                        side: side,
                        audioEnergy: audioEnergy
                    )
                }
                .frame(width: side, height: side)
                .scaleEffect(breath)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var resolvedIntensity: Double {
        max(0.0, min(intensity, 1.35))
    }

    private var resolvedAudioEnergy: Double {
        guard let audioLevel else { return 0 }
        return max(0.0, min(audioLevel, 1.0))
    }

    private var frameInterval: TimeInterval {
        if reduceMotion || !isActive { return 1.0 / 12.0 }
        return 1.0 / 60.0
    }

    private func resolvedPhase(_ seconds: TimeInterval) -> Double {
        guard isActive, !reduceMotion else { return 0.21 }
        // Long, non-obvious cycle so the orb feels alive instead of looped.
        return seconds.truncatingRemainder(dividingBy: 11.6) / 11.6
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
        let luminanceGain = reactive ? (0.82 + audioEnergy * 0.48) : 1.0
        let ribbonLengthGain = reactive ? (1.0 + energy * 0.11) : 1.0
        let ribbonWidthGain = reactive ? (0.94 + energy * 0.42) : 1.0
        let bendGain = reactive ? (0.82 + energy * 0.62) : 1.0
        let radius = side * 0.465
        let circleRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let circle = Path(ellipseIn: circleRect)

        // Atmospheric halo outside the glass shell.
        context.drawLayer { halo in
            halo.addFilter(.blur(radius: side * 0.060))
            halo.opacity = 0.34 * resolvedIntensity * luminanceGain
            halo.fill(
                Path(ellipseIn: circleRect.insetBy(dx: -side * 0.025, dy: -side * 0.025)),
                with: .radialGradient(
                    Gradient(colors: [palette.violet.opacity(0.70), palette.cyan.opacity(0.22), .clear]),
                    center: center,
                    startRadius: side * 0.28,
                    endRadius: side * 0.57
                )
            )
        }

        context.drawLayer { orb in
            orb.clip(to: circle)

            // Very dark glass body. The moving silk remains luminous but never
            // turns into a flat neon disc.
            orb.fill(
                circle,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.035, green: 0.045, blue: 0.075), location: 0.00),
                        .init(color: palette.deep, location: 0.58),
                        .init(color: .black, location: 1.00)
                    ]),
                    center: CGPoint(x: center.x - side * 0.08, y: center.y - side * 0.09),
                    startRadius: 0,
                    endRadius: radius
                )
            )

            // Low-frequency translucent bodies behind the sharper ribbons. They
            // create the rounded, volumetric "liquid glass" depth seen in Siri.
            for index in 0..<5 {
                let i = Double(index)
                let angle = phase * (.pi * 2.0) * (0.20 + 0.025 * i)
                    + i * (.pi * 2.0 / 5.0)
                    + 0.28 * sin(phase * .pi * 2.0 * (0.63 + i * 0.07) + i)
                let length = side
                    * CGFloat(0.35 + 0.028 * sin(phase * .pi * 2.0 * (0.82 + i * 0.04) + i * 0.9))
                    * ribbonLengthGain
                let width = side
                    * CGFloat(0.20 + 0.025 * cos(phase * .pi * 2.0 * (0.71 + i * 0.06) + i))
                    * ribbonWidthGain
                let bend = CGFloat(sin(phase * .pi * 2.0 * (0.57 + i * 0.09) + i * 1.4))
                    * bendGain

                let path = silkPath(
                    center: center,
                    angle: angle,
                    length: length,
                    width: width,
                    bend: bend,
                    pinch: 0.20 + 0.04 * CGFloat(sin(i + phase * .pi * 2.0))
                )

                let color = ribbonColor(index)
                let end = point(center, angle: angle, distance: length)

                orb.drawLayer { veil in
                    veil.blendMode = .screen
                    veil.addFilter(.blur(radius: side * 0.018))
                    veil.opacity = (0.34 + 0.05 * sin(phase * .pi * 4.0 + i))
                        * resolvedIntensity
                        * luminanceGain
                    veil.fill(
                        path,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: color.opacity(0.22), location: 0.00),
                                .init(color: color.opacity(0.86), location: 0.48),
                                .init(color: Color.white.opacity(0.22), location: 0.72),
                                .init(color: color.opacity(0.12), location: 1.00)
                            ]),
                            startPoint: center,
                            endPoint: end
                        )
                    )
                }
            }

            // Sharper inner silk blades. Each is independently phase-shifted so
            // the structure continuously folds through itself rather than simply
            // rotating as one gradient.
            for index in 0..<5 {
                let i = Double(index)
                let orbital = phase * (.pi * 2.0) * (0.26 + 0.018 * i)
                let angle = orbital
                    + i * (.pi * 2.0 / 5.0)
                    + 0.44 * sin(phase * .pi * 2.0 * (0.74 + i * 0.055) + i * 1.11)
                let length = side
                    * CGFloat(0.30 + 0.045 * sin(phase * .pi * 2.0 * (0.88 + i * 0.03) + i * 0.63))
                    * ribbonLengthGain
                let width = side
                    * CGFloat(0.122 + 0.025 * cos(phase * .pi * 2.0 * (0.93 + i * 0.05) + i * 0.41))
                    * ribbonWidthGain
                let bend = CGFloat(sin(phase * .pi * 2.0 * (0.67 + i * 0.075) + i * 1.31))
                    * bendGain

                let path = silkPath(
                    center: center,
                    angle: angle,
                    length: length,
                    width: width,
                    bend: bend,
                    pinch: 0.11
                )

                let color = ribbonColor(index)
                let end = point(center, angle: angle, distance: length)

                orb.drawLayer { blade in
                    blade.blendMode = .plusLighter
                    blade.opacity = (0.62 + 0.10 * sin(phase * .pi * 2.0 * 1.7 + i))
                        * resolvedIntensity
                        * luminanceGain
                    blade.fill(
                        path,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Color.white.opacity(0.68), location: 0.00),
                                .init(color: color.opacity(0.98), location: 0.25),
                                .init(color: color.opacity(0.52), location: 0.72),
                                .init(color: palette.deep.opacity(0.05), location: 1.00)
                            ]),
                            startPoint: center,
                            endPoint: end
                        )
                    )
                }

                // Fine luminous seam: this creates the characteristic sharp cusp
                // where two translucent surfaces cross.
                let seam = seamPath(
                    center: center,
                    angle: angle,
                    length: length * 0.96,
                    bend: bend
                )
                orb.drawLayer { line in
                    line.blendMode = .plusLighter
                    line.addFilter(.blur(radius: max(0.45, side * 0.0045)))
                    line.opacity = 0.78 * resolvedIntensity * luminanceGain
                    line.stroke(
                        seam,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.00),
                                .init(color: color.opacity(0.94), location: 0.32),
                                .init(color: color.opacity(0.32), location: 1.00)
                            ]),
                            startPoint: center,
                            endPoint: end
                        ),
                        style: StrokeStyle(lineWidth: max(0.7, side * 0.008), lineCap: .round)
                    )
                }
            }

            // A slowly drifting translucent glass veil keeps the edge from being
            // perfectly symmetrical and adds the "contained fluid" illusion.
            let drift = phase * .pi * 2.0
            let veilCenter = CGPoint(
                x: center.x + side * 0.11 * CGFloat(sin(drift * 0.61)),
                y: center.y + side * 0.10 * CGFloat(cos(drift * 0.53))
            )
            orb.drawLayer { glass in
                glass.blendMode = .screen
                glass.addFilter(.blur(radius: side * 0.030))
                glass.opacity = 0.24 * resolvedIntensity * luminanceGain
                glass.fill(
                    Path(ellipseIn: CGRect(
                        x: veilCenter.x - side * 0.28,
                        y: veilCenter.y - side * 0.22,
                        width: side * 0.56,
                        height: side * 0.44
                    )),
                    with: .linearGradient(
                        Gradient(colors: [palette.cyan.opacity(0.58), palette.violet.opacity(0.08), .clear]),
                        startPoint: CGPoint(x: veilCenter.x - side * 0.20, y: veilCenter.y - side * 0.16),
                        endPoint: CGPoint(x: veilCenter.x + side * 0.20, y: veilCenter.y + side * 0.16)
                    )
                )
            }

            if showsCoreHighlight {
                let coreShift = CGPoint(
                    x: center.x + side * 0.025 * CGFloat(sin(drift * 1.19)),
                    y: center.y + side * 0.020 * CGFloat(cos(drift * 0.97))
                )
                let coreRadius = side * (0.075 + (reactive ? energy * 0.020 : 0))
                orb.drawLayer { core in
                    core.blendMode = .plusLighter
                    core.addFilter(.blur(radius: side * (0.027 + (reactive ? energy * 0.009 : 0))))
                    core.opacity = (0.52 + 0.18 * sin(drift * 1.33))
                        * resolvedIntensity
                        * luminanceGain
                    core.fill(
                        Path(ellipseIn: CGRect(
                            x: coreShift.x - coreRadius,
                            y: coreShift.y - coreRadius,
                            width: coreRadius * 2,
                            height: coreRadius * 2
                        )),
                        with: .radialGradient(
                            Gradient(colors: [Color.white, palette.cyan.opacity(0.70), .clear]),
                            center: coreShift,
                            startRadius: 0,
                            endRadius: coreRadius
                        )
                    )
                }
            }

            // Inner specular glaze from the upper-left.
            orb.drawLayer { highlight in
                highlight.blendMode = .screen
                highlight.addFilter(.blur(radius: side * 0.020))
                highlight.opacity = 0.18
                highlight.fill(
                    circle,
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.58), Color.white.opacity(0.05), .clear]),
                        center: CGPoint(x: center.x - side * 0.15, y: center.y - side * 0.18),
                        startRadius: 0,
                        endRadius: side * 0.38
                    )
                )
            }
        }

        // Physical shell. Two rims with different softness prevent the orb from
        // looking like a clipped animation inside a flat circle.
        context.drawLayer { rimGlow in
            rimGlow.blendMode = .screen
            rimGlow.addFilter(.blur(radius: side * 0.014))
            rimGlow.opacity = 0.68 * resolvedIntensity * luminanceGain
            rimGlow.stroke(
                circle,
                with: .angularGradient(
                    Gradient(colors: [
                        palette.cyan.opacity(0.72),
                        palette.indigo.opacity(0.36),
                        palette.violet.opacity(0.78),
                        palette.magenta.opacity(0.62),
                        palette.aqua.opacity(0.38),
                        palette.cyan.opacity(0.72)
                    ]),
                    center: center,
                    startAngle: .degrees(phase * 150.0),
                    endAngle: .degrees(phase * 150.0 + 360.0)
                ),
                lineWidth: max(1.0, side * (0.012 + (reactive ? energy * 0.004 : 0)))
            )
        }

        context.stroke(
            circle,
            with: .color(Color.white.opacity(0.13)),
            lineWidth: max(0.55, side * 0.004)
        )
    }

    private func ribbonColor(_ index: Int) -> Color {
        switch index % 5 {
        case 0: return palette.cyan
        case 1: return palette.violet
        case 2: return palette.magenta
        case 3: return palette.indigo
        default: return palette.aqua
        }
    }

    /// A closed, pinched cubic surface that behaves like a translucent piece of
    /// silk anchored near the core and flowing out toward the glass shell.
    private func silkPath(
        center: CGPoint,
        angle: Double,
        length: CGFloat,
        width: CGFloat,
        bend: CGFloat,
        pinch: CGFloat
    ) -> Path {
        let dir = vector(angle)
        let normal = CGVector(dx: -dir.dy, dy: dir.dx)

        let start = offset(center, dir, -length * 0.08)
        let endBase = offset(center, dir, length)
        let end = offset(endBase, normal, width * bend * 0.34)

        let topStart = offset(start, normal, width * pinch)
        let bottomStart = offset(start, normal, -width * pinch)

        let topC1 = offset(offset(center, dir, length * 0.18), normal, width * (0.78 + 0.16 * bend))
        let topC2 = offset(offset(center, dir, length * 0.68), normal, width * (0.46 - 0.20 * bend))
        let topEnd = offset(end, normal, width * 0.08)

        let bottomC2 = offset(offset(center, dir, length * 0.66), normal, -width * (0.38 + 0.22 * bend))
        let bottomC1 = offset(offset(center, dir, length * 0.16), normal, -width * (0.70 - 0.18 * bend))
        let bottomEnd = offset(end, normal, -width * 0.09)

        var path = Path()
        path.move(to: topStart)
        path.addCurve(to: topEnd, control1: topC1, control2: topC2)
        path.addQuadCurve(to: bottomEnd, control: offset(end, dir, length * 0.055))
        path.addCurve(to: bottomStart, control1: bottomC2, control2: bottomC1)
        path.addQuadCurve(to: topStart, control: offset(start, dir, -length * 0.045))
        path.closeSubpath()
        return path
    }

    private func seamPath(
        center: CGPoint,
        angle: Double,
        length: CGFloat,
        bend: CGFloat
    ) -> Path {
        let dir = vector(angle)
        let normal = CGVector(dx: -dir.dy, dy: dir.dx)
        let end = offset(offset(center, dir, length), normal, length * bend * 0.13)
        let c1 = offset(offset(center, dir, length * 0.22), normal, length * bend * 0.18)
        let c2 = offset(offset(center, dir, length * 0.67), normal, -length * bend * 0.10)

        var path = Path()
        path.move(to: offset(center, dir, -length * 0.07))
        path.addCurve(to: end, control1: c1, control2: c2)
        return path
    }

    private func vector(_ angle: Double) -> CGVector {
        CGVector(dx: CGFloat(cos(angle)), dy: CGFloat(sin(angle)))
    }

    private func point(_ origin: CGPoint, angle: Double, distance: CGFloat) -> CGPoint {
        let v = vector(angle)
        return offset(origin, v, distance)
    }

    private func offset(_ point: CGPoint, _ vector: CGVector, _ distance: CGFloat) -> CGPoint {
        CGPoint(x: point.x + vector.dx * distance, y: point.y + vector.dy * distance)
    }
}
