import Foundation

/// Customer-visible add-on presentation only.
///
/// The package generator, supplier costs, markup, payment fee, rounding and profit
/// rules live exclusively in Cloudflare PackageEngine. Keep this file free of any
/// authoritative package arithmetic so the iOS binary cannot reveal the generator.
enum PackagePricingPresentation {
    /// These two values are intentionally public because they are shown to the
    /// pilgrim as selectable meal-service add-ons in the UI.
    private static let comfortMealServiceUsd = Decimal(30)
    private static let luxuryMealServiceUsd = Decimal(50)

    static func optionalMealUnitPriceUsd(for tier: PackageTier) -> Decimal? {
        switch tier {
        case .economy, .standard:
            return nil
        case .comfort:
            return comfortMealServiceUsd
        case .luxury:
            return luxuryMealServiceUsd
        }
    }
}

/// User-facing errors for server-authoritative package pricing. The name is kept
/// for source compatibility with existing views; it no longer represents a local
/// pricing engine.
enum LocalPricingError: LocalizedError {
    case invalidFlightFare
    case missingHotelPrice(String)
    case invalidComponents

    var errorDescription: String? {
        switch self {
        case .invalidFlightFare:
            return "Не удалось получить текущую стоимость выбранного перелёта."
        case .missingHotelPrice(let city):
            return "Цена Primary Hotel в городе \(city) сейчас недоступна или устарела. Выберите другой доступный отель или повторите позже."
        case .invalidComponents:
            return "Компоненты пакета неполные. Повторите расчёт."
        }
    }
}
