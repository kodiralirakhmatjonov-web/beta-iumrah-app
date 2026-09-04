import SwiftUI

struct UmrahAdvisorHomeCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @AppStorage("iumrah.umrahFlow.guideLanguage") private var savedGuideLanguageCode = ""

    @State private var showsLanguagePicker = false
    @State private var startsFlow = false
    @State private var selectedGuideLanguage: UmrahGuideLanguage = .uzbek

    var body: some View {
        Button {
            IumrahHaptics.selection()
            selectedGuideLanguage = savedGuideLanguage
            showsLanguagePicker = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.title)
        .accessibilityHint(copy.subtitle)
        .sheet(isPresented: $showsLanguagePicker) {
            UmrahLanguagesSheet(selection: $selectedGuideLanguage) { language in
                savedGuideLanguageCode = language.rawValue
                showsLanguagePicker = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    startsFlow = true
                }
            }
            .environmentObject(settings)
        }
        .navigationDestination(isPresented: $startsFlow) {
            UmrahFlowRootView(initialStage: .start, guideLanguage: selectedGuideLanguage)
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.025, green: 0.024, blue: 0.040),
                            Color(red: 0.015, green: 0.016, blue: 0.024),
                            Color(red: 0.025, green: 0.021, blue: 0.038)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            UmrahAdvisorHomeAura()
                .frame(height: 136)
                .opacity(0.94)
                .allowsHitTesting(false)

            // Preserve legibility while allowing the moving aura to remain visible.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.28),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.09))
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 36, height: 36)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("iumrah Advisor")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(copy.voiceGuide)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(copy.languages)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.white.opacity(0.075), in: Capsule())
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.09), lineWidth: 0.7)
                    }
                }

                Spacer(minLength: 16)

                Text(copy.title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(copy.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                Spacer(minLength: 22)

                HStack(spacing: 9) {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                    Text(copy.button)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 17)
                .frame(height: 48)
                .background(Color.white.opacity(0.96), in: Capsule())
                .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
            }
            .padding(19)
        }
        .frame(maxWidth: .infinity, minHeight: 268, maxHeight: 268, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
        }
        .shadow(color: Color(red: 0.24, green: 0.10, blue: 0.56).opacity(0.14), radius: 24, y: 12)
    }

    private var savedGuideLanguage: UmrahGuideLanguage {
        if let stored = UmrahGuideLanguage(rawValue: savedGuideLanguageCode) {
            return stored
        }
        return UmrahGuideLanguage.preferred(for: settings.language)
    }

    private var copy: (title: String, subtitle: String, button: String, languages: String, voiceGuide: String) {
        switch settings.language {
        case .russian:
            return (
                "Начать Умру",
                "Advisor проведёт Вас голосом через Таваф, Сафа и Марва и завершение Умры.",
                "Начать",
                "10 языков",
                "Голосовой гид для Умры"
            )
        case .english:
            return (
                "Start Umrah",
                "Advisor guides you by voice through Tawaf, Safa & Marwa and the completion of Umrah.",
                "Start",
                "10 languages",
                "Voice guide for Umrah"
            )
        case .uzbek:
            return (
                "Umrani boshlash",
                "Advisor Tavof, Safo va Marva hamda Umrani yakunlashgacha ovoz bilan kuzatadi.",
                "Boshlash",
                "10 til",
                "Umra uchun ovozli gid"
            )
        case .uzbekCyrillic:
            return (
                "Умрани бошлаш",
                "Advisor Тавоф, Сафо ва Марва ҳамда Умрани якунлашгача овоз билан кузатади.",
                "Бошлаш",
                "10 тил",
                "Умра учун овозли гид"
            )
        }
    }
}

private struct UmrahAdvisorHomeAura: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 12.0 : 1.0 / 30.0)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.20 : 0.18 + (sin(time * 1.18) + 1) * 0.065

            AdvisorVoiceGradient(
                amplitude: CGFloat(pulse),
                isSpeaking: true,
                minimumHeight: 132,
                maximumHeightRatio: 0.98,
                bottomOverscan: 30
            )
            .environment(\.colorScheme, .dark)
        }
    }
}
