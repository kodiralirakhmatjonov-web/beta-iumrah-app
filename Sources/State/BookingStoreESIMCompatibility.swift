import Foundation

// Compatibility bridge for repositories where the eSIM client model was added
// after BookingStore.swift. Keeping this in a separate file avoids replacing
// the newer eSIM-aware BookingModels/HomeDashboard implementation.
@MainActor
private enum BookingESIMCompatibilityCache {
    static var primaryByStore: [ObjectIdentifier: [String: ClientESIMProfile]] = [:]

    static func setPrimary(_ profile: ClientESIMProfile?, bookingID: String, store: BookingStore) {
        let storeID = ObjectIdentifier(store)
        var values = primaryByStore[storeID] ?? [:]
        if let profile {
            values[bookingID] = profile
        } else {
            values.removeValue(forKey: bookingID)
        }
        primaryByStore[storeID] = values
    }

    static func primary(bookingID: String, store: BookingStore) -> ClientESIMProfile? {
        primaryByStore[ObjectIdentifier(store)]?[bookingID]
    }
}

extension ClientTripResponse {
    /// Source-compatible initializer for call sites created before `esims`
    /// became part of ClientTripResponse.
    init(ok: Bool?, trip: ClientTripSnapshot, assignment: ClientBookingAssignment?) {
        self.init(ok: ok, trip: trip, assignment: assignment, esims: nil)
    }
}

extension BookingStore {
    /// Refreshes the eSIM state from the existing authenticated operational-trip
    /// endpoint. No separate paid API or additional backend is introduced here.
    func loadESIMs(for bookingID: String) async throws {
        guard let session = booking(id: bookingID) else {
            BookingESIMCompatibilityCache.setPrimary(nil, bookingID: bookingID, store: self)
            return
        }

        let token = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            // Account-restored sessions may not have a local booking token.
            // Do not manufacture eSIM data in that case.
            BookingESIMCompatibilityCache.setPrimary(nil, bookingID: bookingID, store: self)
            return
        }

        let response = try await BookingService().fetchOperationalTrip(
            id: bookingID,
            headers: ["x-booking-token": token]
        )
        BookingESIMCompatibilityCache.setPrimary(
            response.esims?.first,
            bookingID: bookingID,
            store: self
        )
    }

    func primaryESIM(for bookingID: String) -> ClientESIMProfile? {
        BookingESIMCompatibilityCache.primary(bookingID: bookingID, store: self)
    }
}
