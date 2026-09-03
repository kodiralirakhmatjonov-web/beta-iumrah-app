import SwiftUI

struct UmrahAdvisorHomeCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        NavigationLink {
            UmrahFlowRootView(initialStage: .start)
        } label: {
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
                        .foregroundStyle(.white.opacity(0.52))

                        Text(copy.title)
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .tracking(-0.65)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        Text(copy.subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 46, height: 46)
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 1)
                    }
                }

                UmrahAdvisorWave(isActive: true, compact: true)
                    .frame(height: 58)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(copy.button)
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.white, in: Capsule())

                    Spacer(minLength: 6)

                    Text(copy.badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.55)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.055, green: 0.055, blue: 0.060),
                                Color(red: 0.105, green: 0.075, blue: 0.052)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.18), radius: 26, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.title)
        .accessibilityHint(copy.subtitle)
    }

    private var copy: (title: String, subtitle: String, button: String, badge: String) {
        switch settings.language {
        case .russian:
            return (
                "Начать Умру с Advisor",
                "Голосовой гид проведёт Вас пошагово через Таваф, Сафа и Марва и завершение Умры.",
                "Начать Умру",
                "VOICE GUIDE"
            )
        case .english:
            return (
                "Start Umrah with Advisor",
                "A voice guide takes you step by step through Tawaf, Safa & Marwa and the completion of Umrah.",
                "Start Umrah",
                "VOICE GUIDE"
            )
        case .uzbek:
            return (
                "Advisor bilan Umrani boshlang",
                "Ovozli gid Tavof, Safo va Marva hamda Umrani yakunlashgacha bosqichma-bosqich kuzatadi.",
                "Umrani boshlash",
                "OVOZLI GID"
            )
        case .uzbekCyrillic:
            return (
                "Advisor билан Умрани бошланг",
                "Овозли гид Тавоф, Сафо ва Марва ҳамда Умрани якунлашгача босқичма-босқич кузатади.",
                "Умрани бошлаш",
                "ОВОЗЛИ ГИД"
            )
        }
    }
}
