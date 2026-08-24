import SwiftUI

struct PrimaryHotelView: View {
    @EnvironmentObject private var journey: JourneyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SectionHeader(
                    "Ваш основной отель",
                    eyebrow: "\(journey.trip.packageTier.title) · \(journey.trip.hotelStars)★",
                    subtitle: "Primary Hotel подбирается из опубликованного каталога iumrah."
                )

                content
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color(uiColor: .systemGroupedBackground))
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
            HotelCard(hotel: hotel, badge: "Primary Hotel")

            NavigationLink {
                OutboundFlightView()
            } label: {
                Text("Оставить этот отель")
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            NavigationLink {
                HotelSelectionView()
            } label: {
                Text("Изменить отель")
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        } else {
            VStack(spacing: 12) {
                Image(systemName: "building.2.crop.circle")
                    .font(.largeTitle)
                Text("В опубликованном каталоге пока нет подходящего отеля.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .iumrahCard()
        }
    }
}
