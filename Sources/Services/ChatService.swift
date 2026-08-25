import Foundation

struct ChatService {
    private let api = APIClient.shared

    func messages(bookingId: String, accessToken: String) async throws -> [ChatMessage] {
        let response: ChatReadResponse = try await api.get(
            "/api/chat/\(bookingId)",
            headers: ["x-booking-token": accessToken]
        )
        return response.messages
    }

    func send(_ message: String, bookingId: String, accessToken: String) async throws -> ChatMessage? {
        let response: ChatSendResponse = try await api.post(
            "/api/chat/\(bookingId)",
            body: ChatSendRequest(message: message),
            headers: ["x-booking-token": accessToken]
        )
        return response.message
    }
}
