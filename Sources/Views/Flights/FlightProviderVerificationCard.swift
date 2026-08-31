import SwiftUI

struct FlightProviderVerificationCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let challenge: FlightBotChallenge
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(.thinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(bodyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(actionTitle, action: onOpen)
                .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var title: String {
        switch settings.language {
        case .russian: return "\(challenge.providerName) просит подтверждение"
        case .english: return "\(challenge.providerName) needs confirmation"
        case .uzbek: return "\(challenge.providerName) tasdiqlashni so‘ramoqda"
        case .uzbekCyrillic: return "\(challenge.providerName) тасдиқлашни сўрамоқда"
        }
    }

    private var bodyText: String {
        switch settings.language {
        case .russian: return "Откроем защищённую страницу авиакомпании на этом iPhone и затем продолжим поиск автоматически. Уже найденные варианты останутся на месте."
        case .english: return "Open the airline's secure page on this iPhone, then iumrah will continue the search automatically. Existing results stay visible."
        case .uzbek: return "Shu iPhone’da aviakompaniyaning xavfsiz sahifasi ochiladi, so‘ng iumrah qidiruvni avtomatik davom ettiradi. Topilgan variantlar saqlanadi."
        case .uzbekCyrillic: return "Шу iPhone’да авиакомпаниянинг хавфсиз саҳифаси очилади, сўнг iumrah қидирувни автоматик давом эттиради. Топилган вариантлар сақланади."
        }
    }

    private var actionTitle: String {
        switch settings.language {
        case .russian: return "Продолжить поиск"
        case .english: return "Continue search"
        case .uzbek: return "Qidiruvni davom ettirish"
        case .uzbekCyrillic: return "Қидирувни давом эттириш"
        }
    }
}
