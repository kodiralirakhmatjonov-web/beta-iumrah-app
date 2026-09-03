import SwiftUI

/// Native, continuously rendered booking identity card inspired by the
/// iridescent point-dome motion language supplied for iumrah Booking.
///
/// The surface is generated in real time with SwiftUI Canvas. There is no
/// embedded video/GIF and no network dependency.
struct IumrahBookingDomeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.075, green: 0.076, blue: 0.082),
                            Color(red: 0.032, green: 0.033, blue: 0.038)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Canvas(rendersAsynchronously: true) { context, size in
                        renderDome(
                            in: &context,
                            size: size,
                            time: reduceMotion ? 0.85 : timeline.date.timeIntervalSinceReferenceDate
                        )
                    }
                    .allowsHitTesting(false)

                    Text("iumrah Booking")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .tracking(-0.25)
                        .foregroundStyle(.white)
                        .padding(.leading, 16)
                        .padding(.top, 14)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .aspectRatio(1.60, contentMode: .fit)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.075), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("iumrah Booking")
    }

    private func renderDome(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        guard size.width > 1, size.height > 1 else { return }

        let cycle: Double = 4.60
        let progress = positiveRemainder(time, cycle) / cycle
        let center = CGPoint(x: size.width * 0.5, y: size.height * 1.005)
        let sphereRadius = min(size.width * 0.49, size.height * 0.79)
        let unitDot = size.width * 0.00615

        // Draw the more distant points first so the larger front-facing rings
        // naturally sit above them and preserve the spherical depth cue.
        for point in Self.points {
            let depth = point.depth
            let perspective = 0.88 + (0.18 * depth)

            let x = center.x + (point.x * sphereRadius * perspective)
            let y = center.y + (point.y * sphereRadius * (0.90 + 0.18 * depth))

            // Front-facing points are deliberately larger, matching the
            // optical-depth behavior in the supplied reference animation.
            let radius = unitDot * (0.66 + 0.68 * depth)

            let nx = point.x
            let ny = point.y + 1.0

            // A full-spectrum spatial sweep. Advancing exactly one hue turn
            // per cycle makes the 4.6 s loop visually seamless.
            let hue = positiveRemainder(
                0.585
                + progress
                + (0.235 * nx)
                + (0.055 * ny)
                + (0.045 * depth),
                1.0
            )

            // Two softly coupled luminance waves create the same behavior as
            // the reference: the dome occasionally recedes almost to graphite
            // before blooming back into saturated color.
            let travel = 0.5 + 0.5 * sin(
                2.0 * .pi * (
                    progress
                    + (0.30 * nx)
                    - (0.10 * ny)
                    + (0.07 * depth)
                )
            )
            let breathe = 0.5 + 0.5 * sin(2.0 * .pi * ((2.0 * progress) + 0.08))
            let globalLight = 0.20 + (0.80 * breathe)
            let intensity = clamp(
                0.10 + (0.90 * (0.28 + (0.72 * travel)) * globalLight),
                lower: 0.06,
                upper: 1.0
            )

            let spectral = Color(
                hue: hue,
                saturation: 0.78,
                brightness: 1.0
            )

            // Faint neutral ring remains when the travelling color wave is
            // dark, so the point mesh never disappears completely.
            let neutralAlpha = 0.17 + (0.16 * depth)
            fillCircle(
                in: &context,
                center: CGPoint(x: x, y: y),
                radius: radius,
                color: Color.white.opacity(neutralAlpha)
            )

            // Restrained colored halo.
            fillCircle(
                in: &context,
                center: CGPoint(x: x, y: y),
                radius: radius * 1.62,
                color: spectral.opacity(0.10 * intensity)
            )

            // Iridescent ring body.
            fillCircle(
                in: &context,
                center: CGPoint(x: x, y: y),
                radius: radius,
                color: spectral.opacity(0.92 * intensity)
            )

            // Dark inset gives every point the characteristic hollow / lens
            // appearance visible in the supplied Apple Cash reference.
            fillCircle(
                in: &context,
                center: CGPoint(x: x, y: y),
                radius: radius * 0.43,
                color: Color(red: 0.018, green: 0.019, blue: 0.023).opacity(0.92)
            )

            // Tiny specular reflection prevents the points from looking like
            // flat vector circles when the color reaches peak intensity.
            let highlightCenter = CGPoint(
                x: x - (radius * 0.27),
                y: y - (radius * 0.28)
            )
            fillCircle(
                in: &context,
                center: highlightCenter,
                radius: max(0.28, radius * 0.17),
                color: Color.white.opacity(0.26 * intensity)
            )
        }
    }

    private func fillCircle(
        in context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        guard radius > 0 else { return }
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func positiveRemainder(_ value: Double, _ divisor: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: divisor)
        return result < 0 ? result + divisor : result
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    /// Precomputed sphere lattice. Keeping trigonometry out of the animation
    /// frame makes the effect inexpensive enough to run continuously even on
    /// older iPhones supported by the current iOS 17 deployment target.
    private static let points: [DomePoint] = {
        let ringCount = 18
        var output: [DomePoint] = []
        output.reserveCapacity(620)

        let thetaStart = 0.085
        let thetaEnd = (Double.pi / 2.0) - 0.115

        for ring in 0..<ringCount {
            let fraction = Double(ring) / Double(max(1, ringCount - 1))
            let theta = thetaStart + ((thetaEnd - thetaStart) * fraction)
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)
            let count = max(6, Int((48.0 * sinTheta).rounded()))
            let stagger = ring.isMultiple(of: 2) ? 0.0 : 0.25

            for index in 0..<count {
                let phi = Double.pi * ((Double(index) + 0.5 + stagger) / Double(count))
                let depth = sinTheta * sin(phi)
                let rawX = sinTheta * cos(phi)
                let rawY = -cosTheta

                // Subtle front-surface perspective keeps latitude bands from
                // reading as flat horizontal rows.
                let x = rawX * (0.94 + (0.06 * depth))
                let y = rawY

                output.append(DomePoint(x: x, y: y, depth: depth))
            }
        }

        return output.sorted { $0.depth < $1.depth }
    }()
}

private struct DomePoint {
    let x: Double
    let y: Double
    let depth: Double
}
