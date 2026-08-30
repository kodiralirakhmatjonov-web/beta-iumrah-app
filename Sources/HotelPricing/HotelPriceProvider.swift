import Foundation

struct HotelPriceProvider: Hashable {
    let id: HotelPriceProviderID
    let displayName: String
    let baseURL: URL

    func searchURL(for request: HotelPriceSearchRequest) -> URL {
        let checkIn = Self.dayFormatter.string(from: request.checkIn)
        let checkOut = Self.dayFormatter.string(from: request.checkOut)
        let destination = "\(request.hotel.name), \(request.city)"

        switch id {
        case .booking:
            var components = URLComponents(string: "https://www.booking.com/searchresults.html")!
            components.queryItems = [
                URLQueryItem(name: "ss", value: destination),
                URLQueryItem(name: "checkin", value: checkIn),
                URLQueryItem(name: "checkout", value: checkOut),
                URLQueryItem(name: "group_adults", value: String(request.totalHotelGuests)),
                URLQueryItem(name: "group_children", value: "0"),
                URLQueryItem(name: "no_rooms", value: String(max(1, request.rooms))),
                URLQueryItem(name: "selected_currency", value: "USD"),
                URLQueryItem(name: "lang", value: "en-us")
            ]
            return components.url ?? baseURL

        case .expedia:
            var components = URLComponents(string: "https://www.expedia.com/Hotel-Search")!
            components.queryItems = [
                URLQueryItem(name: "destination", value: destination),
                URLQueryItem(name: "startDate", value: checkIn),
                URLQueryItem(name: "endDate", value: checkOut),
                URLQueryItem(name: "adults", value: String(request.totalHotelGuests)),
                URLQueryItem(name: "rooms", value: String(max(1, request.rooms))),
                URLQueryItem(name: "useRewards", value: "false")
            ]
            return components.url ?? baseURL
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum HotelPriceProviderRegistry {
    static let providers: [HotelPriceProvider] = [
        .init(id: .booking, displayName: "Booking.com", baseURL: URL(string: "https://www.booking.com/")!),
        .init(id: .expedia, displayName: "Expedia", baseURL: URL(string: "https://www.expedia.com/")!)
    ]
}
