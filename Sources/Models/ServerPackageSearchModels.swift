import Foundation

enum ServerPackageProductKey: String, Codable, CaseIterable, Identifiable, Hashable {
    case essential
    case comfort
    case luxury

    var id: String { rawValue }
}

enum ServerPackageSearchMode: String, Codable, Hashable {
    case standard
    case sundayClub
}

enum ServerPackageSearchStatus: String, Codable, Hashable {
    case queued
    case searching
    case ready
    case partial
    case failed

    var isTerminal: Bool { self == .ready || self == .failed }
}

enum ServerPackageCardStatus: String, Codable, Hashable {
    case searching
    case ready
    case blocked
}

enum ServerIntercityTransport: String, Codable, Hashable {
    case road
    case haramainTrain
}

struct ServerPackageSearchRequest: Encodable {
    struct Travelers: Encodable {
        let adults: Int
        let children: Int
        let infants: Int
        let rooms: Int
    }

    let clientRequestId: String
    let originCode: String
    let arrivalAirportCode: String
    let startDate: String
    let endDate: String
    let flexibility: String
    let includeMadinah: Bool
    let travelers: Travelers

    init(trip: TripDraft, clientRequestId: String) {
        self.clientRequestId = clientRequestId
        originCode = trip.originCode
        arrivalAirportCode = trip.isWeekendUmrah ? "JED" : trip.arrivalAirport.rawValue
        startDate = Self.dayFormatter.string(from: trip.departureDate)
        endDate = Self.dayFormatter.string(from: trip.returnDate)
        flexibility = trip.flexibility.rawValue
        includeMadinah = trip.scope == .makkahAndMadinah
        travelers = .init(adults: trip.adults, children: trip.children, infants: trip.infants, rooms: trip.rooms)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct ServerPackageItinerary: Codable, Hashable {
    let mode: ServerPackageSearchMode
    let originCode: String
    let outboundDestination: String
    let returnOrigin: String
    let startDate: String
    let endDate: String
    let totalDays: Int
    let totalNights: Int
    let includeMadinah: Bool
    let makkahCheckIn: String
    let makkahCheckOut: String
    let makkahNights: Int
    let madinahCheckIn: String?
    let madinahCheckOut: String?
    let madinahNights: Int
}

struct ServerPackageHotel: Codable, Hashable, Identifiable {
    let hotelId: String
    let hotelName: String
    let city: String
    let stars: Int?
    let rating: Double?
    let reviewCount: Int?
    let coverImageURL: String?
    let imageCount: Int
    let roomCount: Int
    let updatedAt: String
    let roomId: String?
    let pricingMode: String

    var id: String { hotelId }

    var hotelSummary: HotelSummary {
        HotelSummary(
            id: hotelId,
            name: hotelName,
            city: city,
            stars: stars,
            rating: rating,
            reviewCount: reviewCount,
            status: "published",
            coverImageURL: coverImageURL,
            imageCount: imageCount,
            roomCount: roomCount,
            updatedAt: updatedAt
        )
    }
}

struct ServerPackageFlightSegment: Codable, Hashable, Identifiable {
    let id: String
    let airline: String
    let airlineCode: String
    let flightNumber: String
    let origin: String
    let destination: String
    let departureAt: String
    let arrivalAt: String
    let durationMinutes: Int
    let originTerminal: String?
    let destinationTerminal: String?
    let aircraft: String?
    let operatingCarrier: String?
    let cabin: String?
}

struct ServerPackageFlightCandidate: Codable, Hashable, Identifiable {
    let id: String
    let providerId: String
    let sourceLabel: String
    let direction: String
    let dateOffset: Int
    let travelDate: String
    let origin: String
    let destination: String
    let airline: String
    let airlineCode: String
    let flightNumber: String
    let departureAt: String
    let arrivalAt: String
    let durationMinutes: Int
    let stops: Int
    let currency: String
    let segments: [ServerPackageFlightSegment]

    func flightOffer(quote: ServerPublicPackageQuote) -> FlightOffer? {
        guard let first = segments.first,
              let departure = ServerPackageDateParser.dateTime(departureAt, airportCode: origin),
              let arrival = ServerPackageDateParser.dateTime(arrivalAt, airportCode: destination) else { return nil }

        let normalizedSegments = segments.compactMap { item -> FlightSegment? in
            guard let segmentDeparture = ServerPackageDateParser.dateTime(item.departureAt, airportCode: item.origin),
                  let segmentArrival = ServerPackageDateParser.dateTime(item.arrivalAt, airportCode: item.destination),
                  FlightReferenceCatalog.normalizedVerifiedFlightNumber(item.flightNumber) != nil else { return nil }
            let code = FlightReferenceCatalog.airlineCode(from: item.flightNumber) ?? item.airlineCode.uppercased()
            let carrier = FlightReferenceCatalog.airlineName(code: code, fallback: item.airline)
            return FlightSegment(
                id: item.id,
                airline: carrier,
                airlineCode: code,
                flightNumber: item.flightNumber,
                origin: FlightAirportSnapshot(code: item.origin, terminal: item.originTerminal),
                destination: FlightAirportSnapshot(code: item.destination, terminal: item.destinationTerminal),
                departureAt: segmentDeparture,
                arrivalAt: segmentArrival,
                durationMinutes: item.durationMinutes,
                aircraft: item.aircraft,
                operatingCarrier: item.operatingCarrier,
                cabin: item.cabin
            )
        }
        guard normalizedSegments.count == segments.count,
              normalizedSegments.count == stops + 1 else { return nil }

        let primaryCode = FlightReferenceCatalog.airlineCode(from: first.flightNumber) ?? first.airlineCode.uppercased()
        let primaryCarrier = FlightReferenceCatalog.airlineName(code: primaryCode, fallback: first.airline)
        let connections = normalizedSegments.dropLast().map { $0.destination }
        let offer = FlightOffer(
            id: id,
            direction: direction.lowercased() == "inbound" ? .inbound : .outbound,
            airline: primaryCarrier,
            flightNumber: first.flightNumber,
            origin: origin,
            destination: destination,
            departureAt: departure,
            arrivalAt: arrival,
            stops: stops,
            durationMinutes: durationMinutes,
            totalPackagePrice: quote.pricePerPerson,
            currency: quote.currency,
            sourceLabel: sourceLabel,
            packageTotalPrice: quote.totalPackagePrice,
            quoteId: quote.quoteId,
            sourceCandidateID: id,
            airlineCode: primaryCode,
            segments: normalizedSegments,
            connectionAirports: connections
        )
        return offer.isVerifiedForBooking ? offer : nil
    }
}

struct ServerPackageTransport: Codable, Hashable {
    let type: ServerIntercityTransport
    let label: String
    let haramainSarPerTraveler: Int?
}

struct ServerPublicPackageQuote: Codable, Hashable {
    let quoteId: String
    let pricingVersion: String
    let currency: String
    let pricePerPerson: Decimal
    let totalPackagePrice: Decimal
    let roomCount: Int
    let vehicleCount: Int

    var packageQuote: PackageQuote {
        PackageQuote(
            totalPackagePrice: totalPackagePrice,
            pricePerPerson: pricePerPerson,
            currency: currency,
            isEstimated: false,
            quoteId: quoteId
        )
    }
}

struct ServerGeneratedPackage: Codable, Hashable, Identifiable {
    let key: ServerPackageProductKey
    let pricingTier: PackageTier
    let stars: Int
    let recommended: Bool
    let status: ServerPackageCardStatus
    let blockReason: String?
    let hotelMakkah: ServerPackageHotel?
    let hotelMadinah: ServerPackageHotel?
    let transport: ServerPackageTransport
    let selectedOutboundCandidateId: String?
    let selectedInboundCandidateId: String?
    let selectedDateOffset: Int
    let quote: ServerPublicPackageQuote?
    let quoteExpiresAt: String?
    let hotelPricingMode: String

    var id: ServerPackageProductKey { key }
}

struct ServerPackageSearchSnapshot: Codable, Hashable {
    let ok: Bool
    let searchId: String
    let clientRequestId: String
    let sequence: Int
    let status: ServerPackageSearchStatus
    let mode: ServerPackageSearchMode
    let itinerary: ServerPackageItinerary
    let packages: [ServerGeneratedPackage]
    let outboundFlights: [ServerPackageFlightCandidate]
    let inboundFlights: [ServerPackageFlightCandidate]
    let searchedDateOffsets: [Int]
    let pendingDateOffsets: [Int]
    let providerReady: Bool
    let message: String?
    let updatedAt: String
}

struct ServerPackageRequoteRequest: Encodable {
    let packageKey: ServerPackageProductKey
    let outboundCandidateId: String
    let inboundCandidateId: String
    let makkahHotelId: String?
    let madinahHotelId: String?
    let makkahRoomId: String?
    let madinahRoomId: String?
}

struct ServerPackageRequoteResponse: Decodable {
    let ok: Bool
    let package: ServerGeneratedPackage
    let itinerary: ServerPackageItinerary
}

enum ServerPackageDateParser {
    static func day(_ value: String) -> Date? {
        guard value.count == 10 else { return nil }
        var components = DateComponents()
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        return components.date
    }

    static func dateTime(_ value: String, airportCode: String) -> Date? {
        if value.hasSuffix("Z") || value.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            if let value = isoWithFraction.date(from: value) ?? iso.date(from: value) { return value }
        }
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = FlightReferenceCatalog.timeZone(for: airportCode) ?? TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension ServerPackageItinerary {
    func shifted(by offset: Int) -> ServerPackageItinerary {
        guard offset != 0 else { return self }
        func shift(_ value: String?) -> String? {
            guard let value, let date = ServerPackageDateParser.day(value),
                  let shifted = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: date) else { return value }
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: shifted)
        }
        return ServerPackageItinerary(
            mode: mode,
            originCode: originCode,
            outboundDestination: outboundDestination,
            returnOrigin: returnOrigin,
            startDate: shift(startDate) ?? startDate,
            endDate: shift(endDate) ?? endDate,
            totalDays: totalDays,
            totalNights: totalNights,
            includeMadinah: includeMadinah,
            makkahCheckIn: shift(makkahCheckIn) ?? makkahCheckIn,
            makkahCheckOut: shift(makkahCheckOut) ?? makkahCheckOut,
            makkahNights: makkahNights,
            madinahCheckIn: shift(madinahCheckIn),
            madinahCheckOut: shift(madinahCheckOut),
            madinahNights: madinahNights
        )
    }
}
