import SwiftUI

struct SystemNotificationCard: View {
    let notification: ClientSystemNotification
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var isUnread: Bool { !notification.isRead }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Label {
                        Text("iumrah Signal")
                            .font(.caption.weight(.bold))
                            .tracking(0.45)
                    } icon: {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(topAccentColor)

                    Spacer(minLength: 8)

                    if isUnread {
                        Text(tr("New", "Новое", "Yangi", "Янги"))
                            .font(.caption2.weight(.black))
                            .tracking(0.4)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(Color.white.opacity(colorScheme == .dark ? 0.94 : 0.88), in: Capsule())
                            .foregroundStyle(Color.iumrahCareDark)
                    } else {
                        Text(tr("Read", "Прочитано", "O‘qilgan", "Ўқилган"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(readChipBackground, in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(notification.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(closeIconColor)
                    .frame(width: 28, height: 28)
                    .background(closeBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(cardStroke, lineWidth: 1)
        }
        .shadow(color: shadowColor, radius: 22, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("iumrah Signal. \(notification.title). \(notification.body)")
    }

    private var cardBackground: some ShapeStyle {
        if isUnread {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.040, green: 0.255, blue: 0.150),
                        Color(red: 0.090, green: 0.430, blue: 0.235),
                        Color(red: 0.340, green: 0.630, blue: 0.450)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [Color.iumrahCardBackground, Color.iumrahRaisedBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var cardStroke: Color {
        isUnread ? Color.white.opacity(0.12) : Color.primary.opacity(0.06)
    }

    private var shadowColor: Color {
        isUnread ? Color.iumrahCareDark.opacity(0.22) : Color.black.opacity(0.06)
    }

    private var primaryTextColor: Color {
        isUnread ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isUnread ? Color.white.opacity(0.82) : .secondary
    }

    private var topAccentColor: Color {
        isUnread ? Color.white.opacity(0.94) : Color.iumrahCareDark
    }

    private var primaryActionColor: Color {
        isUnread ? Color.white.opacity(0.96) : .primary
    }

    private var readChipBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var closeBackground: Color {
        isUnread
            ? Color.white.opacity(0.14)
            : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
    }

    private var closeIconColor: Color {
        isUnread ? Color.white.opacity(0.88) : .secondary
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
