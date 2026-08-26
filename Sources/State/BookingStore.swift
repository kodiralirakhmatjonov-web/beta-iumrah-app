import Foundation
import SwiftUI

enum BookingStoreError: LocalizedError {
    case permanentDeleteUnavailable

    var errorDescription: String? {
        switch self {
        case .permanentDeleteUnavailable:
            return "Permanent booking deletion is not available on the server."
        }
    }
}

@MainActor
final class BookingStore: ObservableObject {
    @Published private(set) var sessions: [StoredBookingSession] = []
    @Published private(set) var chats: [String: [ChatMessage]] = [:]

    private let bookingService = BookingService()
    private let chatService = ChatService()
    private let legacyStorageKey = "iumrah.booking.sessions.v1"

    init() {
        loadFromStorage()
    }

    func create(
        trip: TripDraft,
        hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption?,
        outbound: FlightOffer,
        inbound: FlightOffer,
        quote: PackageQuote,
        language: AppSettingsStore.Language,
        pilgrimProfile: BookingPilgrimProfile?
    ) async throws -> StoredBookingSession {
        let payload = BookingDraftBuilder.make(
            trip: trip,
            hotel: hotel,
            room: room,
            roomCategory: roomCategory,
            outbound: outbound,
            inbound: inbound,
            quote: quote,
            language: language,
            pilgrimProfile: pilgrimProfile
        )
        let response = try await bookingService.createBooking(payload)
        guard let token = response.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw APIError.missingBookingToken
        }
        let serverProfile = response.booking.pilgrimProfile ?? pilgrimProfile
        let session = StoredBookingSession(
            id: response.booking.id,
            accessToken: token,
            booking: response.booking,
            travelerName: serverProfile?.displayName,
            telegram: serverProfile?.telegram,
            whatsapp: serverProfile?.whatsapp,
            outboundFlight: outbound,
            inboundFlight: inbound,
            hotelSelection: BookingHotelSelectionSnapshot(hotel: hotel, room: room, roomCategory: roomCategory)
        )
        upsert(session)
        if room != nil || roomCategory != nil {
            _ = try? await bookingService.updateHotelSelection(
                id: session.id,
                accessToken: session.accessToken,
                snapshot: session.hotelSelection ?? BookingHotelSelectionSnapshot(hotel: hotel, room: room, roomCategory: roomCategory)
            )
        }
        await syncCloudSession(id: session.id)
        if let token = PushNotificationManager.shared.deviceToken {
            await registerPushDevice(token: token)
        }
        return booking(id: session.id) ?? session
    }

    func refreshAll() async {
        for session in sessions {
            guard !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            do {
                let booking = try await bookingService.fetchBooking(id: session.id, accessToken: session.accessToken)
                if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].booking = booking
                    if let profile = booking.pilgrimProfile {
                        sessions[index].travelerName = profile.displayName
                        sessions[index].telegram = profile.telegram
                        sessions[index].whatsapp = profile.whatsapp
                    }
                    if let hotelSelection = booking.hotelSelection {
                        let localSelection = sessions[index].hotelSelection
                        if hotelSelection.roomCategory == nil,
                           hotelSelection.roomId == nil,
                           let localSelection,
                           localSelection.hotelId == hotelSelection.hotelId,
                           localSelection.roomCategory != nil {
                            // Keep a previously synced iumrah room category if an older parser omits it.
                            sessions[index].hotelSelection = localSelection
                        } else {
                            sessions[index].hotelSelection = hotelSelection
                        }
                    }
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
        guard let session = booking(id: bookingID), !session.accessToken.isEmpty else {
            throw APIError.missingBookingToken
        }
        let response = try await chatService.loadChat(bookingID: bookingID, accessToken: session.accessToken)
        let messages = response.messages.sorted { lhs, rhs in
            lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt < rhs.createdAt
        }
        chats[bookingID] = messages
        try? await chatService.markRead(bookingID: bookingID, accessToken: session.accessToken)
        return messages
    }

    func send(message: String, for bookingID: String) async throws -> ChatMessage {
        guard let session = booking(id: bookingID), !session.accessToken.isEmpty else {
            throw APIError.missingBookingToken
        }
        let created = try await chatService.send(message: message, bookingID: bookingID, accessToken: session.accessToken)
        var current = chats[bookingID] ?? []
        current.append(created)
        chats[bookingID] = current.sorted { lhs, rhs in
            lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt < rhs.createdAt
        }
        return created
    }

    func syncHotelSelectionIfNeeded(bookingID: String) async {
        guard let session = booking(id: bookingID),
              let snapshot = session.hotelSelection,
              snapshot.roomId != nil || snapshot.roomCategory != nil,
              (session.booking.hotelSelection?.roomId != snapshot.roomId ||
               session.booking.hotelSelection?.roomCategory != snapshot.roomCategory),
              !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            _ = try await bookingService.updateHotelSelection(
                id: bookingID,
                accessToken: session.accessToken,
                snapshot: snapshot
            )
        } catch {
            // Keep the local selection and retry on a later booking-detail refresh.
        }
    }

    func updateHotelSelection(
        bookingID: String,
        hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil
    ) async throws {
        guard let session = booking(id: bookingID), !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.missingBookingToken
        }
        _ = try await bookingService.updateHotelSelection(
            id: bookingID,
            accessToken: session.accessToken,
            hotel: hotel,
            room: room,
            roomCategory: roomCategory
        )
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].hotelSelection = BookingHotelSelectionSnapshot(hotel: hotel, room: room, roomCategory: roomCategory)
        persist()
        await syncCloudSession(id: bookingID)
    }

    func deleteBooking(id: String) async throws {
        guard let session = booking(id: id), !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.missingBookingToken
        }
        _ = try await bookingService.deleteBooking(id: id, accessToken: session.accessToken)
        sessions.removeAll(where: { $0.id == id })
        chats[id] = nil
        persist()
    }

    func synchronizeCloud() async {
        for session in sessions {
            guard !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            await syncCloudSession(id: session.id)
        }
    }

    func registerPushDevice(token: String) async {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        for session in sessions {
            guard !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            do {
                let response = try await bookingService.registerPushDevice(token: value, session: session)
                if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].iumrahID = response.iumrahID ?? response.pilgrimID ?? sessions[index].iumrahID
                    persist()
                }
                return
            } catch {
                continue
            }
        }
    }

    private func syncCloudSession(id: String) async {
        guard let session = booking(id: id), !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let response = try await bookingService.syncClientBooking(session)
            if let index = sessions.firstIndex(where: { $0.id == id }) {
                sessions[index].iumrahID = response.iumrahID ?? response.pilgrimID ?? sessions[index].iumrahID
                persist()
            }
        } catch {
            // The booking remains usable locally; the next launch/refresh retries the cloud link.
        }
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
        _ = BookingSessionVault.save(sessions)
    }

    private func loadFromStorage() {
        let secureSessions = BookingSessionVault.load()
        if !secureSessions.isEmpty {
            sessions = migrateLegacyPrimaryRooms(in: secureSessions)
            _ = BookingSessionVault.save(sessions)
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            return
        }

        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
              let decoded = try? JSONDecoder().decode([StoredBookingSession].self, from: data) else {
            return
        }

        sessions = migrateLegacyPrimaryRooms(in: decoded)
        if BookingSessionVault.save(sessions) {
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
    }

    private func migrateLegacyPrimaryRooms(in values: [StoredBookingSession]) -> [StoredBookingSession] {
        values.map { value in
            var value = value
            if let selection = value.hotelSelection {
                value.hotelSelection = selection.migratedLegacyPrimaryRoom
            }
            return value
        }
    }
}
