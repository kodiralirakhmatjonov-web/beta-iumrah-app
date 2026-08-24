import SwiftUI

struct PackagePriceView: View {
    let amount: Decimal
    let currency: String
    var suffix: String = "/ чел."

    private var formatted: String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "\(currency) \(number)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(formatted)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(suffix)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
