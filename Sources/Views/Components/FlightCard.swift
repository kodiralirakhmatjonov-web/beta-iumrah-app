import SwiftUI

/// Consumer flight card inspired by Expedia Packages.
///
/// The customer never sees a raw supplier fare as the dominant number. The primary
/// value is always the complete iumrah package price per pilgrim for this flight
/// combination. The card also shows the full package total and the delta versus the
/// cheapest package option, mirroring the mental model used by package OTAs.
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
        VStack(alignment: .leading, spacing: 18) {
            topRow
            routeDetails
            Divider().opacity(0.7)
            bottomMeta
        }
        .padding(18)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(isSelected ? Color.primary : Color.primary.opacity(0.10), lineWidth: isSelected ? 1.6 : 1)
        }
        .shadow(color: Color.primary.opacity(0.045), radius: 14, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 14) {
            AirlineLogoView(airlineCode: offer.primaryAirlineCode, size: 38)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(time(offer.departureAt))
                    routeLine
                    Text(time(offer.arrivalAt))
                    if arrivesNextDay {
                        Text("+1")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                            .baselineOffset(8)
                    }
                }
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()

                Text("\(airportCity(offer.origin)) (\(offer.origin)) – \(airportCity(offer.destination)) (\(offer.destination))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(offer.airlinesSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            packagePriceColumn
        }
    }

    private var packagePriceColumn: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if let price = packagePricePerPerson {
                Text(deltaDisplay)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(deltaLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)

                Text("\(usd(price)) \(perPilgrimPackageLabel)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)

                Text("\(usd(price * Decimal(max(1, travelerCount)))) \(packageTotalLabel)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            } else if isPackagePriceLoading {
                ProgressView()
                    .controlSize(.small)
                Text(calculatingLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(priceUnavailableLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(minWidth: 124, alignment: .trailing)
    }

    private var routeDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(durationText(offer.durationMinutes)) · \(stopLabel)")
                    .font(.subheadline.weight(.semibold))

                if isRecommended {
                    Text(recommendedLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary)
                        .foregroundStyle(Color.iumrahCardBackground)
                        .clipShape(Capsule())
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                }
            }

            if let layover = offer.layovers.first {
                Text(layoverText(layover))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let connection = offer.connectionAirports?.first {
                Text(connectionText(connection))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !offer.flightNumbersSummary.isEmpty {
                Text(offer.flightNumbersSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var bottomMeta: some View {
        HStack(spacing: 12) {
            Label(cabinLabel, systemImage: "seatbelt")
            if let baggage = offer.baggage {
                if let carry = baggage.carryOn, carry > 0 {
                    Label("\(carry)", systemImage: "bag")
                }
                if let checked = baggage.checked, checked > 0 {
                    Label("\(checked)", systemImage: "suitcase")
                }
            }
            Spacer(minLength: 8)
            Text(offer.sourceLabel)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private var routeLine: some View {
        HStack(spacing: 3) {
            Rectangle().frame(width: 16, height: 1.5)
            Circle().frame(width: 6, height: 6)
            Rectangle().frame(width: 16, height: 1.5)
        }
        .foregroundStyle(.secondary)
    }

    private var packageDelta: Decimal? {
        guard let current = packagePricePerPerson,
              let baseline = referencePackagePricePerPerson else { return nil }
        return current > baseline ? current - baseline : 0
    }

    private var arrivesNextDay: Bool {
        let calendar = Calendar(identifier: .gregorian)
        return !calendar.isDate(offer.departureAt, inSameDayAs: offer.arrivalAt)
    }

    private var stopLabel: String {
        switch settings.language {
        case .russian:
            return offer.stops == 0 ? "прямой" : offer.stops == 1 ? "1 пересадка" : "\(offer.stops) пересадки"
        case .english:
            return offer.stops == 0 ? "nonstop" : offer.stops == 1 ? "1 stop" : "\(offer.stops) stops"
        case .uzbek:
            return offer.stops == 0 ? "to‘g‘ridan-to‘g‘ri" : "\(offer.stops) ta to‘xtash"
        case .uzbekCyrillic:
            return offer.stops == 0 ? "тўғридан-тўғри" : "\(offer.stops) та тўхташ"
        }
    }

    private var recommendedLabel: String {
        switch settings.language {
        case .russian: return "Рекомендуем"
        case .english: return "Recommended"
        case .uzbek: return "Tavsiya"
        case .uzbekCyrillic: return "Тавсия"
        }
    }

    private var deltaDisplay: String {
        guard let delta = packageDelta else { return usd(0) }
        return "+\(usd(delta))"
    }

    private var deltaLabel: String {
        switch settings.language {
        case .russian: return "к пакету / 1 человек"
        case .english: return "package difference / traveler"
        case .uzbek: return "paket farqi / 1 kishi"
        case .uzbekCyrillic: return "пакет фарқи / 1 киши"
        }
    }

    private var perPilgrimPackageLabel: String {
        switch settings.language {
        case .russian: return "пакет / 1 человек"
        case .english: return "package / traveler"
        case .uzbek: return "paket / 1 kishi"
        case .uzbekCyrillic: return "пакет / 1 киши"
        }
    }

    private var packageTotalLabel: String {
        switch settings.language {
        case .russian: return "пакет всего"
        case .english: return "package total"
        case .uzbek: return "jami paket"
        case .uzbekCyrillic: return "жами пакет"
        }
    }

    private var calculatingLabel: String {
        switch settings.language {
        case .russian: return "считаем пакет"
        case .english: return "calculating package"
        case .uzbek: return "paket hisoblanmoqda"
        case .uzbekCyrillic: return "пакет ҳисобланмоқда"
        }
    }

    private var priceUnavailableLabel: String {
        switch settings.language {
        case .russian: return "цена пакета пока недоступна"
        case .english: return "package price unavailable"
        case .uzbek: return "paket narxi hozircha yo‘q"
        case .uzbekCyrillic: return "пакет нархи ҳозирча йўқ"
        }
    }

    private var cabinLabel: String {
        let value = offer.cabinClass?.lowercased() ?? "economy"
        switch (value, settings.language) {
        case ("business", .russian): return "Бизнес"
        case ("first", .russian): return "Первый"
        case ("premium_economy", .russian): return "Премиум эконом"
        case (_, .russian): return "Эконом"
        case ("business", .english): return "Business"
        case ("first", .english): return "First"
        case ("premium_economy", .english): return "Premium economy"
        case (_, .english): return "Economy"
        case ("business", .uzbek), ("business", .uzbekCyrillic): return "Business"
        case ("first", .uzbek), ("first", .uzbekCyrillic): return "First"
        case ("premium_economy", .uzbek), ("premium_economy", .uzbekCyrillic): return "Premium economy"
        default: return "Economy"
        }
    }

    private func layoverText(_ layover: FlightLayover) -> String {
        let city = layover.airport.displayCity
        switch settings.language {
        case .russian: return "Пересадка · \(city) (\(layover.airport.code))"
        case .english: return "Layover · \(city) (\(layover.airport.code))"
        case .uzbek: return "To‘xtash · \(city) (\(layover.airport.code))"
        case .uzbekCyrillic: return "Тўхташ · \(city) (\(layover.airport.code))"
        }
    }

    private func connectionText(_ airport: FlightAirportSnapshot) -> String {
        switch settings.language {
        case .russian: return "Пересадка · \(airport.displayCity) (\(airport.code))"
        case .english: return "Connection · \(airport.displayCity) (\(airport.code))"
        case .uzbek: return "Ulanish · \(airport.displayCity) (\(airport.code))"
        case .uzbekCyrillic: return "Уланиш · \(airport.displayCity) (\(airport.code))"
        }
    }

    private func airportCity(_ code: String) -> String {
        FlightReferenceCatalog.airport(code)?.city ?? code
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = max(0, minutes) / 60
        let rest = max(0, minutes) % 60
        switch settings.language {
        case .russian: return rest == 0 ? "\(hours)ч" : "\(hours)ч \(rest)м"
        case .english: return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
        case .uzbek: return rest == 0 ? "\(hours)soat" : "\(hours)soat \(rest)d"
        case .uzbekCyrillic: return rest == 0 ? "\(hours)соат" : "\(hours)соат \(rest)д"
        }
    }

    private func usd(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "US$"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: number) ?? "US$\(number.stringValue)"
    }
}
