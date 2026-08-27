import Foundation

struct ChatService {
    private let api = APIClient.shared

    func loadChat(bookingID: String, accessToken: String) async throws -> ChatListResponse {
        try await api.get(
            "/api/catalog/hotels/client/chats/\(bookingID)/messages",
            headers: ["x-booking-token": accessToken]
        )
    }

    func send(message: String, bookingID: String, accessToken: String) async throws -> ChatMessage {
        let response: ChatMessagePostResponse = try await api.post(
            "/api/catalog/hotels/client/chats/\(bookingID)/messages",
            body: ChatMessageSendRequest(body: message, clientMessageID: UUID().uuidString),
            headers: ["x-booking-token": accessToken]
        )
        return response.message
    }

    func sendPhoto(data: Data, bookingID: String, accessToken: String) async throws -> ChatMessage {
        let response: ChatMessagePostResponse = try await api.upload(
            "/api/catalog/hotels/client/chats/\(bookingID)/attachments",
            data: data,
            contentType: "image/jpeg",
            headers: ["x-booking-token": accessToken],
            timeoutInterval: 75
        )
        return response.message
    }

    func loadAttachment(path: String, accessToken: String) async throws -> Data {
        try await api.fetchData(
            path,
            headers: ["x-booking-token": accessToken],
            timeoutInterval: 45
        )
    }

    func markRead(bookingID: String, accessToken: String) async throws {
        let _: BasicOKResponse = try await api.post(
            "/api/catalog/hotels/client/chats/\(bookingID)/read",
            body: EmptyPayload(),
            headers: ["x-booking-token": accessToken]
        )
    }
}

private struct ChatMessageSendRequest: Encodable {
    let body: String
    let clientMessageID: String
}

private struct EmptyPayload: Encodable {}

private struct BasicOKResponse: Decodable { let ok: Bool }
