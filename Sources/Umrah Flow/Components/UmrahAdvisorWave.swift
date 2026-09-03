import Foundation
import SwiftUI

struct UmrahAdvisorWave: View {
    var isActive: Bool
    var compact = false

    private let waveColors: [Color] = [
        Color(red: 1.00, green: 0.72, blue: 0.30),
        Color(red: 1.00, green: 0.60, blue: 0.16),
        Color(red: 1.00, green: 0.49, blue: 0.05),
        Color(red: 0.96, green: 0.39, blue: 0.03),
        Color(red: 0.88, green: 0.30, blue: 0.02),
        Color(red: 1.00, green: 0.45, blue: 0.00)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: isActive ? 1.0 / 30.0 : 1.0 / 12.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let centerY = size.height * 0.50
                let centerX = size.width / 2
                let lineCount = waveColors.count

                for index in 0..<lineCount {
                    var path = Path()
                    let baseAmplitude = (compact ? 8.0 : 12.0) + Double(index) * (compact ? 1.8 : 2.5)
                    let frequency = 1.25 + Double(index) * 0.10
                    let speed = isActive ? 2.6 : 0.72
                    let phase = Double(index) * 1.17

                    for x in stride(from: 0.0, through: Double(size.width), by: 2.0) {
                        let normalizedX = x / max(Double(size.width), 1)
                        let distance = abs(x - Double(centerX)) / max(Double(centerX), 1)
                        let edgeFade = max(0, 1 - distance)
                        let centerBoost = exp(-pow((x - Double(centerX)) / max(Double(size.width) * 0.13, 1), 2))
                        let activityBoost = isActive ? 1.0 : 0.48
                        let amplitude = (baseAmplitude * edgeFade + centerBoost * (compact ? 12 : 25)) * activityBoost
                        let y = Double(centerY) + sin(normalizedX * 2 * .pi * frequency + time * speed + phase) * amplitude

                        if x == 0 {
                            path.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
                        } else {
                            path.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
                        }
                    }

                    context.stroke(
                        path,
                        with: .color(waveColors[index].opacity(isActive ? 0.90 : 0.52)),
                        style: StrokeStyle(lineWidth: compact ? 0.9 : 1.15, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}
