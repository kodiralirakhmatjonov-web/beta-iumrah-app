import Foundation

@MainActor
final class HotelLivePriceSearchService {
    private struct CacheEntry {
        let createdAt: Date
        let value: HotelPriceSearchSnapshot
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheLifetime: TimeInterval = 12 * 60

    func search(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String? = nil,
        makkahRoomName: String? = nil,
        madinahRoomId: String? = nil,
        madinahRoomName: String? = nil
    ) async -> HotelPriceSearchSnapshot {
        let key = signature(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName
        )
        if let cached = cache[key], Date().timeIntervalSince(cached.createdAt) < cacheLifetime { return cached.value }

        let requests = makeRequests(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName
        )
        let values = await searchHotelsProgressively(makkah: requests.makkah, madinah: requests.madinah)
        let snapshot = HotelPriceSearchSnapshot(makkah: values.makkah, madinah: values.madinah)
        cache[key] = CacheEntry(createdAt: Date(), value: snapshot)
        return snapshot
    }


    /// Verifies Makkah and Madinah concurrently without allowing more than two
    /// hotel WKWebViews at once on smaller iPhones. Each provider is one round:
    /// Booking checks both cities in parallel, then Expedia checks both cities.
    /// This preserves cross-provider comparison while removing the old city-by-city
    /// serialization that delayed Madinah verification.
    private func searchHotelsProgressively(
        makkah: HotelPriceSearchRequest,
        madinah: HotelPriceSearchRequest?
    ) async -> (makkah: [HotelPriceObservation], madinah: [HotelPriceObservation]) {
        guard let madinah else {
            return (await searchHotel(makkah), [])
        }

        let deadline = Date().addingTimeInterval(AppConfig.hotelPriceSearchHardTimeoutSeconds)
        var makkahValues: [HotelPriceObservation] = []
        var madinahValues: [HotelPriceObservation] = []

        for provider in HotelPriceProviderRegistry.providers {
            guard Date() < deadline else { break }
            async let makkahValue = search(provider: provider, request: makkah, deadline: deadline)
            async let madinahValue = search(provider: provider, request: madinah, deadline: deadline)
            let pair = await (makkahValue, madinahValue)
            if let value = pair.0 { makkahValues.append(value) }
            if let value = pair.1 { madinahValues.append(value) }
        }

        return (
            makkahValues.sorted { $0.amount < $1.amount },
            madinahValues.sorted { $0.amount < $1.amount }
        )
    }

    private func searchHotel(_ request: HotelPriceSearchRequest) async -> [HotelPriceObservation] {
        let deadline = Date().addingTimeInterval(AppConfig.hotelPriceSearchHardTimeoutSeconds)
        let tasks = HotelPriceProviderRegistry.providers.map { provider in
            Task { @MainActor in
                await self.search(provider: provider, request: request, deadline: deadline)
            }
        }
        var values: [HotelPriceObservation] = []
        for task in tasks {
            if let value = await task.value { values.append(value) }
        }
        return values.sorted { $0.amount < $1.amount }
    }

    private func search(
        provider: HotelPriceProvider,
        request: HotelPriceSearchRequest,
        deadline: Date
    ) async -> HotelPriceObservation? {
        guard Date() < deadline else { return nil }
        do {
            let budget = min(AppConfig.hotelPriceProviderTimeoutSeconds, max(6, deadline.timeIntervalSinceNow))
            return try await HotelPriceBotRunner(provider: provider, request: request).run(timeoutSeconds: budget)
        } catch {
            return nil
        }
    }

    private func makeRequests(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        madinahRoomId: String?,
        madinahRoomName: String?
    ) -> (makkah: HotelPriceSearchRequest, madinah: HotelPriceSearchRequest?) {
        let windows = TripStayPlanner.windows(for: trip, calendar: Calendar(identifier: .gregorian))

        let makkah = HotelPriceSearchRequest(
            hotel: makkahHotel,
            city: "Makkah",
            checkIn: windows.makkah.checkIn,
            checkOut: windows.makkah.checkOut,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants,
            rooms: trip.rooms,
            selectedRoomId: makkahRoomId,
            selectedRoomName: makkahRoomName
        )

        let madinah: HotelPriceSearchRequest?
        if trip.scope == .makkahAndMadinah, let madinahHotel, let window = windows.madinah {
            madinah = HotelPriceSearchRequest(
                hotel: madinahHotel,
                city: "Madinah",
                checkIn: window.checkIn,
                checkOut: window.checkOut,
                adults: trip.adults,
                children: trip.children,
                infants: trip.infants,
                rooms: trip.rooms,
                selectedRoomId: madinahRoomId,
                selectedRoomName: madinahRoomName
            )
        } else {
            madinah = nil
        }
        return (makkah, madinah)
    }

    private func signature(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        madinahRoomId: String?,
        madinahRoomName: String?
    ) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            makkahHotel.id,
            makkahRoomId ?? "-",
            makkahRoomName ?? "-",
            madinahHotel?.id ?? "-",
            madinahRoomId ?? "-",
            madinahRoomName ?? "-",
            formatter.string(from: trip.departureDate),
            formatter.string(from: trip.returnDate),
            String(trip.adults), String(trip.children), String(trip.infants), String(trip.rooms)
        ].joined(separator: "|")
    }
}
