import Foundation
import SwiftUI

@MainActor
final class BookingStore: ObservableObject {
    @Published private(set) var sessions: [StoredBookingSession] = []
    @Published private(set) var chats: [String: [ChatMessage]] = [:]

    private let bookingService = BookingService()
    private let chatService = ChatService()
    private let storageKey = "iumrah.booking.sessions.v1"

    init() {
        loadFromStorage()
    }

    func create(
        trip: TripDraft,
        hotel: HotelSummary,
        outbound: FlightOffer,
        inbound: FlightOffer,
        quote: PackageQuote,
        language: AppSettingsStore.Language,
        pilgrimProfile: BookingPilgrimProfile?
    ) async throws -> StoredBookingSession {
        let payload = BookingDraftBuilder.make(
            trip: trip,
            hotel: hotel,
            outbound: outbound,
            inbound: inbound,
            quote: quote,
            language: language,
            pilgrimProfile: pilgrimProfile
        )
        let response = try await bookingService.createBooking(payload)
        let session = StoredBookingSession(
            id: response.booking.id,
            accessToken: response.accessToken ?? "",
            booking: response.booking,
            travelerName: pilgrimProfile?.displayName,
            telegram: pilgrimProfile?.telegram,
            whatsapp: pilgrimProfile?.whatsapp
        )
        upsert(session)
        return session
    }

    func refreshAll() async {
        for session in sessions {
            do {
                let booking = try await bookingService.fetchBooking(id: session.id, accessToken: session.accessToken)
                if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].booking = booking
                }
            } catch {
                continue
            }
        }
        persist()
    }

    func booking(id: String) -> StoredBookingSession? {
        sessions.first(where: { $0.id == id })
    }

    func loadChat(for bookingID: String) async throws -> [ChatMessage] {
        guard let session = booking(id: bookingID) else { return [] }
        let messages = try await chatService.loadChat(bookingID: bookingID, accessToken: session.accessToken)
        chats[bookingID] = messages
        return messages
    }

    func send(message: String, for bookingID: String) async throws -> ChatMessage {
        guard let session = booking(id: bookingID) else { throw APIError.invalidResponse }
        let created = try await chatService.send(message: message, bookingID: bookingID, accessToken: session.accessToken)
        var current = chats[bookingID] ?? []
        current.append(created)
        chats[bookingID] = current.sorted(by: { $0.id < $1.id })
        return created
    }

    private func upsert(_ session: StoredBookingSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {}
    }

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([StoredBookingSession].self, from: data) else {
            return
        }
        sessions = decoded
    }
}
