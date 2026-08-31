import Foundation

enum BookingDraftBuilder {
    static func make(
        trip: TripDraft,
        hotel: HotelSummary,
        madinahHotel: HotelSummary? = nil,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption?,
        madinahRoom: HotelRoom? = nil,
        madinahRoomCategory: IumrahRoomCategoryOption? = nil,
        outbound: FlightOffer,
        inbound: FlightOffer,
        quote: PackageQuote,
        language: AppSettingsStore.Language,
        pilgrimProfile: BookingPilgrimProfile?
    ) -> BookingCreateEnvelope {
        let stay = TripStayPlanner.breakdown(for: trip)
        let dates = stayDates(trip: trip, stay: stay)
        let includeMadinah = trip.scope == .makkahAndMadinah
        let services = [
            "flight",
            "makkahHotel",
            includeMadinah ? "madinahHotel" : nil,
            "visa",
            "meals",
            "transfer",
            "accompaniment",
            "ziyaratMakkah",
            includeMadinah ? "ziyaratMadinah" : nil,
            "esim",
            "care",
        ].compactMap { $0 }

        let draft = BookingDraftRequest(
            planId: trip.packageTier.rawValue,
            totalUsd: NSDecimalNumber(decimal: quote.totalPackagePrice).doubleValue,
            perPilgrimUsd: NSDecimalNumber(decimal: quote.pricePerPerson).doubleValue,
            input: .init(
                from: trip.originAirport?.city ?? trip.originCode,
                originCode: trip.originCode,
                arrivalAirportCode: trip.outboundDestinationCode,
                cabinClass: "economy",
                preferredPlan: trip.packageTier.rawValue,
                startDate: day(trip.departureDate),
                endDate: day(trip.returnDate),
                flexibleDays: flexibleDays(trip.flexibility),
                hotelPreference: String(trip.hotelStars),
                includeMadinah: includeMadinah,
                travelers: .init(adults: trip.adults, children: trip.children, infants: trip.infants, rooms: trip.rooms)
            ),
            route: .init(
                originCode: trip.originCode,
                outboundDestination: trip.outboundDestinationCode,
                returnOrigin: trip.returnOriginCode
            ),
            stay: .init(
                totalDays: stay.totalDays,
                totalNights: stay.totalNights,
                makkahCheckIn: dates.makkahCheckIn,
                makkahCheckOut: dates.makkahCheckOut,
                makkahNights: stay.makkahNights,
                madinahCheckIn: dates.madinahCheckIn,
                madinahCheckOut: dates.madinahCheckOut,
                madinahNights: stay.madinahNights
            ),
            selection: .init(
                flightId: "\(outbound.id)|\(inbound.id)",
                makkahHotelId: hotel.id,
                madinahHotelId: includeMadinah ? madinahHotel?.id : nil,
                makkahRoomId: room?.id,
                makkahRoomCategory: roomCategory?.category,
                madinahRoomId: includeMadinah ? madinahRoom?.id : nil,
                madinahRoomCategory: includeMadinah ? madinahRoomCategory?.category : nil
            ),
            customization: .init(
                accompaniment: true,
                guideMeetingPoint: "airport",
                ziyaratMakkah: true,
                ziyaratMadinah: includeMadinah,
                meals: true,
                esim: true
            ),
            includedServices: services,
            hotelNames: .init(
                makkah: hotel.name,
                madinah: includeMadinah ? (madinahHotel?.name ?? L10n.text("recommended_madinah_hotel", language)) : ""
            ),
            flight: "\(outbound.airlinesSummary) \(outbound.flightNumbersSummary) · \(inbound.airlinesSummary) \(inbound.flightNumbersSummary)",
            pilgrimProfile: pilgrimProfile,
            generatorTrace: .init(
                quoteId: quote.quoteId ?? inbound.quoteId,
                outbound: generatorFlight(outbound),
                inbound: generatorFlight(inbound),
                makkahHotel: generatorHotel(hotel, room: room, roomCategory: roomCategory),
                madinahHotel: madinahHotel.map { generatorHotel($0, room: madinahRoom, roomCategory: madinahRoomCategory) }
            )
        )
        return BookingCreateEnvelope(lang: language.rawValue, booking: draft)
    }

