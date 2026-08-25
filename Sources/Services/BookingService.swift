import Foundation

struct BookingService {
    private let api = APIClient.shared

    func create(_ request: BookingCreateEnvelope) async throws -> BookingCreateResponse {
        try await api.post("/api/bookings", body: request)
    }

    func read(id: String, accessToken: String) async throws -> RemoteBooking {
        let response: BookingDetailResponse = try await api.get(
            "/api/bookings/\(id)",
            headers: ["x-booking-token": accessToken]
        )
        return response.booking
    }
}
