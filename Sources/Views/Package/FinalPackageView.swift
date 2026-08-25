import SwiftUI

struct FinalPackageView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @ObservedObject private var push = PushNotificationManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                completionHero

                if let quote = journey.quote {
                    priceCard(quote)
                } else {
                    ProgressView(L10n.text("final_calculating", settings.language))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                }

                itineraryCard
                confidenceCard
                notificationCard

                NavigationLink {
                    BookingCheckoutView()
                } label: {
                    Text(L10n.text("final_book_cta", settings.language))
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
        .iumrahInternalNavigation(progress: .ready)
        .task {
            if journey.quote == nil { await journey.buildQuote() }
            await push.refreshAndRegisterIfAllowed()
        }
    }

    private var completionHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
            Text(L10n.text("final_title", settings.language))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text(L10n.text("final_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private func priceCard(_ quote: PackageQuote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("final_price", settings.language))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            PackagePriceView(amount: quote.pricePerPerson, currency: quote.currency)
            Text(L10n.format(
                "final_total_group",
                settings.language,
                journey.trip.travelerCount,
                money(quote.totalPackagePrice, quote.currency)
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Label(L10n.text("final_price_note", settings.language), systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var itineraryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text("final_in_trip", settings.language))
                .font(.headline)
                .padding(.bottom, 8)
            if let flight = journey.selectedOutbound {
                timelineRow(icon: "airplane.departure", title: L10n.text("final_outbound", settings.language), value: "\(flight.airlinesSummary) · \(flight.flightNumbersSummary)")
            }
            if let hotel = journey.selectedHotel {
                timelineRow(icon: "building.2.fill", title: L10n.text("final_hotel", settings.language), value: hotel.name)
            }
            timelineRow(icon: "car.fill", title: L10n.text("final_transfer", settings.language), value: L10n.text("included", settings.language))
            if let flight = journey.selectedInbound {
                timelineRow(icon: "airplane.arrival", title: L10n.text("final_return", settings.language), value: "\(flight.airlinesSummary) · \(flight.flightNumbersSummary)")
            }
            timelineRow(icon: "heart.fill", title: L10n.text("final_care", settings.language), value: L10n.text("included", settings.language))
            timelineRow(icon: "doc.text.fill", title: L10n.text("final_visa", settings.language), value: L10n.text("included", settings.language))
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
            Text(L10n.text("final_before", settings.language))
                .font(.headline)
            confidenceRow(L10n.text("final_check_one", settings.language))
            confidenceRow(L10n.text("final_check_two", settings.language))
            confidenceRow(L10n.text("final_check_three", settings.language))
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
                    Text(L10n.text("notifications_title", settings.language))
                        .font(.headline)
                    Text(push.statusText(language: settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if push.lastError != nil {
                Text(L10n.text("notifications_error", settings.language))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !push.isAuthorized {
                Button {
                    Task { await push.requestAuthorization() }
                } label: {
                    Text(L10n.text("notifications_enable", settings.language))
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            } else if push.deviceToken != nil {
                Label(L10n.text("notifications_enabled", settings.language), systemImage: "checkmark.circle.fill")
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
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }
}
