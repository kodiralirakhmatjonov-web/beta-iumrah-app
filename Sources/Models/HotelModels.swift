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

enum IumrahRoomCategory: String, Codable, CaseIterable, Hashable {
    case double = "DOUBLE"
    case triple = "TRIPLE"
    case quadruple = "QUADRUPLE"

    var titleKey: String {
        switch self {
        case .double: return "room_type_double"
        case .triple: return "room_type_triple"
        case .quadruple: return "room_type_quad"
        }
    }

    var bodyKey: String {
        switch self {
        case .double: return "room_type_double_body"
        case .triple: return "room_type_triple_body"
        case .quadruple: return "room_type_quad_body"
        }
    }
}

struct IumrahRoomCategoryOption: Codable, Identifiable, Hashable {
    let id: String
    let hotelId: String
    let category: IumrahRoomCategory
    let displayName: String
    let maxGuests: Int
    let bedConfiguration: String
    let position: Int
    let source: String
}

struct HotelRoomCategoriesResponse: Decodable {
    let ok: Bool
    let hotelId: String
    let categories: [IumrahRoomCategoryOption]
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
    let roomCategory: IumrahRoomCategory?
    let roomSource: String?

    init(
        hotel: HotelSummary,
        room: HotelRoom? = nil,
        roomCategory: IumrahRoomCategoryOption? = nil,
        authoritativeRoomId: String? = nil
    ) {
        hotelId = hotel.id
        hotelName = hotel.name
        city = hotel.city
        coverImageURL = hotel.coverImageURL
        roomId = room?.id ?? authoritativeRoomId
        roomName = room?.name ?? roomCategory?.displayName
        roomBeds = room?.beds ?? roomCategory?.bedConfiguration
        roomSizeM2 = room?.sizeM2
        roomMaxGuests = room?.maxGuests ?? roomCategory?.maxGuests
        self.roomCategory = roomCategory?.category
        roomSource = roomCategory != nil || authoritativeRoomId != nil ? "iumrahPrimary" : room != nil ? "hotelInventory" : nil
    }

    private init(
        hotelId: String,
        hotelName: String,
        city: String,
        coverImageURL: String?,
        roomId: String?,
        roomName: String?,
        roomBeds: String?,
        roomSizeM2: Double?,
        roomMaxGuests: Int?,
        roomCategory: IumrahRoomCategory?,
        roomSource: String?
    ) {
        self.hotelId = hotelId
        self.hotelName = hotelName
        self.city = city
        self.coverImageURL = coverImageURL
        self.roomId = roomId
        self.roomName = roomName
        self.roomBeds = roomBeds
        self.roomSizeM2 = roomSizeM2
        self.roomMaxGuests = roomMaxGuests
        self.roomCategory = roomCategory
        self.roomSource = roomSource
    }

    var migratedLegacyPrimaryRoom: BookingHotelSelectionSnapshot {
        guard roomCategory == nil, let roomId else { return self }
        let category: IumrahRoomCategory
        let name: String
        let beds: String
        let guests: Int
        switch roomId {
        case "iumrah-double-room":
            category = .double
            name = "Double Room"
            beds = "1 King Bed"
            guests = 2
        case "iumrah-triple-room":
            category = .triple
            name = "Triple Room"
            beds = "3 Single Beds"
            guests = 3
        case "iumrah-quad-room":
            category = .quadruple
            name = "Quadruple Room"
            beds = "4 Single Beds"
            guests = 4
        default:
            return self
        }
        return BookingHotelSelectionSnapshot(
            hotelId: hotelId,
            hotelName: hotelName,
            city: city,
            coverImageURL: coverImageURL,
            roomId: nil,
            roomName: name,
            roomBeds: beds,
            roomSizeM2: nil,
            roomMaxGuests: guests,
            roomCategory: category,
            roomSource: "iumrahPrimary"
        )
    }
}
