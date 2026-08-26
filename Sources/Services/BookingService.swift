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

    func deleteBooking(id: String, accessToken: String) async throws -> BookingMutationResponse {
        try await api.delete(
            "/api/package/booking/\(id)",
            headers: ["x-booking-token": accessToken]
        )
    }
}
