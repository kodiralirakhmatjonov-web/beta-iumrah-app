import Foundation

struct FlightFareCalendarEntry: Identifiable, Hashable, Decodable {
    let outboundDate: String
    let inboundDate: String?
    let minTotalFare: Double
    let minPerTravelerFare: Double
    let currency: String
    let observedAt: String

    var id: String { "\(outboundDate)|\(inboundDate ?? "")|\(currency)" }

    enum CodingKeys: String, CodingKey {
        case outboundDate = "outbound_date"
        case inboundDate = "inbound_date"
        case minTotalFare = "min_total_fare"
        case minPerTravelerFare = "min_per_traveler_fare"
        case currency
        case observedAt = "observed_at"
    }
}

private struct FlightFareCalendarEnvelope: Decodable {
    let ok: Bool
    let prices: [FlightFareCalendarEntry]
    let observations: [FlightFareCalendarEntry]
    let suggestions: [FlightFareCalendarEntry]
}

@MainActor
final class FlightFareCalendarService {
    static let shared = FlightFareCalendarService()
    private let api = APIClient.shared

    private init() {}

    func load(
        trip: TripDraft,
        from: Date,
        to: Date,
        selectedOutbound: Date? = nil
    ) async throws -> (prices: [FlightFareCalendarEntry], observations: [FlightFareCalendarEntry], suggestions: [FlightFareCalendarEntry]) {
        let filters = trip.effectiveFlightFilters
        var query = [
            URLQueryItem(name: "outbound_origin", value: trip.originCode),
            URLQueryItem(name: "outbound_destination", value: trip.outboundDestinationCode),
            URLQueryItem(name: "inbound_origin", value: trip.returnOriginCode),
            URLQueryItem(name: "inbound_destination", value: trip.originCode),
            URLQueryItem(name: "adults", value: String(trip.adults)),
            URLQueryItem(name: "children", value: String(trip.children)),
            URLQueryItem(name: "infants_in_seat", value: String(filters.infantSeating == .seat ? trip.infants : 0)),
            URLQueryItem(name: "infants_on_lap", value: String(filters.infantSeating == .lap ? trip.infants : 0)),
            URLQueryItem(name: "cabin_class", value: filters.cabinClass.rawValue),
            URLQueryItem(name: "from", value: Self.day.string(from: from)),
            URLQueryItem(name: "to", value: Self.day.string(from: to)),
        ]
        if let selectedOutbound {
            query.append(URLQueryItem(name: "selected_outbound", value: Self.day.string(from: selectedOutbound)))
        }
        let response: FlightFareCalendarEnvelope = try await api.get(
            "/api/package/flights/calendar",
            query: query,
            timeoutInterval: 10
        )
        guard response.ok else { return ([], [], []) }
        return (response.prices, response.observations, response.suggestions)
    }

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(_ string: String) -> Date? { day.date(from: string) }
}
