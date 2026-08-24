import SwiftUI

struct FinalPackageView: View {
    @EnvironmentObject private var journey: JourneyStore
    @ObservedObject private var push = PushNotificationManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(
                    "Ваша Умра собрана",
                    eyebrow: journey.trip.packageTier.title,
                    subtitle: "Отель, перелёты и параметры поездки объединены в один пакет."
                )

                if let quote = journey.quote {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Итоговая стоимость")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        PackagePriceView(amount: quote.pricePerPerson, currency: quote.currency)
                        Text("Всего за \(journey.trip.travelerCount) путешественников: \(money(quote.totalPackagePrice, quote.currency))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if quote.isEstimated {
                            Label("Тестовый quote в beta-сборке", systemImage: "testtube.2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .iumrahCard()
                } else {
                    ProgressView("Считаем пакет…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                }

                if let hotel = journey.selectedHotel {
                    summaryRow(icon: "building.2", title: "Отель", value: hotel.name)
                }
                if let flight = journey.selectedOutbound {
                    summaryRow(icon: "airplane.departure", title: "Туда", value: "\(flight.airline) · \(flight.flightNumber)")
                }
                if let flight = journey.selectedInbound {
                    summaryRow(icon: "airplane.arrival", title: "Обратно", value: "\(flight.airline) · \(flight.flightNumber)")
                }

                notificationCard

                Button {
                    // Booking endpoint will be connected after PackageQuote API is live.
                } label: {
                    Text("Продолжить к бронированию")
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(true)
                .opacity(0.45)

                Text("Следующий backend-шаг: реальный PackageQuote → Booking → Live Chat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Пакет")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if journey.quote == nil { await journey.buildQuote() }
            await push.refreshAndRegisterIfAllowed()
        }
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: push.isAuthorized ? "bell.badge.fill" : "bell.badge")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.thinMaterial)
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
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !push.isAuthorized {
                Button {
                    Task { await push.requestAuthorization() }
                } label: {
                    Text("Включить уведомления")
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            } else if push.deviceToken != nil {
                Label("APNs зарегистрировал этот iPhone", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func summaryRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 38, height: 38)
                .background(.thinMaterial)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.semibold)).lineLimit(2)
            }
            Spacer()
        }
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
