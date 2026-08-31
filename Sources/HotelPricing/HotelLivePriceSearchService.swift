import Foundation

@MainActor
final class HotelLivePriceSearchService {
    private struct CacheEntry {
        let createdAt: Date
        let value: HotelPriceSearchSnapshot
    }

    private var cache: [String: CacheEntry] = [:]
    private let cacheLifetime: TimeInterval = 12 * 60

    func search(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async -> HotelPriceSearchSnapshot {
        let key = signature(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        if let cached = cache[key], Date().timeIntervalSince(cached.createdAt) < cacheLifetime { return cached.value }

        let requests = makeRequests(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        // Keep only two hotel WKWebViews active at once (Booking + Expedia).
        // Flight search already runs several provider web sessions in parallel;
        // launching four additional hotel WebViews on smaller iPhones can trigger
        // WebKit process eviction. Makkah and Madinah therefore run one after the
        // other while both hotel providers still race in parallel for each city.
        let makkah = await searchHotel(requests.makkah)
        let madinah = await searchHotelIfPresent(requests.madinah)
        let snapshot = HotelPriceSearchSnapshot(makkah: makkah, madinah: madinah)
        cache[key] = CacheEntry(createdAt: Date(), value: snapshot)
        return snapshot
    }


    private func searchHotelIfPresent(_ request: HotelPriceSearchRequest?) async -> [HotelPriceObservation] {
        guard let request else { return [] }
        return await searchHotel(request)
    }

    private func searchHotel(_ request: HotelPriceSearchRequest) async -> [HotelPriceObservation] {
        let deadline = Date().addingTimeInterval(AppConfig.hotelPriceSearchHardTimeoutSeconds)
        let tasks = HotelPriceProviderRegistry.providers.map { provider in
            Task { @MainActor () -> HotelPriceObservation? in
                guard Date() < deadline else { return nil }
                do {
                    let budget = min(AppConfig.hotelPriceProviderTimeoutSeconds, max(6, deadline.timeIntervalSinceNow))
                    return try await HotelPriceBotRunner(provider: provider, request: request).run(timeoutSeconds: budget)
                } catch {
                    return nil
                }
            }
        }
        var values: [HotelPriceObservation] = []
        for task in tasks {
            if let value = await task.value { values.append(value) }
        }
        return values.sorted { $0.amount < $1.amount }
    }

    private func makeRequests(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) -> (makkah: HotelPriceSearchRequest, madinah: HotelPriceSearchRequest?) {
        let windows = TripStayPlanner.windows(for: trip, calendar: Calendar(identifier: .gregorian))

        let makkah = HotelPriceSearchRequest(
            hotel: makkahHotel,
            city: "Makkah",
            checkIn: windows.makkah.checkIn,
            checkOut: windows.makkah.checkOut,
            adults: trip.adults,
            children: trip.children,
            infants: trip.infants,
            rooms: trip.rooms
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
                rooms: trip.rooms
            )
        } else {
            madinah = nil
        }
        return (makkah, madinah)
    }

    private func signature(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            makkahHotel.id,
            madinahHotel?.id ?? "-",
            formatter.string(from: trip.departureDate),
            formatter.string(from: trip.returnDate),
            String(trip.adults), String(trip.children), String(trip.infants), String(trip.rooms)
        ].joined(separator: "|")
    }
}
