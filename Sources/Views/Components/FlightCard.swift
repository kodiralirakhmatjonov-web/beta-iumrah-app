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
                    if !offer.flightNumbersSummary.isEmpty {
                        Text(flightNumbersLabel)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    Text(departureDateLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
            } else if let connection = offer.connectionAirports?.first {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(connectionSummary(connection))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            if showsFareMetadata {
                fareMetadataRow
            }

            Divider()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticketPriceTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(ticketPriceSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                PackagePriceView(
                    amount: offer.totalPackagePrice,
                    currency: offer.currency,
                    showsPerPerson: offer.fareScope == .perPassenger
                )
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

    private var ticketPriceTitle: String {
        switch settings.language {
        case .russian: return offer.fareScope == .totalParty ? "Перелёт для всех паломников" : "Тариф на пассажира"
        case .english: return offer.fareScope == .totalParty ? "Flight fare for all pilgrims" : "Fare per passenger"
        case .uzbek: return offer.fareScope == .totalParty ? "Barcha ziyoratchilar uchun aviachipta" : "Bir yo‘lovchi uchun tarif"
        case .uzbekCyrillic: return offer.fareScope == .totalParty ? "Барча зиёратчилар учун авиачипта" : "Бир йўловчи учун тариф"
        }
    }

    private var ticketPriceSubtitle: String {
        switch settings.language {
        case .russian: return "Актуальный тариф на момент поиска"
        case .english: return "Current fare at search time"
        case .uzbek: return "Qidiruv vaqtidagi joriy tarif"
        case .uzbekCyrillic: return "Қидирув вақтидаги жорий тариф"
        }
    }

    private var showsFareMetadata: Bool {
        offer.cabinClass != nil || offer.baggage != nil || offer.requiresSelfTransfer == true
    }

    private var fareMetadataRow: some View {
        HStack(spacing: 8) {
            if let cabin = offer.cabinClass {
                metadataPill(systemImage: "seat.recline.normal", text: cabinText(cabin), warning: false)
            }
            if let baggage = offer.baggage {
                if let checked = baggage.checked {
                    metadataPill(systemImage: "suitcase.fill", text: bagText(checked, checked: true), warning: false)
                } else if let carryOn = baggage.carryOn {
                    metadataPill(systemImage: "bag.fill", text: bagText(carryOn, checked: false), warning: false)
                }
            }
            if offer.requiresSelfTransfer == true {
                metadataPill(systemImage: "exclamationmark.triangle.fill", text: separateTicketsText, warning: true)
            }
            Spacer(minLength: 0)
        }
        .font(.caption2.weight(.semibold))
    }

    private func metadataPill(systemImage: String, text: String, warning: Bool) -> some View {
        Label(text, systemImage: systemImage)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background((warning ? Color.orange.opacity(0.12) : Color.iumrahRaisedBackground), in: Capsule())
            .foregroundStyle(warning ? Color.orange : Color.secondary)
    }

    private func cabinText(_ raw: String) -> String {
        switch raw.lowercased() {
        case "business": return settings.language == .russian ? "Бизнес" : (settings.language == .english ? "Business" : "Biznes")
        case "premium_economy": return settings.language == .russian ? "Премиум" : "Premium"
        case "first": return settings.language == .russian ? "Первый" : (settings.language == .english ? "First" : "Birinchi")
        default: return settings.language == .russian ? "Эконом" : (settings.language == .english ? "Economy" : "Ekonom")
        }
    }

    private func bagText(_ count: Int, checked: Bool) -> String {
        switch settings.language {
        case .russian: return checked ? "Багаж ×\(count)" : "Ручная кладь ×\(count)"
        case .english: return checked ? "Checked ×\(count)" : "Carry-on ×\(count)"
        case .uzbek: return checked ? "Bagaj ×\(count)" : "Qo‘l yuki ×\(count)"
        case .uzbekCyrillic: return checked ? "Багаж ×\(count)" : "Қўл юки ×\(count)"
        }
    }

    private var separateTicketsText: String {
        switch settings.language {
        case .russian: return "Отдельные билеты"
        case .english: return "Separate tickets"
        case .uzbek: return "Alohida chiptalar"
        case .uzbekCyrillic: return "Алоҳида чипталар"
        }
    }

    private var airlineLabel: String {
        let normalized = offer.airline.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["авиакомпания", "airline", "google flights", "skyscanner"].contains(normalized) {
            return L10n.text("flight_airline_unknown", settings.language)
        }
        return FlightReferenceCatalog.airlineName(code: offer.primaryAirlineCode, fallback: offer.airline)
    }

    private var departureDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = settings.language == .russian ? Locale(identifier: "ru_RU") : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy"
        if let zone = offer.displaySegments.first?.origin.timeZoneIdentifier, let timeZone = TimeZone(identifier: zone) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: offer.departureAt)
    }

    private var flightNumbersLabel: String {
        let prefix: String
        switch settings.language {
        case .russian: prefix = "Рейс"
        case .english: prefix = "Flight"
        case .uzbek: prefix = "Reys"
        case .uzbekCyrillic: prefix = "Рейс"
        }
        return "\(prefix) \(offer.flightNumbersSummary)"
    }

    private var stopLabel: String {
        guard offer.stops > 0 else { return L10n.text("flight_direct", settings.language) }
        let base = L10n.format("flight_stops", settings.language, offer.stops)
        if let layover = offer.layovers.first {
            let country = FlightReferenceCatalog.airportCountry(layover.airport.code)
            return [base, layover.airport.code, country].compactMap { $0 }.joined(separator: " · ")
        }
        if let connection = offer.connectionAirports?.first {
            let country = FlightReferenceCatalog.airportCountry(connection.code)
            return [base, connection.code, country].compactMap { $0 }.joined(separator: " · ")
        }
        return base
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
            Text(shortDateFormatter(for: airport?.timeZoneIdentifier).string(from: date ?? (isOrigin ? offer.departureAt : offer.arrivalAt)))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(minWidth: 82, alignment: trailing ? .trailing : .leading)
    }

    private func layoverSummary(_ layover: FlightLayover) -> String {
        let country = FlightReferenceCatalog.airportCountry(layover.airport.code)
        let place = [layover.airport.displayCity, country].compactMap { $0 }.joined(separator: ", ")
        if layover.durationMinutes > 0 {
            if layover.airportChange {
                return L10n.format("flight_airport_change", settings.language, place, durationText(layover.durationMinutes))
            }
            return L10n.format("flight_layover_summary", settings.language, place, durationText(layover.durationMinutes))
        }
        switch settings.language {
        case .russian: return layover.airportChange ? "Смена аэропорта · \(place)" : "Пересадка · \(place)"
        case .english: return layover.airportChange ? "Airport change · \(place)" : "Connection · \(place)"
        case .uzbek: return layover.airportChange ? "Aeroport almashadi · \(place)" : "Ulanish · \(place)"
        case .uzbekCyrillic: return layover.airportChange ? "Аэропорт алмашади · \(place)" : "Уланиш · \(place)"
        }
    }


    private func connectionSummary(_ airport: FlightAirportSnapshot) -> String {
        let country = FlightReferenceCatalog.airportCountry(airport.code)
        let place = [airport.displayCity, country].compactMap { $0 }.joined(separator: ", ")
        switch settings.language {
        case .russian: return "Пересадка · \(place)"
        case .english: return "Connection · \(place)"
        case .uzbek: return "Ulanish · \(place)"
        case .uzbekCyrillic: return "Уланиш · \(place)"
        }
    }

    private func durationText(_ minutes: Int) -> String {
        if minutes <= 0 {
            switch settings.language {
            case .russian: return "Время по данным источника"
            case .english: return "Duration from source"
            case .uzbek: return "Vaqt manba ma’lumotida"
            case .uzbekCyrillic: return "Вақт манба маълумотида"
            }
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return L10n.format("flight_minutes_short", settings.language, mins) }
        if mins == 0 { return L10n.format("flight_hours_short", settings.language, hours) }
        return L10n.format("flight_duration_short", settings.language, hours, mins)
    }

    private func shortDateFormatter(for identifier: String?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM"
        if let identifier, let timeZone = TimeZone(identifier: identifier) { formatter.timeZone = timeZone }
        return formatter
    }

    private func timeFormatter(for identifier: String?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let identifier, let timeZone = TimeZone(identifier: identifier) { formatter.timeZone = timeZone }
        return formatter
    }
}
