import SwiftUI

struct HotelsHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var makkahHotels: [HotelSummary] = []
    @State private var madinahHotels: [HotelSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = HotelCatalogService()

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahRootPageTitle(title: L10n.text("tab_hotels", settings.language))
                hero
                if isLoading && makkahHotels.isEmpty && madinahHotels.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    citySection(title: L10n.text("hotels_makkah", settings.language), hotels: makkahHotels)
                    citySection(title: L10n.text("hotels_madinah", settings.language), hotels: madinahHotels)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .task { await load() }
        .refreshable { await load() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("hotels_title", settings.language))
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(L10n.text("hotels_subtitle", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
            Text(L10n.text("hotels_note", settings.language))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(14)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard(dark: true)
    }

    private func citySection(title: String, hotels: [HotelSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title, eyebrow: L10n.text("hotels_selected_badge", settings.language), subtitle: nil)
            if hotels.isEmpty {
                EmptyView()
            }
            ForEach(hotels.prefix(4)) { hotel in
                hotelRow(hotel)
            }
        }
    }

    private func hotelRow(_ hotel: HotelSummary) -> some View {
        HStack(alignment: .center, spacing: 14) {
            AsyncImage(url: AppConfig.absoluteURL(hotel.coverImageURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    LinearGradient(colors: [Color.iumrahRaisedBackground, Color.iumrahCardBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(Image(systemName: "building.2").font(.title3).foregroundStyle(.secondary))
                }
            }
            .frame(width: 94, height: 94)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(hotel.name)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    if let stars = hotel.stars {
                        Label("\(stars)★", systemImage: "star.fill")
                    }
                    if let rating = hotel.rating {
                        Label(String(format: "%.1f", rating), systemImage: "sparkles")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Text(L10n.city(hotel.city, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .iumrahCard()
    }

    @MainActor
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let makkah = service.listHotels(city: "Makkah")
            async let madinah = service.listHotels(city: "Madinah")
            makkahHotels = try await makkah
            madinahHotels = try await madinah
            errorMessage = nil
        } catch {
            errorMessage = L10n.text("hotels_load_error", settings.language)
        }
    }
}
