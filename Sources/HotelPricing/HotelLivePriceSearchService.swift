import Foundation

@MainActor
final class HotelLivePriceSearchService {
    private struct CacheEntry {
        let createdAt: Date
        let value: HotelPriceSearchSnapshot
    }

    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<HotelPriceSearchSnapshot, Never>] = [:]
    private let cacheLifetime: TimeInterval = 5 * 60
    private let packageEngine = RemotePackageEngineClient()

    func search(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String? = nil,
        makkahRoomName: String? = nil,
        makkahRoomCapacity: Int? = nil,
        madinahRoomId: String? = nil,
        madinahRoomName: String? = nil,
        madinahRoomCapacity: Int? = nil,
        forceRefresh: Bool = false
    ) async -> HotelPriceSearchSnapshot {
        // Booking/Expedia search surfaces can reliably verify the concrete hotel,
        // dates, occupancy and room count, but the app's internal Double/Triple/
        // Quadruple IDs are not provider inventory IDs. They therefore must not be
        // used as a cache key or as proof of a provider room/rate plan.
        let key = signature(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomCapacity: makkahRoomCapacity,
            madinahRoomCapacity: madinahRoomCapacity
        )

        if forceRefresh {
            cache.removeValue(forKey: key)
        } else if let cached = cache[key], Date().timeIntervalSince(cached.createdAt) < cacheLifetime {
            return cached.value
        }

        // The hotel-selection screen, outbound search and final-price screen can
        // reach this method within a few seconds of one another. Coalesce them into
        // one provider lookup so the app neither opens duplicate WKWebViews nor
        // waits for a second identical search at the end of generation.
        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return HotelPriceSearchSnapshot.empty }
            return await self.performSearch(
                trip: trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                makkahRoomId: makkahRoomId,
                makkahRoomName: makkahRoomName,
                makkahRoomCapacity: makkahRoomCapacity,
                madinahRoomId: madinahRoomId,
                madinahRoomName: madinahRoomName,
                madinahRoomCapacity: madinahRoomCapacity
            )
        }
        inFlight[key] = task
        let snapshot = await task.value
        inFlight.removeValue(forKey: key)

        // Never negative-cache a provider failure/challenge. A failed search must be
        // retryable immediately from the final-price screen instead of getting stuck
        // behind a five-minute empty cache entry.
        let isComplete = !snapshot.makkah.isEmpty && (trip.scope != .makkahAndMadinah || !snapshot.madinah.isEmpty)
        if isComplete {
            cache[key] = CacheEntry(createdAt: Date(), value: snapshot)
        }
        return snapshot
    }

    private func performSearch(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        makkahRoomCapacity: Int?,
        madinahRoomId: String?,
        madinahRoomName: String?,
        madinahRoomCapacity: Int?
    ) async -> HotelPriceSearchSnapshot {
        async let makkahSourcesTask = fetchPricingSources(hotelID: makkahHotel.id)
        async let madinahSourcesTask = fetchPricingSources(hotelID: madinahHotel?.id)
        let (makkahSources, madinahSources) = await (makkahSourcesTask, madinahSourcesTask)

        let requests = makeRequests(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: makkahRoomId,
            makkahRoomName: makkahRoomName,
            makkahRoomCapacity: makkahRoomCapacity,
            makkahPricingSources: makkahSources,
            madinahRoomId: madinahRoomId,
            madinahRoomName: madinahRoomName,
            madinahRoomCapacity: madinahRoomCapacity,
            madinahPricingSources: madinahSources
        )
        let values = await searchHotelsProgressively(makkah: requests.makkah, madinah: requests.madinah)
        return HotelPriceSearchSnapshot(makkah: values.makkah, madinah: values.madinah)
    }

    func invalidateAll() {
        cache.removeAll()
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
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
            #if DEBUG
            print("[HotelPrice] \(provider.displayName) \(request.city) \(request.hotel.name): \(error)")
            #endif
            return nil
        }
    }

    private func makeRequests(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        makkahRoomCapacity: Int?,
        makkahPricingSources: [HotelPricingSourceIdentity],
        madinahRoomId: String?,
        madinahRoomName: String?,
        madinahRoomCapacity: Int?,
        madinahPricingSources: [HotelPricingSourceIdentity]
    ) -> (makkah: HotelPriceSearchRequest, madinah: HotelPriceSearchRequest?) {
        let windows = TripStayPlanner.windows(for: trip, calendar: Calendar(identifier: .gregorian))
        let makkahRooms = resolvedRoomCount(for: trip, roomCapacity: makkahRoomCapacity)
        let madinahRooms = resolvedRoomCount(for: trip, roomCapacity: madinahRoomCapacity)

        let makkah = HotelPriceSearchRequest(
            hotel: makkahHotel,
            city: "Makkah",
            checkIn: windows.makkah.checkIn,
            checkOut: windows.makkah.checkOut,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants,
            rooms: makkahRooms,
            // Keep the app selection attached for diagnostics/bookings, but the
            // provider bot verifies the hotel stay rather than pretending that an
            // internal iumrah room ID is a Booking/Expedia inventory ID.
            selectedRoomId: makkahRoomId,
            selectedRoomName: makkahRoomName,
            pricingSources: makkahPricingSources
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
                rooms: madinahRooms,
                selectedRoomId: madinahRoomId,
                selectedRoomName: madinahRoomName,
                pricingSources: madinahPricingSources
            )
        } else {
            madinah = nil
        }
        return (makkah, madinah)
    }

    private func fetchPricingSources(hotelID: String?) async -> [HotelPricingSourceIdentity] {
        guard let hotelID, !hotelID.isEmpty else { return [] }
        return (try? await packageEngine.hotelPricingSources(hotelID: hotelID)) ?? []
    }

    private func signature(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomCapacity: Int?,
        madinahRoomCapacity: Int?
    ) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            makkahHotel.id,
            madinahHotel?.id ?? "-",
            formatter.string(from: trip.hotelStayStartDate),
            formatter.string(from: trip.returnDate),
            String(trip.adults), String(trip.children), String(trip.infants),
            String(resolvedRoomCount(for: trip, roomCapacity: makkahRoomCapacity)),
            String(resolvedRoomCount(for: trip, roomCapacity: madinahRoomCapacity)), trip.scope.rawValue
        ].joined(separator: "|")
    }

    private func resolvedRoomCount(for trip: TripDraft, roomCapacity: Int?) -> Int {
        let bedOccupants = max(1, trip.adults + trip.children)
        let capacity = max(1, roomCapacity ?? 4)
        let minimumRooms = max(1, Int(ceil(Double(bedOccupants) / Double(capacity))))
        return max(trip.rooms, minimumRooms)
    }
}
