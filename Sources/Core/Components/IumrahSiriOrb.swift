import SwiftUI

/// Reusable circular iumrah voice/system presence.
///
/// A native, self-contained orb built from SwiftUI layers and TimelineView.
/// It intentionally contains no business logic so the same visual can be reused
/// by Advisor, package generation, booking processing, or other active states.
struct IumrahSiriOrb: View {
    var isActive: Bool = true
    var intensity: Double = 1.0
    var showsCoreHighlight: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let violet = Color(red: 0.48, green: 0.20, blue: 1.00)
    private let electricPurple = Color(red: 0.72, green: 0.24, blue: 1.00)
    private let magenta = Color(red: 0.98, green: 0.20, blue: 0.74)
    private let blue = Color(red: 0.16, green: 0.42, blue: 1.00)
    private let cyan = Color(red: 0.08, green: 0.82, blue: 0.98)

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = resolvedPhase(t)
                let pulse = 0.975 + 0.025 * sin(phase * .pi * 4.0)

                ZStack {
                    // Outer atmospheric halo. It is deliberately separated from the
                    // orb so the circle still has a crisp physical edge.
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    violet.opacity(0.30 * resolvedIntensity),
                                    electricPurple.opacity(0.12 * resolvedIntensity),
                                    .clear
                                ],
                                center: .center,
                                startRadius: side * 0.26,
                                endRadius: side * 0.62
                            )
                        )
                        .frame(width: side * 1.20, height: side * 1.20)
                        .blur(radius: side * 0.055)

                    orbSurface(side: side, phase: phase)
                        .frame(width: side, height: side)
                        .scaleEffect(pulse)

                    if showsCoreHighlight {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.035),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.38, y: 0.27),
                                    startRadius: 0,
                                    endRadius: side * 0.42
                                )
                            )
                            .frame(width: side * 0.88, height: side * 0.88)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .drawingGroup(opaque: false, colorMode: .extendedLinear)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var resolvedIntensity: Double {
        max(0.0, min(intensity, 1.45))
    }

    private var frameInterval: TimeInterval {
        if reduceMotion || !isActive { return 1.0 / 12.0 }
        return 1.0 / 60.0
    }

    private func resolvedPhase(_ seconds: TimeInterval) -> Double {
        guard isActive, !reduceMotion else { return 0.16 }
        return seconds.truncatingRemainder(dividingBy: 8.4) / 8.4
    }

    private func orbSurface(side: CGFloat, phase: Double) -> some View {
        let turn = Angle.degrees(phase * 360.0)
        let counterTurn = Angle.degrees(-phase * 286.0 + 42.0)

        return ZStack {
            Circle()
                .fill(Color(red: 0.012, green: 0.010, blue: 0.027))

            // Slow moving luminous masses. Different periods and paths keep the
            // motion organic instead of looking like a rotating gradient wheel.
            movingGlow(
                color: cyan,
                diameter: side * 0.88,
                x: side * (0.26 + 0.28 * wave(phase, speed: 1.00, offset: 0.08)),
                y: side * (0.28 + 0.25 * wave(phase, speed: 0.83, offset: 0.52)),
                opacity: 0.94
            )

            movingGlow(
                color: violet,
                diameter: side * 0.98,
                x: side * (0.72 - 0.30 * wave(phase, speed: 0.72, offset: 0.31)),
                y: side * (0.70 - 0.27 * wave(phase, speed: 1.08, offset: 0.12)),
                opacity: 1.00
            )

            movingGlow(
                color: magenta,
                diameter: side * 0.72,
                x: side * (0.78 - 0.24 * wave(phase, speed: 1.21, offset: 0.67)),
                y: side * (0.30 + 0.30 * wave(phase, speed: 0.91, offset: 0.22)),
                opacity: 0.92
            )

            movingGlow(
                color: blue,
                diameter: side * 0.76,
                x: side * (0.28 + 0.25 * wave(phase, speed: 0.88, offset: 0.76)),
                y: side * (0.74 - 0.29 * wave(phase, speed: 1.16, offset: 0.42)),
                opacity: 0.95
            )

            movingGlow(
                color: electricPurple,
                diameter: side * 0.62,
                x: side * (0.50 + 0.22 * wave(phase, speed: 1.38, offset: 0.18)),
                y: side * (0.50 + 0.20 * wave(phase, speed: 1.12, offset: 0.82)),
                opacity: 0.88
            )

            // Two counter-rotating spectral fields add the characteristic living
            // Siri-like colour migration around the circumference.
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: cyan.opacity(0.74), location: 0.00),
                            .init(color: blue.opacity(0.16), location: 0.15),
                            .init(color: violet.opacity(0.74), location: 0.34),
                            .init(color: magenta.opacity(0.58), location: 0.56),
                            .init(color: electricPurple.opacity(0.70), location: 0.76),
                            .init(color: cyan.opacity(0.74), location: 1.00)
                        ]),
                        center: .center,
                        startAngle: turn,
                        endAngle: turn + .degrees(360)
                    )
                )
                .opacity(0.64 * resolvedIntensity)
                .blur(radius: side * 0.085)
                .blendMode(.screen)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            violet.opacity(0.68),
                            .clear,
                            cyan.opacity(0.50),
                            .clear,
                            magenta.opacity(0.58),
                            .clear,
                            violet.opacity(0.68)
                        ],
                        center: .center,
                        startAngle: counterTurn,
                        endAngle: counterTurn + .degrees(360)
                    )
                )
                .scaleEffect(0.84)
                .opacity(0.62 * resolvedIntensity)
                .blur(radius: side * 0.06)
                .blendMode(.plusLighter)

            // Dark translucent core gives depth and prevents the orb from becoming
            // a flat neon disc.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.10),
                            Color.black.opacity(0.03),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: side * 0.05,
                        endRadius: side * 0.48
                    )
                )

            // Physical glass edge + luminous rim.
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [cyan, blue, violet, magenta, electricPurple, cyan],
                        center: .center,
                        startAngle: turn,
                        endAngle: turn + .degrees(360)
                    ),
                    lineWidth: max(1.1, side * 0.017)
                )
                .opacity(0.88 * resolvedIntensity)
                .blur(radius: side * 0.010)

            Circle()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.65)
        }
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(violet.opacity(0.28 * resolvedIntensity), lineWidth: max(1, side * 0.018))
                .blur(radius: side * 0.040)
        }
    }

    private func movingGlow(
        color: Color,
        diameter: CGFloat,
        x: CGFloat,
        y: CGFloat,
        opacity: Double
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(opacity * resolvedIntensity),
                        color.opacity(0.50 * opacity * resolvedIntensity),
                        color.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.50
                )
            )
            .frame(width: diameter, height: diameter)
            .position(x: x, y: y)
            .blur(radius: diameter * 0.065)
            .blendMode(.screen)
    }

    private func wave(_ phase: Double, speed: Double, offset: Double) -> CGFloat {
        let value = sin((phase * speed + offset) * .pi * 2.0)
        return CGFloat((value + 1.0) * 0.5)
    }
}
