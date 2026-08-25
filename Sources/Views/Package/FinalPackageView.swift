import SwiftUI

struct FinalPackageView: View {
    @EnvironmentObject private var journey: JourneyStore
    @ObservedObject private var push = PushNotificationManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                completionHero

                if let quote = journey.quote {
                    priceCard(quote)
                } else {
                    ProgressView("Считаем итоговую стоимость…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                }

                itineraryCard
                confidenceCard
                notificationCard

                NavigationLink {
                    BookingCheckoutView()
                } label: {
                    Text("Забронировать мою Умру")
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(journey.quote == nil || journey.selectedOutbound == nil || journey.selectedInbound == nil)
                .opacity(journey.quote == nil || journey.selectedOutbound == nil || journey.selectedInbound == nil ? 0.45 : 1)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("Готовая поездка")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if journey.quote == nil { await journey.buildQuote() }
            await push.refreshAndRegisterIfAllowed()
        }
    }

    private var completionHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
            Text("Ваша Умра готова")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text("Мы собрали поездку по вашим датам и предпочтениям. Отель, перелёты и выбранные услуги уже связаны в один пакет.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private func priceCard(_ quote: PackageQuote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Итоговая стоимость")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            PackagePriceView(amount: quote.pricePerPerson, currency: quote.currency)
            Text("Всего за \(journey.trip.travelerCount) путешественников: \(money(quote.totalPackagePrice, quote.currency))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("Это стоимость выбранного пакета целиком", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var itineraryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("В вашей поездке")
                .font(.headline)
                .padding(.bottom, 8)
            if let flight = journey.selectedOutbound {
                timelineRow(icon: "airplane.departure", title: "Перелёт туда", value: "\(flight.airline) · \(flight.flightNumber)")
            }
            if let hotel = journey.selectedHotel {
                timelineRow(icon: "building.2.fill", title: "Отель", value: hotel.name)
            }
            timelineRow(icon: "car.fill", title: "Трансфер и услуги", value: "Включены по выбранному пакету")
            if let flight = journey.selectedInbound {
                timelineRow(icon: "airplane.arrival", title: "Перелёт обратно", value: "\(flight.airline) · \(flight.flightNumber)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func timelineRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.semibold)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Перед бронированием")
                .font(.headline)
            confidenceRow("Мы ещё раз проверим доступность выбранных вариантов")
            confidenceRow("Условия будут доступны до подтверждения")
            confidenceRow("После бронирования поездка появится во вкладке «Бронирование» и в iumrah Care")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func confidenceRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: push.isAuthorized ? "bell.badge.fill" : "bell.badge")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Уведомления о поездке")
                        .font(.headline)
                    Text(push.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if let error = push.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if !push.isAuthorized {
                Button {
                    Task { await push.requestAuthorization() }
                } label: {
                    Text("Включить уведомления")
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            } else if push.deviceToken != nil {
                Label("Уведомления подключены", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func money(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }
}
