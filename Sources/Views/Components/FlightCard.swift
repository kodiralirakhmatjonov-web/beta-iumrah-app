import SwiftUI

struct FlightCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let offer: FlightOffer
    let isSelected: Bool
    var isRecommended: Bool = false
    var referenceOffer: FlightOffer? = nil
    var travelerCount: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 8) {
                Label(ticketTypeLabel, systemImage: offer.pairedLeg == nil ? "arrow.right" : "arrow.left.arrow.right")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground, in: Capsule())
                Spacer(minLength: 8)
                Text(offer.sourceLabel)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .center, spacing: 11) {
                AirlineLogoView(airlineCode: offer.primaryAirlineCode, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(airlineLabel)
                        .font(.headline.weight(.semibold))
                    Text(offer.flightNumbersSummary.isEmpty ? flightNumberPendingLabel : flightNumbersLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(offer.flightNumbersSummary.isEmpty ? Color.secondary : Color.primary)
                        .lineLimit(2)
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

            Label(outboundTitle, systemImage: "airplane.departure")
                .font(.subheadline.weight(.bold))

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

            if offer.direction == .outbound, let paired = offer.pairedLeg {
                Divider()
                pairedReturnSection(paired)
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
                Text(actualFareText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
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
        case .russian: return offer.pairedLeg == nil ? "Цена билета в одну сторону" : "Цена билета туда и обратно"
        case .english: return offer.pairedLeg == nil ? "One-way ticket price" : "Round-trip ticket price"
        case .uzbek: return offer.pairedLeg == nil ? "Bir tomonlama chipta narxi" : "Borish-qaytish chiptasi narxi"
        case .uzbekCyrillic: return offer.pairedLeg == nil ? "Бир томонлама чипта нархи" : "Бориш-қайтиш чиптаси нархи"
        }
    }

    private func pairedReturnSection(_ paired: FlightPairedLeg) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: "airplane.arrival")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Color.iumrahRaisedBackground, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(pairedReturnTitle)
                        .font(.subheadline.weight(.bold))
                    Text(pairedFlightNumbers(paired).isEmpty ? flightNumberPendingLabel : pairedFlightNumbers(paired))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(pairedDateFormatter(paired).string(from: paired.departureAt))
                    .font(.caption.weight(.semibold))
            }

            HStack(alignment: .center, spacing: 12) {
                pairedRoutePoint(paired, isOrigin: true, trailing: false)
                VStack(spacing: 5) {
                    Text(durationText(paired.durationMinutes))
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
                    Text(pairedStopLabel(paired))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                pairedRoutePoint(paired, isOrigin: false, trailing: true)
            }
        }
    }

    private var pairedReturnTitle: String {
        switch settings.language {
        case .russian: return "Обратно"
        case .english: return "Return"
        case .uzbek: return "Qaytish"
        case .uzbekCyrillic: return "Қайтиш"
        }
    }

    private var outboundTitle: String {
        switch settings.language {
        case .russian: return "Туда"
        case .english: return "Outbound"
        case .uzbek: return "Borish"
        case .uzbekCyrillic: return "Бориш"
        }
    }

    private var ticketTypeLabel: String {
        switch (offer.pairedLeg != nil, settings.language) {
        case (true, .russian): return "Билет туда и обратно"
        case (true, .english): return "Round-trip ticket"
        case (true, .uzbek): return "Borish-qaytish chiptasi"
        case (true, .uzbekCyrillic): return "Бориш-қайтиш чиптаси"
        case (false, .russian): return "Билет в одну сторону"
        case (false, .english): return "One-way ticket"
        case (false, .uzbek): return "Bir tomonlama chipta"
        case (false, .uzbekCyrillic): return "Бир томонлама чипта"
        }
    }

    private var flightNumberPendingLabel: String {
        switch settings.language {
        case .russian: return "Номер рейса уточняется у перевозчика"
        case .english: return "Flight number pending from carrier"
        case .uzbek: return "Reys raqami tashuvchidan aniqlanmoqda"
        case .uzbekCyrillic: return "Рейс рақами ташувчидан аниқланмоқда"
        }
    }

    private func pairedFlightNumbers(_ paired: FlightPairedLeg) -> String {
        var seen = Set<String>()
        let values = (paired.segments ?? []).compactMap { FlightReferenceCatalog.normalizedVerifiedFlightNumber($0.flightNumber) }
            .filter { seen.insert($0).inserted }
        let fallback = FlightReferenceCatalog.normalizedVerifiedFlightNumber(paired.flightNumber) ?? ""
        return values.isEmpty ? fallback : values.joined(separator: " · ")
    }

    private func pairedDateFormatter(_ paired: FlightPairedLeg) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM"
        if let identifier = paired.segments?.first?.origin.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) { formatter.timeZone = timeZone }
        return formatter
    }

    private func pairedTimeFormatter(_ paired: FlightPairedLeg) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let identifier = paired.segments?.first?.origin.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) { formatter.timeZone = timeZone }
        return formatter
    }

    @ViewBuilder
    private func pairedRoutePoint(_ paired: FlightPairedLeg, isOrigin: Bool, trailing: Bool) -> some View {
        let segment = isOrigin ? paired.segments?.first : paired.segments?.last
        let airport = isOrigin ? segment?.origin : segment?.destination
        let date = isOrigin ? (segment?.departureAt ?? paired.departureAt) : (segment?.arrivalAt ?? paired.arrivalAt)
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(timeFormatter(for: airport?.timeZoneIdentifier).string(from: date))
                .font(.title3.monospacedDigit().weight(.bold))
            Text(airport?.code ?? (isOrigin ? paired.origin : paired.destination))
                .font(.caption.weight(.semibold))
            if let city = airport?.city {
                Text(city)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(shortDateFormatter(for: airport?.timeZoneIdentifier).string(from: date))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 82, alignment: trailing ? .trailing : .leading)
    }

    private func pairedStopLabel(_ paired: FlightPairedLeg) -> String {
        guard paired.stops > 0 else { return L10n.text("flight_direct", settings.language) }
        let base = L10n.format("flight_stops", settings.language, paired.stops)
        guard let airport = paired.segments?.dropLast().first?.destination else { return base }
        let country = FlightReferenceCatalog.airportCountry(airport.code)
        return [base, airport.code, country].compactMap { $0 }.joined(separator: " · ")
    }

    private var ticketPriceSubtitle: String {
        switch settings.language {
        case .russian: return isRecommended ? "За всех пассажиров · самый дешёвый найденный" : "За всех пассажиров · \(relativePriceText) к самому дешёвому"
        case .english: return isRecommended ? "All passengers · lowest fare found" : "All passengers · \(relativePriceText) vs lowest"
        case .uzbek: return isRecommended ? "Barcha yo‘lovchilar · eng arzon topilgan" : "Barcha yo‘lovchilar · eng arzonga \(relativePriceText)"
        case .uzbekCyrillic: return isRecommended ? "Барча йўловчилар · энг арзон топилган" : "Барча йўловчилар · энг арзонга \(relativePriceText)"
        }
    }

    private var actualFareText: String {
        guard let amount = partyFare(for: offer) else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = offer.currency.uppercased()
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(NSDecimalNumber(decimal: amount)) \(offer.currency.uppercased())"
    }

    private var relativePriceAmount: Decimal {
        guard let referenceOffer,
              referenceOffer.currency.caseInsensitiveCompare(offer.currency) == .orderedSame,
              let current = partyFare(for: offer),
              let baseline = partyFare(for: referenceOffer) else { return 0 }
        return current - baseline
    }

    private var relativePriceText: String {
        let amount = relativePriceAmount
        let rounded = NSDecimalNumber(decimal: amount).doubleValue.rounded()
        let absolute = Int(abs(rounded))
        let sign = rounded < 0 ? "−" : "+"
        let currency: String
        switch offer.currency.uppercased() {
        case "USD": currency = "$"
        case "EUR": currency = "€"
        case "GBP": currency = "£"
        case "SAR": currency = "SAR"
        case "AED": currency = "AED"
        default: currency = offer.currency.uppercased()
        }
        return "\(sign)\(absolute) \(currency)"
    }

    private func partyFare(for value: FlightOffer) -> Decimal? {
        guard let amount = value.fareAmount, let scope = value.fareScope, amount > 0 else { return nil }
        switch scope {
        case .totalParty: return amount
        case .perPassenger: return amount * Decimal(max(1, travelerCount))
        case .unknown: return nil
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
