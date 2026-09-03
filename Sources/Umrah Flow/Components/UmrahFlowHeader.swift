import SwiftUI

struct UmrahFlowHeader: View {
    let title: String
    let progress: Double
    let showsModeToggle: Bool
    let isModeBarVisible: Bool
    let onToggleModeBar: () -> Void
    let onOpenNavigator: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("iumrah")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .tracking(-0.6)
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer(minLength: 8)

                if showsModeToggle {
                    UmrahGlassIconButton(
                        systemName: isModeBarVisible ? "line.3.horizontal.decrease" : "line.3.horizontal",
                        foreground: .white,
                        accent: Color(red: 0.96, green: 0.38, blue: 0.04),
                        accessibilityLabel: isModeBarVisible ? "Hide mode bar" : "Show mode bar",
                        action: onToggleModeBar
                    )
                    .transition(.scale.combined(with: .opacity))
                }

                UmrahGlassIconButton(
                    systemName: "chevron.backward",
                    foreground: .white,
                    accessibilityLabel: "Umrah navigation",
                    action: onOpenNavigator
                )
            }

            GeometryReader { proxy in
                let normalized = max(0, min(progress, 1))
                let width = proxy.size.width * CGFloat(normalized)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.055))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.66, blue: 0.22),
                                    Color(red: 0.96, green: 0.38, blue: 0.04)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(normalized > 0 ? 22 : 0, width))
                        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: normalized)
                }
                .iumrahGlass(in: Capsule())
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
