import SwiftUI

struct InUmrahView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore

    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AdvisorVoiceGradient(amplitude: 0.03, isSpeaking: false, maximumHeightRatio: 0.38)
                    .opacity(0.55)
                    .allowsHitTesting(false)

                VStack(spacing: 18) {
                    Spacer()

                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 48, height: 48)
                        .iumrahGlass(in: Circle())

                    UmrahAnimatedText(
                        text: store.text("home1_title", fallback: "Your Umrah"),
                        font: .system(size: 28, weight: .bold, design: .rounded),
                        foreground: palette.textPrimary,
                        alignment: .center
                    )

                    UmrahAnimatedText(
                        text: store.text("home1_sub", fallback: "A step-by-step Umrah with iumrah Advisor."),
                        font: .system(size: 17, weight: .medium, design: .rounded),
                        foreground: palette.textSecondary,
                        alignment: .center
                    )

                    Button {
                        IumrahHaptics.success()
                        withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                            flow.stage = .start
                        }
                    } label: {
                        Label(store.text("home1_btn", fallback: "Start Umrah"), systemImage: "play.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 54)
                            .iumrahGlass(in: Capsule(), interactive: true, tint: palette.accent.opacity(0.58))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                        .frame(height: max(120, proxy.size.height * 0.22))
                }
                .padding(.horizontal, 54)
            }
        }
    }
}
