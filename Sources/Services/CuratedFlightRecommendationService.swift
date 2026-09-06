import Foundation

@MainActor
final class CuratedFlightRecommendationService {
    static let shared = CuratedFlightRecommendationService()
    private let api = APIClient.shared

    private init() {}

    /// Loads every staff-published direct Umrah option for the departure airport.
    /// The carousel is deliberately broader than the currently selected JED/MED
    /// itinerary order so the pilgrim can discover a better flight/date first.
    func load(trip: TripDraft, from: Date = Date(), days: Int = 365) async throws -> [CuratedFlightRecommendation] {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: from)
        let end = calendar.date(byAdding: .day, value: max(1, min(days, 365)), to: start) ?? start

        let response: CuratedFlightRecommendationsResponse = try await api.get(
            "/api/package/flights/recommendations",
            query: [
                URLQueryItem(name: "umrah_origin", value: trip.originCode.uppercased()),
                URLQueryItem(name: "from", value: Self.day.string(from: start)),
                URLQueryItem(name: "to", value: Self.day.string(from: end))
            ],
            timeoutInterval: 10
        )

        guard response.ok else { return [] }
        // Keep the server order: staff priority first, then the lowest hidden
        // supplier fare. The customer sees no fare, only the best-ranked cards.
        return response.recommendations.filter { $0.nonstop }
    }

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        return day.date(from: string)
    }
}
