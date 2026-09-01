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

    func linkBooking(bookingID: String, bookingToken: String, token: String) async throws -> IumrahAccountLinkBookingResponse {
        let response: IumrahAccountLinkBookingResponse = try await api.post(
            "/api/catalog/hotels/client/account/link-booking",
            body: IumrahAccountLinkBookingRequest(bookingID: bookingID),
            headers: ["Authorization": "Bearer \(token)", "x-booking-token": bookingToken]
        )
        return response
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

    func registerCurrentSession(token: String, locale: String) async throws -> IumrahSecurityOverview {
        try await api.post(
            "/api/package/client/account/security/register",
            body: IumrahDeviceRegistrationRequest(device: IumrahAccountDeviceIdentity.current(locale: locale)),
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    func securityOverview(token: String) async throws -> IumrahSecurityOverview {
        try await api.get(
            "/api/package/client/account/security",
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func claimPrimaryDevice(password: String, token: String) async throws -> IumrahSecurityOverview {
        try await api.post(
            "/api/package/client/account/security/claim-primary",
            body: IumrahClaimPrimaryRequest(password: password),
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func terminateSession(id: String, token: String) async throws -> IumrahTerminateSessionResponse {
        try await api.delete(
            "/api/package/client/account/security/sessions/\(id)",
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }

    func signInWithApple(_ credential: IumrahAppleCredential, locale: String) async throws -> IumrahAccountAuthResponse {
        try await api.post(
            "/api/package/client/account/apple/sign-in",
            body: IumrahAppleSignInRequest(
                identityToken: credential.identityToken,
                nonce: credential.nonce,
                device: IumrahAccountDeviceIdentity.current(locale: locale)
            )
        )
    }

    func linkApple(_ credential: IumrahAppleCredential, token: String) async throws -> IumrahAppleLinkResponse {
        try await api.post(
            "/api/package/client/account/apple/link",
            body: IumrahAppleRequest(identityToken: credential.identityToken, nonce: credential.nonce),
            headers: IumrahAccountDeviceIdentity.securityHeaders(token: token)
        )
    }
}

private struct EmptyBody: Encodable {}
