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

    func updateHotelSelection(id: String, accessToken: String, hotel: HotelSummary, room: HotelRoom?) async throws -> BookingMutationResponse {
        try await api.patch(
            "/api/package/booking/\(id)",
            body: BookingHotelUpdateRequest(hotel: hotel, room: room),
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

    private func clientHeaders(accessToken: String) -> [String: String] {
        [
            "x-booking-token": accessToken,
            "x-iumrah-client-id": IumrahClientIdentity.currentID()
        ]
    }

    func syncClientBooking(_ session: StoredBookingSession) async throws -> ClientBookingSyncResponse {
        let profile = session.booking.pilgrimProfile
        let request = ClientBookingSyncRequest(
            bookingID: session.id,
            clientUserID: IumrahClientIdentity.currentID(),
            firstName: profile?.firstName ?? "",
            lastName: profile?.lastName ?? "",
            displayName: session.travelerName ?? profile?.displayName ?? "",
            telegram: session.telegram ?? profile?.telegram ?? "",
            whatsapp: session.whatsapp ?? profile?.whatsapp ?? "",
            bookingSnapshot: session.booking
        )
        return try await api.post(
            "/api/catalog/hotels/client/bookings/\(session.id)/sync",
            body: request,
            headers: clientHeaders(accessToken: session.accessToken)
        )
    }

    func registerPushDevice(token: String, session: StoredBookingSession) async throws -> ClientPushRegistrationResponse {
        let profile = session.booking.pilgrimProfile
        let request = ClientPushRegistrationRequest(
            deviceToken: token,
            environment: "production",
            clientUserID: IumrahClientIdentity.currentID(),
            firstName: profile?.firstName ?? "",
            lastName: profile?.lastName ?? "",
            displayName: session.travelerName ?? profile?.displayName ?? "",
            telegram: session.telegram ?? profile?.telegram ?? "",
            whatsapp: session.whatsapp ?? profile?.whatsapp ?? ""
        )
        return try await api.post(
            "/api/catalog/hotels/client/bookings/\(session.id)/push",
            body: request,
            headers: clientHeaders(accessToken: session.accessToken)
        )
    }

    func deleteBooking(id: String, accessToken: String) async throws -> BookingMutationResponse {
        try await api.delete(
            "/api/catalog/hotels/client/bookings/\(id)",
            headers: clientHeaders(accessToken: accessToken)
        )
    }
}
