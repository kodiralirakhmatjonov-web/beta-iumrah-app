import SwiftUI

struct AfterUmrahView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AdvisorVoiceGradient(amplitude: 0.04, isSpeaking: false, maximumHeightRatio: 0.42)
                    .opacity(0.60)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 18) {
                        Spacer(minLength: 32)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(palette.accent)
                            .symbolEffect(.bounce, value: flow.stage)

                        UmrahAnimatedText(
                            text: store.text("home2_3title", fallback: "Umrah completed"),
                            font: .system(size: 30, weight: .bold, design: .rounded),
                            foreground: palette.textPrimary,
                            alignment: .center
                        )

                        UmrahAnimatedText(
                            text: store.text("home2_3_subtitle", fallback: "May Allah accept your Umrah and your duas."),
                            font: .system(size: 17, weight: .medium, design: .rounded),
                            foreground: palette.textSecondary,
                            alignment: .center,
                            lineSpacing: 5
                        )

                        Button {
                            IumrahHaptics.success()
                            onFinish()
                        } label: {
                            Label(UmrahFlowCopy.done(store.guideLanguage), systemImage: "checkmark")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .frame(height: 54)
                                .iumrahGlass(in: Capsule(), interactive: true, tint: palette.accent.opacity(0.58))
                        }
                        .buttonStyle(.plain)

                        Button {
                            IumrahHaptics.selection()
                            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                                flow.reset()
                            }
                        } label: {
                            Text(store.text("home_3_btn3", fallback: "Start another Umrah"))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.textPrimary)
                                .padding(.horizontal, 18)
                                .frame(height: 46)
                                .iumrahGlass(in: Capsule(), interactive: true)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: max(130, proxy.size.height * 0.24))
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 44)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}
