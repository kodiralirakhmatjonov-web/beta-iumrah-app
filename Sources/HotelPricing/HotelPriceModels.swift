import Foundation

enum HotelPriceProviderID: String, Codable, Hashable, CaseIterable {
    case booking
    case expedia
}

enum HotelPriceUnit: String, Codable, Hashable {
    case totalStay
    case perRoomStay
    case perRoomNight
}

struct HotelPriceObservation: Identifiable, Codable, Hashable {
    let id: String
    let hotelId: String
    let hotelName: String
    let city: String
    let amount: Decimal
    let currency: String
    let unit: HotelPriceUnit
    let providerId: HotelPriceProviderID
    let providerName: String
    let observedAt: String
    let checkInDate: String
    let checkOutDate: String
    let sourceURL: String
}

struct HotelPriceSearchSnapshot: Codable, Hashable {
    let makkah: [HotelPriceObservation]
    let madinah: [HotelPriceObservation]

    static let empty = HotelPriceSearchSnapshot(makkah: [], madinah: [])

    var hasLiveRates: Bool { !makkah.isEmpty || !madinah.isEmpty }
}

struct HotelPriceSearchRequest: Hashable {
    let hotel: HotelSummary
    let city: String
    let checkIn: Date
    let checkOut: Date
    let adults: Int
    let children: Int
    let infants: Int
    let rooms: Int

    var totalHotelGuests: Int {
        // Search engines require child ages for exact child pricing. Until the trip
        // builder collects ages, count children as adult occupants so a live search
        // does not silently under-price the room. Infants are not counted as beds.
        max(1, adults + children)
    }
}
