import SwiftUI

struct PrimaryHotelView: View {
    @EnvironmentObject private var journey: JourneyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SectionHeader(
                    "Мы подобрали отель для вашей поездки",
                    eyebrow: "Рекомендует iumrah",
                    subtitle: "Он соответствует выбранному уровню \(journey.trip.packageTier.title) и категории \(journey.trip.hotelStars)★. Вы можете оставить его или посмотреть другие варианты."
                )

                content
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("Отель")
        .navigationBarTitleDisplayMode(.inline)
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
                Text("Загружаем каталог iumrah…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
        } else if let message = journey.errorMessage, journey.hotels.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Повторить") {
                    Task { await journey.loadMakkahHotels() }
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            }
            .iumrahCard()
        } else if let hotel = journey.selectedHotel {
            HotelCard(hotel: hotel, badge: "Рекомендует iumrah")

            NavigationLink {
                OutboundFlightView()
            } label: {
                Text("Продолжить с этим отелем")
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            NavigationLink {
                HotelSelectionView()
            } label: {
                Text("Посмотреть другие варианты")
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        } else {
            VStack(spacing: 12) {
                Image(systemName: "building.2.crop.circle")
                    .font(.largeTitle)
                Text("В каталоге пока нет подходящего отеля.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .iumrahCard()
        }
    }
}
