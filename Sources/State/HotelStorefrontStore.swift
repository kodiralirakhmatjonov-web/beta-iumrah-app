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
        snapshotURL = caches.appendingPathComponent("iumrah-hotel-storefront-v2.json")
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
        AppConfig.apiBaseURL.appendingPathComponent("hotel").appendingPathComponent(hotel.id)
    }

    private func prepare(force: Bool) async {
        guard force || !hasPrepared else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let makkahRequest = catalog.listHotels(city: "Makkah")
            async let madinahRequest = catalog.listHotels(city: "Madinah")
            async let flightRequest = storefront.flightBoard(origin: "TAS")

            let (newMakkah, newMadinah, newFlightBoard) = try await (makkahRequest, madinahRequest, flightRequest)
            makkahHotels = newMakkah
            madinahHotels = newMadinah
            flightBoard = newFlightBoard

            // Price cards do not depend on full hotel-detail payloads. Build them
            // immediately from the already-cached catalogue rate + published flight
            // baseline so the storefront becomes usable while photo metadata warms.
            rebuildQuotes()
            hasPrepared = baseline != nil && !standardQuotes.isEmpty
            startImageWarmup()

            let loadedDetails = await fetchDetails(for: newMakkah + newMadinah)
            for detail in loadedDetails { details[detail.id] = detail }
            persistDiskSnapshot()
            startImageWarmup()
        } catch {
            rebuildQuotes()
            hasPrepared = !allHotels.isEmpty && baseline != nil
            errorMessage = L10n.error(error, .russian)
            startImageWarmup()
        }
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
            standardQuotes = [:]
            luxuryQuotes = [:]
            return
        }
        var standard: [String: HotelStorefrontQuote] = [:]
        var luxury: [String: HotelStorefrontQuote] = [:]
        for hotel in allHotels {
            if let quote = try? storefront.quote(hotel: hotel, tier: .standard, baseline: baseline) {
                standard[hotel.id] = quote
            }
            if let quote = try? storefront.quote(hotel: hotel, tier: .luxury, baseline: baseline) {
                luxury[hotel.id] = quote
            }
        }
        standardQuotes = standard
        luxuryQuotes = luxury
    }

    private func restoreDiskSnapshot() {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(HotelStorefrontDiskSnapshot.self, from: data) else { return }
        makkahHotels = snapshot.makkahHotels
        madinahHotels = snapshot.madinahHotels
        details = Dictionary(uniqueKeysWithValues: snapshot.hotelDetails.map { ($0.id, $0) })
        flightBoard = snapshot.flightBoard
        rebuildQuotes()
        // Disk data is used immediately for instant rendering, but every app launch
        // still runs a network preparation to respect the independent 48h price cache.
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
        // The storefront needs its three-photo collages immediately. Warm those first.
        // For detail pages, prefetch only the first gallery screen in the background;
        // the persistent cache stores the rest as the pilgrim browses them. This keeps
        // launch responsive and avoids downloading an entire hotel media library at once.
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
