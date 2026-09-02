import SwiftUI

struct SystemNotificationCard: View {
    let notification: ClientSystemNotification
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var isUnread: Bool { !notification.isRead }
    private let cardCorner: CGFloat = 24
    private let cardHeight: CGFloat = 158

    var body: some View {
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
                .foregroundStyle(topAccentColor)

                Spacer(minLength: 8)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(closeIconColor)
                        .frame(width: 28, height: 28)
                        .background(closeBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(notification.title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .tracking(-0.25)
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Label(destinationTitle, systemImage: destinationIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text(tr("Open", "Открыть", "Ochish", "Очиш"))
                        .font(.caption.weight(.bold))
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(primaryActionColor)
            }
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(cardBackground)
                .shadow(color: shadowColor, radius: 18, x: 0, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .strokeBorder(cardStroke, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("iumrah Signal. \(notification.title). \(notification.body)")
    }

    private var cardBackground: LinearGradient {
        if isUnread {
            return LinearGradient(
                colors: [
                    Color(red: 0.050, green: 0.255, blue: 0.160),
                    Color(red: 0.100, green: 0.430, blue: 0.245),
                    Color(red: 0.355, green: 0.635, blue: 0.455)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.iumrahCardBackground, Color.iumrahRaisedBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.white, Color(red: 0.965, green: 0.968, blue: 0.974)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardStroke: Color {
        isUnread ? Color.white.opacity(0.12) : Color.primary.opacity(0.06)
    }

    private var shadowColor: Color {
        isUnread ? Color.iumrahCareDark.opacity(0.16) : Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08)
    }

    private var primaryTextColor: Color {
        isUnread ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isUnread ? Color.white.opacity(0.82) : .secondary
    }

    private var topAccentColor: Color {
        isUnread ? Color.white.opacity(0.96) : Color.iumrahCareDark
    }

    private var primaryActionColor: Color {
        isUnread ? Color.white.opacity(0.96) : .primary
    }

    private var closeBackground: Color {
        isUnread
            ? Color.white.opacity(0.16)
            : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
    }

    private var closeIconColor: Color {
        isUnread ? Color.white.opacity(0.90) : .secondary
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
