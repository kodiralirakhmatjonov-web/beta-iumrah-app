import SwiftUI

/// Flight result card for the independent Ignav one-way architecture.
///
/// The large number is always the Umrah package price per pilgrim. The raw Ignav
/// ticket fare is deliberately secondary and explicitly labelled as the fare for
/// all travellers so a provider group fare can never be mistaken for package price.
struct FlightCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let offer: FlightOffer
    let isSelected: Bool
    var isRecommended: Bool = false
    var travelerCount: Int = 1
    var packagePricePerPerson: Decimal? = nil
    var referencePackagePricePerPerson: Decimal? = nil
    var usesProvisionalOppositeLeg: Bool = false
    var isPackagePriceLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            route

            if let layover = offer.layovers.first {
                HStack(spacing: 8) {
                    Image(systemName: layover.airportChange ? "arrow.triangle.swap" : "clock.arrow.circlepath")
                    Text(layoverSummary(layover)).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            } else if let connection = offer.connectionAirports?.first {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(connectionSummary(connection)).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            if showsFareMetadata { fareMetadataRow }

            Divider()
            packagePriceBlock
            ticketFareRow
        }
        .iumrahCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label(directionBadge, systemImage: offer.direction == .outbound ? "airplane.departure" : "airplane.arrival")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground, in: Capsule())

                Spacer(minLength: 8)

                Text(offer.sourceLabel.uppercased())
                    .font(.caption2.monospaced().weight(.bold))
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
                Spacer(minLength: 8)
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
        }
    }

    private var route: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(directionTitle)
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
                        Image(systemName: "airplane").font(.caption2)
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
        }
    }

    private var packagePriceBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(packagePriceTitle)
                    .font(.subheadline.weight(.semibold))
                Text(packagePriceSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 10)
            if let packagePricePerPerson {
                Text(usd(packagePricePerPerson))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else if isPackagePriceLoading {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text(calculatingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "exclamationmark.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ticketFareRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "ticket.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.iumrahRaisedBackground, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(ticketFareTitle)
                    .font(.caption.weight(.semibold))
                Text(passengerCountText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            Text(actualFareText)
                .font(.subheadline.monospacedDigit().weight(.bold))
        }
    }

    private var packagePriceTitle: String {
        switch settings.language {
        case .russian: return "Пакет на 1 человека"
        case .english: return "Package per pilgrim"
        case .uzbek: return "1 kishi uchun paket"
        case .uzbekCyrillic: return "1 киши учун пакет"
        }
    }

    private var packagePriceSubtitle: String {
        if packagePricePerPerson == nil {
            if isPackagePriceLoading {
                switch settings.language {
                case .russian: return "Отели и второй перелёт проверяются в фоне — цена появится автоматически"
                case .english: return "Hotels and the other flight leg are being checked in the background"
                case .uzbek: return "Mehmonxona va ikkinchi reys fonda tekshirilmoqda"
                case .uzbekCyrillic: return "Меҳмонхона ва иккинчи рейс фонда текширилмоқда"
                }
            }
            switch settings.language {
            case .russian: return "Пока нет подтверждённой цены отеля — билет можно выбрать, цену пакета повторим позже"
            case .english: return "Hotel price is not verified yet — ticket selection is still available"
            case .uzbek: return "Mehmonxona narxi hali tasdiqlanmadi — chiptani tanlash mumkin"
            case .uzbekCyrillic: return "Меҳмонхона нархи ҳали тасдиқланмади — чиптани танлаш мумкин"
            }
        }

        if let referencePackagePricePerPerson,
           let packagePricePerPerson,
           packagePricePerPerson > referencePackagePricePerPerson {
            let difference = packagePricePerPerson - referencePackagePricePerPerson
            switch settings.language {
            case .russian: return "+\(usd(difference))/чел. к самому выгодному пакету"
            case .english: return "+\(usd(difference))/person vs best package"
            case .uzbek: return "Eng yaxshi paketdan +\(usd(difference))/kishi"
            case .uzbekCyrillic: return "Энг яхши пакетдан +\(usd(difference))/киши"
            }
        }

        if usesProvisionalOppositeLeg {
            switch settings.language {
            case .russian: return "С отелями и услугами · обратный билет пока по минимальному найденному тарифу"
            case .english: return "Hotels + services · return leg uses the lowest fare found for now"
            case .uzbek: return "Mehmonxona va xizmatlar · qaytish hozircha eng arzon tarif bo‘yicha"
            case .uzbekCyrillic: return "Меҳмонхона ва хизматлар · қайтиш ҳозирча энг арзон тариф бўйича"
            }
        }

        switch settings.language {
        case .russian: return "Итоговая цена с выбранными перелётами, отелями и услугами"
        case .english: return "Total with selected flights, hotels and services"
        case .uzbek: return "Tanlangan reyslar, mehmonxonalar va xizmatlar bilan jami"
        case .uzbekCyrillic: return "Танланган рейслар, меҳмонхоналар ва хизматлар билан жами"
        }
    }

    private var ticketFareTitle: String {
        switch (offer.direction, settings.language) {
        case (.outbound, .russian): return "Авиабилет туда"
        case (.inbound, .russian): return "Авиабилет обратно"
        case (.outbound, .english): return "Outbound ticket"
        case (.inbound, .english): return "Return ticket"
        case (.outbound, .uzbek): return "Borish chiptasi"
        case (.inbound, .uzbek): return "Qaytish chiptasi"
        case (.outbound, .uzbekCyrillic): return "Бориш чиптаси"
        case (.inbound, .uzbekCyrillic): return "Қайтиш чиптаси"
        }
    }

    private var passengerCountText: String {
        let count = max(1, travelerCount)
        switch settings.language {
        case .russian: return "Тариф Ignav · за всех пассажиров: \(count)"
        case .english: return "Ignav fare · all travellers: \(count)"
        case .uzbek: return "Ignav tarifi · barcha yo‘lovchilar: \(count)"
        case .uzbekCyrillic: return "Ignav тарифи · барча йўловчилар: \(count)"
        }
    }

    private var directionBadge: String {
        switch (offer.direction, settings.language) {
        case (.outbound, .russian): return "Туда"
        case (.inbound, .russian): return "Обратно"
        case (.outbound, .english): return "Outbound"
        case (.inbound, .english): return "Return"
        case (.outbound, .uzbek): return "Borish"
        case (.inbound, .uzbek): return "Qaytish"
        case (.outbound, .uzbekCyrillic): return "Бориш"
        case (.inbound, .uzbekCyrillic): return "Қайтиш"
        }
    }

    private var directionTitle: String { directionBadge }

    private var calculatingText: String {
        switch settings.language {
        case .russian: return "Рассчитываем"
        case .english: return "Calculating"
        case .uzbek: return "Hisoblanmoqda"
        case .uzbekCyrillic: return "Ҳисобланмоқда"
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

    private func usd(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$\(NSDecimalNumber(decimal: amount))"
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
        case .russian: return "Самостоятельная пересадка"
        case .english: return "Self-transfer"
        case .uzbek: return "Mustaqil transfer"
        case .uzbekCyrillic: return "Мустақил трансфер"
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
