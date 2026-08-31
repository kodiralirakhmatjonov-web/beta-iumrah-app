import Foundation
import Combine

struct FlightBotChallenge: Identifiable, Hashable {
    let id: String
    let providerID: FlightBotProviderID
    let providerName: String
    let url: URL
    let request: FlightBotSearchRequest
    let createdAt: Date

    var sessionKey: FlightBotDeviceSessionKey {
        FlightBotDeviceSessionKey(providerID: providerID, direction: request.direction)
    }

    init(provider: FlightBotProvider, request: FlightBotSearchRequest, url: URL) {
        self.id = UUID().uuidString
        self.providerID = provider.id
        self.providerName = provider.displayName
        self.url = url
        self.request = request
        self.createdAt = Date()
    }
}

@MainActor
final class FlightBotChallengeCenter: ObservableObject {
    static let shared = FlightBotChallengeCenter()

    @Published private(set) var pending: FlightBotChallenge?

    private init() {}

    func publish(_ challenge: FlightBotChallenge) {
        // Avoid replacing an actionable verification sheet with the same carrier's
        // duplicate challenge emitted by a nearby flexible-date attempt.
        if let pending,
           pending.providerID == challenge.providerID,
           pending.request.direction == challenge.request.direction {
            return
        }
        pending = challenge
    }

    func clear(_ challenge: FlightBotChallenge? = nil) {
        if let challenge, pending?.id != challenge.id { return }
        pending = nil
    }
}
