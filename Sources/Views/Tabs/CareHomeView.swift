import SwiftUI

struct CareHomeView: View {
    @EnvironmentObject private var bookings: BookingStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                careHero

                if bookings.sessions.isEmpty {
                    lockedChatCard
                } else {
                    SectionHeader(
                        "Ваши чаты",
                        eyebrow: "Поддержка поездки",
                        subtitle: "Каждый чат связан с конкретной поездкой, поэтому не нужно заново объяснять маршрут, даты и отель."
                    )
                    ForEach(bookings.sessions) { session in
                        NavigationLink {
                            BookingChatView(bookingID: session.id)
                        } label: {
                            chatCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                }

                supportPromise
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await bookings.refreshAll() }
    }

    private var careHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 74)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Spacer()
                Text("ПЕРВЫЙ ГОД БЕСПЛАТНО")
                    .font(.caption2.weight(.bold))
                    .tracking(0.45)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("iumrah Care")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Заботится на каждом этапе вашей поездки")
                    .font(.title3.weight(.semibold))
                Text("Отвечает на вопросы, помогает решать проблемы поездки и видит контекст вашего бронирования. В течение первого года сервис доступен бесплатно каждому паломнику.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 18) {
                careMetric(icon: "message.fill", text: "Ответы")
                careMetric(icon: "bell.fill", text: "События")
                careMetric(icon: "heart.fill", text: "Забота")
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard(dark: true)
    }

    private func careMetric(icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.headline)
            Text(text).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chatCard(_ session: StoredBookingSession) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

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
            Label("Чат откроется после бронирования", systemImage: "lock.fill")
                .font(.headline)
            Text("Соберите поездку и отправьте её на проверку доступности. После этого поддержка будет связана с вашим бронированием.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var supportPromise: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Самостоятельно — не значит одному.")
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text("До поездки, в дороге и во время Умры iumrah Care остаётся одной линией поддержки, связанной с вашей поездкой.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }
}
