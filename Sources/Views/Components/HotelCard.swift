import SwiftUI

struct HotelCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let hotel: HotelSummary
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: AppConfig.absoluteURL(hotel.coverImageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack {
                            Rectangle().fill(.quaternary)
                            ProgressView()
                        }
                    @unknown default:
                        placeholder
                    }
                }
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                if let badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(12)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(hotel.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let stars = hotel.stars {
                        Label("\(stars)★", systemImage: "star.fill")
                    }
                    if let rating = hotel.rating {
                        Label(String(format: "%.1f", rating), systemImage: "heart.fill")
                    }
                    Text(L10n.city(hotel.city, settings.language))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                if let price = hotel.price, price.isFresh, let nightly = price.nightlyUSD {
                    HStack(spacing: 7) {
                        Text(String(format: "$%.0f", nightly))
                            .font(.subheadline.weight(.bold))
                        Text(priceSuffix)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 6)
                        Text(price.providerDisplayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .iumrahCard()
    }

    private var priceSuffix: String {
        switch settings.language {
        case .russian: return "за номер / ночь"
        case .english: return "room / night"
        case .uzbek: return "xona / tun"
        case .uzbekCyrillic: return "хона / тун"
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "building.2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }
}
