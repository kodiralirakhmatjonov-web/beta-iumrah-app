import SwiftUI

struct BookingsHomeView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SectionHeader(
                    "Booking",
                    eyebrow: "Ваши поездки",
                    subtitle: "Статусы бронирований читаются напрямую из iumrah Booking DB."
                )

                if bookings.sessions.isEmpty {
                    if journey.quote != nil || journey.selectedHotel != nil {
                        currentDraftCard
                    }
                    emptyCard
                } else {
                    ForEach(bookings.sessions) { session in
                        NavigationLink {
                            BookingDetailView(bookingID: session.id)
                        } label: {
                            bookingCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await bookings.refreshAll() }
        .task { await bookings.refreshAll() }
    }

    private func bookingCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.id)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(statusTitle(session.booking.status))
                        .font(.title3.weight(.bold))
                }
                Spacer()
                Image(systemName: statusIcon(session.booking.status))
                    .font(.title3)
            }

            HStack(spacing: 8) {
                Text(session.booking.planId.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Capsule())
                Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Capsule())
            }

            if !session.booking.hotelNames.makkah.isEmpty {
                Label(session.booking.hotelNames.makkah, systemImage: "building.2")
                    .font(.subheadline)
            }

            HStack {
                Text(session.booking.input.startDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                PackagePriceView(amount: session.booking.perPilgrimUsd, currency: "USD")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var currentDraftCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Текущий пакет", systemImage: "suitcase.rolling")
                .font(.headline)
            if let hotel = journey.selectedHotel {
                Text(hotel.name)
                    .font(.title3.weight(.semibold))
            }
            Text("Пакет ещё не отправлен в Booking. Завершите выбор рейсов и подтвердите его на финальном экране.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "suitcase")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Бронирований пока нет")
                .font(.title3.weight(.bold))
            Text("Когда Вы отправите собранный Umrah-пакет на проверку наличия, поездка появится здесь.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .iumrahCard()
    }
}
