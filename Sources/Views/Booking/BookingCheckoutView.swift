import SwiftUI

struct BookingCheckoutView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @State private var createdSession: StoredBookingSession?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(
                    "Отправить на бронирование",
                    eyebrow: "Booking",
                    subtitle: "Создадим защищённый номер поездки и отправим пакет на проверку наличия. После этого откроется iumrah Care."
                )

                if let createdSession {
                    successCard(createdSession)
                } else {
                    packageCard
                    routeCard
                    createCard
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var packageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(journey.trip.packageTier.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            if let quote = journey.quote {
                PackagePriceView(amount: quote.pricePerPerson, currency: quote.currency)
                Text("Итого за \(journey.trip.travelerCount) путешественников: \(money(quote.totalPackagePrice, quote.currency))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let hotel = journey.selectedHotel {
                Label(hotel.name, systemImage: "building.2")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Маршрут", systemImage: "airplane")
                .font(.headline)
            Text("\(journey.trip.originCode) → \(journey.trip.outboundDestinationCode)")
                .font(.title3.weight(.bold))
            Text("Обратно: \(journey.trip.returnOriginCode) → \(journey.trip.originCode)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let outbound = journey.selectedOutbound, let inbound = journey.selectedInbound {
                Text("\(outbound.airline) \(outbound.flightNumber) · \(inbound.airline) \(inbound.flightNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Что произойдёт")
                .font(.headline)
            Text("Пакет получит номер IUM-…, статус начнётся с проверки наличия. Этот же номер и защищённый токен используются для Booking и Live Chat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = bookings.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await createBooking() }
            } label: {
                if bookings.isCreating {
                    ProgressView().tint(.white)
                } else {
                    Text("Отправить на проверку наличия")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(bookings.isCreating || !canCreate)
            .opacity(canCreate ? 1 : 0.45)
        }
        .iumrahCard()
    }

    private func successCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
            Text("Booking создан")
                .font(.title2.weight(.bold))
            Text(session.id)
                .font(.headline.monospaced())
            Text("Сейчас iumrah проверяет наличие компонентов пакета. Статус и чат доступны во вкладках Booking и Care.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Открыть Booking") {
                chrome.navigate(to: .booking)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            Button("Открыть iumrah Care") {
                chrome.navigate(to: .care)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var canCreate: Bool {
        journey.quote != nil && journey.selectedHotel != nil && journey.selectedOutbound != nil && journey.selectedInbound != nil
    }

    private func createBooking() async {
        guard let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound,
              let inbound = journey.selectedInbound,
              let quote = journey.quote else { return }
        createdSession = await bookings.create(
            trip: journey.trip,
            hotel: hotel,
            outbound: outbound,
            inbound: inbound,
            quote: quote
        )
    }

    private func money(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }
}
