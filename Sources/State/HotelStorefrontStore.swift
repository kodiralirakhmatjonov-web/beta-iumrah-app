import Foundation
import SwiftUI

@MainActor
final class HotelStorefrontStore: ObservableObject {
    @Published private(set) var makkahHotels: [HotelSummary] = []
    @Published private(set) var madinahHotels: [HotelSummary] = []
    @Published private(set) var details: [String: HotelDetail] = [:]
    @Published private(set) var flightBoard: StorefrontFlightBoardResponse?
    @Published private(set) var standardQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var comfortQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var luxuryQuotes: [String: HotelStorefrontQuote] = [:]
    @Published private(set) var departureOriginCode = "TAS"
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
    var baseline: StorefrontFlightBaseline? {
        guard let board = flightBoard else { return nil }
        if let pair = preferredHotelPackagePair(in: board.options) {
            return storefrontBaseline(from: pair)
        }
        return board.baseline
    }

    func automaticTier(for hotel: HotelSummary) -> PackageTier {
        switch hotel.stars ?? 3 {
        case 5...: return .luxury
        case 4: return .comfort
        default: return .standard
        }
    }

    func automaticQuote(for hotel: HotelSummary) -> HotelStorefrontQuote? {
        quote(for: hotel, tier: automaticTier(for: hotel))
    }

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
        switch tier {
        case .luxury: return luxuryQuotes[hotel.id]
        case .comfort: return comfortQuotes[hotel.id]
        case .economy, .standard: return standardQuotes[hotel.id]
        }
    }

    func updateDepartureAirport(_ code: String) async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 3 else { return }
        guard normalized != departureOriginCode || flightBoard?.origin.uppercased() != normalized || baseline == nil else { return }

        departureOriginCode = normalized
        do {
            let board = try await storefront.resilientFlightBoard(origin: normalized)
            flightBoard = board
            rebuildQuotes()
            rebuildFlightPackagePreviews()
            hasPrepared = !allHotels.isEmpty && baseline != nil && (!standardQuotes.isEmpty || !comfortQuotes.isEmpty || !luxuryQuotes.isEmpty)
            errorMessage = nil
            persistDiskSnapshot()
        } catch {
            errorMessage = L10n.error(error, .russian)
        }
    }

    func packagePreview(for option: StorefrontFlightOption) -> StorefrontFlightPackagePreview? {
        flightPackagePreviews[option.id]
    }

    /// Rebuilds the exact package quote used by the Flights Scanner checkout after
    /// the pilgrim changes traveler count, room selection or transfer class.
    /// Supplier/component values stay internal; the caller only receives PackageQuote.
    func checkoutQuote(
        for preview: StorefrontFlightPackagePreview,
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomID: String?,
        madinahRoomID: String?,
        transferVehicle: TransferVehicleKind?,
        includeHaramainTrain: Bool = false,
        haramainPublicAddOnUsd: Decimal = 0
    ) -> PackageQuote? {
        guard preview.flightFarePerPersonUSD > 0,
              let offers = bookingFlightOffers(for: preview),
              let makkahNightly = nightlyUSD(for: makkahHotel) else { return nil }

        let windows = TripStayPlanner.windows(for: trip, calendar: storefrontCalendar)
        let makkah = LocalHotelPriceComponent(
            nightlyUsd: makkahNightly,
            nights: windows.makkah.nights,
            rooms: max(1, trip.rooms),
            hotelId: makkahHotel.id,
            roomId: makkahRoomID,
            source: "iumrah-flights-scanner-checkout-makkah"
        )

        var madinah: LocalHotelPriceComponent?
        if trip.scope == .makkahAndMadinah {
            guard let madinahHotel,
                  let madinahWindow = windows.madinah,
                  let madinahNightly = nightlyUSD(for: madinahHotel) else { return nil }
            madinah = LocalHotelPriceComponent(
                nightlyUsd: madinahNightly,
                nights: madinahWindow.nights,
                rooms: max(1, trip.rooms),
                hotelId: madinahHotel.id,
                roomId: madinahRoomID,
                source: "iumrah-flights-scanner-checkout-madinah"
            )
        }

        return try? LocalPackagePricingEngine.calculate(
            trip: trip,
            journeyFareUsd: preview.flightFarePerPersonUSD,
            journeyFareScope: .perPassenger,
            pricingOffer: offers.inbound,
            outboundOffer: offers.outbound,
            inboundOffer: offers.inbound,
            makkahHotel: makkah,
            madinahHotel: madinah,
            includeHaramainTrain: includeHaramainTrain,
            transferVehicle: transferVehicle,
            haramainPublicAddOnUsd: haramainPublicAddOnUsd
        )
    }

    /// Booking-safe snapshots for the published flight pair. The package fare is
    /// carried once by the pair; the booking payload still preserves both physical
    /// legs and their staff-published identifiers for operations/audit.
    func bookingFlightOffers(for preview: StorefrontFlightPackagePreview) -> (outbound: FlightOffer, inbound: FlightOffer)? {
        guard let outboundDeparture = isoDate(preview.outbound.departureAt),
              let outboundArrival = isoDate(preview.outbound.arrivalAt),
              let inboundDeparture = isoDate(preview.inbound.departureAt),
              let inboundArrival = isoDate(preview.inbound.arrivalAt) else { return nil }

        return (
            syntheticOffer(
                id: preview.outboundOptionID,
                leg: preview.outbound,
                direction: .outbound,
                departure: outboundDeparture,
                arrival: outboundArrival,
                fare: preview.flightFarePerPersonUSD,
                observedAt: preview.fareObservedAt
            ),
            syntheticOffer(
                id: preview.returnOptionID,
                leg: preview.inbound,
                direction: .inbound,
                departure: inboundDeparture,
                arrival: inboundArrival,
                fare: preview.flightFarePerPersonUSD,
                observedAt: preview.fareObservedAt
            )
        )
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
        hasPrepared = !allHotels.isEmpty && baseline != nil && (!standardQuotes.isEmpty || !comfortQuotes.isEmpty || !luxuryQuotes.isEmpty)

        if allHotels.isEmpty {
            if let error = hotelErrors.first {
                errorMessage = L10n.error(error, .russian)
            } else {
                errorMessage = "Каталог отелей временно недоступен."
            }
        } else if baseline == nil {
            // Do not hide hotels. This message is shown only in the package-price
            // placeholder and helps distinguish pricing availability from catalog data.
            errorMessage = "iumrah Flights Scanner обновляет рейсы для расчёта пакета."
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
        do { return .success(try await storefront.resilientFlightBoard(origin: departureOriginCode)) }
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
        var comfort: [String: HotelStorefrontQuote] = [:]
        var luxury: [String: HotelStorefrontQuote] = [:]
        for hotel in allHotels {
            let price = bestFreshPrice(for: hotel)
            if let quote = try? storefront.quote(hotel: hotel, tier: .standard, baseline: baseline, price: price) {
                standard[hotel.id] = quote
            }
            if let quote = try? storefront.quote(hotel: hotel, tier: .comfort, baseline: baseline, price: price) {
                comfort[hotel.id] = quote
            }
            if let quote = try? storefront.quote(hotel: hotel, tier: .luxury, baseline: baseline, price: price) {
                luxury[hotel.id] = quote
            }
        }
        standardQuotes = standard
        comfortQuotes = comfort
        luxuryQuotes = luxury
    }

    private func bestFreshPrice(for hotel: HotelSummary) -> HotelCatalogPrice? {
        if let detailPrice = details[hotel.id]?.price, detailPrice.isFresh { return detailPrice }
        if let summaryPrice = hotel.price, summaryPrice.isFresh { return summaryPrice }
        return details[hotel.id]?.price ?? hotel.price
    }

    // MARK: - iumrah Flights Scanner package composition

    /// The flight storefront is a package surface, not a raw fare board.
    /// Uzbekistan → Saudi Arabia rows are package anchors. The scanner pairs each
    /// anchor with a Saudi Arabia → Uzbekistan return and mirrors the same composed
    /// package price onto that return row. Raw ticket prices stay internal.
    private func rebuildFlightPackagePreviews() {
        guard let board = flightBoard else {
            flightPackagePreviews = [:]
            return
        }

        let standardMakkahHotel = fixedStorefrontHotel(
            in: makkahHotels,
            preferredNames: ["Nawazi Hotel", "Nawazi Watheer Hotel"],
            requiredTokenGroups: [["nawazi"]]
        )
        let standardMadinahHotel = fixedStorefrontHotel(
            in: madinahHotels,
            preferredNames: ["Mihrab Tayyiba", "Mihrab Tayba", "Mihrab Taiba"],
            requiredTokenGroups: [["mihrab"], ["tayyiba", "tayba", "taiba"]]
        )
        let comfortMakkahHotel = fixedStorefrontHotel(
            in: makkahHotels,
            preferredNames: ["Shohada Hotel", "Al Shohada Hotel", "Shuhada Hotel", "Al Shuhada Hotel"],
            requiredTokenGroups: [["shohada", "shuhada"]]
        )

        var output: [String: StorefrontFlightPackagePreview] = [:]

        // Only outbound Uzbekistan → Saudi rows create packages. Saudi → Uzbekistan
        // rows receive the price of the first package that actually uses that leg.
        // This prevents the same return flight from independently inventing a second price.
        for option in board.options where isPackageAnchor(option) {
            guard let pair = packagePair(forOutbound: option, among: board.options),
                  let preview = makePackagePreview(
                    pair: pair,
                    standardMakkahHotel: standardMakkahHotel,
                    standardMadinahHotel: standardMadinahHotel,
                    comfortMakkahHotel: comfortMakkahHotel
                  ) else { continue }

            output[option.id] = preview
            if pair.returnOptionID != option.id, output[pair.returnOptionID] == nil {
                output[pair.returnOptionID] = preview
            }
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
        let durationDays: Int
        let travelerCount: Int
        let kind: StorefrontUmrahPackageKind
    }

    private func preferredHotelPackagePair(in options: [StorefrontFlightOption]) -> FlightPackagePair? {
        let origin = departureOriginCode.uppercased()
        let anchors = options
            .filter { option in
                isPackageAnchor(option) && option.outbound.origin.uppercased() == origin
            }
            .sorted { lhs, rhs in
                let lhsDay = stableTravelDay(lhs.outbound.departureAt) ?? .distantFuture
                let rhsDay = stableTravelDay(rhs.outbound.departureAt) ?? .distantFuture
                if lhsDay != rhsDay { return lhsDay < rhsDay }
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.perTravelerFare < rhs.perTravelerFare
            }

        for option in anchors {
            if let pair = packagePair(forOutbound: option, among: options) { return pair }
        }
        return nil
    }

    private func storefrontBaseline(from pair: FlightPackagePair) -> StorefrontFlightBaseline {
        StorefrontFlightBaseline(
            mode: "iumrah_configurator_published_pair",
            travelers: pair.travelerCount,
            currency: "USD",
            perTravelerFareUsd: NSDecimalNumber(decimal: pair.farePerPersonUSD).doubleValue,
            totalFareUsd: NSDecimalNumber(decimal: pair.farePerPersonUSD * Decimal(pair.travelerCount)).doubleValue,
            outboundOfferID: pair.outboundOptionID,
            inboundOfferID: pair.returnOptionID,
            outbound: pair.outbound,
            inbound: pair.inbound,
            observedAt: pair.observedAt
        )
    }

    private func isPackageAnchor(_ option: StorefrontFlightOption) -> Bool {
        let origin = option.outbound.origin.uppercased()
        let destination = option.outbound.destination.uppercased()
        return !isSaudi(origin) && isSaudi(destination)
    }

    private func packagePair(
        forOutbound option: StorefrontFlightOption,
        among all: [StorefrontFlightOption]
    ) -> FlightPackagePair? {
        guard option.currency.caseInsensitiveCompare("USD") == .orderedSame,
              option.perTravelerFare.isFinite,
              option.perTravelerFare > 0,
              isPackageAnchor(option) else { return nil }

        // A staff row may already contain both directions. Keep it authoritative when
        // it satisfies the same scanner rules as two one-way publications.
        if let inbound = option.inbound,
           let gap = tripGapDays(outbound: option.outbound, inbound: inbound),
           isSaudi(inbound.origin),
           isAllowedReturnDestination(inbound.destination, for: option.outbound.origin),
           let kind = packageKind(outbound: option.outbound, inbound: inbound, gapDays: gap) {
            return FlightPackagePair(
                outboundOptionID: option.id,
                returnOptionID: option.id,
                outbound: option.outbound,
                inbound: inbound,
                farePerPersonUSD: Decimal(option.perTravelerFare),
                observedAt: option.observedAt,
                durationDays: gap,
                travelerCount: max(1, option.travelerCount),
                kind: kind
            )
        }

        guard option.inbound == nil else { return nil }

        let preferredDestination = option.outbound.origin.uppercased()
        if let candidate = bestReturnOneWay(
            for: option.outbound,
            among: all,
            returnDestination: preferredDestination
        ) {
            return oneWayPair(outboundOption: option, returnOption: candidate)
        }

        // Regional departures may legitimately return to Tashkent when no matching
        // flight to the original city exists inside the valid package window.
        if preferredDestination != "TAS",
           let fallback = bestReturnOneWay(
            for: option.outbound,
            among: all,
            returnDestination: "TAS"
           ) {
            return oneWayPair(outboundOption: option, returnOption: fallback)
        }

        return nil
    }

    private func oneWayPair(
        outboundOption: StorefrontFlightOption,
        returnOption: StorefrontFlightOption
    ) -> FlightPackagePair? {
        guard let gap = tripGapDays(outbound: outboundOption.outbound, inbound: returnOption.outbound),
              let kind = packageKind(outbound: outboundOption.outbound, inbound: returnOption.outbound, gapDays: gap) else {
            return nil
        }
        return FlightPackagePair(
            outboundOptionID: outboundOption.id,
            returnOptionID: returnOption.id,
            outbound: outboundOption.outbound,
            inbound: returnOption.outbound,
            farePerPersonUSD: Decimal(outboundOption.perTravelerFare) + Decimal(returnOption.perTravelerFare),
            observedAt: max(outboundOption.observedAt, returnOption.observedAt),
            durationDays: gap,
            travelerCount: max(1, outboundOption.travelerCount),
            kind: kind
        )
    }

    private func bestReturnOneWay(
        for outbound: StorefrontFlightLeg,
        among all: [StorefrontFlightOption],
        returnDestination: String
    ) -> StorefrontFlightOption? {
        let candidates = all.filter { candidate in
            guard candidate.inbound == nil,
                  candidate.currency.caseInsensitiveCompare("USD") == .orderedSame,
                  candidate.perTravelerFare.isFinite,
                  candidate.perTravelerFare > 0,
                  isSaudi(candidate.outbound.origin),
                  candidate.outbound.destination.caseInsensitiveCompare(returnDestination) == .orderedSame,
                  let gap = tripGapDays(outbound: outbound, inbound: candidate.outbound),
                  packageKind(outbound: outbound, inbound: candidate.outbound, gapDays: gap) != nil else {
                return false
            }
            return true
        }

        guard !candidates.isEmpty else { return nil }

        // JED arrivals get a real 2–3 day Makkah-only Comfort product whenever that
        // window exists. Otherwise the scanner composes a 4–15 day two-city Standard trip.
        if outbound.destination.uppercased() == "JED" {
            let short = candidates.filter { candidate in
                guard candidate.outbound.origin.uppercased() == "JED",
                      let gap = tripGapDays(outbound: outbound, inbound: candidate.outbound) else { return false }
                return (2...3).contains(gap)
            }
            if !short.isEmpty {
                return short.min { lhs, rhs in
                    let lhsGap = tripGapDays(outbound: outbound, inbound: lhs.outbound) ?? 99
                    let rhsGap = tripGapDays(outbound: outbound, inbound: rhs.outbound) ?? 99
                    let lhsDistance = abs(lhsGap - 3)
                    let rhsDistance = abs(rhsGap - 3)
                    if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                    if lhs.perTravelerFare != rhs.perTravelerFare { return lhs.perTravelerFare < rhs.perTravelerFare }
                    if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                    return lhs.outbound.departureAt < rhs.outbound.departureAt
                }
            }
        }

        let long = candidates.filter { candidate in
            guard let gap = tripGapDays(outbound: outbound, inbound: candidate.outbound) else { return false }
            return (4...15).contains(gap)
        }
        return long.min { lhs, rhs in
            let complementary = complementarySaudiAirport(for: outbound.destination)
            let lhsOpenJaw = lhs.outbound.origin.uppercased() == complementary
            let rhsOpenJaw = rhs.outbound.origin.uppercased() == complementary
            if lhsOpenJaw != rhsOpenJaw { return lhsOpenJaw && !rhsOpenJaw }

            let lhsGap = tripGapDays(outbound: outbound, inbound: lhs.outbound) ?? 99
            let rhsGap = tripGapDays(outbound: outbound, inbound: rhs.outbound) ?? 99
            let lhsDistance = abs(lhsGap - 7)
            let rhsDistance = abs(rhsGap - 7)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            if lhs.perTravelerFare != rhs.perTravelerFare { return lhs.perTravelerFare < rhs.perTravelerFare }
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.outbound.departureAt < rhs.outbound.departureAt
        }
    }

    private func packageKind(
        outbound: StorefrontFlightLeg,
        inbound: StorefrontFlightLeg,
        gapDays: Int
    ) -> StorefrontUmrahPackageKind? {
        guard isSaudi(outbound.destination), isSaudi(inbound.origin) else { return nil }

        if outbound.destination.uppercased() == "JED",
           inbound.origin.uppercased() == "JED",
           (2...3).contains(gapDays) {
            return .makkahComfortShort
        }

        if (4...15).contains(gapDays) {
            return .makkahMadinahStandard
        }

        return nil
    }

    private func isAllowedReturnDestination(_ airport: String, for outboundOrigin: String) -> Bool {
        let destination = airport.uppercased()
        let preferred = outboundOrigin.uppercased()
        return destination == preferred || (preferred != "TAS" && destination == "TAS")
    }

    private func makePackagePreview(
        pair: FlightPackagePair,
        standardMakkahHotel: HotelSummary?,
        standardMadinahHotel: HotelSummary?,
        comfortMakkahHotel: HotelSummary?
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
        trip.arrivalAirport = pair.outbound.destination.uppercased() == "MED" ? .madinah : .jeddah
        trip.departureDate = tripDepartureDay
        trip.saudiArrivalDate = saudiArrivalDay
        trip.returnDate = returnDay
        trip.flexibility = .exact
        trip.adults = 1
        trip.children = 0
        trip.infants = 0
        trip.rooms = 1
        trip.flightTripType = .roundTrip

        let makkahHotel: HotelSummary
        let madinahHotel: HotelSummary?
        switch pair.kind {
        case .makkahComfortShort:
            guard let hotel = comfortMakkahHotel, nightlyUSD(for: hotel) != nil else { return nil }
            makkahHotel = hotel
            madinahHotel = nil
            trip.scope = .makkahOnly
            trip.packageTier = .comfort
            trip.hotelStars = PackageTier.comfort.primaryHotelStars

        case .makkahMadinahStandard:
            guard let makkah = standardMakkahHotel,
                  let madinah = standardMadinahHotel,
                  nightlyUSD(for: makkah) != nil,
                  nightlyUSD(for: madinah) != nil else { return nil }
            makkahHotel = makkah
            madinahHotel = madinah
            trip.scope = .makkahAndMadinah
            trip.packageTier = .standard
            trip.hotelStars = PackageTier.standard.primaryHotelStars
        }

        guard let makkahNightly = nightlyUSD(for: makkahHotel) else { return nil }
        let windows = TripStayPlanner.windows(for: trip, calendar: storefrontCalendar)
        let makkahComponent = LocalHotelPriceComponent(
            nightlyUsd: makkahNightly,
            nights: windows.makkah.nights,
            rooms: 1,
            hotelId: makkahHotel.id,
            roomId: nil,
            source: pair.kind == .makkahComfortShort
                ? "iumrah-storefront-comfort-shohada"
                : "iumrah-storefront-standard-nawazi"
        )

        var madinahComponent: LocalHotelPriceComponent?
        if let madinahHotel,
           let window = windows.madinah,
           let nightly = nightlyUSD(for: madinahHotel) {
            madinahComponent = LocalHotelPriceComponent(
                nightlyUsd: nightly,
                nights: window.nights,
                rooms: 1,
                hotelId: madinahHotel.id,
                roomId: nil,
                source: "iumrah-storefront-standard-mihrab-tayyiba"
            )
        }

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
        var packageHotels = [storefrontPackageHotel(makkahHotel, nights: stay.makkahNights)]
        if let madinahHotel, stay.madinahNights > 0 {
            packageHotels.append(storefrontPackageHotel(madinahHotel, nights: stay.madinahNights))
        }

        return StorefrontFlightPackagePreview(
            pricePerPerson: quote.pricePerPerson,
            totalPackagePrice: quote.totalPackagePrice,
            flightFarePerPersonUSD: pair.farePerPersonUSD,
            fareObservedAt: pair.observedAt,
            outboundOptionID: pair.outboundOptionID,
            returnOptionID: pair.returnOptionID,
            outbound: pair.outbound,
            inbound: pair.inbound,
            durationDays: pair.durationDays,
            totalNights: stay.totalNights,
            makkahNights: stay.makkahNights,
            madinahNights: stay.madinahNights,
            kind: pair.kind,
            tier: trip.packageTier,
            hotels: packageHotels,
            packageQuote: quote
        )
    }

    private func storefrontPackageHotel(_ hotel: HotelSummary, nights: Int) -> StorefrontPackageHotel {
        StorefrontPackageHotel(
            id: hotel.id,
            name: hotel.name,
            city: hotel.city,
            stars: hotel.stars,
            coverImageURL: previewImages(for: hotel, limit: 1).first ?? hotel.coverImageURL,
            nights: max(1, nights)
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
        let directSegments: [FlightSegment]?
        if leg.stops == 0 {
            directSegments = [
                FlightSegment(
                    id: "storefront-segment:\(id):\(direction.rawValue)",
                    airline: leg.airline,
                    airlineCode: leg.airlineCode,
                    flightNumber: leg.flightNumber,
                    origin: FlightAirportSnapshot(code: leg.origin),
                    destination: FlightAirportSnapshot(code: leg.destination),
                    departureAt: departure,
                    arrivalAt: arrival,
                    durationMinutes: max(1, leg.durationMinutes),
                    cabin: leg.cabinClass
                )
            ]
        } else {
            directSegments = nil
        }

        return FlightOffer(
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
            sourceLabel: "iumrah Flights Scanner",
            sourceCandidateID: id,
            airlineCode: leg.airlineCode,
            segments: directSegments,
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
        departureOriginCode = snapshot.flightBoard?.origin.uppercased() ?? "TAS"
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
