import Foundation
import SwiftUI

@MainActor
final class HotelStorefrontStore: ObservableObject {
    @Published private(set) var makkahHotels: [HotelSummary] = []
    @Published private(set) var madinahHotels: [HotelSummary] = []
    @Published private(set) var details: [String: HotelDetail] = [:]
    @Published private(set) var flightBoard: StorefrontFlightBoardResponse?
    @Published private(set) var standardQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var luxuryQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var flightPackagePreviews: [String: StorefrontFlightPackagePreview] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasPrepared = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var favoriteHotelIDs: Set<String> = []

    private let catalog = HotelCatalogService()
    private let storefront = HotelStorefrontService()
    private let favoritesKey = "iumrah.hotelStorefront.favorites.v1"
    private let snapshotURL: URL
    private var preparationTask: Task<Void, Never>?

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        snapshotURL = caches.appendingPathComponent("iumrah-hotel-storefront-v3.json")
        favoriteHotelIDs = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
        restoreDiskSnapshot()
    }

    var allHotels: [HotelSummary] { makkahHotels + madinahHotels }
    var baseline: StorefrontFlightBaseline? { flightBoard?.baseline }

    func prepareIfNeeded() async {
        if hasPrepared { return }
        if let preparationTask {
            await preparationTask.value
            return
        }
        let task = Task { @MainActor in await prepare(force: false) }
        preparationTask = task
        await task.value
        preparationTask = nil
    }

    func refresh() async {
        if let preparationTask { await preparationTask.value }
        let task = Task { @MainActor in await prepare(force: true) }
        preparationTask = task
        await task.value
        preparationTask = nil
    }

    func hotel(id: String) -> HotelSummary? {
        allHotels.first(where: { $0.id == id })
    }

    func detail(for hotel: HotelSummary) -> HotelDetail? { details[hotel.id] }

    func ingest(detail: HotelDetail) {
        details[detail.id] = detail
        rebuildQuotes()
        rebuildFlightPackagePreviews()
        persistDiskSnapshot()
        startImageWarmup()
    }

    func quote(for hotel: HotelSummary, tier: PackageTier = .standard) -> HotelStorefrontQuote? {
        tier == .luxury ? luxuryQuotes[hotel.id] : standardQuotes[hotel.id]
    }

    func packagePreview(for option: StorefrontFlightOption) -> StorefrontFlightPackagePreview? {
        flightPackagePreviews[option.id]
    }

    func previewImages(for hotel: HotelSummary, limit: Int = 3) -> [String] {
        var values: [String] = []
        if let detail = details[hotel.id] {
            values.append(contentsOf: detail.images.sorted(by: imageSort).map(\.url))
        }
        if let cover = hotel.coverImageURL { values.insert(cover, at: 0) }
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }.prefix(limit).map { $0 }
    }

    func isFavorite(_ hotel: HotelSummary) -> Bool { favoriteHotelIDs.contains(hotel.id) }

    func toggleFavorite(_ hotel: HotelSummary) {
        if favoriteHotelIDs.contains(hotel.id) { favoriteHotelIDs.remove(hotel.id) }
        else { favoriteHotelIDs.insert(hotel.id) }
        UserDefaults.standard.set(Array(favoriteHotelIDs).sorted(), forKey: favoritesKey)
        IumrahHaptics.selection()
    }

    func shareURL(for hotel: HotelSummary) -> URL {
        AppConfig.apiBaseURL.appendingPathComponent("h").appendingPathComponent(HotelStorefrontService.publicHotelToken(hotel.id))
    }

    /// The catalogue and the package baseline are intentionally loaded independently.
    /// A Package Engine problem must never make the hotel catalogue disappear.
    /// As soon as both a fresh hotel price and a published flight baseline are present,
    /// the package quote is pure local arithmetic and is rebuilt immediately.
    private func prepare(force: Bool) async {
        guard force || !hasPrepared else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let makkahRequest = hotelListResult(cities: ["Makkah", "Mecca", "Makka"])
        async let madinahRequest = hotelListResult(cities: [
            "Madinah", "Medina", "Madina", "Medinah",
            "Al Madinah", "Al Medina",
            "Madinah Al Munawwarah", "Al Madinah Al Munawwarah"
        ])
        async let flightRequest = flightBoardResult()

        let (makkahResult, madinahResult, flightResult) = await (makkahRequest, madinahRequest, flightRequest)

        var hotelErrors: [Error] = []
        switch makkahResult {
        case .success(let hotels): makkahHotels = hotels
        case .failure(let error): hotelErrors.append(error)
        }
        switch madinahResult {
        case .success(let hotels): madinahHotels = hotels
        case .failure(let error): hotelErrors.append(error)
        }
        if case .success(let board) = flightResult {
            flightBoard = board
        }

        // Most catalogue responses already contain the fresh 48h nightly rate,
        // so quotes normally become available here before detail/gallery requests.
        rebuildQuotes()
        rebuildFlightPackagePreviews()
        startImageWarmup()

        // Hotel detail is also a price fallback. Some catalogue deployments expose
        // the current hotel price only on the detail payload. The previous storefront
        // loaded that payload but never rebuilt quotes afterwards, leaving every hotel
        // filtered out even though the price was present in the database.
        let hotels = allHotels
        if !hotels.isEmpty {
            let loadedDetails = await fetchDetails(for: hotels)
            for detail in loadedDetails { details[detail.id] = detail }
            rebuildQuotes()
            rebuildFlightPackagePreviews()
            persistDiskSnapshot()
            startImageWarmup()
        }

        // A completed catalogue + baseline preparation should not rerun on every
        // tab appearance. Pull-to-refresh remains available for an explicit retry.
        hasPrepared = !allHotels.isEmpty && baseline != nil && !standardQuotes.isEmpty

        if allHotels.isEmpty {
            if let error = hotelErrors.first {
                errorMessage = L10n.error(error, .russian)
            } else {
                errorMessage = "Каталог отелей временно недоступен."
            }
        } else if baseline == nil {
            // Do not hide hotels. This message is shown only in the package-price
            // placeholder and helps distinguish pricing availability from catalog data.
            errorMessage = "Обновляем опубликованные рейсы для расчёта пакета."
        }
    }

    private func hotelListResult(city: String) async -> Result<[HotelSummary], Error> {
        do { return .success(try await catalog.listHotels(city: city)) }
        catch { return .failure(error) }
    }

    private func hotelListResult(cities: [String]) async -> Result<[HotelSummary], Error> {
        var merged: [String: HotelSummary] = [:]
        var lastError: Error?
        for city in cities {
            do {
                for hotel in try await catalog.listHotels(city: city) { merged[hotel.id] = hotel }
            } catch {
                lastError = error
            }
        }
        let hotels = Array(merged.values).sorted { lhs, rhs in
            if lhs.stars != rhs.stars { return (lhs.stars ?? 0) > (rhs.stars ?? 0) }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        if !hotels.isEmpty { return .success(hotels) }
        if let lastError { return .failure(lastError) }
        return .success([])
    }

    private func flightBoardResult() async -> Result<StorefrontFlightBoardResponse, Error> {
        do { return .success(try await storefront.resilientFlightBoard(origin: "TAS")) }
        catch { return .failure(error) }
    }

    private func fetchDetails(for hotels: [HotelSummary]) async -> [HotelDetail] {
        await withTaskGroup(of: HotelDetail?.self, returning: [HotelDetail].self) { group in
            for hotel in hotels {
                group.addTask {
                    try? await self.catalog.hotelDetail(id: hotel.id)
                }
            }
            var loaded: [HotelDetail] = []
            for await detail in group {
                if let detail { loaded.append(detail) }
            }
            return loaded
        }
    }

    private func rebuildQuotes() {
        guard let baseline else {
            // Keep the last valid local quotes from the disk snapshot while the
            // flight baseline refreshes. A transient network failure must never
            // turn already calculated hotel cards back into endless spinners.
            return
        }

        var standard: [String: HotelStorefrontQuote] = [:]
        var luxury: [String: HotelStorefrontQuote] = [:]
        for hotel in allHotels {
            let price = bestFreshPrice(for: hotel)
            if let quote = try? storefront.quote(hotel: hotel, tier: .standard, baseline: baseline, price: price) {
                standard[hotel.id] = quote
            }
            if let quote = try? storefront.quote(hotel: hotel, tier: .luxury, baseline: baseline, price: price) {
                luxury[hotel.id] = quote
            }
        }
        standardQuotes = standard
        luxuryQuotes = luxury
    }

    private func bestFreshPrice(for hotel: HotelSummary) -> HotelCatalogPrice? {
        if let detailPrice = details[hotel.id]?.price, detailPrice.isFresh { return detailPrice }
        if let summaryPrice = hotel.price, summaryPrice.isFresh { return summaryPrice }
        return details[hotel.id]?.price ?? hotel.price
    }

    // MARK: - Published-flight package prices

    /// Hotels > Flights never exposes a component ticket fare as the headline price.
    /// Every eligible publication is attached to a complete 4...8-day Umrah journey
    /// and sent through the exact same LocalPackagePricingEngine used by Generator.
    private func rebuildFlightPackagePreviews() {
        guard let board = flightBoard,
              let makkahHotel = fixedStorefrontHotel(
                in: makkahHotels,
                preferredNames: ["Nawazi Hotel", "Nawazi Watheer Hotel"],
                requiredTokenGroups: [["nawazi"]]
              ),
              let madinahHotel = fixedStorefrontHotel(
                in: madinahHotels,
                preferredNames: ["Mihrab Tayyiba", "Mihrab Tayba", "Mihrab Taiba"],
                requiredTokenGroups: [["mihrab"], ["tayyiba", "tayba", "taiba"]]
              ),
              let makkahNightly = nightlyUSD(for: makkahHotel),
              let madinahNightly = nightlyUSD(for: madinahHotel) else {
            flightPackagePreviews = [:]
            return
        }

        var output: [String: StorefrontFlightPackagePreview] = [:]
        for option in board.options {
            guard let pair = packagePair(for: option, among: board.options),
                  let preview = makePackagePreview(
                    pair: pair,
                    makkahHotel: makkahHotel,
                    madinahHotel: madinahHotel,
                    makkahNightly: makkahNightly,
                    madinahNightly: madinahNightly
                  ) else { continue }
            output[option.id] = preview
        }
        flightPackagePreviews = output
    }

    private struct FlightPackagePair {
        let outboundOptionID: String
        let returnOptionID: String
        let outbound: StorefrontFlightLeg
        let inbound: StorefrontFlightLeg
        let farePerPersonUSD: Decimal
        let observedAt: String
    }

    private func packagePair(
        for option: StorefrontFlightOption,
        among all: [StorefrontFlightOption]
    ) -> FlightPackagePair? {
        guard option.currency.caseInsensitiveCompare("USD") == .orderedSame else { return nil }

        if let inbound = option.inbound {
            guard isSaudi(option.outbound.destination),
                  complementarySaudiAirport(for: option.outbound.destination) == inbound.origin.uppercased(),
                  inbound.destination.uppercased() == option.outbound.origin.uppercased(),
                  let gap = tripGapDays(outbound: option.outbound, inbound: inbound),
                  (4...8).contains(gap),
                  option.perTravelerFare.isFinite,
                  option.perTravelerFare > 0 else { return nil }
            return FlightPackagePair(
                outboundOptionID: option.id,
                returnOptionID: option.id,
                outbound: option.outbound,
                inbound: inbound,
                farePerPersonUSD: Decimal(option.perTravelerFare),
                observedAt: option.observedAt
            )
        }

        let leg = option.outbound
        let origin = leg.origin.uppercased()
        let destination = leg.destination.uppercased()

        if !isSaudi(origin), isSaudi(destination) {
            guard let returnOrigin = complementarySaudiAirport(for: destination),
                  let candidate = bestComplementaryOneWay(
                    among: all,
                    origin: returnOrigin,
                    destination: origin,
                    relativeTo: leg,
                    candidateIsAfter: true
                  ) else { return nil }
            return FlightPackagePair(
                outboundOptionID: option.id,
                returnOptionID: candidate.id,
                outbound: leg,
                inbound: candidate.outbound,
                farePerPersonUSD: Decimal(option.perTravelerFare) + Decimal(candidate.perTravelerFare),
                observedAt: max(option.observedAt, candidate.observedAt)
            )
        }

        if isSaudi(origin), !isSaudi(destination) {
            guard let outboundDestination = complementarySaudiAirport(for: origin),
                  let candidate = bestComplementaryOneWay(
                    among: all,
                    origin: destination,
                    destination: outboundDestination,
                    relativeTo: leg,
                    candidateIsAfter: false
                  ) else { return nil }
            return FlightPackagePair(
                outboundOptionID: candidate.id,
                returnOptionID: option.id,
                outbound: candidate.outbound,
                inbound: leg,
                farePerPersonUSD: Decimal(option.perTravelerFare) + Decimal(candidate.perTravelerFare),
                observedAt: max(option.observedAt, candidate.observedAt)
            )
        }

        return nil
    }

    private func bestComplementaryOneWay(
        among all: [StorefrontFlightOption],
        origin: String,
        destination: String,
        relativeTo anchor: StorefrontFlightLeg,
        candidateIsAfter: Bool
    ) -> StorefrontFlightOption? {
        all
            .filter { candidate in
                guard candidate.inbound == nil,
                      candidate.currency.caseInsensitiveCompare("USD") == .orderedSame,
                      candidate.perTravelerFare.isFinite,
                      candidate.perTravelerFare > 0,
                      candidate.outbound.origin.caseInsensitiveCompare(origin) == .orderedSame,
                      candidate.outbound.destination.caseInsensitiveCompare(destination) == .orderedSame else { return false }
                let outbound = candidateIsAfter ? anchor : candidate.outbound
                let inbound = candidateIsAfter ? candidate.outbound : anchor
                guard let days = tripGapDays(outbound: outbound, inbound: inbound) else { return false }
                return (4...8).contains(days)
            }
            .min { lhs, rhs in
                let lhsOutbound = candidateIsAfter ? anchor : lhs.outbound
                let lhsInbound = candidateIsAfter ? lhs.outbound : anchor
                let rhsOutbound = candidateIsAfter ? anchor : rhs.outbound
                let rhsInbound = candidateIsAfter ? rhs.outbound : anchor
                let lhsDays = tripGapDays(outbound: lhsOutbound, inbound: lhsInbound) ?? 99
                let rhsDays = tripGapDays(outbound: rhsOutbound, inbound: rhsInbound) ?? 99
                let lhsDistance = abs(lhsDays - 7)
                let rhsDistance = abs(rhsDays - 7)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                if lhs.perTravelerFare != rhs.perTravelerFare { return lhs.perTravelerFare < rhs.perTravelerFare }
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.outbound.departureAt < rhs.outbound.departureAt
            }
    }

    private func makePackagePreview(
        pair: FlightPackagePair,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary,
        makkahNightly: Decimal,
        madinahNightly: Decimal
    ) -> StorefrontFlightPackagePreview? {
        guard pair.farePerPersonUSD > 0,
              let outboundDeparture = isoDate(pair.outbound.departureAt),
              let outboundArrival = isoDate(pair.outbound.arrivalAt),
              let inboundDeparture = isoDate(pair.inbound.departureAt),
              let inboundArrival = isoDate(pair.inbound.arrivalAt),
              let tripDepartureDay = stableTravelDay(pair.outbound.departureAt),
              let saudiArrivalDay = stableTravelDay(pair.outbound.arrivalAt),
              let returnDay = stableTravelDay(pair.inbound.departureAt),
              returnDay > saudiArrivalDay else { return nil }

        var trip = TripDraft()
        trip.origin = pair.outbound.origin.uppercased()
        trip.originAirport = nil
        trip.scope = .makkahAndMadinah
        trip.arrivalAirport = pair.outbound.destination.uppercased() == "MED" ? .madinah : .jeddah
        trip.departureDate = tripDepartureDay
        trip.saudiArrivalDate = saudiArrivalDay
        trip.returnDate = returnDay
        trip.flexibility = .exact
        trip.adults = 1
        trip.children = 0
        trip.infants = 0
        trip.rooms = 1
        trip.hotelStars = PackageTier.standard.primaryHotelStars
        trip.packageTier = .standard
        trip.flightTripType = .roundTrip

        let windows = TripStayPlanner.windows(for: trip, calendar: storefrontCalendar)
        guard let madinahWindow = windows.madinah else { return nil }

        let makkahComponent = LocalHotelPriceComponent(
            nightlyUsd: makkahNightly,
            nights: windows.makkah.nights,
            rooms: 1,
            hotelId: makkahHotel.id,
            roomId: nil,
            source: "iumrah-storefront-fixed-nawazi"
        )
        let madinahComponent = LocalHotelPriceComponent(
            nightlyUsd: madinahNightly,
            nights: madinahWindow.nights,
            rooms: 1,
            hotelId: madinahHotel.id,
            roomId: nil,
            source: "iumrah-storefront-fixed-mihrab-tayyiba"
        )

        let outboundOffer = syntheticOffer(
            id: pair.outboundOptionID,
            leg: pair.outbound,
            direction: .outbound,
            departure: outboundDeparture,
            arrival: outboundArrival,
            fare: pair.farePerPersonUSD,
            observedAt: pair.observedAt
        )
        let pricingOffer = syntheticOffer(
            id: pair.returnOptionID,
            leg: pair.inbound,
            direction: .inbound,
            departure: inboundDeparture,
            arrival: inboundArrival,
            fare: pair.farePerPersonUSD,
            observedAt: pair.observedAt
        )

        guard let quote = try? LocalPackagePricingEngine.calculate(
            trip: trip,
            journeyFareUsd: pair.farePerPersonUSD,
            journeyFareScope: .perPassenger,
            pricingOffer: pricingOffer,
            outboundOffer: outboundOffer,
            inboundOffer: pricingOffer,
            makkahHotel: makkahComponent,
            madinahHotel: madinahComponent,
            includeHaramainTrain: false,
            transferVehicle: nil,
            haramainPublicAddOnUsd: 0
        ) else { return nil }

        let stay = TripStayPlanner.breakdown(for: trip, calendar: storefrontCalendar)
        return StorefrontFlightPackagePreview(
            pricePerPerson: quote.pricePerPerson,
            totalPackagePrice: quote.totalPackagePrice,
            outboundOptionID: pair.outboundOptionID,
            returnOptionID: pair.returnOptionID,
            outbound: pair.outbound,
            inbound: pair.inbound,
            totalNights: stay.totalNights,
            makkahNights: stay.makkahNights,
            madinahNights: stay.madinahNights,
            makkahHotelName: makkahHotel.name,
            madinahHotelName: madinahHotel.name
        )
    }

    private func syntheticOffer(
        id: String,
        leg: StorefrontFlightLeg,
        direction: FlightDirection,
        departure: Date,
        arrival: Date,
        fare: Decimal,
        observedAt: String
    ) -> FlightOffer {
        FlightOffer(
            id: "storefront-package:\(id):\(direction.rawValue)",
            direction: direction,
            airline: leg.airline,
            flightNumber: leg.flightNumber,
            origin: leg.origin,
            destination: leg.destination,
            departureAt: departure,
            arrivalAt: arrival,
            stops: leg.stops,
            durationMinutes: leg.durationMinutes,
            totalPackagePrice: fare,
            currency: "USD",
            sourceLabel: "iumrah Business",
            airlineCode: leg.airlineCode,
            fareAmount: fare,
            fareScope: .perPassenger,
            fareObservedAt: isoDate(observedAt),
            providerItineraryID: id,
            cabinClass: leg.cabinClass,
            requiresSelfTransfer: false
        )
    }

    private func fixedStorefrontHotel(
        in hotels: [HotelSummary],
        preferredNames: [String],
        requiredTokenGroups: [[String]]
    ) -> HotelSummary? {
        let exactNames = Set(preferredNames.map(normalizedHotelName))
        if let hotel = hotels.first(where: { exactNames.contains(normalizedHotelName($0.name)) && nightlyUSD(for: $0) != nil }) {
            return hotel
        }

        // Business names can carry a suffix such as “Hotel”, “Madinah”,
        // “Watheer”, or use Tayyiba/Tayba/Taiba transliteration. Match each
        // semantic token group without binding storefront pricing to one spelling.
        return hotels.first { hotel in
            let normalized = normalizedHotelName(hotel.name)
            let matches = requiredTokenGroups.allSatisfy { alternatives in
                alternatives.contains { normalized.contains($0) }
            }
            return matches && nightlyUSD(for: hotel) != nil
        }
    }

    private func normalizedHotelName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func nightlyUSD(for hotel: HotelSummary) -> Decimal? {
        let candidates = [details[hotel.id]?.price, hotel.price].compactMap { $0 }
        for price in candidates {
            guard let value = price.nightlyUSD, value.isFinite, value > 0 else { continue }
            return Decimal(value)
        }
        return nil
    }

    private func isSaudi(_ airport: String) -> Bool {
        let code = airport.uppercased()
        return code == "JED" || code == "MED"
    }

    private func complementarySaudiAirport(for airport: String) -> String? {
        switch airport.uppercased() {
        case "MED": return "JED"
        case "JED": return "MED"
        default: return nil
        }
    }

    private func tripGapDays(outbound: StorefrontFlightLeg, inbound: StorefrontFlightLeg) -> Int? {
        guard let first = stableTravelDay(outbound.departureAt),
              let second = stableTravelDay(inbound.departureAt) else { return nil }
        return storefrontCalendar.dateComponents([.day], from: first, to: second).day
    }

    private func stableTravelDay(_ value: String) -> Date? {
        let day = String(value.prefix(10))
        guard day.count == 10 else { return nil }
        return storefrontDayFormatter.date(from: day)
    }

    private func isoDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = fractional.date(from: value) { return value }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }

    private var storefrontCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var storefrontDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = storefrontCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = storefrontCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        // Noon UTC keeps the intended travel day stable when the pricing engine
        // later reads the draft with the device's local calendar/time zone.
        formatter.defaultDate = Date(timeIntervalSince1970: 43_200)
        return formatter
    }

    private func restoreDiskSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(HotelStorefrontDiskSnapshot.self, from: data) else { return }
        makkahHotels = snapshot.makkahHotels
        madinahHotels = snapshot.madinahHotels
        details = Dictionary(uniqueKeysWithValues: snapshot.hotelDetails.map { ($0.id, $0) })
        flightBoard = snapshot.flightBoard
        rebuildQuotes()
        rebuildFlightPackagePreviews()
        // Disk data renders immediately, then the app refreshes prices/flight baseline
        // once per launch. Photo bytes themselves live in the persistent image cache.
        hasPrepared = false
        startImageWarmup()
    }

    private func persistDiskSnapshot() {
        let snapshot = HotelStorefrontDiskSnapshot(
            makkahHotels: makkahHotels,
            madinahHotels: madinahHotels,
            hotelDetails: Array(details.values),
            flightBoard: flightBoard,
            savedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private func startImageWarmup() {
        let critical = allHotels
            .flatMap { previewImages(for: $0, limit: 3) }
            .compactMap { AppConfig.absoluteURL($0) }
        let detailWarmup = details.values
            .flatMap { detail in detail.images.sorted(by: imageSort).prefix(8).map(\.url) }
            .compactMap { AppConfig.absoluteURL($0) }
        Task(priority: .userInitiated) { await HotelImageCache.shared.prefetch(urls: critical) }
        Task(priority: .utility) { await HotelImageCache.shared.prefetch(urls: detailWarmup) }
    }

    private func imageSort(_ lhs: HotelImage, _ rhs: HotelImage) -> Bool {
        if lhs.isCover != rhs.isCover { return lhs.isCover && !rhs.isCover }
        return lhs.position < rhs.position
    }
}
