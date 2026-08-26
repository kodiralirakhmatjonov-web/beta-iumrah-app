import Foundation

struct ChatService {
    private let api = APIClient.shared

    private func headers(accessToken: String) -> [String: String] {
        [
            "x-booking-token": accessToken,
            "x-iumrah-client-id": IumrahClientIdentity.currentID()
        ]
    }

    func loadChat(bookingID: String, accessToken: String) async throws -> ChatListResponse {
        try await api.get(
            "/api/catalog/hotels/client/chats/\(bookingID)/messages",
            headers: headers(accessToken: accessToken)
        )
    }

    func send(message: String, bookingID: String, accessToken: String) async throws -> ChatMessage {
        let response: ChatMessagePostResponse = try await api.post(
            "/api/catalog/hotels/client/chats/\(bookingID)/messages",
            body: ["body": message, "clientMessageID": UUID().uuidString.lowercased()],
            headers: headers(accessToken: accessToken)
        )
        return response.message
    }

    func loadAttachment(bookingID: String, attachmentID: String, accessToken: String) async throws -> Data {
        let url = AppConfig.apiBaseURL.appending(path: "/api/catalog/hotels/client/chats/\(bookingID)/media/\(attachmentID)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("iumrah-ios-beta/0.25", forHTTPHeaderField: "User-Agent")
        for (key, value) in headers(accessToken: accessToken) { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
            throw APIError.invalidResponse
        }
        return data
    }

    func markRead(bookingID: String, accessToken: String) async throws {
        let _: BookingMutationResponse = try await api.post(
            "/api/catalog/hotels/client/chats/\(bookingID)/read",
            body: ["ok": true],
            headers: headers(accessToken: accessToken)
        )
    }
}
