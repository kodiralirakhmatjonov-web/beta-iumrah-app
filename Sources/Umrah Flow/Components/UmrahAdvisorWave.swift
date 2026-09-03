import Foundation
import SwiftUI

struct UmrahAdvisorWave: View {
    var isActive: Bool
    var compact = false

    private let waveColors: [Color] = [
        Color(red: 1.00, green: 0.72, blue: 0.30),
        Color(red: 1.00, green: 0.65, blue: 0.18),
        Color(red: 1.00, green: 0.57, blue: 0.06),
        Color(red: 1.00, green: 0.49, blue: 0.02),
        Color(red: 0.96, green: 0.39, blue: 0.03),
        Color(red: 0.90, green: 0.31, blue: 0.02),
        Color(red: 1.00, green: 0.45, blue: 0.00)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: isActive ? 1.0 / 30.0 : 1.0 / 14.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let centerY = size.height * 0.52
                let centerX = size.width / 2

                for index in waveColors.indices {
                    var path = Path()
                    let baseAmplitude = (compact ? 8.0 : 13.0) + Double(index) * (compact ? 1.7 : 2.8)
                    let frequency = 1.38 + Double(index) * 0.07
                    let speed = isActive ? 2.8 : 0.78
                    let phase = [0.0, 1.3, 2.7, 0.8, 3.9, 5.2, 4.1][index]

                    for x in stride(from: 0.0, through: Double(size.width), by: 2.0) {
                        let normalizedX = x / max(Double(size.width), 1)
                        let distance = abs(x - Double(centerX)) / max(Double(centerX), 1)
                        let edgeFade = max(0, 1 - distance)
                        let centerBoost = exp(-pow((x - Double(centerX)) / max(Double(size.width) * 0.10, 1), 2))
                        let activity = isActive ? 1.0 : 0.50
                        let amplitude = (baseAmplitude * edgeFade + centerBoost * (compact ? 14 : 36)) * activity
                        let y = Double(centerY) + sin(normalizedX * 2 * .pi * frequency + time * speed + phase) * amplitude

                        if x == 0 {
                            path.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
                        } else {
                            path.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
                        }
                    }

                    context.stroke(
                        path,
                        with: .color(waveColors[index].opacity(isActive ? 0.92 : 0.48)),
                        style: StrokeStyle(lineWidth: compact ? 0.9 : 1.08, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.86), location: 0.12),
                    .init(color: .white, location: 0.50),
                    .init(color: .white.opacity(0.86), location: 0.88),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .drawingGroup()
        .accessibilityHidden(true)
    }
}
