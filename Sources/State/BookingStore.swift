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
    private let clientPushService = ClientPushService()
    private let legacyStorageKey = "iumrah.booking.sessions.v1"

    init() {
        loadFromStorage()
    }

    func create(
        trip: TripDraft,
        hotel: HotelSummary,
        room: HotelRoom?,
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
        guard let token = response.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            throw APIError.missingBookingToken
        }
        let serverProfile = response.booking.pilgrimProfile ?? pilgrimProfile
        var session = StoredBookingSession(
            id: response.booking.id,
            accessToken: token,
            booking: response.booking,
            travelerName: serverProfile?.displayName,
            telegram: serverProfile?.telegram,
            whatsapp: serverProfile?.whatsapp,
            outboundFlight: outbound,
            inboundFlight: inbound,
            hotelSelection: BookingHotelSelectionSnapshot(hotel: hotel, room: room)
        )
        if let profile = serverProfile, !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let trip = try? await bookingService.syncClientIdentity(
                id: session.id,
                accessToken: session.accessToken,
                clientUserID: ClientIdentityStore.id,
                profile: profile
            ) {
                session.pilgrimID = trip.pilgrimID
                session.operationStatus = trip.status
            }
        }
        upsert(session)
        if room != nil {
            _ = try? await bookingService.updateHotelSelection(
                id: session.id,
                accessToken: session.accessToken,
                snapshot: session.hotelSelection ?? BookingHotelSelectionSnapshot(hotel: hotel, room: room)
            )
        }
        return session
    }

    func refreshAll() async {
        for session in sessions {
            guard !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            do {
                let booking = try await bookingService.fetchBooking(id: session.id, accessToken: session.accessToken)
                var operationalTrip: ClientTripSnapshot?
                if let profile = identityProfile(remote: booking.pilgrimProfile, session: session) {
                    operationalTrip = try? await bookingService.syncClientIdentity(
                        id: session.id,
                        accessToken: session.accessToken,
                        clientUserID: ClientIdentityStore.id,
                        profile: profile
                    )
                }
                if operationalTrip == nil {
                    operationalTrip = try? await bookingService.fetchOperationalTrip(id: session.id, accessToken: session.accessToken)
                }
                if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].booking = booking
                    sessions[index].operationStatus = operationalTrip?.status ?? sessions[index].operationStatus
                    sessions[index].pilgrimID = operationalTrip?.pilgrimID ?? sessions[index].pilgrimID
                    if let profile = booking.pilgrimProfile {
                        sessions[index].travelerName = profile.displayName
                        sessions[index].telegram = profile.telegram
                        sessions[index].whatsapp = profile.whatsapp
                    }
                    if let hotelSelection = booking.hotelSelection {
                        sessions[index].hotelSelection = hotelSelection
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
        let messages = response.messages.sorted(by: { $0.createdAt < $1.createdAt })
        chats[bookingID] = messages
        _ = try? await chatService.markRead(bookingID: bookingID, accessToken: session.accessToken)
        return messages
    }

    func send(message: String, for bookingID: String) async throws -> ChatMessage {
        guard let session = booking(id: bookingID), !session.accessToken.isEmpty else {
            throw APIError.missingBookingToken
        }
        let created = try await chatService.send(message: message, bookingID: bookingID, accessToken: session.accessToken)
        var current = chats[bookingID] ?? []
        current.append(created)
        chats[bookingID] = current.sorted(by: { $0.createdAt < $1.createdAt })
        return created
    }


    func sendPhoto(data: Data, for bookingID: String) async throws -> ChatMessage {
        guard let session = booking(id: bookingID), !session.accessToken.isEmpty else {
            throw APIError.missingBookingToken
        }
        let created = try await chatService.sendPhoto(data: data, bookingID: bookingID, accessToken: session.accessToken)
        var current = chats[bookingID] ?? []
        current.append(created)
        chats[bookingID] = current.sorted(by: { $0.createdAt < $1.createdAt })
        return created
    }

    func chatAttachmentData(path: String, bookingID: String) async throws -> Data {
        guard let session = booking(id: bookingID), !session.accessToken.isEmpty else {
            throw APIError.missingBookingToken
        }
        return try await chatService.loadAttachment(path: path, accessToken: session.accessToken)
    }

    func syncPushSubscriptions(deviceToken: String, locale: String) async {
        let token = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        for session in sessions where !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                try await clientPushService.register(
                    deviceToken: token,
                    bookingID: session.id,
                    accessToken: session.accessToken,
                    locale: locale
                )
            } catch {
                // A single stale/deleted booking must not block registration for the user's other trips.
                continue
            }
        }
    }

    func syncHotelSelectionIfNeeded(bookingID: String) async {
        guard let session = booking(id: bookingID),
              let snapshot = session.hotelSelection,
              snapshot.roomId != nil,
              session.booking.hotelSelection?.roomId != snapshot.roomId,
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

    func updateHotelSelection(bookingID: String, hotel: HotelSummary, room: HotelRoom?) async throws {
        guard let session = booking(id: bookingID), !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.missingBookingToken
        }
        _ = try await bookingService.updateHotelSelection(
            id: bookingID,
            accessToken: session.accessToken,
            hotel: hotel,
            room: room
        )
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].hotelSelection = BookingHotelSelectionSnapshot(hotel: hotel, room: room)
        persist()
    }

    func deleteBooking(id: String) async throws {
        guard let session = booking(id: id), !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.missingBookingToken
        }
        do {
            _ = try await bookingService.deleteBooking(id: id, accessToken: session.accessToken)
        } catch APIError.status(let code) where code == 405 {
            throw BookingStoreError.permanentDeleteUnavailable
        } catch APIError.server(let code, let message) where code == 405 || message.uppercased() == "METHOD_NOT_ALLOWED" {
            throw BookingStoreError.permanentDeleteUnavailable
        }
        sessions.removeAll(where: { $0.id == id })
        chats[id] = nil
        persist()
    }

    private func identityProfile(remote: BookingPilgrimProfile?, session: StoredBookingSession) -> BookingPilgrimProfile? {
        if let remote,
           !remote.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !remote.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return remote
        }
        let parts = (session.travelerName ?? "")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard parts.count >= 2 else { return nil }
        return BookingPilgrimProfile(
            firstName: parts[0],
            lastName: parts.dropFirst().joined(separator: " "),
            telegram: session.telegram ?? "",
            whatsapp: session.whatsapp ?? ""
        )
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
            sessions = secureSessions
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            return
        }

        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
              let decoded = try? JSONDecoder().decode([StoredBookingSession].self, from: data) else {
            return
        }

        sessions = decoded
        if BookingSessionVault.save(decoded) {
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
    }
}
