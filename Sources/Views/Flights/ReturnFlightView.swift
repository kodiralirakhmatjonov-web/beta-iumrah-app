import SwiftUI

struct ReturnFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @ObservedObject private var challengeCenter = FlightBotChallengeCenter.shared
    @State private var offers: [FlightOffer] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showingChallenge = false
    @State private var showingReadyAnimation = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                SectionHeader(
                    "Обратный перелёт",
                    eyebrow: "Обратно",
                    subtitle: "Выберите обратный рейс. Цена означает весь пакет целиком и пересчитана с выбранным рейсом туда."
                )

                Label("Real Flight Engine · точный пересчёт PackageQuote", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isLoading {
                    FlightSearchProgressView()
                } else if showingReadyAnimation {
                    FlightSearchReadyView()
                } else if let errorText {
                    FlightSearchFailureView(
                        message: errorText,
                        challenge: challengeCenter.pending,
                        onRetry: { Task { await retrySearch() } },
                        onOpenChallenge: { showingChallenge = true }
                    )
                } else {
                    ForEach(Array(offers.enumerated()), id: \.element.id) { index, offer in
                        Button {
                            journey.selectedInbound = offer
                            journey.quote = nil
                        } label: {
                            FlightCard(offer: offer, isSelected: journey.selectedInbound?.id == offer.id, isRecommended: index == 0)
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
        .background(Color.iumrahPageBackground)
        .navigationTitle("Обратно")
        .navigationBarTitleDisplayMode(.inline)
        .task { await search(force: false) }
        .sheet(isPresented: $showingChallenge) {
            if let challenge = challengeCenter.pending {
                FlightChallengeSheet(challenge: challenge) {
                    challengeCenter.clear()
                    Task { await retrySearch() }
                }
            }
        }
    }

    private func retrySearch() async {
        offers = []
        showingReadyAnimation = false
        journey.selectedInbound = nil
        journey.quote = nil
        await search(force: true)
    }

    private func search(force: Bool) async {
        if !force, !offers.isEmpty { isLoading = false; return }
        guard let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound else {
            errorText = "Сначала выберите реальный рейс туда."
            isLoading = false
            return
        }

        isLoading = true
        errorText = nil
        journey.errorMessage = nil
        do {
            let found = try await journey.flightService.searchReturn(trip: journey.trip, hotel: hotel, outbound: outbound)
            offers = found
            isLoading = false
            showingReadyAnimation = true
            IumrahHaptics.soft()
            try? await Task.sleep(for: .milliseconds(1700))
            withAnimation(.easeInOut(duration: 0.28)) { showingReadyAnimation = false }
            return
        } catch {
            errorText = error.localizedDescription
            journey.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
