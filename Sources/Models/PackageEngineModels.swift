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

    let tier: String
    let hotelStars: Int
    let includeMadinah: Bool
    let totalDays: Int
    let nights: Nights
    let travelers: Travelers
    let flights: Flights
    let primaryHotelIds: PrimaryHotelIDs
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
