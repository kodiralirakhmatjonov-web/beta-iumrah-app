import SwiftUI

struct FlightCard: View {
    let offer: FlightOffer
    let isSelected: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.airline)
                        .font(.headline)
                    Text(offer.flightNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                timeBlock(code: offer.origin, date: offer.departureAt)
                VStack(spacing: 5) {
                    Image(systemName: "airplane")
                        .font(.caption)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.tertiary)
                    Text(offer.stopLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                timeBlock(code: offer.destination, date: offer.arrivalAt)
            }

            Divider()
            HStack {
                Text("Весь пакет")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                PackagePriceView(amount: offer.totalPackagePrice, currency: offer.currency)
            }
        }
        .iumrahCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(.primary, lineWidth: 1.5)
            }
        }
    }

    private func timeBlock(code: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.timeFormatter.string(from: date))
                .font(.title3.monospacedDigit().weight(.bold))
            Text(code.uppercased())
                .font(.caption.weight(.semibold))
            Text(Self.dayFormatter.string(from: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
