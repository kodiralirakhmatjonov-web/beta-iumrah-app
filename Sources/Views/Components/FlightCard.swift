import SwiftUI

/// Flight result card for the independent-leg Ignav architecture.
///
/// The provider fare itself is deliberately not presented as the primary number on
/// this screen. Pilgrims compare Umrah packages, so the large number is always the
/// public package price per pilgrim for the flight combination represented by the
/// current row. The raw Ignav fare remains available in FlightDetailsView and in the
/// Business pricing report.
struct FlightCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let offer: FlightOffer
    let isSelected: Bool
    var isRecommended: Bool = false
    var packagePricePerPerson: Decimal? = nil
    var isPackagePriceLoading: Bool = false
    var packagePriceContext: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            airlineHeader
            routeSection

            if let layover = offer.layovers.first {
                layoverRow(layover)
            } else if let connection = offer.connectionAirports?.first {
                connectionRow(connection)
            }

            if showsFareMetadata {
                fareMetadataRow
            }

            Divider()
            packagePriceSection
        }
        .iumrahCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.9), lineWidth: 1.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
    }

    private var topBar: some View {
        HStack(spacing: 9) {
            Label(directionLabel, systemImage: directionSystemImage)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 11)
                .frame(height: 31)
                .background(Color.iumrahRaisedBackground, in: Capsule())

            if isRecommended {
                Text(L10n.text("flight_recommended", settings.language))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(height: 31)
                    .background(Color.primary, in: Capsule())
                    .foregroundStyle(Color.iumrahCardBackground)
            }

            Spacer(minLength: 8)

            Text("IGNAV")
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }

    private var airlineHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            AirlineLogoView(airlineCode: offer.primaryAirlineCode, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(airlineLabel)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(offer.flightNumbersSummary.isEmpty ? flightNumberPendingLabel : flightNumbersLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(offer.flightNumbersSummary.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(2)

                Text(departureDateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                routePoint(segment: offer.displaySegments.first, isOrigin: true, trailing: false)

                VStack(spacing: 6) {
                    Text(durationText(offer.durationMinutes))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 5) {
                        Circle().frame(width: 4, height: 4)
                        Rectangle().frame(height: 1)
                        Image(systemName: "airplane")
                            .font(.caption)
                        Rectangle().frame(height: 1)
                        Circle().frame(width: 4, height: 4)
                    }
                    .foregroundStyle(.tertiary)

                    Text(stopLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                routePoint(segment: offer.displaySegments.last, isOrigin: false, trailing: true)
            }
        }
    }

    private var packagePriceSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(packagePriceTitle)
                    .font(.subheadline.weight(.semibold))

                Text(packagePriceSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            if let packagePricePerPerson {
                Text(packagePriceText(packagePricePerPerson))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else if isPackagePriceLoading {
                ProgressView()
                    .controlSize(.regular)
                    .frame(width: 42, height: 42)
            } else {
                Text("—")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var packagePriceTitle: String {
        switch settings.language {
        case .russian: return "Пакет на 1 человека"
        case .english: return "Package per pilgrim"
        case .uzbek: return "1 ziyoratchi uchun paket"
        case .uzbekCyrillic: return "1 зиёратчи учун пакет"
        }
    }

    private var packagePriceSubtitle: String {
        if packagePricePerPerson == nil && isPackagePriceLoading {
            switch settings.language {
            case .russian: return "Рассчитываем перелёты, отели и услуги"
            case .english: return "Calculating flights, hotels and services"
            case .uzbek: return "Parvoz, mehmonxona va xizmatlar hisoblanmoqda"
            case .uzbekCyrillic: return "Парвоз, меҳмонхона ва хизматлар ҳисобланмоқда"
            }
        }
        if let packagePriceContext, !packagePriceContext.isEmpty { return packagePriceContext }
        switch settings.language {
        case .russian: return "Итоговая цена Umrah с этим вариантом"
        case .english: return "Total Umrah price with this option"
        case .uzbek: return "Ushbu variant bilan Umrah umumiy narxi"
        case .uzbekCyrillic: return "Ушбу вариант билан Umrah умумий нархи"
        }
    }

    private func packagePriceText(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "$\(NSDecimalNumber(decimal: amount).intValue)"
    }

    private var directionLabel: String {
        switch (offer.direction, settings.language) {
        case (.outbound, .russian): return "Перелёт туда"
        case (.inbound, .russian): return "Перелёт обратно"
        case (.outbound, .english): return "Outbound flight"
        case (.inbound, .english): return "Return flight"
        case (.outbound, .uzbek): return "Borish reysi"
        case (.inbound, .uzbek): return "Qaytish reysi"
        case (.outbound, .uzbekCyrillic): return "Бориш рейси"
        case (.inbound, .uzbekCyrillic): return "Қайтиш рейси"
        }
    }

    private var directionSystemImage: String {
        offer.direction == .outbound ? "airplane.departure" : "airplane.arrival"
    }

    private var flightNumberPendingLabel: String {
        switch settings.language {
        case .russian: return "Номер рейса уточняется"
        case .english: return "Flight number pending"
        case .uzbek: return "Reys raqami aniqlanmoqda"
        case .uzbekCyrillic: return "Рейс рақами аниқланмоқда"
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
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 29)
            .background(warning ? Color.orange.opacity(0.12) : Color.iumrahRaisedBackground, in: Capsule())
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
        case .russian: return "Самостоятельная пересадка"
        case .english: return "Self-transfer"
        case .uzbek: return "Mustaqil transfer"
        case .uzbekCyrillic: return "Мустақил трансфер"
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
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM yyyy"
        if let zone = offer.displaySegments.first?.origin.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: zone) {
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
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            Text(timeFormatter(for: airport?.timeZoneIdentifier).string(from: date ?? (isOrigin ? offer.departureAt : offer.arrivalAt)))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(airport?.code ?? (isOrigin ? offer.origin : offer.destination))
                .font(.caption.weight(.bold))
            if let city = airport?.city {
                Text(city)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(shortDateFormatter(for: airport?.timeZoneIdentifier).string(from: date ?? (isOrigin ? offer.departureAt : offer.arrivalAt)))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(minWidth: 82, alignment: trailing ? .trailing : .leading)
    }

    private func layoverRow(_ layover: FlightLayover) -> some View {
        HStack(spacing: 9) {
            Image(systemName: layover.airportChange ? "arrow.triangle.swap" : "clock.arrow.circlepath")
            Text(layoverSummary(layover))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private func connectionRow(_ airport: FlightAirportSnapshot) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.triangle.branch")
            Text(connectionSummary(airport))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
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
            case .russian: return "По данным источника"
            case .english: return "From provider"
            case .uzbek: return "Manba bo‘yicha"
            case .uzbekCyrillic: return "Манба бўйича"
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
