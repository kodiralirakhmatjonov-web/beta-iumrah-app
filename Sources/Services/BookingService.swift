import Foundation

struct BookingService {
    private let api = APIClient.shared

    func createBooking(_ request: BookingCreateEnvelope) async throws -> BookingCreateResponse {
        try await api.post("/api/bookings", body: request)
    }

    func fetchBooking(id: String, accessToken: String) async throws -> RemoteBooking {
        let response: BookingCreateResponse = try await api.get(
            "/api/bookings/\(id)",
            headers: ["x-booking-token": accessToken]
        )
        return response.booking
    }



    func syncClientIdentity(id: String, accessToken: String, clientUserID: String, profile: BookingPilgrimProfile) async throws -> ClientTripSnapshot {
        let response: ClientTripResponse = try await api.post(
            "/api/catalog/hotels/client/trips/\(id)/sync",
            body: ClientIdentitySyncRequest(
                clientUserID: clientUserID,
                firstName: profile.firstName,
                lastName: profile.lastName,
                displayName: profile.displayName,
                telegram: profile.telegram,
                whatsapp: profile.whatsapp
            ),
            headers: ["x-booking-token": accessToken]
        )
        return response.trip
    }

    func fetchOperationalTrip(id: String, accessToken: String) async throws -> ClientTripSnapshot {
        let response: ClientTripResponse = try await api.get(
            "/api/catalog/hotels/client/trips/\(id)",
            headers: ["x-booking-token": accessToken]
        )
        return response.trip
    }

    func updateHotelSelection(
        id: String,
        accessToken: String,
        hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil
    ) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)",
            body: BookingHotelUpdateRequest(hotel: hotel, room: room, roomCategory: roomCategory),
            headers: ["x-booking-token": accessToken]
        )
    }

    func updateHotelSelection(id: String, accessToken: String, snapshot: BookingHotelSelectionSnapshot) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)",
            body: BookingHotelUpdateRequest(snapshot: snapshot),
            headers: ["x-booking-token": accessToken]
        )
    }

    func deleteBooking(id: String, accessToken: String) async throws -> BookingMutationResponse {
        try await api.delete(
            "/api/catalog/hotels/client/bookings/\(id)",
            headers: ["x-booking-token": accessToken]
        )
    }
}


private struct ClientIdentitySyncRequest: Encodable {
    let clientUserID: String
    let firstName: String
    let lastName: String
    let displayName: String
    let telegram: String
    let whatsapp: String
}
