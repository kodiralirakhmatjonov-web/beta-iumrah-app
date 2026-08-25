import Foundation

struct ChatService {
    private let api = APIClient.shared

    func loadChat(bookingID: String, accessToken: String) async throws -> [ChatMessage] {
        let response: ChatListResponse = try await api.get(
            "/api/chat/\(bookingID)",
            headers: ["x-booking-token": accessToken]
        )
        return response.messages
    }

    func send(message: String, bookingID: String, accessToken: String) async throws -> ChatMessage {
        let response: ChatMessagePostResponse = try await api.post(
            "/api/chat/\(bookingID)",
            body: ["message": message],
            headers: ["x-booking-token": accessToken]
        )
        return response.message
    }
}
