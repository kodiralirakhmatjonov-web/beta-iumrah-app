import Foundation

struct BookingCreateEnvelope: Encodable {
    let lang: String
    let booking: BookingDraftRequest
}

struct BookingDraftRequest: Encodable {
    struct TripInput: Encodable {
        struct Travelers: Encodable {
            let adults: Int
            let children: Int
            let infants: Int
            let rooms: Int
        }

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
        let travelers: Travelers
    }

    struct Route: Encodable {
        let originCode: String
        let outboundDestination: String
        let returnOrigin: String
    }

    struct Stay: Encodable {
        let totalDays: Int
        let totalNights: Int
        let makkahCheckIn: String
        let makkahCheckOut: String
        let makkahNights: Int
        let madinahCheckIn: String?
        let madinahCheckOut: String?
        let madinahNights: Int
    }

    struct Selection: Encodable {
        let flightId: String
        let makkahHotelId: String
        let madinahHotelId: String?
    }

    struct Customization: Encodable {
        let accompaniment: Bool
        let guideMeetingPoint: String
        let ziyaratMakkah: Bool
        let ziyaratMadinah: Bool
        let meals: Bool
        let esim: Bool
    }

    struct HotelNames: Encodable {
        let makkah: String
        let madinah: String
    }

    let planId: String
    let totalUsd: Decimal
    let perPilgrimUsd: Decimal
    let input: TripInput
    let route: Route
    let stay: Stay
    let selection: Selection
    let customization: Customization
    let includedServices: [String]
    let hotelNames: HotelNames
    let flight: String
}

struct RemoteBooking: Codable, Identifiable, Hashable {
    struct Input: Codable, Hashable {
        struct Travelers: Codable, Hashable {
            let adults: Int
            let children: Int
            let infants: Int
            let rooms: Int
        }

        let from: String
        let originCode: String?
        let arrivalAirportCode: String?
        let startDate: String
        let endDate: String
        let hotelPreference: String
        let includeMadinah: Bool
        let travelers: Travelers
    }

    struct Route: Codable, Hashable {
        let originCode: String
        let outboundDestination: String
        let returnOrigin: String
    }

    struct HotelNames: Codable, Hashable {
        let makkah: String
        let madinah: String
    }

    let id: String
    let status: String
    let createdAt: String
    let updatedAt: String?
    let planId: String
    let totalUsd: Decimal
    let perPilgrimUsd: Decimal
    let input: Input
    let route: Route
    let hotelNames: HotelNames
    let flight: String
}

struct BookingCreateResponse: Decodable {
    let booking: RemoteBooking
    let accessToken: String
}

struct BookingDetailResponse: Decodable {
    let booking: RemoteBooking
}

struct StoredBookingSession: Codable, Identifiable, Hashable {
    let id: String
    let accessToken: String
    var booking: RemoteBooking

    init(booking: RemoteBooking, accessToken: String) {
        self.id = booking.id
        self.accessToken = accessToken
        self.booking = booking
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    let bookingId: String
    let senderType: String
    let senderId: String
    let body: String
    let createdAt: String
}

struct ChatReadResponse: Decodable {
    let messages: [ChatMessage]
}

struct ChatSendRequest: Encodable {
    let message: String
}

struct ChatSendResponse: Decodable {
    let message: ChatMessage?
}
