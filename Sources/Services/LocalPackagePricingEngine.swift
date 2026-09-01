import Foundation

struct LocalHotelPriceComponent: Hashable {
    enum Unit: String, Hashable {
        case totalStay
        case perRoomStay
        case perRoomNight
    }
    let amountUsd: Decimal
    let unit: Unit
    let nights: Int
    let rooms: Int
    let hotelId: String
    let roomId: String?
    let source: String
}

/// Launch pricing policy for the indicative Umrah package price.
/// Keep the existing business model: 50% markup on the complete trip cost,
/// then gross up by the 2% payment fee.
enum LocalPackagePricingEngine {
    static let packageMarkupRate = Decimal(string: "0.50")!
    static let paymentFeeRate = Decimal(string: "0.02")!
    static let publicRoundingStep = Decimal(5)

    static let visaPerTravellerUsd = Decimal(120)
    static let makkahZiyaratPerGroupUsd = Decimal(100)
    static let madinahZiyaratPerGroupUsd = Decimal(100)
    static let accompanimentWithMadinahPerGroupUsd = Decimal(300)
    static let accompanimentMakkahOnlyPerGroupUsd = Decimal(100)
    static let roadWithMadinahPerSedanUsd = Decimal(300)
    static let localWithTrainPerSedanUsd = Decimal(200)
    static let makkahOnlyPerSedanUsd = Decimal(200)
    static let haramainSarPerTraveller = Decimal(300)
    static let sarPerUsd = Decimal(string: "3.75")!
    static let sedanCapacity = 3

    static func calculate(
        trip: TripDraft,
        journeyFareUsd: Decimal,
        journeyScope: FlightFareScope,
        makkahHotel: LocalHotelPriceComponent,
        madinahHotel: LocalHotelPriceComponent?
    ) throws -> PackageQuote {
        let travelers = max(1, trip.travelerCount)
        let vehicles = max(1, Int(ceil(Double(travelers) / Double(sedanCapacity))))
        let stay = TripStayPlanner.breakdown(for: trip)

        // Ignav flexible search already returns one price for the complete ordered
        // outbound + return/open-jaw itinerary. Consume it exactly once.
        let flights = try groupFare(journeyFareUsd, scope: journeyScope, travelers: travelers)
        let hotels = hotelCost(makkahHotel)
            + (trip.scope == .makkahAndMadinah ? hotelCost(madinahHotel) : 0)
        let visa = visaPerTravellerUsd * Decimal(travelers)
        let mealTravellers = max(0, trip.adults + trip.children)
        let meals = mealRate(trip.packageTier) * Decimal(max(1, stay.totalDays)) * Decimal(mealTravellers)

        let includeMadinah = trip.scope == .makkahAndMadinah
        let usesTrain = includeMadinah && (trip.packageTier == .comfort || trip.packageTier == .luxury)
        let transfer = includeMadinah
            ? (usesTrain ? localWithTrainPerSedanUsd : roadWithMadinahPerSedanUsd) * Decimal(vehicles)
            : makkahOnlyPerSedanUsd * Decimal(vehicles)
        let intercity = usesTrain ? (haramainSarPerTraveller / sarPerUsd) * Decimal(travelers) : 0
        let guide = includeMadinah ? accompanimentWithMadinahPerGroupUsd : accompanimentMakkahOnlyPerGroupUsd
        let ziyarat = makkahZiyaratPerGroupUsd + (includeMadinah ? madinahZiyaratPerGroupUsd : 0)

        let totalCost = flights + hotels + visa + meals + transfer + intercity + guide + ziyarat
        guard totalCost > 0 else { throw LocalPricingError.invalidComponents }

        let baseSelling = totalCost + totalCost * packageMarkupRate
        let calculatedSelling = baseSelling / (1 - paymentFeeRate)
        let perPerson = roundPublic(calculatedSelling / Decimal(travelers))
        let total = perPerson * Decimal(travelers)
        return PackageQuote(
            totalPackagePrice: total,
            pricePerPerson: perPerson,
            currency: "USD",
            isEstimated: false,
            quoteId: "local-\(UUID().uuidString.lowercased())"
        )
    }

    private static func groupFare(_ amount: Decimal, scope: FlightFareScope, travelers: Int) throws -> Decimal {
        guard amount > 0 else { throw LocalPricingError.invalidFlightFare }
        switch scope {
        case .totalParty: return amount
        case .perPassenger: return amount * Decimal(travelers)
        case .unknown: throw LocalPricingError.invalidFlightFare
        }
    }

    private static func hotelCost(_ value: LocalHotelPriceComponent?) -> Decimal {
        guard let value else { return 0 }
        switch value.unit {
        case .totalStay: return value.amountUsd
        case .perRoomStay: return value.amountUsd * Decimal(max(1, value.rooms))
        case .perRoomNight: return value.amountUsd * Decimal(max(1, value.rooms)) * Decimal(max(1, value.nights))
        }
    }

    private static func mealRate(_ tier: PackageTier) -> Decimal {
        switch tier {
        case .economy, .standard: return 15
        case .comfort: return 50
        case .luxury: return 100
        }
    }

    private static func roundPublic(_ value: Decimal) -> Decimal {
        let number = NSDecimalNumber(decimal: value / publicRoundingStep).doubleValue
        return Decimal(max(1, Int(number.rounded()))) * publicRoundingStep
    }
}

enum LocalPricingError: LocalizedError {
    case invalidFlightFare
    case missingHotelPrice(String)
    case invalidComponents

    var errorDescription: String? {
        switch self {
        case .invalidFlightFare: return "Не удалось получить текущую стоимость выбранного перелёта."
        case .missingHotelPrice(let city): return "Не удалось получить текущую цену Primary Hotel в городе \(city). Повторите поиск или выберите другой отель."
        case .invalidComponents: return "Компоненты пакета неполные. Повторите расчёт."
        }
    }
}
