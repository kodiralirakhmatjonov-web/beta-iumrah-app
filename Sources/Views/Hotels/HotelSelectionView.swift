import SwiftUI

enum HotelSelectionRole: String, Hashable {
    case makkah
    case madinah
}

struct HotelSelectionView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    let role: HotelSelectionRole

    init(role: HotelSelectionRole = .makkah) {
        self.role = role
    }

    private var sourceHotels: [HotelSummary] {
        role == .makkah ? journey.hotels : journey.madinahHotels
    }

    private var selectedHotelID: String? {
        role == .makkah ? journey.selectedHotel?.id : journey.selectedMadinahHotel?.id
    }

    private var filteredHotels: [HotelSummary] {
        sourceHotels.filter(\.hasFreshCatalogPrice).sorted { lhs, rhs in
            let lhsExact = lhs.stars == journey.trip.hotelStars
            let rhsExact = rhs.stars == journey.trip.hotelStars
            if lhsExact != rhsExact { return lhsExact && !rhsExact }
            if lhs.stars != rhs.stars { return (lhs.stars ?? 0) > (rhs.stars ?? 0) }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(role == .makkah ? FlowCopy.text(.hotelSelectionTitleMakkah, settings.language) : FlowCopy.text(.hotelSelectionTitleMadinah, settings.language))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .tracking(-0.7)
                    Text(FlowCopy.text(.hotelSelectionBody, settings.language))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if filteredHotels.isEmpty {
                    VStack(spacing: 14) {
                        if role == .makkah ? journey.isLoadingHotels : journey.isLoadingMadinahHotels {
                            ProgressView()
                        } else {
                            Image(systemName: "building.2")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                        Text(L10n.text("primary_hotel_empty", settings.language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(filteredHotels) { hotel in
                        NavigationLink {
                            HotelDetailView(hotel: hotel, selectionFlow: true, selectionRole: role)
                        } label: {
                            HotelCard(
                                hotel: hotel,
                                badge: selectedHotelID == hotel.id ? FlowCopy.text(.selected, settings.language) : nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: nil)
        .task {
            if role == .makkah, journey.hotels.isEmpty { await journey.loadMakkahHotels() }
            if role == .madinah, journey.madinahHotels.isEmpty { await journey.loadMadinahHotels() }
        }
    }
}
