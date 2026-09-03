import SwiftUI

struct SystemNotificationCard: View {
    let notification: ClientSystemNotification
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: AppSettingsStore

    private let cardCorner: CGFloat = 26
    private let cardHeight: CGFloat = 176

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.050, green: 0.255, blue: 0.160),
                            Color(red: 0.095, green: 0.420, blue: 0.240),
                            Color(red: 0.330, green: 0.610, blue: 0.435)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 10) {
                    Label {
                        Text("iumrah Signal")
                            .font(.caption.weight(.bold))
                            .tracking(0.35)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.96))

                    Spacer(minLength: 8)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(notification.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .tracking(-0.25)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.84))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Label(destinationTitle, systemImage: destinationIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Text(tr("Open", "Открыть", "Ochish", "Очиш"))
                            .font(.caption.weight(.bold))
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.96))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("iumrah Signal. \(notification.title). \(notification.body)")
    }

    private var destinationIcon: String {
        switch notification.destination {
        case "hotels": return "building.2.fill"
        case "bookings", "booking": return "suitcase.fill"
        case "care": return "heart.fill"
        case "account": return "person.crop.circle.fill"
        default: return "house.fill"
        }
    }

    private var destinationTitle: String {
        switch notification.destination {
        case "hotels": return tr("Hotels", "Отели", "Mehmonxonalar", "Меҳмонхоналар")
        case "bookings": return tr("Trips", "Поездки", "Safarlar", "Сафарлар")
        case "booking": return tr("Trip details", "Детали поездки", "Safar tafsilotlari", "Сафар тафсилотлари")
        case "care": return tr("iumrah Care", "iumrah Care", "iumrah Care", "iumrah Care")
        case "account": return "Account"
        default: return tr("Home", "Главная", "Asosiy", "Асосий")
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
