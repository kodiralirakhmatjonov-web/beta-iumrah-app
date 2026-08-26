import SwiftUI

struct HotelSelectionView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    private var filteredHotels: [HotelSummary] {
        let exact = journey.hotels.filter { $0.stars == journey.trip.hotelStars }
        return exact.isEmpty ? journey.hotels : exact
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                SectionHeader(
                    L10n.text("hotel_change_title", settings.language),
                    eyebrow: L10n.text("hotel_catalog_eyebrow", settings.language),
                    subtitle: L10n.text("hotel_change_body", settings.language)
                )

                ForEach(filteredHotels) { hotel in
                    NavigationLink {
                        HotelDetailView(
                            hotel: hotel,
                            onRoomSelected: { _ in dismiss() }
                        )
                    } label: {
                        HotelCard(
                            hotel: hotel,
                            badge: journey.selectedHotel?.id == hotel.id ? L10n.text("selected", settings.language) : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .hotel)
    }
}
