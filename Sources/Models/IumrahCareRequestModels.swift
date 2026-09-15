import Foundation

enum IumrahCareTimingMode: String, Codable, CaseIterable, Identifiable {
    case flexibleMonth = "flexible_month"
    case exactDates = "exact_dates"

    var id: String { rawValue }
}

enum IumrahCareTripPriority: String, Codable, CaseIterable, Identifiable {
    case lowestPrice = "lowest_price"
    case nearHaram = "near_haram"
    case balanced = "balanced"
    case premium = "premium"

    var id: String { rawValue }
}

enum IumrahCareTransferPreference: String, Codable, CaseIterable, Identifiable {
    case comfortable = "comfortable"
    case privateSUV = "private_suv"
    case vip = "vip"

    var id: String { rawValue }
}

enum IumrahCareGuidePreference: String, Codable, CaseIterable, Identifiable {
    case none
    case voice
    case live

    var id: String { rawValue }
}

struct IumrahCarePackageRequest: Encodable {
    let locale: String
    let firstName: String
    let lastName: String
    let phone: String
    let telegram: String
    let accountID: String?
    let originCode: String
    let timingMode: IumrahCareTimingMode
    let preferredMonth: String?
    let flexibleWindowDays: Int?
    let exactStartDate: String?
    let exactEndDate: String?
    let adults: Int
    let children: Int
    let infants: Int
    let rooms: Int
    let scope: String
    let firstSaudiCity: String?
    let priority: IumrahCareTripPriority
    let hotelClass: Int
    let transferPreference: IumrahCareTransferPreference
    let directFlightsPreferred: Bool
    let checkedBaggagePreferred: Bool
    let includeZiyarat: Bool
    let includeESIM: Bool
    let guidePreference: IumrahCareGuidePreference
    let budgetUSD: Int?
    let notes: String
}

struct IumrahCarePackageRequestResponse: Decodable, Hashable {
    let ok: Bool
    let requestID: String
    let status: String
    let createdAt: String
    let responseDueAt: String
}
