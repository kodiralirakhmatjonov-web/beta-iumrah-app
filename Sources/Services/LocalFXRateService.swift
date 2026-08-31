import Foundation

@MainActor
final class LocalFXRateService {
    static let shared = LocalFXRateService()

    private struct CBUEntry: Decodable {
        let Ccy: String
        let Rate: String
    }

    private var cached: [String: Decimal] = ["USD": 1]
    private var cachedAt: Date?
    private let cacheLifetime: TimeInterval = 6 * 60 * 60

    private init() {}

    func usd(_ amount: Decimal, currency rawCurrency: String) async throws -> Decimal {
        let currency = rawCurrency.uppercased()
        guard amount >= 0 else { throw LocalFXError.invalidAmount }
        if currency == "USD" { return amount }
        try await refreshIfNeeded()
        guard let sourceUZS = cached[currency], let usdUZS = cached["USD"], usdUZS > 0 else {
            throw LocalFXError.unsupportedCurrency(currency)
        }
        return amount * sourceUZS / usdUZS
    }

    private func refreshIfNeeded() async throws {
        if let cachedAt, Date().timeIntervalSince(cachedAt) < cacheLifetime, cached.count > 1 { return }
        guard let url = URL(string: "https://cbu.uz/en/arkhiv-kursov-valyut/json/") else { throw LocalFXError.unavailable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw LocalFXError.unavailable }
        let rows = try JSONDecoder().decode([CBUEntry].self, from: data)
        var next: [String: Decimal] = [:]
        for row in rows {
            let normalized = row.Rate.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
            if let rate = Decimal(string: normalized), rate > 0 { next[row.Ccy.uppercased()] = rate }
        }
        // CBU's USD rate is UZS per USD; do not force it to 1.
        guard next["USD"] != nil else { throw LocalFXError.unavailable }
        cached = next
        cachedAt = Date()
    }
}

enum LocalFXError: LocalizedError {
    case invalidAmount
    case unsupportedCurrency(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Некорректная сумма компонента."
        case .unsupportedCurrency(let currency): return "Не удалось пересчитать валюту \(currency) в USD."
        case .unavailable: return "Курс валют временно недоступен. Повторите расчёт."
        }
    }
}
