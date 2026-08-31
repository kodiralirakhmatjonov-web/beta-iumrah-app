import Foundation

struct NormalizedFlightLegCost: Encodable, Hashable {
    let totalGroupUsd: Decimal?
    let adultUsd: Decimal?
    let childUsd: Decimal?
    let infantUsd: Decimal?

    init(totalGroupUsd: Decimal) {
        self.totalGroupUsd = totalGroupUsd
        self.adultUsd = nil
        self.childUsd = nil
        self.infantUsd = nil
    }

    init(adultUsd: Decimal, childUsd: Decimal? = nil, infantUsd: Decimal? = nil) {
        self.totalGroupUsd = nil
        self.adultUsd = adultUsd
        self.childUsd = childUsd
        self.infantUsd = infantUsd
    }
}

struct ConsumerPackageQuoteRequest: Encodable {
    struct Travelers: Encodable {
        let adults: Int
        let children: Int
        let infants: Int
        let rooms: Int
    }

    struct Nights: Encodable {
        let makkah: Int
        let madinah: Int
    }

    struct Flights: Encodable {
        let outbound: NormalizedFlightLegCost
        let inbound: NormalizedFlightLegCost
    }

    struct PrimaryHotelIDs: Encodable {
        let makkah: String?
        let madinah: String?
    }

    struct HotelPriceObservations: Encodable {
        let makkah: [HotelPriceObservation]
        let madinah: [HotelPriceObservation]
    }

    let tier: String
    let hotelStars: Int
    let includeMadinah: Bool
    let totalDays: Int
    let nights: Nights
    let travelers: Travelers
    let travelStartDate: String
    let flights: Flights
    let primaryHotelIds: PrimaryHotelIDs
    let hotelPriceObservations: HotelPriceObservations?
}

struct PublicPackageQuoteResponse: Decodable, Hashable {
    let quoteId: String
    let pricingVersion: String
    let currency: String
    let pricePerPerson: Decimal
    let totalPackagePrice: Decimal
    let roomCount: Int
    let vehicleCount: Int
}

struct PackageEngineHealthResponse: Decodable {
    let ok: Bool
    let service: String
    let pricingVersion: String
    let hotelsDbConfigured: Bool
    let bookingsDbConfigured: Bool?
    let primaryHotelConfigCount: Int?
    let pricingReady: Bool?
    let makkahPricingReady: Bool?
    let madinahPricingReady: Bool?
    let fallbackResolutionEnabled: Bool?
    let flightOptionQuotingReady: Bool?
    let legacyEstimateFallbackEnabled: Bool?
    let pricingMode: String?
    let roomCategoriesReady: Bool?
    let roomCategoryCount: Int?
    let bookingRoomColumnsReady: Bool?
    let searchSessionsConfigured: Bool?
    let flightProviderConfigured: Bool?
    let serverSearchReady: Bool?
}

struct PrimaryHotelResolutionResponse: Decodable, Hashable {
    let ok: Bool
    let hotelId: String
    let roomId: String?
    let tier: String
    let stars: Int
    let city: String
    let pricingMode: String?
}

struct FlightFareObservationRequest: Encodable {
    let candidateId: String
    let amount: Decimal
    let currency: String
    let fareScope: String
    let providerId: String
    let observedAt: String
    let travelDate: String

    init(candidate: LiveFlightCandidate) throws {
        guard candidate.fareScope != .unknown else {
            throw FlightPricingBridgeError.unresolvedFareScope(candidate.providerName)
        }
        self.candidateId = candidate.id
        self.amount = candidate.observedFare
        self.currency = candidate.observedCurrency
        self.fareScope = candidate.fareScope.rawValue
        self.providerId = candidate.providerID.rawValue
        self.observedAt = Self.isoFormatter.string(from: candidate.observedAt)
        self.travelDate = Self.travelDate(for: candidate)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func travelDate(for candidate: LiveFlightCandidate) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        // The fare belongs to the departure airport's local calendar day. Using
        // the device timezone here can shift late-night departures by one day and
        // make Package Engine pair the wrong flexible-date option.
        formatter.timeZone = FlightReferenceCatalog.timeZone(for: candidate.origin) ?? TimeZone(secondsFromGMT: 0)
        return formatter.string(from: candidate.departureAt)
    }
}

