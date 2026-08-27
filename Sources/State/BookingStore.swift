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
    private let hotelCatalogService = HotelCatalogService()
    private let chatService = ChatService()
    private let clientPushService = ClientPushService()
    private let legacyStorageKey = "iumrah.booking.sessions.v1"

    init() {
        loadFromStorage()
    }

    func create(
        trip: TripDraft,
        hotel: HotelSummary,
        madinahHotel: HotelSummary? = nil,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption? = nil,
        madinahRoom: HotelRoom? = nil,
        madinahRoomCategory: IumrahRoomCategoryOption? = nil,
        outbound: FlightOffer,
        inbound: FlightOffer,
        quote: PackageQuote,
        language: AppSettingsStore.Language,
        pilgrimProfile: BookingPilgrimProfile?
    ) async throws -> StoredBookingSession {
        let payload = BookingDraftBuilder.make(
            trip: trip,
            hotel: hotel,
            madinahHotel: madinahHotel,
            room: room,
            roomCategory: roomCategory,
            madinahRoom: madinahRoom,
            madinahRoomCategory: madinahRoomCategory,
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
            hotelSelection: BookingHotelSelectionSnapshot(hotel: hotel, room: room, roomCategory: roomCategory),
            madinahHotelSelection: madinahHotel.map { BookingHotelSelectionSnapshot(hotel: $0, room: madinahRoom, roomCategory: madinahRoomCategory) }
        )
        if let profile = serverProfile, !profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let response = try? await bookingService.syncClientIdentity(
                id: session.id,
                accessToken: session.accessToken,
                clientUserID: ClientIdentityStore.id,
                profile: profile
            ) {
                session.pilgrimID = response.trip.pilgrimID
                session.operationStatus = response.trip.status
                session.guide = response.assignment?.guide
            }
        }
        upsert(session)
        if let makkahSelection = session.hotelSelection {
            _ = try? await bookingService.updateHotelSelection(
                id: session.id,
                accessToken: session.accessToken,
                role: .makkah,
                snapshot: makkahSelection
            )
        }
        if let madinahSelection = session.madinahHotelSelection {
            _ = try? await bookingService.updateHotelSelection(
                id: session.id,
                accessToken: session.accessToken,
                role: .madinah,
                snapshot: madinahSelection
            )
        }
        return session
    }

    func refreshAll() async {
        var staleBookingIDs = Set<String>()

        for session in sessions {
            let token = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty {
                staleBookingIDs.insert(session.id)
                continue
            }

            do {
                let booking = try await bookingService.fetchBooking(id: session.id, accessToken: token)
                var operational: ClientTripResponse?
                if let profile = identityProfile(remote: booking.pilgrimProfile, session: session) {
                    operational = try? await bookingService.syncClientIdentity(
                        id: session.id,
                        accessToken: token,
                        clientUserID: ClientIdentityStore.id,
                        profile: profile
                    )
                }
                if operational == nil {
                    operational = try? await bookingService.fetchOperationalTrip(id: session.id, accessToken: token)
                }

                if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[index].booking = booking
                    sessions[index].operationStatus = operational?.trip.status ?? sessions[index].operationStatus
                    sessions[index].pilgrimID = operational?.trip.pilgrimID ?? sessions[index].pilgrimID
                    sessions[index].guide = operational?.assignment?.guide ?? sessions[index].guide

                    if let profile = booking.pilgrimProfile {
                        sessions[index].travelerName = profile.displayName
                        sessions[index].telegram = profile.telegram
                        sessions[index].whatsapp = profile.whatsapp
                    }
                    mergeRemoteHotelSelection(booking.hotelSelection, into: &sessions[index].hotelSelection)
                    mergeRemoteHotelSelection(booking.madinahHotelSelection, into: &sessions[index].madinahHotelSelection)
                    if let customization = booking.customization {
                        sessions[index].ziyaratMakkahOverride = customization.ziyaratMakkah
                        sessions[index].ziyaratMadinahOverride = customization.ziyaratMadinah
                    }
                }

                await hydrateHotelSelectionIfNeeded(bookingID: session.id, role: .makkah)
                if booking.input.includeMadinah {
                    await hydrateHotelSelectionIfNeeded(bookingID: session.id, role: .madinah)
                }
            } catch APIError.status(let code) where code == 404 || code == 410 {
                staleBookingIDs.insert(session.id)
            } catch APIError.server(let code, let message) where isRemoteMissing(code: code, message: message) {
                staleBookingIDs.insert(session.id)
            } catch {
                continue
            }
        }

        for id in staleBookingIDs {
            purgeLocalBooking(id: id)
        }
        persist()
    }

    func booking(id: String) -> StoredBookingSession? {
        sessions.first(where: { $0.id == id })
    }

    private func hydrateHotelSelectionIfNeeded(bookingID: String, role: HotelSelectionRole) async {
        guard let current = booking(id: bookingID) else { return }
        let existing = role == .madinah ? current.madinahHotelSelection : current.hotelSelection
        guard existing == nil else { return }

        let rawName = role == .madinah ? current.booking.hotelNames.madinah : current.booking.hotelNames.makkah
        let targetName = normalizedHotelName(rawName)
        guard !targetName.isEmpty else { return }

        let city = role == .madinah ? "Madinah" : "Makkah"
        guard let hotels = try? await hotelCatalogService.listHotels(city: city),
              let hotel = hotels.first(where: { normalizedHotelName($0.name) == targetName }),
              let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }

        let snapshot = BookingHotelSelectionSnapshot(hotel: hotel, room: nil, roomCategory: nil)
        if role == .madinah {
            sessions[index].madinahHotelSelection = snapshot
        } else {
            sessions[index].hotelSelection = snapshot
        }
    }

    private func normalizedHotelName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
              !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        await syncHotelSelectionIfNeeded(
            bookingID: bookingID,
            role: .makkah,
            local: session.hotelSelection,
            remote: session.booking.hotelSelection,
            accessToken: session.accessToken
        )
        await syncHotelSelectionIfNeeded(
            bookingID: bookingID,
            role: .madinah,
            local: session.madinahHotelSelection,
            remote: session.booking.madinahHotelSelection,
            accessToken: session.accessToken
        )
    }

    func updateHotelSelection(
        bookingID: String,
        role: HotelSelectionRole = .makkah,
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
            role: role,
            hotel: hotel,
            room: room,
            roomCategory: roomCategory
        )
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        let snapshot = BookingHotelSelectionSnapshot(hotel: hotel, room: room, roomCategory: roomCategory)
        if role == .madinah {
            sessions[index].madinahHotelSelection = snapshot
        } else {
            sessions[index].hotelSelection = snapshot
        }
        sessions[index].pendingChangeConfirmation = true
        persist()
    }

    func updateContacts(bookingID: String, telegram: String, whatsapp: String) async throws {
        guard let session = booking(id: bookingID), !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.missingBookingToken
        }
        let cleanTelegram = telegram.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWhatsApp = whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await bookingService.updateContacts(
            id: bookingID,
            accessToken: session.accessToken,
            telegram: cleanTelegram,
            whatsapp: cleanWhatsApp
        )

        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].telegram = cleanTelegram
        sessions[index].whatsapp = cleanWhatsApp
        sessions[index].pendingChangeConfirmation = true
        if let profile = identityProfile(remote: sessions[index].booking.pilgrimProfile, session: sessions[index]) {
            let updatedProfile = BookingPilgrimProfile(
                firstName: profile.firstName,
                lastName: profile.lastName,
                telegram: cleanTelegram,
                whatsapp: cleanWhatsApp
            )
            if let response = try? await bookingService.syncClientIdentity(
                id: bookingID,
                accessToken: session.accessToken,
                clientUserID: ClientIdentityStore.id,
                profile: updatedProfile
            ) {
                sessions[index].pilgrimID = response.trip.pilgrimID ?? sessions[index].pilgrimID
                sessions[index].operationStatus = response.trip.status
                sessions[index].guide = response.assignment?.guide ?? sessions[index].guide
            }
        }
        persist()
    }

    func updateZiyarat(bookingID: String, makkah: Bool, madinah: Bool) async throws {
        guard let session = booking(id: bookingID), !session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.missingBookingToken
        }
        _ = try await bookingService.updateZiyarat(
            id: bookingID,
            accessToken: session.accessToken,
            makkah: makkah,
            madinah: madinah
        )
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].ziyaratMakkahOverride = makkah
        sessions[index].ziyaratMadinahOverride = madinah
        sessions[index].pendingChangeConfirmation = true
        persist()
    }

    func requestChangeConfirmation(bookingID: String, message: String) async throws {
        _ = try await send(message: message, for: bookingID)
        guard let index = sessions.firstIndex(where: { $0.id == bookingID }) else { return }
        sessions[index].pendingChangeConfirmation = false
        persist()
    }

    private func syncHotelSelectionIfNeeded(
        bookingID: String,
        role: HotelSelectionRole,
        local: BookingHotelSelectionSnapshot?,
        remote: BookingHotelSelectionSnapshot?,
        accessToken: String
    ) async {
        guard let local else { return }
        let differs = remote?.hotelId != local.hotelId ||
            remote?.roomId != local.roomId ||
            remote?.roomCategory != local.roomCategory
        guard differs else { return }
        do {
            _ = try await bookingService.updateHotelSelection(
                id: bookingID,
                accessToken: accessToken,
                role: role,
                snapshot: local
            )
        } catch {
            // Keep the local selection and retry on a later booking-detail refresh.
        }
    }

    func deleteBooking(id: String) async throws {
        guard let session = booking(id: id) else {
            purgeLocalBooking(id: id)
            return
        }

        let token = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            do {
                _ = try await bookingService.deleteBooking(id: id, accessToken: token)
            } catch APIError.status(let code) where code == 404 || code == 410 {
                // Idempotent delete: if the server no longer has the booking, the local copy is stale.
            } catch APIError.server(let code, let message) where isRemoteMissing(code: code, message: message) {
                // Same as a successful delete from the client's point of view.
            } catch APIError.status(let code) where code == 405 {
                throw BookingStoreError.permanentDeleteUnavailable
            } catch APIError.server(let code, let message) where code == 405 || message.uppercased().contains("METHOD_NOT_ALLOWED") {
                throw BookingStoreError.permanentDeleteUnavailable
            } catch {
                // Some legacy delete paths completed the database mutation and then returned 500.
                // Reconcile once: if the booking is now absent remotely, finish the local delete.
                guard await remoteBookingIsMissing(id: id, accessToken: token) else { throw error }
            }
        }

        purgeLocalBooking(id: id)
        persist()
    }


    private func remoteBookingIsMissing(id: String, accessToken: String) async -> Bool {
        do {
            _ = try await bookingService.fetchBooking(id: id, accessToken: accessToken)
            return false
        } catch APIError.status(let code) where code == 404 || code == 410 {
            return true
        } catch APIError.server(let code, let message) where isRemoteMissing(code: code, message: message) {
            return true
        } catch {
            return false
        }
    }
    private func purgeLocalBooking(id: String) {
        sessions.removeAll(where: { $0.id == id })
        chats[id] = nil
    }

    private func isRemoteMissing(code: Int, message: String) -> Bool {
        let normalized = message.uppercased()
        return code == 404 || code == 410 || normalized.contains("NOT_FOUND") || normalized.contains("NOT FOUND")
    }

    private func mergeRemoteHotelSelection(_ remote: BookingHotelSelectionSnapshot?, into local: inout BookingHotelSelectionSnapshot?) {
        guard let remote else { return }
        if remote.roomCategory == nil,
           remote.roomId == nil,
           let current = local,
           current.hotelId == remote.hotelId,
           current.roomCategory != nil {
            return
        }
        local = remote
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
            var migrated = value
            if let selection = migrated.hotelSelection {
                migrated.hotelSelection = selection.migratedLegacyPrimaryRoom
            }
            return migrated
        }
    }
}
