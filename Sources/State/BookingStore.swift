import Foundation
import Combine

@MainActor
final class BookingStore: ObservableObject {
    @Published private(set) var sessions: [StoredBookingSession]
    @Published var isCreating = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let service = BookingService()

    init() {
        self.sessions = BookingSessionVault.load()
    }

    var latest: StoredBookingSession? { sessions.first }

    func create(
        trip: TripDraft,
        hotel: HotelSummary,
        outbound: FlightOffer,
        inbound: FlightOffer,
        quote: PackageQuote
    ) async -> StoredBookingSession? {
        guard !isCreating else { return nil }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            let request = BookingDraftBuilder.make(trip: trip, hotel: hotel, outbound: outbound, inbound: inbound, quote: quote)
            let response = try await service.create(request)
            let session = StoredBookingSession(booking: response.booking, accessToken: response.accessToken)
            sessions.removeAll { $0.id == session.id }
            sessions.insert(session, at: 0)
            persist()
            IumrahHaptics.success()
            return session
        } catch {
            errorMessage = error.localizedDescription
            IumrahHaptics.error()
            return nil
        }
    }

    func refreshAll() async {
        guard !isRefreshing, !sessions.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var refreshed = sessions
        for index in refreshed.indices {
            do {
                refreshed[index].booking = try await service.read(id: refreshed[index].id, accessToken: refreshed[index].accessToken)
            } catch {
                continue
            }
        }
        sessions = refreshed.sorted { $0.booking.createdAt > $1.booking.createdAt }
        persist()
    }

    func refresh(id: String) async {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        do {
            sessions[index].booking = try await service.read(id: sessions[index].id, accessToken: sessions[index].accessToken)
            persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func session(id: String) -> StoredBookingSession? {
        sessions.first(where: { $0.id == id })
    }

    private func persist() {
        BookingSessionVault.save(Array(sessions.prefix(20)))
    }
}
