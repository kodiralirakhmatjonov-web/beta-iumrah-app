import SwiftUI

struct FlightSearchFailureView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let message: String
    let challenge: FlightBotChallenge?
    let onRetry: () -> Void
    let onOpenChallenge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: challenge == nil ? "wifi.exclamationmark" : "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                metric(icon: "network", text: sourcesLabel)
                metric(icon: "airplane", text: flightsLabel)
                metric(icon: "building.2", text: hotelsLabel)
            }

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let challenge {
                VStack(alignment: .leading, spacing: 9) {
                    Text(L10n.format("flight_challenge_body", settings.language, challenge.providerName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.text("challenge_open", settings.language)) { onOpenChallenge() }
                        .buttonStyle(IumrahSecondaryButtonStyle())
                }
            }

            Button(action: onRetry) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.clockwise")
                    Text(continueLabel)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            DisclosureGroup(technicalLabel) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }

    private func metric(icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var title: String {
        switch settings.language {
        case .russian: return challenge == nil ? "Поиск прервался" : "Нужна проверка источника"
        case .english: return challenge == nil ? "Search was interrupted" : "A source needs verification"
        case .uzbek: return challenge == nil ? "Qidiruv uzildi" : "Manbani tekshirish kerak"
        case .uzbekCyrillic: return challenge == nil ? "Қидирув узилди" : "Манбани текшириш керак"
        }
    }

    private var subtitle: String {
        switch settings.language {
        case .russian: return "Проверьте соединение и продолжите поиск."
        case .english: return "Check your connection and continue the search."
        case .uzbek: return "Internet aloqasini tekshirib, qidiruvni davom ettiring."
        case .uzbekCyrillic: return "Интернет алоқасини текшириб, қидирувни давом эттиринг."
        }
    }

    private var bodyText: String {
        switch settings.language {
        case .russian:
            return "Генератор проверяет рейсы, выбранные отели и цены более чем в 10 сервисах. При нестабильном соединении отдельный источник может не успеть ответить. Проверьте интернет и нажмите «Продолжить поиск»."
        case .english:
            return "The generator checks flights, your selected hotels and prices across more than 10 services. With an unstable connection, an individual source may not respond in time. Check your connection and continue the search."
        case .uzbek:
            return "Generator reyslar, tanlangan mehmonxonalar va narxlarni 10 dan ortiq servisda tekshiradi. Internet beqaror bo‘lsa, ayrim manbalar vaqtida javob bermasligi mumkin. Ulanishni tekshirib, qidiruvni davom ettiring."
        case .uzbekCyrillic:
            return "Генератор рейслар, танланган меҳмонхоналар ва нархларни 10 дан ортиқ сервисда текширади. Интернет беқарор бўлса, айрим манбалар вақтида жавоб бермаслиги мумкин. Уланишни текшириб, қидирувни давом эттиринг."
        }
    }

    private var continueLabel: String {
        switch settings.language {
        case .russian: return "Продолжить поиск"
        case .english: return "Continue search"
        case .uzbek: return "Qidiruvni davom ettirish"
        case .uzbekCyrillic: return "Қидирувни давом эттириш"
        }
    }

    private var sourcesLabel: String {
        switch settings.language {
        case .russian: return "10+ источников"
        case .english: return "10+ sources"
        case .uzbek: return "10+ manba"
        case .uzbekCyrillic: return "10+ манба"
        }
    }

    private var flightsLabel: String {
        switch settings.language {
        case .russian: return "Рейсы"
        case .english: return "Flights"
        case .uzbek: return "Reyslar"
        case .uzbekCyrillic: return "Рейслар"
        }
    }

    private var hotelsLabel: String {
        switch settings.language {
        case .russian: return "Цены отелей"
        case .english: return "Hotel prices"
        case .uzbek: return "Mehmonxona narxi"
        case .uzbekCyrillic: return "Меҳмонхона нархи"
        }
    }

    private var technicalLabel: String {
        switch settings.language {
        case .russian: return "Техническая информация"
        case .english: return "Technical details"
        case .uzbek: return "Texnik ma’lumot"
        case .uzbekCyrillic: return "Техник маълумот"
        }
    }
}
