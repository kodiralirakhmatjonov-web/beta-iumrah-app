import Foundation

struct HotelsResponse: Decodable {
    let hotels: [HotelSummary]
}

struct HotelSummary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let stars: Int?
    let rating: Double?
    let reviewCount: Int?
    let status: String
    let coverImageURL: String?
    let imageCount: Int
    let roomCount: Int
    let updatedAt: String
}

struct HotelDetailResponse: Decodable {
    let ok: Bool
    let hotel: HotelDetail
}

struct HotelDetail: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let country: String
    let propertyType: String?
    let stars: Int?
    let rating: Double?
    let ratingScale: Double?
    let reviewCount: Int?
    let address: String
    let description: String
    let latitude: Double?
    let longitude: Double?
    let checkIn: String?
    let checkOut: String?
    let googleMapsURL: String?
    let status: String
    let amenities: [String]
    let rooms: [HotelRoom]
    let images: [HotelImage]
}

struct HotelRoom: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let maxGuests: Int?
    let sizeM2: Double?
    let beds: String?
    let view: String?
    let description: String?
    let amenities: [String]
}

struct HotelImage: Codable, Identifiable, Hashable {
    let id: String
    let provider: String?
    let category: String
    let label: String?
    let roomName: String?
    let position: Int
    let isCover: Bool
    let url: String
}


struct BookingHotelSelectionSnapshot: Codable, Hashable {
    let hotelId: String
    let hotelName: String
    let city: String
    let coverImageURL: String?
    let roomId: String?
    let roomName: String?
    let roomBeds: String?
    let roomSizeM2: Double?
    let roomMaxGuests: Int?

    init(hotel: HotelSummary, room: HotelRoom? = nil) {
        hotelId = hotel.id
        hotelName = hotel.name
        city = hotel.city
        coverImageURL = hotel.coverImageURL
        roomId = room?.id
        roomName = room?.name
        roomBeds = room?.beds
        roomSizeM2 = room?.sizeM2
        roomMaxGuests = room?.maxGuests
    }
}
