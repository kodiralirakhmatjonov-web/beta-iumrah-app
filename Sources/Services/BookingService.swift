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



    func syncClientIdentity(id: String, accessToken: String, clientUserID: String, profile: BookingPilgrimProfile) async throws -> ClientTripResponse {
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
        return response
    }

    func fetchOperationalTrip(id: String, accessToken: String) async throws -> ClientTripResponse {
        let response: ClientTripResponse = try await api.get(
            "/api/catalog/hotels/client/trips/\(id)",
            headers: ["x-booking-token": accessToken]
        )
        return response
    }

    func updateHotelSelection(
        id: String,
        accessToken: String,
        role: HotelSelectionRole,
        hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil
    ) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)",
            body: BookingHotelUpdateRequest(role: role, hotel: hotel, room: room, roomCategory: roomCategory),
            headers: ["x-booking-token": accessToken]
        )
    }

    func updateHotelSelection(id: String, accessToken: String, role: HotelSelectionRole, snapshot: BookingHotelSelectionSnapshot) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)",
            body: BookingHotelUpdateRequest(role: role, snapshot: snapshot),
            headers: ["x-booking-token": accessToken]
        )
    }

    func updateContacts(id: String, accessToken: String, telegram: String, whatsapp: String) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)/contact",
            body: BookingContactUpdateRequest(telegram: telegram, whatsapp: whatsapp),
            headers: ["x-booking-token": accessToken]
        )
    }

    func updateZiyarat(id: String, accessToken: String, makkah: Bool, madinah: Bool) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)/customization",
            body: BookingCustomizationUpdateRequest(ziyaratMakkah: makkah, ziyaratMadinah: madinah),
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
