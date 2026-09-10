import Foundation

enum HotelsShowcaseBoard: String, CaseIterable, Identifiable {
    case hotels
    case flights
    case sundayClub

    var id: String { rawValue }
}

struct StorefrontFlightLeg: Codable, Hashable {
    let airline: String
    let flightNumber: String
    let airlineCode: String
    let origin: String
    let destination: String
    let departureAt: String
    let arrivalAt: String
    let durationMinutes: Int
    let stops: Int
    let cabinClass: String

    enum CodingKeys: String, CodingKey {
        case airline
        case flightNumber = "flight_number"
        case airlineCode = "airline_code"
        case origin, destination
        case departureAt = "departure_at"
        case arrivalAt = "arrival_at"
        case durationMinutes = "duration_minutes"
        case stops
        case cabinClass = "cabin_class"
    }
}

struct StorefrontFlightBaggage: Codable, Hashable {
    let carryOn: Int?
    let checked: Int?
}

struct StorefrontFlightOption: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let priority: Int
    let currency: String
    let travelerCount: Int
    let totalFare: Double
    let perTravelerFare: Double
    let observedAt: String
    let outbound: StorefrontFlightLeg
    let inbound: StorefrontFlightLeg?
    let baggage: StorefrontFlightBaggage?
}

struct StorefrontFlightBaseline: Codable, Hashable {
    let mode: String
    let travelers: Int
    let currency: String
    let perTravelerFareUsd: Double
    let totalFareUsd: Double
    let outboundOfferID: String
    let inboundOfferID: String
    let outbound: StorefrontFlightLeg
    let inbound: StorefrontFlightLeg
    let observedAt: String
}

struct StorefrontFlightBoardResponse: Codable, Hashable {
    let ok: Bool
    let origin: String
    let generatedAt: String
    let baseline: StorefrontFlightBaseline?
    let options: [StorefrontFlightOption]
}

/// A customer-facing package price attached to one published flight row.
/// The row itself may be one-way; the preview pairs it with the complementary
/// published Saudi leg 4...8 days away and prices the complete Umrah package
/// for one pilgrim with the fixed storefront hotels.
struct StorefrontFlightPackagePreview: Hashable {
    let pricePerPerson: Decimal
    let totalPackagePrice: Decimal
    let outboundOptionID: String
    let returnOptionID: String
    let outbound: StorefrontFlightLeg
    let inbound: StorefrontFlightLeg
    let totalNights: Int
    let makkahNights: Int
    let madinahNights: Int
    let makkahHotelName: String
    let madinahHotelName: String
}

struct HotelStorefrontQuote: Hashable {
    let tier: PackageTier
    let packageQuote: PackageQuote
    let hotelNightlyUsd: Decimal
    let hotelNights: Int
    let rooms: Int
    let travelers: Int
    let flightFarePerTravelerUsd: Decimal
}

struct HotelStorefrontDiskSnapshot: Codable {
    let makkahHotels: [HotelSummary]
    let madinahHotels: [HotelSummary]
    let hotelDetails: [HotelDetail]
    let flightBoard: StorefrontFlightBoardResponse?
    let savedAt: Date
}
