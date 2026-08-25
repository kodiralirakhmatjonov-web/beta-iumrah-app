import SwiftUI

struct FlightCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let offer: FlightOffer
    let isSelected: Bool
    var isRecommended: Bool = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    if isRecommended {
                        Label(L10n.text("flight_recommended", settings.language), systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary)
                            .foregroundColor(Color.iumrahCardBackground)
                            .clipShape(Capsule())
                            .padding(.bottom, 3)
                    }
                    Text(airlineLabel)
                        .font(.headline)
                    Text(offer.flightNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                timeBlock(code: offer.origin, date: offer.departureAt, trailing: false)
                VStack(spacing: 5) {
                    Image(systemName: "airplane")
                        .font(.caption)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.tertiary)
                    Text(stopLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                timeBlock(code: offer.destination, date: offer.arrivalAt, trailing: true)
            }

            Divider()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("flight_whole_package", settings.language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(L10n.text("flight_package_contents", settings.language))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                PackagePriceView(amount: offer.totalPackagePrice, currency: offer.currency)
            }
        }
        .iumrahCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
            }
        }
    }

    private var airlineLabel: String {
        let normalized = offer.airline.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "авиакомпания" || normalized == "airline" {
            return L10n.text("flight_airline_unknown", settings.language)
        }
        return offer.airline
    }

    private var stopLabel: String {
        offer.stops == 0
            ? L10n.text("flight_direct", settings.language)
            : L10n.format("flight_stops", settings.language, offer.stops)
    }

    private func timeBlock(code: String, date: Date, trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(Self.timeFormatter.string(from: date))
                .font(.title3.monospacedDigit().weight(.bold))
            Text(code.uppercased())
                .font(.caption.weight(.semibold))
            Text(dayFormatter.string(from: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 78, alignment: trailing ? .trailing : .leading)
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        return formatter
    }
}
