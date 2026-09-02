import Foundation

struct HotelPriceProvider: Hashable {
    let id: HotelPriceProviderID
    let displayName: String
    let baseURL: URL

    func searchURL(for request: HotelPriceSearchRequest) -> URL {
        searchURLs(for: request).first ?? baseURL
    }

    func searchURLs(for request: HotelPriceSearchRequest) -> [URL] {
        let checkIn = Self.dayFormatter.string(from: request.checkIn)
        let checkOut = Self.dayFormatter.string(from: request.checkOut)

        // Business already stores the exact provider identity for a curated hotel.
        // Prefer that property page over a name-only destination search: it removes
        // ambiguity between similarly named hotels and lets the provider render the
        // requested stay directly. Search results remain a fallback for older hotels
        // whose provider identity has not been curated yet.
        let direct = directPropertyURL(
            for: request,
            checkIn: checkIn,
            checkOut: checkOut
        )
        let fallback = fallbackSearchURL(for: request, checkIn: checkIn, checkOut: checkOut)
        var seen = Set<String>()
        return [direct, fallback].compactMap { value in
            guard let value, seen.insert(value.absoluteString).inserted else { return nil }
            return value
        }
    }

    private func fallbackSearchURL(
        for request: HotelPriceSearchRequest,
        checkIn: String,
        checkOut: String
    ) -> URL? {
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
            return components.url

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
            return components.url
        }
    }

    private func directPropertyURL(
        for request: HotelPriceSearchRequest,
        checkIn: String,
        checkOut: String
    ) -> URL? {
        guard let identity = request.pricingSource(for: id) else { return nil }
        let rawURL = identity.canonicalURL ?? identity.sourceURL
        guard var components = URLComponents(string: rawURL),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              id.accepts(host: host) else { return nil }

        var items = components.queryItems ?? []
        func set(_ name: String, _ value: String) {
            items.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            items.append(URLQueryItem(name: name, value: value))
        }

        switch id {
        case .booking:
            set("checkin", checkIn)
            set("checkout", checkOut)
            set("group_adults", String(request.totalHotelGuests))
            set("group_children", "0")
            set("no_rooms", String(max(1, request.rooms)))
            set("selected_currency", "USD")
            set("lang", "en-us")

        case .expedia:
            // Expedia currently accepts the property-page chkin/chkout pair. Keep
            // startDate/endDate as compatibility aliases because older canonical
            // links and Hotel-Search redirects still consume those names.
            set("chkin", checkIn)
            set("chkout", checkOut)
            set("startDate", checkIn)
            set("endDate", checkOut)
            set("adults", String(request.totalHotelGuests))
            set("rooms", String(max(1, request.rooms)))
            set("useRewards", "false")
        }
        components.queryItems = items
        return components.url
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

    static func provider(_ id: HotelPriceProviderID) -> HotelPriceProvider? {
        providers.first { $0.id == id }
    }
}
