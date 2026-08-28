import Foundation

struct IumrahAccountService {
    private let api = APIClient.shared

    func activate(bookingID: String, bookingToken: String, password: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/catalog/hotels/client/account/activate",
            body: IumrahAccountActivateRequest(bookingID: bookingID, password: password),
            headers: ["x-booking-token": bookingToken]
        )
    }

    func login(iumrahID: String, password: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/catalog/hotels/client/account/login",
            body: IumrahAccountLoginRequest(iumrahID: iumrahID, password: password)
        )
    }

    func session(token: String) async throws -> IumrahAccountProfile {
        let value: IumrahAccountSessionResponse = try await api.get(
            "/api/catalog/hotels/client/account/session",
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.account
    }

    func logout(token: String) async {
        let _: IumrahSimpleResponse? = try? await api.post(
            "/api/catalog/hotels/client/account/logout",
            body: EmptyBody(),
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func updateProfile(_ request: IumrahAccountProfileUpdateRequest, token: String) async throws -> IumrahAccountProfile {
        let value: IumrahAccountSessionResponse = try await api.put(
            "/api/catalog/hotels/client/account/profile",
            body: request,
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.account
    }

    func trips(token: String) async throws -> [ClientTripSnapshot] {
        let value: IumrahAccountTripsResponse = try await api.get(
            "/api/catalog/hotels/client/trips",
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.trips
    }

    func tripDetail(bookingID: String, token: String) async throws -> IumrahAccountTripDetailResponse {
        try await api.get(
            "/api/catalog/hotels/client/trips/\(bookingID)",
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func linkBooking(bookingID: String, bookingToken: String, token: String) async throws -> String {
        let response: IumrahAccountLinkBookingResponse = try await api.post(
            "/api/catalog/hotels/client/account/link-booking",
            body: IumrahAccountLinkBookingRequest(bookingID: bookingID),
            headers: ["Authorization": "Bearer \(token)", "x-booking-token": bookingToken]
        )
        return response.pilgrimID
    }

    func checkout(bookingID: String, authorizationHeaders: [String: String]) async throws -> IumrahCheckoutResponse {
        try await api.get(
            "/api/catalog/hotels/client/trips/\(bookingID)/checkout",
            headers: authorizationHeaders
        )
    }

    func saveTraveler(bookingID: String, position: Int, form: IumrahTravelerForm, token: String) async throws -> IumrahTravelerForm {
        let value: IumrahTravelerSaveResponse = try await api.put(
            "/api/catalog/hotels/client/trips/\(bookingID)/travelers/\(position)",
            body: IumrahTravelerSaveRequest(form),
            headers: ["Authorization": "Bearer \(token)"]
        )
        return value.traveler
    }

    func uploadPassport(bookingID: String, position: Int, data: Data, contentType: String, token: String) async throws {
        let _: IumrahSimpleResponse = try await api.upload(
            "/api/catalog/hotels/client/trips/\(bookingID)/travelers/\(position)/passport",
            data: data,
            contentType: contentType,
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func uploadReceipt(bookingID: String, method: String, data: Data, contentType: String, token: String) async throws -> String {
        let value: IumrahReceiptResponse = try await api.upload(
            "/api/catalog/hotels/client/trips/\(bookingID)/receipt",
            data: data,
            contentType: contentType,
            headers: ["Authorization": "Bearer \(token)", "x-payment-method": method]
        )
        return value.id
    }

    func media(path: String, token: String) async throws -> Data {
        try await api.fetchData(path, headers: ["Authorization": "Bearer \(token)"])
    }
}

private struct EmptyBody: Encodable {}
