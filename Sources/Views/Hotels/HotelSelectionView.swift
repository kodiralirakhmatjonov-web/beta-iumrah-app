import SwiftUI

struct HotelSelectionView: View {
    @EnvironmentObject private var journey: JourneyStore
    @Environment(\.dismiss) private var dismiss

    private var filteredHotels: [HotelSummary] {
        let exact = journey.hotels.filter { $0.stars == journey.trip.hotelStars }
        return exact.isEmpty ? journey.hotels : exact
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                SectionHeader(
                    "Изменить отель",
                    eyebrow: "Каталог iumrah",
                    subtitle: "Здесь показываются только отели из вашей опубликованной базы. Live-поиск цены будет подключён отдельным adapter’ом."
                )

                ForEach(filteredHotels) { hotel in
                    Button {
                        journey.chooseHotel(hotel)
                        dismiss()
                    } label: {
                        HotelCard(hotel: hotel, badge: journey.selectedHotel?.id == hotel.id ? "Выбран" : nil)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("Отели")
        .navigationBarTitleDisplayMode(.inline)
    }
}
