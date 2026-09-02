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
        authoritativeMakkahRoomId: String? = nil,
        authoritativeMadinahRoomId: String? = nil,
        intercityTransport: ServerIntercityTransport? = nil,
        outbound: FlightOffer,
        inbound: FlightOffer?,
        quote: PackageQuote,
        language: AppSettingsStore.Language,
        pilgrimProfile: BookingPilgrimProfile?
    ) -> BookingCreateEnvelope {
        let stay = TripStayPlanner.breakdown(for: trip)
        let dates = stayDates(trip: trip, stay: stay)
        let includeMadinah = trip.scope == .makkahAndMadinah
        // Generator V2 pricing chooses Haramain locally for Comfort/Luxury. Keep
        // the booking payload aligned even when the discontinued server-package
        // flow does not pass an explicit intercity transport value.
        let usesHaramain = includeMadinah && (
            intercityTransport == .haramainTrain ||
            (intercityTransport == nil && (trip.packageTier == .comfort || trip.packageTier == .luxury))
        )
        let services = [
            "flight",
            "makkahHotel",
            includeMadinah ? "madinahHotel" : nil,
            "visa",
            "meals",
            "transfer",
            usesHaramain ? "haramainTrain" : nil,
            "accompaniment",
            "ziyaratMakkah",
            includeMadinah ? "ziyaratMadinah" : nil,
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
                cabinClass: outbound.cabinClass ?? trip.effectiveFlightFilters.cabinClass.rawValue,
                preferredPlan: trip.packageTier.rawValue,
                startDate: day(trip.departureDate),
                endDate: day(trip.returnDate),
                flexibleDays: flexibleDays(trip.flexibility),
                hotelPreference: String(trip.hotelStars),
                includeMadinah: includeMadinah,
                flightTripType: trip.resolvedFlightTripType.rawValue,
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
                flightId: [outbound.id, inbound?.id].compactMap { $0 }.joined(separator: "|"),
                makkahHotelId: hotel.id,
                madinahHotelId: includeMadinah ? madinahHotel?.id : nil,
                makkahRoomId: room?.id ?? roomCategory?.id ?? authoritativeMakkahRoomId,
                makkahRoomCategory: roomCategory?.category,
                madinahRoomId: includeMadinah ? (madinahRoom?.id ?? madinahRoomCategory?.id ?? authoritativeMadinahRoomId) : nil,
                madinahRoomCategory: includeMadinah ? madinahRoomCategory?.category : nil
            ),
            customization: .init(
                accompaniment: true,
                guideMeetingPoint: "airport",
                ziyaratMakkah: true,
                ziyaratMadinah: includeMadinah,
                meals: true,
                esim: false
            ),
            includedServices: services,
            hotelNames: .init(
                makkah: hotel.name,
                madinah: includeMadinah ? (madinahHotel?.name ?? L10n.text("recommended_madinah_hotel", language)) : ""
            ),
            flight: flightSummary(outbound: outbound, inbound: inbound),
            pilgrimProfile: pilgrimProfile,
            generatorTrace: .init(
                quoteId: quote.quoteId ?? inbound?.quoteId ?? outbound.quoteId,
                outbound: generatorFlight(outbound),
                inbound: inbound.map(generatorFlight),
                makkahHotel: generatorHotel(hotel, room: room, roomCategory: roomCategory, authoritativeRoomId: authoritativeMakkahRoomId),
                madinahHotel: madinahHotel.map { generatorHotel($0, room: madinahRoom, roomCategory: madinahRoomCategory, authoritativeRoomId: authoritativeMadinahRoomId) }
            ),
            pricingSnapshot: quote.pricingSnapshot
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
            departureAt: isoDateTimeString(offer.departureAt),
            arrivalAt: isoDateTimeString(offer.arrivalAt),
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
                    departureAt: isoDateTimeString(segment.departureAt),
                    arrivalAt: isoDateTimeString(segment.arrivalAt),
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

    private static func flightSummary(outbound: FlightOffer, inbound: FlightOffer?) -> String {
        let outboundValue = [outbound.airlinesSummary, outbound.flightNumbersSummary]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
        guard let inbound else { return outboundValue }
        let inboundValue = [inbound.airlinesSummary, inbound.flightNumbersSummary]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
        return [outboundValue, inboundValue].filter { !$0.isEmpty }.joined(separator: " / ")
    }

    private static func generatorHotel(
        _ hotel: HotelSummary,
        room: HotelRoom?,
        roomCategory: IumrahRoomCategoryOption?,
        authoritativeRoomId: String? = nil
    ) -> BookingGeneratorHotelSnapshot {
        BookingGeneratorHotelSnapshot(
            hotelId: hotel.id,
            hotelName: hotel.name,
            city: hotel.city,
            roomId: room?.id ?? roomCategory?.id ?? authoritativeRoomId,
            roomName: room?.name ?? roomCategory?.displayName,
            roomCategory: roomCategory?.category.rawValue
        )
    }

    private static func isoDateTimeString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private struct StayDates {
        let makkahCheckIn: String
        let makkahCheckOut: String
        let madinahCheckIn: String?
        let madinahCheckOut: String?
    }

    private static func stayDates(trip: TripDraft, stay: TripStayBreakdown) -> StayDates {
        let windows = TripStayPlanner.windows(for: trip)
        return StayDates(
            makkahCheckIn: day(windows.makkah.checkIn),
            makkahCheckOut: day(windows.makkah.checkOut),
            madinahCheckIn: windows.madinah.map { day($0.checkIn) },
            madinahCheckOut: windows.madinah.map { day($0.checkOut) }
        )
    }

    private static func flexibleDays(_ flexibility: DateFlexibility) -> Int {
        switch flexibility {
        case .exact, .weekend:
            return 0
        case .plusMinusOne, .plusMinusTwo:
            // Both legacy flexible raw values now represent the seven-day
            // discovery window (anchor ±3 days). Keep booking metadata aligned
            // with the dates the user was actually allowed to select.
            return 3
        }
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
