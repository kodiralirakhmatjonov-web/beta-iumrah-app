import SwiftUI

struct AccountNotificationsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared

    private static let isoFormatter = ISO8601DateFormatter()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                hero

                if clientNotifications.inboxNotifications.isEmpty {
                    emptyState
                } else {
                    ForEach(clientNotifications.inboxNotifications) { notification in
                        notificationRow(notification)
                    }
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("iumrah Signal")
        .navigationBarTitleDisplayMode(.inline)
        .iumrahInternalNavigation()
        .refreshable {
            await clientNotifications.refresh(accountToken: account.bearerToken)
        }
        .task {
            await clientNotifications.refresh(accountToken: account.bearerToken)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("iumrah Signal")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(tr(
                        "Important updates stay here even after the push disappears.",
                        "Важные уведомления остаются здесь, даже если push уже исчез.",
                        "Muhim xabarlar push yo‘qolgandan keyin ham shu yerda qoladi.",
                        "Муҳим хабарлар push йўқолгандан кейин ҳам шу ерда қолади."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.iumrahCareDark)
                    .frame(width: 44, height: 44)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 15, style: .continuous), tint: Color.iumrahCareLight.opacity(0.14))
            }

            HStack(spacing: 10) {
                countChip(
                    value: "\(clientNotifications.unreadCount)",
                    title: tr("new", "новых", "yangi", "янги"),
                    emphasized: clientNotifications.unreadCount > 0
                )
                countChip(
                    value: "\(clientNotifications.inboxNotifications.count)",
                    title: tr("total", "всего", "jami", "жами"),
                    emphasized: false
                )
            }
        }
        .iumrahCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("No notifications yet", "Пока нет уведомлений", "Hali bildirishnomalar yo‘q", "Ҳали билдиришномалар йўқ"))
                .font(.headline)
            Text(tr(
                "When iumrah sends a Signal, it will appear here and on the Home screen.",
                "Когда iumrah отправит Signal, он появится здесь и на главной странице.",
                "iumrah Signal yuborganda, u shu yerda va Asosiy sahifada ko‘rinadi.",
                "iumrah Signal юборганда, у шу ерда ва Асосий саҳифада кўринади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func notificationRow(_ notification: ClientSystemNotification) -> some View {
        let hiddenOnHome = clientNotifications.isDismissedFromHome(notification)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(formattedDate(notification.sentAt ?? notification.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                statusChip(notification.isRead ? tr("Read", "Прочитано", "O‘qilgan", "Ўқилган") : tr("New", "Новое", "Yangi", "Янги"), unread: !notification.isRead)
            }

            Text(notification.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label(destinationTitle(notification), systemImage: destinationIcon(notification))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if hiddenOnHome {
                    Text(tr("Hidden on Home", "Скрыто на главной", "Asosiyda yashirilgan", "Асосийда яширилган"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button {
                    IumrahHaptics.selection()
                    if hiddenOnHome { clientNotifications.restoreToHome(notification) }
                    else { clientNotifications.dismissFromHome(notification) }
                } label: {
                    Text(hiddenOnHome
                         ? tr("Show on Home", "Показать на главной", "Asosiyda ko‘rsatish", "Асосийда кўрсатиш")
                         : tr("Hide on Home", "Скрыть с главной", "Asosiydan yashirish", "Асосийдан яшириш"))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .iumrahGlass(in: Capsule(), interactive: true)
                }
                .buttonStyle(.plain)
            }

            Button {
                open(notification)
            } label: {
                HStack(spacing: 8) {
                    Text(tr("Open destination", "Открыть назначение", "Manzilni ochish", "Манзилни очиш"))
                    Spacer(minLength: 6)
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: true)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 10)
    }

    private func countChip(value: String, title: String, emphasized: Bool) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(emphasized ? Color.iumrahCareDark : .secondary)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(emphasized ? Color.iumrahCareLight.opacity(0.14) : Color.iumrahRaisedBackground, in: Capsule())
    }

    private func statusChip(_ text: String, unread: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .tracking(0.3)
            .foregroundStyle(unread ? Color.iumrahCareDark : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(unread ? Color.iumrahCareLight.opacity(0.18) : Color.secondary.opacity(0.12), in: Capsule())
    }

    private func open(_ notification: ClientSystemNotification) {
        IumrahHaptics.selection()
        Task { await clientNotifications.markOpened(notification, accountToken: account.bearerToken) }
        switch notification.destination {
        case "hotels": chrome.navigate(to: .hotels)
        case "bookings": chrome.navigate(to: .booking)
        case "care": chrome.navigate(to: .care)
        case "account": chrome.navigate(to: .account)
        case "booking":
            if let bookingID = notification.destinationBookingID,
               bookings.booking(id: bookingID) != nil {
                chrome.openBooking(id: bookingID)
            } else {
                chrome.navigate(to: .booking)
            }
        default:
            chrome.navigate(to: .home)
        }
    }

    private func destinationIcon(_ notification: ClientSystemNotification) -> String {
        switch notification.destination {
        case "hotels": return "building.2.fill"
        case "bookings", "booking": return "suitcase.fill"
        case "care": return "heart.fill"
        case "account": return "person.crop.circle.fill"
        default: return "house.fill"
        }
    }

    private func destinationTitle(_ notification: ClientSystemNotification) -> String {
        switch notification.destination {
        case "hotels": return tr("Hotels", "Отели", "Mehmonxonalar", "Меҳмонхоналар")
        case "bookings": return tr("Trips", "Поездки", "Safarlar", "Сафарлар")
        case "booking": return tr("Trip details", "Детали поездки", "Safar tafsilotlari", "Сафар тафсилотлари")
        case "care": return tr("iumrah Care", "iumrah Care", "iumrah Care", "iumrah Care")
        case "account": return "Account"
        default: return tr("Home", "Главная", "Asosiy", "Асосий")
        }
    }

    private func formattedDate(_ value: String) -> String {
        guard let date = Self.isoFormatter.date(from: value) else { return value }
        let formatter = DateFormatter()
        switch settings.language {
        case .english: formatter.locale = Locale(identifier: "en_US")
        case .russian: formatter.locale = Locale(identifier: "ru_RU")
        case .uzbek: formatter.locale = Locale(identifier: "uz_UZ")
        case .uzbekCyrillic: formatter.locale = Locale(identifier: "uz_Cyrl_UZ")
        }
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