    private static func generatorFlight(_ offer: FlightOffer) -> BookingGeneratorFlightSnapshot {
        BookingGeneratorFlightSnapshot(
            candidateId: offer.sourceCandidateID,
            airline: offer.airlinesSummary,
            flightNumbers: offer.flightNumbersSummary,
            origin: offer.origin,
            destination: offer.destination,
            departureAt: isoDateTime.string(from: offer.departureAt),
            arrivalAt: isoDateTime.string(from: offer.arrivalAt),
            source: offer.sourceLabel,
            stops: offer.stops,
            durationMinutes: offer.durationMinutes > 0 ? offer.durationMinutes : nil,
            segments: offer.displaySegments.map { segment in
                BookingGeneratorFlightSegmentSnapshot(
                    airline: FlightReferenceCatalog.airlineName(code: segment.airlineCode, fallback: segment.airline),
                    airlineCode: segment.airlineCode,
                    flightNumber: segment.flightNumber,
                    origin: segment.origin.code,
                    destination: segment.destination.code,
                    departureAt: isoDateTime.string(from: segment.departureAt),
                    arrivalAt: isoDateTime.string(from: segment.arrivalAt),
                    originTerminal: segment.origin.terminal,
                    destinationTerminal: segment.destination.terminal,
                    aircraft: segment.aircraft,
                    operatingCarrier: segment.operatingCarrier,
                    cabin: segment.cabin
                )
            },
            connectionAirports: offer.connectionAirports?.map(\.code)
        )
    }

    private static func generatorHotel(_ hotel: HotelSummary, room: HotelRoom?, roomCategory: IumrahRoomCategoryOption?) -> BookingGeneratorHotelSnapshot {
        BookingGeneratorHotelSnapshot(
            hotelId: hotel.id,
            hotelName: hotel.name,
            city: hotel.city,
            roomId: room?.id ?? roomCategory?.id,
            roomName: room?.name ?? roomCategory?.displayName,
            roomCategory: roomCategory?.category.rawValue
        )
    }

    private static let isoDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private struct StayDates {
        let makkahCheckIn: String
        let makkahCheckOut: String
        let madinahCheckIn: String?
        let madinahCheckOut: String?
    }

    private static func stayDates(trip: TripDraft, stay: TripStayBreakdown) -> StayDates {
        let start = Calendar.current.startOfDay(for: trip.departureDate)
        let end = Calendar.current.startOfDay(for: trip.returnDate)
        guard trip.scope == .makkahAndMadinah else {
            return .init(makkahCheckIn: day(start), makkahCheckOut: day(end), madinahCheckIn: nil, madinahCheckOut: nil)
        }

        if trip.arrivalAirport == .madinah {
            let madinahEnd = Calendar.current.date(byAdding: .day, value: stay.madinahNights, to: start) ?? start
            return .init(
                makkahCheckIn: day(madinahEnd),
                makkahCheckOut: day(end),
                madinahCheckIn: day(start),
                madinahCheckOut: day(madinahEnd)
            )
        }

        let makkahEnd = Calendar.current.date(byAdding: .day, value: stay.makkahNights, to: start) ?? start
        return .init(
            makkahCheckIn: day(start),
            makkahCheckOut: day(makkahEnd),
            madinahCheckIn: day(makkahEnd),
            madinahCheckOut: day(end)
        )
    }

    private static func flexibleDays(_ value: DateFlexibility) -> Int {
        switch value {
        case .exact: return 0
        case .plusMinusOne, .plusMinusTwo: return 2
        case .weekend: return 0
        }
    }

    private static func day(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
