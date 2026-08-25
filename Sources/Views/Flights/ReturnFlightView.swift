import SwiftUI

struct ReturnFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var chrome: AppChromeStore
    @ObservedObject private var challengeCenter = FlightBotChallengeCenter.shared
    @State private var offers: [FlightOffer] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showingChallenge = false
    @State private var showingReadyAnimation = false

    var body: some View {
        Group {
            if isLoading {
                FlightSearchImmersiveView(state: .searching)
            } else if showingReadyAnimation {
                FlightSearchImmersiveView(state: .ready)
            } else {
                resultsView
            }
        }
        .background(isLoading || showingReadyAnimation ? Color.black : Color.iumrahPageBackground)
        .navigationTitle(isLoading || showingReadyAnimation ? "" : "Обратно")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isLoading || showingReadyAnimation ? .hidden : .visible, for: .navigationBar)
        .task { await search(force: false) }
        .onAppear { chrome.setImmersive(isLoading || showingReadyAnimation) }
        .onChange(of: isLoading) { _, _ in updateImmersive() }
        .onChange(of: showingReadyAnimation) { _, _ in updateImmersive() }
        .onDisappear { chrome.setImmersive(false) }
        .sheet(isPresented: $showingChallenge) {
            if let challenge = challengeCenter.pending {
                FlightChallengeSheet(challenge: challenge) {
                    challengeCenter.clear()
                    Task { await retrySearch() }
                }
            }
        }
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                SectionHeader(
                    "Выберите обратный перелёт",
                    eyebrow: "Обратно",
                    subtitle: "Стоимость пересчитана вместе с уже выбранным рейсом туда и означает весь пакет целиком."
                )

                if let errorText {
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
                            IumrahHaptics.selection()
                        } label: {
                            FlightCard(offer: offer, isSelected: journey.selectedInbound?.id == offer.id, isRecommended: index == 0)
                        }
                        .buttonStyle(.plain)
                    }

                    if journey.selectedInbound != nil {
                        NavigationLink {
                            FinalPackageView()
                        } label: {
                            Text("Посмотреть готовую Умру")
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
    }

    private func updateImmersive() {
        chrome.setImmersive(isLoading || showingReadyAnimation)
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
            errorText = "Сначала выберите рейс туда."
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
            IumrahHaptics.success()
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeInOut(duration: 0.28)) { showingReadyAnimation = false }
            return
        } catch {
            errorText = error.localizedDescription
            journey.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
