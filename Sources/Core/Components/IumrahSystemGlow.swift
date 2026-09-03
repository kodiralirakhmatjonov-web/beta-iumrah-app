import SwiftUI

/// Reusable iumrah system-presence animation.
///
/// The component deliberately owns only the visual language: a living multi-colour
/// edge light with soft interior aurora. It can be embedded as a compact Home widget
/// today and reused later as a screen-edge state for Advisor / package generation.
struct IumrahSystemGlow: View {
    enum Presentation {
        case widget
        case screenEdge
    }

    var presentation: Presentation = .widget
    var isActive: Bool = true
    var cornerRadius: CGFloat = 26
    var intensity: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let violet = Color(red: 0.49, green: 0.22, blue: 1.00)
    private let electricPurple = Color(red: 0.72, green: 0.26, blue: 1.00)
    private let blue = Color(red: 0.20, green: 0.43, blue: 1.00)
    private let cyan = Color(red: 0.10, green: 0.82, blue: 0.96)
    private let softPink = Color(red: 0.98, green: 0.28, blue: 0.76)

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
            GeometryReader { proxy in
                let size = proxy.size
                let seconds = timeline.date.timeIntervalSinceReferenceDate
                let phase = resolvedPhase(seconds)

                ZStack {
                    if presentation == .widget {
                        widgetInterior(size: size, phase: phase)
                    }

                    edgeGlow(phase: phase)

                    if presentation == .widget {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.075), lineWidth: 0.7)
                    }
                }
                .drawingGroup(opaque: false, colorMode: .extendedLinear)
            }
        }
        .accessibilityHidden(true)
    }

    private var frameInterval: TimeInterval {
        if reduceMotion || !isActive { return 1.0 / 12.0 }
        return 1.0 / 60.0
    }

    private func resolvedPhase(_ seconds: TimeInterval) -> Double {
        guard isActive, !reduceMotion else { return 0.18 }
        return seconds.truncatingRemainder(dividingBy: 7.2) / 7.2
    }

    @ViewBuilder
    private func widgetInterior(size: CGSize, phase: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.020, green: 0.018, blue: 0.034),
                            Color(red: 0.030, green: 0.020, blue: 0.050),
                            Color(red: 0.014, green: 0.018, blue: 0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            auroraOrb(
                color: violet,
                diameter: max(size.width * 0.62, 120),
                x: size.width * (0.16 + 0.70 * wave(phase, offset: 0.05)),
                y: size.height * (0.18 + 0.64 * wave(phase, offset: 0.36)),
                opacity: 0.34
            )

            auroraOrb(
                color: cyan,
                diameter: max(size.width * 0.46, 100),
                x: size.width * (0.82 - 0.66 * wave(phase, offset: 0.28)),
                y: size.height * (0.76 - 0.50 * wave(phase, offset: 0.71)),
                opacity: 0.25
            )

            auroraOrb(
                color: softPink,
                diameter: max(size.width * 0.40, 90),
                x: size.width * (0.22 + 0.58 * wave(phase, offset: 0.62)),
                y: size.height * (0.72 - 0.46 * wave(phase, offset: 0.14)),
                opacity: 0.20
            )

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.035), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(-14))
            .offset(x: CGFloat((phase - 0.5) * Double(size.width) * 1.5))
            .blur(radius: 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func edgeGlow(phase: Double) -> some View {
        let rotation = Angle.degrees(phase * 360.0 - 54.0)
        let reverseRotation = Angle.degrees(-phase * 282.0 + 116.0)
        let pulse = 0.84 + 0.16 * sin(phase * .pi * 4.0)
        let resolvedIntensity = max(0.0, min(intensity, 1.5))
        let width: CGFloat = presentation == .widget ? 2.2 : 3.6
        let blur: CGFloat = presentation == .widget ? 9.0 : 15.0

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: violet, location: 0.00),
                            .init(color: electricPurple, location: 0.17),
                            .init(color: softPink, location: 0.34),
                            .init(color: blue, location: 0.57),
                            .init(color: cyan, location: 0.76),
                            .init(color: violet, location: 1.00)
                        ]),
                        center: .center,
                        startAngle: rotation,
                        endAngle: rotation + .degrees(360)
                    ),
                    lineWidth: width * 3.4
                )
                .opacity(0.34 * pulse * resolvedIntensity)
                .blur(radius: blur)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: cyan.opacity(0.94), location: 0.00),
                            .init(color: blue.opacity(0.92), location: 0.21),
                            .init(color: violet.opacity(0.98), location: 0.47),
                            .init(color: softPink.opacity(0.94), location: 0.71),
                            .init(color: electricPurple.opacity(0.94), location: 1.00)
                        ]),
                        center: .center,
                        startAngle: reverseRotation,
                        endAngle: reverseRotation + .degrees(360)
                    ),
                    lineWidth: width * 1.8
                )
                .opacity(0.42 * resolvedIntensity)
                .blur(radius: blur * 0.42)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [violet, softPink, blue, cyan, violet]),
                        center: .center,
                        startAngle: rotation,
                        endAngle: rotation + .degrees(360)
                    ),
                    lineWidth: width
                )
                .opacity(0.88 * resolvedIntensity)
        }
        .padding(presentation == .widget ? 1.5 : 2.0)
    }

    private func auroraOrb(
        color: Color,
        diameter: CGFloat,
        x: CGFloat,
        y: CGFloat,
        opacity: Double
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity * intensity), color.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.5
                )
            )
            .frame(width: diameter, height: diameter)
            .position(x: x, y: y)
            .blur(radius: 11)
            .blendMode(.screen)
    }

    private func wave(_ phase: Double, offset: Double) -> CGFloat {
        let value = sin((phase + offset) * .pi * 2.0)
        return CGFloat((value + 1.0) * 0.5)
    }
}