struct FlightQuoteContextRequest: Encodable {
    struct Travelers: Encodable {
        let adults: Int
        let children: Int
        let infants: Int
        let rooms: Int
    }

    struct Nights: Encodable {
        let makkah: Int
        let madinah: Int
    }

    struct PrimaryHotelIDs: Encodable {
        let makkah: String?
        let madinah: String?
    }

    struct HotelPriceObservations: Encodable {
        let makkah: [HotelPriceObservation]
        let madinah: [HotelPriceObservation]
    }

    let tier: String
    let hotelStars: Int
    let includeMadinah: Bool
    let totalDays: Int
    let nights: Nights
    let travelers: Travelers
    let travelStartDate: String
    let primaryHotelIds: PrimaryHotelIDs
    let hotelPriceObservations: HotelPriceObservations?

    init(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, hotelPrices: HotelPriceSearchSnapshot? = nil) {
        let stay = TripStayPlanner.breakdown(for: trip)
        self.tier = trip.packageTier.rawValue
        self.hotelStars = trip.hotelStars
        self.includeMadinah = trip.scope == .makkahAndMadinah
        self.totalDays = stay.totalDays
        self.nights = .init(makkah: stay.makkahNights, madinah: stay.madinahNights)
        self.travelers = .init(adults: trip.adults, children: trip.children, infants: trip.infants, rooms: trip.rooms)
        self.travelStartDate = Self.dayFormatter.string(from: trip.departureDate)
        self.primaryHotelIds = .init(
            makkah: makkahHotel.id,
            madinah: trip.scope == .makkahAndMadinah ? madinahHotel?.id : nil
        )
        if let hotelPrices, hotelPrices.hasLiveRates {
            self.hotelPriceObservations = .init(makkah: hotelPrices.makkah, madinah: hotelPrices.madinah)
        } else {
            self.hotelPriceObservations = nil
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct OutboundFlightOptionsQuoteRequest: Encodable {
    let phase = "outbound"
    let context: FlightQuoteContextRequest
    let outboundCandidates: [FlightFareObservationRequest]
    let returnCandidates: [FlightFareObservationRequest]
}

struct ReturnFlightOptionsQuoteRequest: Encodable {
    let phase = "return"
    let context: FlightQuoteContextRequest
    let selectedOutbound: FlightFareObservationRequest
    let returnCandidates: [FlightFareObservationRequest]
}

struct PublicFlightOptionQuote: Decodable, Hashable {
    let candidateId: String
    let quoteId: String
    let pricingVersion: String
    let currency: String
    let pricePerPerson: Decimal
    let totalPackagePrice: Decimal
    let roomCount: Int
    let vehicleCount: Int
}

struct PublicFlightOptionsQuoteResponse: Decodable {
    let ok: Bool
    let phase: String
    let options: [PublicFlightOptionQuote]
    let referenceReturnCandidateId: String?
    let fxAsOf: String?
    let hotelPricingMode: String?
}

enum FlightPricingBridgeError: LocalizedError {
    case unresolvedFareScope(String)
    case candidateMissing(String)
    case insufficientQuotedOptions(found: Int, minimum: Int)

    var errorDescription: String? {
        switch self {
        case .unresolvedFareScope(let provider):
            return "Не удалось подтвердить тип тарифа у \(provider)."
        case .candidateMissing(let id):
            return "Flight Engine потерял найденный вариант \(id)."
        case .insufficientQuotedOptions(let found, let minimum):
            return "После проверки цены осталось \(found) вариантов; требуется минимум \(minimum)."
        }
    }
}
