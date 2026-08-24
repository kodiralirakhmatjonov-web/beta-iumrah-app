import Foundation
import Combine

struct FlightBotChallenge: Identifiable, Hashable {
    let id: String
    let providerID: FlightBotProviderID
    let providerName: String
    let url: URL
    let createdAt: Date

    init(provider: FlightBotProvider, url: URL) {
        self.id = UUID().uuidString
        self.providerID = provider.id
        self.providerName = provider.displayName
        self.url = url
        self.createdAt = Date()
    }
}

@MainActor
final class FlightBotChallengeCenter: ObservableObject {
    static let shared = FlightBotChallengeCenter()

    @Published private(set) var pending: FlightBotChallenge?

    private init() {}

    func publish(_ challenge: FlightBotChallenge) {
        pending = challenge
    }

    func clear() {
        pending = nil
    }
}
