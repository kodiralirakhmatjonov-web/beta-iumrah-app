import Foundation

enum GeneratorSearchStage: Hashable {
    case starting
    case checkingProvider(String)
    case checkingAirlines
    case checkingHotels
    case comparingFares
    case continuing

    func text(_ language: AppSettingsStore.Language) -> String {
        switch (self, language) {
        case (.starting, .russian): return "Запускаем умный поиск"
        case (.starting, .english): return "Starting smart search"
        case (.starting, .uzbek): return "Aqlli qidiruv boshlanmoqda"
        case (.starting, .uzbekCyrillic): return "Ақлли қидирув бошланмоқда"
        case (.checkingProvider(let name), .russian): return "Проверяем \(name)"
        case (.checkingProvider(let name), .english): return "Checking \(name)"
        case (.checkingProvider(let name), .uzbek): return "\(name) tekshirilmoqda"
        case (.checkingProvider(let name), .uzbekCyrillic): return "\(name) текширилмоқда"
        case (.checkingAirlines, .russian): return "Проверяем актуальные рейсы"
        case (.checkingAirlines, .english): return "Checking current flights"
        case (.checkingAirlines, .uzbek): return "Dolzarb reyslarni tekshiryapmiz"
        case (.checkingAirlines, .uzbekCyrillic): return "Долзарб рейсларни текширяпмиз"
        case (.checkingHotels, .russian): return "Проверяем цены выбранных Primary Hotels"
        case (.checkingHotels, .english): return "Checking your selected Primary Hotels"
        case (.checkingHotels, .uzbek): return "Tanlangan Primary Hotel narxlarini tekshiryapmiz"
        case (.checkingHotels, .uzbekCyrillic): return "Танланган Primary Hotel нархларини текширяпмиз"
        case (.comparingFares, .russian): return "Сравниваем найденные тарифы"
        case (.comparingFares, .english): return "Comparing verified fares"
        case (.comparingFares, .uzbek): return "Topilgan tariflarni solishtiryapmiz"
        case (.comparingFares, .uzbekCyrillic): return "Топилган тарифларни солиштиряпмиз"
        case (.continuing, .russian): return "Продолжаем искать другие варианты"
        case (.continuing, .english): return "Searching for more options"
        case (.continuing, .uzbek): return "Yana variantlarni qidiryapmiz"
        case (.continuing, .uzbekCyrillic): return "Яна вариантларни қидиряпмиз"
        }
    }
}

struct FlightSearchProgress {
    let discoveredCandidates: [LiveFlightCandidate]
    let pricedOffers: [FlightOffer]
    let isSearching: Bool
    let status: GeneratorSearchStage?
    let providerEvents: [FlightProviderSearchEvent]

    init(
        discoveredCandidates: [LiveFlightCandidate],
        pricedOffers: [FlightOffer],
        isSearching: Bool,
        status: GeneratorSearchStage? = nil,
        providerEvents: [FlightProviderSearchEvent] = []
    ) {
        self.discoveredCandidates = discoveredCandidates
        self.pricedOffers = pricedOffers
        self.isSearching = isSearching
        self.status = status
        self.providerEvents = providerEvents
    }

    static let emptySearching = FlightSearchProgress(
        discoveredCandidates: [],
        pricedOffers: [],
        isSearching: true,
        status: .starting
    )
}

typealias FlightSearchProgressHandler = @MainActor (FlightSearchProgress) -> Void

@MainActor
protocol GeneratorComponentProviding: AnyObject {
    var currentHotelPriceSnapshot: HotelPriceSearchSnapshot? { get }
    func ensureHotelPrices(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        makkahRoomId: String?,
        makkahRoomName: String?,
        madinahRoomId: String?,
        madinahRoomName: String?
    ) async -> HotelPriceSearchSnapshot
}

extension GeneratorComponentProviding {
    func ensureHotelPrices(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async -> HotelPriceSearchSnapshot {
        await ensureHotelPrices(
            trip: trip,
            makkahHotel: makkahHotel,
            madinahHotel: madinahHotel,
            makkahRoomId: nil,
            makkahRoomName: nil,
            madinahRoomId: nil,
            madinahRoomName: nil
        )
    }
}

@MainActor
protocol FlightSearchServicing {
    func searchOutbound(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?) async throws -> [FlightOffer]
    func searchReturn(trip: TripDraft, makkahHotel: HotelSummary, madinahHotel: HotelSummary?, outbound: FlightOffer) async throws -> [FlightOffer]

    func searchOutboundProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer]

    func searchReturnProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: FlightOffer,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer]

    func resumeFlightChallenge(_ challenge: FlightBotChallenge) async -> [FlightOffer]
}

extension FlightSearchServicing {
    func resumeFlightChallenge(_ challenge: FlightBotChallenge) async -> [FlightOffer] { [] }

    func searchOutboundProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        onUpdate(.emptySearching)
        let offers = try await searchOutbound(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: offers, isSearching: false))
        return offers
    }

    func searchReturnProgressive(
        trip: TripDraft,
        makkahHotel: HotelSummary,
        madinahHotel: HotelSummary?,
        outbound: FlightOffer,
        onUpdate: @escaping FlightSearchProgressHandler
    ) async throws -> [FlightOffer] {
        onUpdate(.emptySearching)
        let offers = try await searchReturn(trip: trip, makkahHotel: makkahHotel, madinahHotel: madinahHotel, outbound: outbound)
        onUpdate(.init(discoveredCandidates: [], pricedOffers: offers, isSearching: false))
        return offers
    }
}
