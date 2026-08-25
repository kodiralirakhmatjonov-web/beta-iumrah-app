import SwiftUI

struct CareHomeView: View {
    @EnvironmentObject private var bookings: BookingStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SectionHeader(
                    "iumrah Care",
                    eyebrow: "Поддержка",
                    subtitle: "Ваши чаты привязаны к конкретной поездке, поэтому поддержка сразу видит контекст Booking."
                )

                if bookings.sessions.isEmpty {
                    lockedChatCard
                } else {
                    ForEach(bookings.sessions) { session in
                        NavigationLink {
                            BookingChatView(bookingID: session.id)
                        } label: {
                            chatCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                }

                careCard(
                    icon: "bell.and.waves.left.and.right.fill",
                    title: "Помощь в поездке",
                    subtitle: "Статусы, важные уведомления и поддержка по маршруту остаются связаны с Вашим Booking."
                )

                careCard(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "Одна линия поддержки",
                    subtitle: "До поездки, во время Умры и после возвращения — без повторного объяснения деталей поездки."
                )
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await bookings.refreshAll() }
    }

    private func chatCard(_ session: StoredBookingSession) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(Color.iumrahRaisedBackground)
                Image(systemName: "message.fill")
                    .font(.system(size: 19, weight: .semibold))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("iumrah Care")
                        .font(.headline)
                }
                Text(session.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(statusTitle(session.booking.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var lockedChatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Чат откроется после Booking", systemImage: "lock.fill")
                .font(.headline)
            Text("Live Chat использует защищённый token конкретного бронирования. Сначала соберите пакет и отправьте его на проверку наличия.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func careCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }
}
