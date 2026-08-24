import SwiftUI

struct ReturnFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @State private var offers: [FlightOffer] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                SectionHeader(
                    "Обратный перелёт",
                    eyebrow: "Обратно",
                    subtitle: "Выберите обратный рейс. Цена по-прежнему означает весь пакет целиком."
                )

                if isLoading {
                    FlightSearchProgressView()
                } else {
                    ForEach(offers) { offer in
                        Button {
                            journey.selectedInbound = offer
                        } label: {
                            FlightCard(offer: offer, isSelected: journey.selectedInbound?.id == offer.id)
                        }
                        .buttonStyle(.plain)
                    }

                    if journey.selectedInbound != nil {
                        NavigationLink {
                            FinalPackageView()
                        } label: {
                            Text("Посмотреть весь пакет")
                        }
                        .buttonStyle(IumrahPrimaryButtonStyle())
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Обратно")
        .navigationBarTitleDisplayMode(.inline)
        .task { await search() }
    }

    private func search() async {
        guard offers.isEmpty,
              let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound else {
            isLoading = false
            return
        }
        isLoading = true
        do {
            offers = try await journey.flightService.searchReturn(trip: journey.trip, hotel: hotel, outbound: outbound)
        } catch {
            journey.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
