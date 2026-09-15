import Foundation

struct IumrahCareRequestService {
    private let api = APIClient.shared

    func submit(_ request: IumrahCarePackageRequest, accountToken: String?) async throws -> IumrahCarePackageRequestResponse {
        var headers: [String: String] = [:]
        if let accountToken, !accountToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            headers["Authorization"] = "Bearer \(accountToken)"
        }
        return try await api.post(
            "/api/package/care-requests",
            body: request,
            headers: headers,
            timeoutInterval: 30
        )
    }
}
