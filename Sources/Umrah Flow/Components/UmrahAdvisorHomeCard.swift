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
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.032, green: 0.028, blue: 0.055),
                            Color(red: 0.019, green: 0.019, blue: 0.030),
                            Color(red: 0.030, green: 0.024, blue: 0.050)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            UmrahAdvisorHomeAura()
                .frame(height: 178)
                .opacity(0.95)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.system(size: 11, weight: .bold))
                            Text("IUMRAH ADVISOR")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.25)
                        }
                        .foregroundStyle(.white.opacity(0.58))

                        Text(copy.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(-0.60)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        Text(copy.subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 46, height: 46)
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.7)
                            }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Spacer(minLength: 104)

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .bold))
                        Text(copy.button)
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.white, in: Capsule())

                    Spacer(minLength: 6)

                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 11, weight: .semibold))
                        Text(copy.languages)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 314, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color(red: 0.55, green: 0.26, blue: 1.00).opacity(0.20), lineWidth: 0.8)
        }
        .shadow(color: Color(red: 0.28, green: 0.12, blue: 0.72).opacity(0.16), radius: 28, y: 13)
    }

    private var savedGuideLanguage: UmrahGuideLanguage {
        if let stored = UmrahGuideLanguage(rawValue: savedGuideLanguageCode) {
            return stored
        }
        return UmrahGuideLanguage.preferred(for: settings.language)
    }

    private var copy: (title: String, subtitle: String, button: String, languages: String) {
        switch settings.language {
        case .russian:
            return (
                "Начать Умру с Advisor",
                "Голосовой гид проведёт Вас пошагово через Таваф, Сафа и Марва и завершение Умры.",
                "Начать Умру",
                "10 языков"
            )
        case .english:
            return (
                "Start Umrah with Advisor",
                "A voice guide takes you step by step through Tawaf, Safa & Marwa and the completion of Umrah.",
                "Start Umrah",
                "10 languages"
            )
        case .uzbek:
            return (
                "Advisor bilan Umrani boshlang",
                "Ovozli gid Tavof, Safo va Marva hamda Umrani yakunlashgacha bosqichma-bosqich kuzatadi.",
                "Umrani boshlash",
                "10 til"
            )
        case .uzbekCyrillic:
            return (
                "Advisor билан Умрани бошланг",
                "Овозли гид Тавоф, Сафо ва Марва ҳамда Умрани якунлашгача босқичма-босқич кузатади.",
                "Умрани бошлаш",
                "10 тил"
            )
        }
    }
}

private struct UmrahAdvisorHomeAura: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 12.0 : 1.0 / 30.0)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.22 : 0.22 + (sin(time * 1.30) + 1) * 0.075

            AdvisorVoiceGradient(
                amplitude: CGFloat(pulse),
                isSpeaking: true,
                minimumHeight: 176,
                maximumHeightRatio: 0.98,
                bottomOverscan: 34
            )
            .environment(\.colorScheme, .dark)
        }
    }
}
