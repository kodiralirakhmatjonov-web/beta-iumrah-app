import SwiftUI

struct PrimaryHotelView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SectionHeader(
                    L10n.text("primary_hotel_title", settings.language),
                    eyebrow: L10n.text("primary_hotel_badge", settings.language),
                    subtitle: L10n.format(
                        "primary_hotel_subtitle",
                        settings.language,
                        journey.trip.packageTier.title(settings.language),
                        journey.trip.hotelStars
                    )
                )

                content
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .hotel)
        .task {
            if journey.hotels.isEmpty {
                await journey.loadMakkahHotels()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if journey.isLoadingHotels {
            VStack(spacing: 14) {
                ProgressView()
                Text(L10n.text("primary_hotel_loading", settings.language))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        } else if journey.errorMessage != nil, journey.hotels.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                Text(L10n.text("hotels_load_error", settings.language))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button(L10n.text("retry", settings.language)) {
                    Task { await journey.loadMakkahHotels() }
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            }
            .iumrahCard()
        } else if let hotel = journey.selectedHotel {
            NavigationLink {
                HotelDetailView(hotel: hotel, selectionFlow: true)
            } label: {
                HotelCard(hotel: hotel, badge: L10n.text("primary_hotel_badge", settings.language))
            }
            .buttonStyle(.plain)

            NavigationLink {
                HotelDetailView(hotel: hotel, selectionFlow: true)
            } label: {
                Text(L10n.text("primary_hotel_continue", settings.language))
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            NavigationLink {
                HotelSelectionView()
            } label: {
                Text(L10n.text("primary_hotel_other", settings.language))
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        } else {
            VStack(spacing: 12) {
                Image(systemName: "building.2.crop.circle")
                    .font(.largeTitle)
                Text(L10n.text("primary_hotel_empty", settings.language))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .iumrahCard()
        }
    }
}
