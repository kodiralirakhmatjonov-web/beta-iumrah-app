import SwiftUI

struct UmrahAdvisorHomeCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var showsFlow = false
    @State private var showsLanguages = false

    var body: some View {
        VStack(spacing: 10) {
            Button {
                IumrahHaptics.soft()
                showsFlow = true
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
                                .fill(Color.white.opacity(0.03))
                                .frame(width: 48, height: 48)
                                .iumrahGlass(in: Circle())
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: 1)
                        }
                    }

                    UmrahAdvisorWave(isActive: true, compact: true)
                        .frame(height: 64)
                        .padding(.vertical, 7)
                        .allowsHitTesting(false)

                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(copy.button)
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.68), in: Capsule())
                        .iumrahGlass(in: Capsule())

                        Spacer(minLength: 6)

                        Text("VOICE GUIDE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.55)
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.050, green: 0.050, blue: 0.055),
                                    Color(red: 0.105, green: 0.065, blue: 0.038)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .strokeBorder(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.34), lineWidth: 0.9)
                }
                .shadow(color: .black.opacity(0.18), radius: 26, y: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copy.title)
            .accessibilityHint(copy.subtitle)

            Button {
                IumrahHaptics.selection()
                showsLanguages = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                    Text(copy.languages)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color.primary.opacity(0.015), in: Capsule())
                .iumrahGlass(in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .fullScreenCover(isPresented: $showsFlow) {
            UmrahFlowRootView(initialStage: .start)
        }
        .sheet(isPresented: $showsLanguages) {
            UmrahLanguagesSheet()
        }
    }

    private var copy: (title: String, subtitle: String, button: String, languages: String) {
        switch settings.language {
        case .russian:
            return (
                "Начать Умру с Advisor",
                "Голосовой гид проведёт Вас пошагово через Таваф, Сафа и Марва и завершение Умры.",
                "Начать Умру",
                "Голосовой гид доступен на 10+ языках"
            )
        case .english:
            return (
                "Start Umrah with Advisor",
                "A voice guide takes you step by step through Tawaf, Safa & Marwa and the completion of Umrah.",
                "Start Umrah",
                "Voice guide available in 10+ languages"
            )
        case .uzbek:
            return (
                "Advisor bilan Umrani boshlang",
                "Ovozli gid Tavof, Safo va Marva hamda Umrani yakunlashgacha bosqichma-bosqich kuzatadi.",
                "Umrani boshlash",
                "Ovozli gid 10+ tilda mavjud"
            )
        case .uzbekCyrillic:
            return (
                "Advisor билан Умрани бошланг",
                "Овозли гид Тавоф, Сафо ва Марва ҳамда Умрани якунлашгача босқичма-босқич кузатади.",
                "Умрани бошлаш",
                "Овозли гид 10+ тилда мавжуд"
            )
        }
    }
}
