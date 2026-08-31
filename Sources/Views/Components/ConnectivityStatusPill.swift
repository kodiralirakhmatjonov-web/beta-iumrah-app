import SwiftUI

struct ConnectivityStatusPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var connectivity = IumrahConnectivityMonitor()

    var lightStyle = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            pill(phase: phase(for: context.date))
        }
        .frame(width: 88, height: 34)
        .task {
            // NWPathMonitor performs the first check immediately. The periodic
            // probe keeps captive/dead Wi-Fi from remaining visually "Online".
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await connectivity.refresh()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Internet connection: \(connectivity.status.title)")
    }

    private func pill(phase: Double) -> some View {
        let colors = gradientColors
        let gradient = AngularGradient(
            colors: colors + [colors[0]],
            center: .center,
            startAngle: .degrees(phase),
            endAngle: .degrees(phase + 360)
        )

        return HStack(spacing: 5) {
            Text(connectivity.status.title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Image(systemName: connectivity.status.systemImage)
                .font(.system(size: 12.5, weight: .bold))
        }
        .id(connectivity.status)
        .foregroundStyle(Color.white.opacity(0.97))
        .padding(.horizontal, 10)
        .frame(width: 88, height: 34)
        .background {
            Capsule()
                .fill(Color.black.opacity(lightStyle ? 0.42 : 0.88))
        }
        .iumrahGlass(in: Capsule())
        .overlay {
            Capsule()
                .stroke(gradient, lineWidth: 4.2)
                .blur(radius: 5.5)
                .opacity(connectivity.status == .checking ? 0.26 : 0.52)
                .padding(1.5)
        }
        .overlay {
            Capsule()
                .stroke(gradient, lineWidth: 1.55)
                .opacity(connectivity.status == .checking ? 0.72 : 1)
        }
        .shadow(color: accentColor.opacity(connectivity.status == .checking ? 0.08 : 0.18), radius: 10, y: 2)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: connectivity.status)
    }

    private func phase(for date: Date) -> Double {
        guard !reduceMotion else { return 18 }
        let duration: Double
        switch connectivity.status {
        case .online: duration = 5.2
        case .offline: duration = 6.3
        case .checking: duration = 8.0
        }
        return date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: duration) / duration * 360
    }

    private var gradientColors: [Color] {
        switch connectivity.status {
        case .online:
            return [
                Color(red: 0.73, green: 0.98, blue: 0.94),
                Color(red: 0.10, green: 0.90, blue: 0.72),
                Color(red: 0.04, green: 0.82, blue: 0.91),
                Color(red: 0.40, green: 0.98, blue: 0.84)
            ]
        case .offline:
            return [
                Color(red: 1.00, green: 0.73, blue: 0.82),
                Color(red: 1.00, green: 0.14, blue: 0.48),
                Color(red: 0.98, green: 0.08, blue: 0.13),
                Color(red: 0.92, green: 0.28, blue: 0.68)
            ]
        case .checking:
            return [
                Color.white.opacity(0.80),
                Color.white.opacity(0.22),
                Color.white.opacity(0.64),
                Color.white.opacity(0.28)
            ]
        }
    }

    private var accentColor: Color {
        switch connectivity.status {
        case .online: return Color(red: 0.10, green: 0.90, blue: 0.72)
        case .offline: return Color(red: 1.00, green: 0.14, blue: 0.38)
        case .checking: return .white
        }
    }
}
