import Foundation

struct BookingCreateEnvelope: Encodable {
    let lang: String
    let booking: BookingDraftRequest
}

struct BookingDraftRequest: Encodable {
    let planId: String
    let totalUsd: Double
    let perPilgrimUsd: Double
    let input: BookingInput
    let route: BookingRoute
    let stay: BookingStay
    let selection: BookingSelection
    let customization: BookingCustomization
    let includedServices: [String]
    let hotelNames: BookingHotelNames
    let flight: String
    let pilgrimProfile: BookingPilgrimProfile?
}

struct BookingPilgrimProfile: Codable, Hashable {
    let firstName: String
    let lastName: String
    let telegram: String
    let whatsapp: String

    var displayName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct BookingInput: Encodable {
    let from: String
    let originCode: String
    let arrivalAirportCode: String
    let cabinClass: String
    let preferredPlan: String
    let startDate: String
    let endDate: String
    let flexibleDays: Int
    let hotelPreference: String
    let includeMadinah: Bool
    let travelers: BookingTravelers
}

struct BookingTravelers: Codable, Hashable {
    let adults: Int
    let children: Int
    let infants: Int
    let rooms: Int

    var totalPeople: Int { adults + children + infants }
}

struct BookingRoute: Codable, Hashable {
    let originCode: String
    let outboundDestination: String
    let returnOrigin: String
}

struct BookingStay: Codable, Hashable {
    let totalDays: Int
    let totalNights: Int
    let makkahCheckIn: String
    let makkahCheckOut: String
    let makkahNights: Int
    let madinahCheckIn: String?
    let madinahCheckOut: String?
    let madinahNights: Int?
}

struct BookingSelection: Codable, Hashable {
    let flightId: String
    let makkahHotelId: String
    let madinahHotelId: String?
}

struct BookingCustomization: Codable, Hashable {
    let accompaniment: Bool
    let guideMeetingPoint: String
    let ziyaratMakkah: Bool
    let ziyaratMadinah: Bool
    let meals: Bool
    let esim: Bool
}

struct BookingHotelNames: Codable, Hashable {
    let makkah: String
    let madinah: String
}

struct BookingCreateResponse: Decodable {
    let booking: RemoteBooking
    let accessToken: String?
}

struct RemoteBooking: Codable, Identifiable, Hashable {
    let id: String
    let status: String
    let planId: String
    let totalUsd: Double
    let perPilgrimUsd: Double
    let input: BookingInputRecord
    let route: BookingRoute
    let stay: BookingStay
    let hotelNames: BookingHotelNames
    let flight: String
    let createdAt: String
    let updatedAt: String
    let pilgrimProfile: BookingPilgrimProfile?
    let hotelSelection: BookingHotelSelectionSnapshot?
}

struct BookingInputRecord: Codable, Hashable {
    let startDate: String
    let endDate: String
    let from: String
    let originCode: String
    let arrivalAirportCode: String
    let includeMadinah: Bool
    let travelers: BookingTravelers
}

struct ChatListResponse: Decodable {
    let ok: Bool?
    let bookingID: String?
    let messages: [ChatMessage]
}

struct ChatMessagePostResponse: Decodable {
    let ok: Bool?
    let message: ChatMessage
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let bookingID: String
    let senderType: String
    let senderName: String?
    let body: String
    let messageType: String?
    let attachmentID: String?
    let attachmentURL: String?
    let createdAt: String
    let readByStaff: Bool?
}

struct StoredBookingSession: Codable, Identifiable, Hashable {
    let id: String
    let accessToken: String
    var booking: RemoteBooking
    var travelerName: String?
    var telegram: String?
    var whatsapp: String?
    var outboundFlight: FlightOffer?
    var inboundFlight: FlightOffer?
    var hotelSelection: BookingHotelSelectionSnapshot?
    var iumrahID: String? = nil
}

struct ClientBookingSyncRequest: Encodable {
    let bookingID: String
    let clientUserID: String
    let firstName: String
    let lastName: String
    let displayName: String
    let telegram: String
    let whatsapp: String
    let bookingSnapshot: RemoteBooking
}

struct ClientBookingSyncResponse: Decodable {
    let ok: Bool
    let pilgrimID: String?
    let iumrahID: String?
}

struct ClientPushRegistrationRequest: Encodable {
    let deviceToken: String
    let environment: String
    let clientUserID: String
    let firstName: String
    let lastName: String
    let displayName: String
    let telegram: String
    let whatsapp: String
}

struct ClientPushRegistrationResponse: Decodable {
    let ok: Bool
    let ready: Bool?
    let pilgrimID: String?
    let iumrahID: String?
}

struct BookingMutationResponse: Decodable {
    let ok: Bool?
    let deleted: Bool?
    let updatedAt: String?
}


struct BookingHotelUpdateRequest: Encodable {
    let hotelId: String
    let coverImageURL: String?
    let roomId: String?
    let roomName: String?
    let roomBeds: String?
    let roomSizeM2: Double?
    let roomMaxGuests: Int?

    init(hotel: HotelSummary, room: HotelRoom?) {
        hotelId = hotel.id
        coverImageURL = hotel.coverImageURL
        roomId = room?.id
        roomName = room?.name
        roomBeds = room?.beds
        roomSizeM2 = room?.sizeM2
        roomMaxGuests = room?.maxGuests
    }

    init(snapshot: BookingHotelSelectionSnapshot) {
        hotelId = snapshot.hotelId
        coverImageURL = snapshot.coverImageURL
        roomId = snapshot.roomId
        roomName = snapshot.roomName
        roomBeds = snapshot.roomBeds
        roomSizeM2 = snapshot.roomSizeM2
        roomMaxGuests = snapshot.roomMaxGuests
    }
}
