import SwiftUI

struct OutboundFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @State private var offers: [FlightOffer] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                SectionHeader(
                    "Выберите перелёт",
                    eyebrow: "Туда",
                    subtitle: "Для каждого варианта показывается только итоговая стоимость всего Umrah-пакета."
                )

                if AppConfig.usesSandboxFlightSearch {
                    Label("Beta Flight Engine Sandbox", systemImage: "hammer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isLoading {
                    FlightSearchProgressView()
                } else {
                    ForEach(offers) { offer in
                        Button {
                            journey.selectedOutbound = offer
                        } label: {
                            FlightCard(offer: offer, isSelected: journey.selectedOutbound?.id == offer.id)
                        }
                        .buttonStyle(.plain)
                    }

                    if journey.selectedOutbound != nil {
                        NavigationLink {
                            ReturnFlightView()
                        } label: {
                            Text("Выбрать обратный рейс")
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
        .navigationTitle("Перелёт")
        .navigationBarTitleDisplayMode(.inline)
        .task { await search() }
    }

    private func search() async {
        guard offers.isEmpty, let hotel = journey.selectedHotel else { isLoading = false; return }
        isLoading = true
        do {
            offers = try await journey.flightService.searchOutbound(trip: journey.trip, hotel: hotel)
        } catch {
            journey.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
