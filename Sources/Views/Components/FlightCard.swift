import SwiftUI

struct FlightCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let offer: FlightOffer
    let isSelected: Bool
    var isRecommended: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center, spacing: 11) {
                AirlineLogoView(airlineCode: offer.primaryAirlineCode, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(airlineLabel)
                        .font(.headline.weight(.semibold))
                    Text(flightNumbersLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isRecommended {
                    Text(L10n.text("flight_recommended", settings.language))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.primary)
                        .foregroundStyle(Color.iumrahCardBackground)
                        .clipShape(Capsule())
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                routePoint(segment: offer.displaySegments.first, isOrigin: true, trailing: false)
                VStack(spacing: 5) {
                    Text(durationText(offer.durationMinutes))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Circle().frame(width: 4, height: 4)
                        Rectangle().frame(height: 1)
                        Image(systemName: "airplane")
                            .font(.caption2)
                        Rectangle().frame(height: 1)
                        Circle().frame(width: 4, height: 4)
                    }
                    .foregroundStyle(.tertiary)
                    Text(stopLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                routePoint(segment: offer.displaySegments.last, isOrigin: false, trailing: true)
            }

            if let layover = offer.layovers.first {
                HStack(spacing: 8) {
                    Image(systemName: layover.airportChange ? "arrow.triangle.swap" : "clock.arrow.circlepath")
                    Text(layoverSummary(layover))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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
        return FlightReferenceCatalog.airlineName(code: offer.primaryAirlineCode, fallback: offer.airline)
    }

    private var flightNumbersLabel: String {
        offer.flightNumbersSummary
    }

    private var stopLabel: String {
        offer.stops == 0
            ? L10n.text("flight_direct", settings.language)
            : L10n.format("flight_stops", settings.language, offer.stops)
    }

    @ViewBuilder
    private func routePoint(segment: FlightSegment?, isOrigin: Bool, trailing: Bool) -> some View {
        let airport = isOrigin ? segment?.origin : segment?.destination
        let date = isOrigin ? segment?.departureAt : segment?.arrivalAt
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(timeFormatter(for: airport?.timeZoneIdentifier).string(from: date ?? (isOrigin ? offer.departureAt : offer.arrivalAt)))
                .font(.title3.monospacedDigit().weight(.bold))
            Text(airport?.code ?? (isOrigin ? offer.origin : offer.destination))
                .font(.caption.weight(.semibold))
            if let city = airport?.city {
                Text(city)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 82, alignment: trailing ? .trailing : .leading)
    }

    private func layoverSummary(_ layover: FlightLayover) -> String {
        if layover.airportChange {
            return L10n.format("flight_airport_change", settings.language, layover.airport.displayCity, durationText(layover.durationMinutes))
        }
        return L10n.format("flight_layover_summary", settings.language, layover.airport.displayCity, durationText(layover.durationMinutes))
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return L10n.format("flight_minutes_short", settings.language, mins) }
        if mins == 0 { return L10n.format("flight_hours_short", settings.language, hours) }
        return L10n.format("flight_duration_short", settings.language, hours, mins)
    }

    private func timeFormatter(for identifier: String?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let identifier, let timeZone = TimeZone(identifier: identifier) { formatter.timeZone = timeZone }
        return formatter
    }
}
