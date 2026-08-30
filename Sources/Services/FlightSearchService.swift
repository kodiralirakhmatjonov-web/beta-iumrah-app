import Foundation

@MainActor
protocol FlightSearchServicing {
    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer]
    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer]
}

@MainActor
struct BetaFlightSearchService: FlightSearchServicing {
    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer] {
        try await Task.sleep(for: .milliseconds(1100))
        return makeOffers(direction: .outbound, trip: trip, anchor: trip.departureDate)
    }

    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer] {
        try await Task.sleep(for: .milliseconds(900))
        return makeOffers(direction: .inbound, trip: trip, anchor: trip.returnDate)
    }

    private func makeOffers(direction: FlightDirection, trip: TripDraft, anchor: Date) -> [FlightOffer] {
        let calendar = Calendar.current
        let airlines = [
            ("Uzbekistan Airways", "HY"),
            ("Flynas", "XY"),
            ("Turkish Airlines", "TK"),
            ("Qatar Airways", "QR"),
            ("Emirates", "EK"),
            ("Air Arabia", "G9")
        ]

        let baseByTier: [PackageTier: Decimal] = [
            .economy: 1090,
            .standard: 1290,
            .comfort: 1540,
            .luxury: 2290
        ]
        let base = baseByTier[trip.packageTier] ?? 1290

        return airlines.enumerated().map { index, item in
            let dayShift = dayOffset(index: index, flexibility: trip.flexibility)
            let day = calendar.date(byAdding: .day, value: dayShift, to: anchor) ?? anchor
            let departureHour = [6, 8, 11, 14, 18, 22][index]
            let departure = calendar.date(bySettingHour: departureHour, minute: index % 2 == 0 ? 20 : 45, second: 0, of: day) ?? day
            let duration = [310, 425, 520, 455, 500, 390][index]
            let arrival = calendar.date(byAdding: .minute, value: duration, to: departure) ?? departure
            let stops = [0, 1, 1, 1, 1, 1][index]
            let delta = Decimal([0, -45, 95, 70, 140, -15][index])
            let perPerson = base + delta

            return FlightOffer(
                id: "beta-\(direction.rawValue)-\(index)",
                direction: direction,
                airline: item.0,
                flightNumber: "\(item.1) \(120 + index * 17)",
                origin: direction == .outbound ? trip.originCode : trip.returnOriginCode,
                destination: direction == .outbound ? trip.outboundDestinationCode : trip.originCode,
                departureAt: departure,
                arrivalAt: arrival,
                stops: stops,
                durationMinutes: duration,
                totalPackagePrice: perPerson,
                currency: "USD",
                sourceLabel: "Flight Engine Sandbox",
                packageTotalPrice: perPerson * Decimal(max(1, trip.travelerCount))
            )
        }
    }

    private func dayOffset(index: Int, flexibility: DateFlexibility) -> Int {
        switch flexibility {
        case .exact: return 0
        case .plusMinusOne, .plusMinusTwo: return [-2, -1, 0, 1, 2, 0][index]
        case .weekend: return 0
        }
    }
}
