import SwiftUI

struct BookingsHomeView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                builderHero

                if !bookings.sessions.isEmpty {
                    SectionHeader(
                        "Ваши поездки",
                        eyebrow: "Бронирование",
                        subtitle: "Все созданные поездки, их статусы и поддержка остаются в одном месте."
                    )

                    ForEach(bookings.sessions) { session in
                        NavigationLink {
                            BookingDetailView(bookingID: session.id)
                        } label: {
                            bookingCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    noBookingsCard
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await bookings.refreshAll() }
        .task { await bookings.refreshAll() }
        .navigationDestination(isPresented: $chrome.shouldStartTripBuilder) {
            TripBuilderView()
        }
    }

    private var builderHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("НОВАЯ ПОЕЗДКА")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text("Соберите свою Умру")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Circle())
            }

            Text("Выберите даты, людей и уровень поездки. Затем iumrah предложит отель и найдёт подходящие перелёты с итоговой стоимостью всего пакета.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                chrome.shouldStartTripBuilder = true
                IumrahHaptics.selection()
            } label: {
                Text("Создать мою Умру")
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            Label("До бронирования Вы увидите итоговую стоимость", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
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
                Text(localizedPlan(session.booking.planId))
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

    private var noBookingsCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "suitcase")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("Бронирований пока нет")
                    .font(.headline)
                Text("После подтверждения первая поездка появится здесь.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .iumrahCard()
    }

    private func localizedPlan(_ value: String) -> String {
        switch value.lowercased() {
        case "economy": return "Эконом"
        case "standard": return "Стандарт"
        case "comfort": return "Комфорт"
        case "luxury": return "Люкс"
        default: return value
        }
    }
}
