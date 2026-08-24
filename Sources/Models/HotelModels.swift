import Foundation

struct HotelsResponse: Decodable {
    let hotels: [HotelSummary]
}

struct HotelSummary: Decodable, Identifiable, Hashable {
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

struct HotelDetail: Decodable, Identifiable, Hashable {
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

struct HotelRoom: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let maxGuests: Int?
    let sizeM2: Double?
    let beds: String?
    let view: String?
    let description: String?
    let amenities: [String]
}

struct HotelImage: Decodable, Identifiable, Hashable {
    let id: String
    let provider: String?
    let category: String
    let label: String?
    let roomName: String?
    let position: Int
    let isCover: Bool
    let url: String
}
