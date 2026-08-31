import SwiftUI

struct FlightChallengeSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let challenge: FlightBotChallenge
    let onCompleted: () -> Void
    let onCancelled: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

                Divider()

                FlightChallengeWebView(challenge: challenge)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(challenge.providerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeTitle) {
                        FlightBotDeviceSessionPool.shared.verificationCancelled(challenge)
                        FlightBotChallengeCenter.shared.clear(challenge)
                        dismiss()
                        onCancelled()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneTitle) {
                        dismiss()
                        onCompleted()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var title: String {
        switch settings.language {
        case .russian: return "Подтвердите поиск у \(challenge.providerName)"
        case .english: return "Confirm the search with \(challenge.providerName)"
        case .uzbek: return "\(challenge.providerName) qidiruvini tasdiqlang"
        case .uzbekCyrillic: return "\(challenge.providerName) қидирувини тасдиқланг"
        }
    }

    private var subtitle: String {
        switch settings.language {
        case .russian: return "Это страница самой авиакомпании. После подтверждения iumrah продолжит поиск в этой же защищённой сессии."
        case .english: return "This is the airline's own page. After confirmation, iumrah will continue in the same secure session."
        case .uzbek: return "Bu aviakompaniyaning o‘z sahifasi. Tasdiqlagach, iumrah shu xavfsiz sessiyada qidiruvni davom ettiradi."
        case .uzbekCyrillic: return "Бу авиакомпаниянинг ўз саҳифаси. Тасдиқлагандан сўнг, iumrah шу хавфсиз сессияда қидирувни давом эттиради."
        }
    }

    private var doneTitle: String {
        switch settings.language {
        case .russian: return "Продолжить"
        case .english: return "Continue"
        case .uzbek: return "Davom etish"
        case .uzbekCyrillic: return "Давом этиш"
        }
    }

    private var closeTitle: String {
        switch settings.language {
        case .russian: return "Закрыть"
        case .english: return "Close"
        case .uzbek: return "Yopish"
        case .uzbekCyrillic: return "Ёпиш"
        }
    }
}
