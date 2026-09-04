import SwiftUI

struct UmrahFlowHeader: View {
    let title: String
    let progress: Double
    let advisorStatus: String?
    let onOpenNavigator: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Image("UmrahFlowLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 42, alignment: .leading)
                    .accessibilityLabel("iumrah Project")

                Spacer(minLength: 10)

                UmrahGlassIconButton(
                    systemName: "chevron.backward",
                    foreground: palette.textPrimary,
                    accessibilityLabel: "Umrah navigation",
                    action: onOpenNavigator
                )
            }

            GeometryReader { proxy in
                let normalized = max(0, min(progress, 1))
                let width = proxy.size.width * CGFloat(normalized)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.progressTrack)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [palette.progressStart, palette.progressEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(normalized > 0 ? 16 : 0, width))
                        .shadow(color: palette.progressEnd.opacity(colorScheme == .dark ? 0.22 : 0.12), radius: 8)
                        .animation(.smooth(duration: 0.42, extraBounce: 0), value: normalized)
                }
            }
            .frame(height: 5)

            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let advisorStatus, !advisorStatus.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 5, height: 5)
                        Text(advisorStatus)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}
