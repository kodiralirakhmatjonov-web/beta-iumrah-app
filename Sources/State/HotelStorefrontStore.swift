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
        persistDiskSnapshot()
        startImageWarmup()
    }

    func quote(for hotel: HotelSummary, tier: PackageTier = .standard) -> HotelStorefrontQuote? {
        tier == .luxury ? luxuryQuotes[hotel.id] : standardQuotes[hotel.id]
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

        async let makkahRequest = hotelListResult(city: "Makkah")
        async let madinahRequest = hotelListResult(city: "Madinah")
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

    private func restoreDiskSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(HotelStorefrontDiskSnapshot.self, from: data) else { return }
        makkahHotels = snapshot.makkahHotels
        madinahHotels = snapshot.madinahHotels
        details = Dictionary(uniqueKeysWithValues: snapshot.hotelDetails.map { ($0.id, $0) })
        flightBoard = snapshot.flightBoard
        rebuildQuotes()
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
