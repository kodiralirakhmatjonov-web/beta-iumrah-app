import Foundation

struct ChatService {
    private let api = APIClient.shared

    func loadChat(bookingID: String, headers: [String: String]) async throws -> ChatListResponse {
        try await api.get(
            "/api/catalog/hotels/client/chats/\(bookingID)/messages",
            headers: headers
        )
    }

    func send(message: String, bookingID: String, headers: [String: String]) async throws -> ChatMessage {
        let response: ChatMessagePostResponse = try await api.post(
            "/api/catalog/hotels/client/chats/\(bookingID)/messages",
            body: ChatMessageSendRequest(body: message, clientMessageID: UUID().uuidString),
            headers: headers
        )
        return response.message
    }

    func sendPhoto(data: Data, bookingID: String, headers: [String: String]) async throws -> ChatMessage {
        let response: ChatMessagePostResponse = try await api.upload(
            "/api/catalog/hotels/client/chats/\(bookingID)/attachments",
            data: data,
            contentType: "image/jpeg",
            headers: headers,
            timeoutInterval: 75
        )
        return response.message
    }

    func loadAttachment(path: String, headers: [String: String]) async throws -> Data {
        try await api.fetchData(
            path,
            headers: headers,
            timeoutInterval: 45
        )
    }

    func markRead(bookingID: String, headers: [String: String]) async throws {
        let _: BasicOKResponse = try await api.post(
            "/api/catalog/hotels/client/chats/\(bookingID)/read",
            body: EmptyPayload(),
            headers: headers
        )
    }
}

private struct ChatMessageSendRequest: Encodable {
    let body: String
    let clientMessageID: String
}

private struct EmptyPayload: Encodable {}

private struct BasicOKResponse: Decodable { let ok: Bool }
