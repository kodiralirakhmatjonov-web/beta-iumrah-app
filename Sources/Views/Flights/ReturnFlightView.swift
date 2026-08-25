import SwiftUI

struct ReturnFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
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
                    .iumrahInternalNavigation(progress: .flight)
            }
        }
        .background(isLoading || showingReadyAnimation ? Color.black : Color.iumrahPageBackground)
        .toolbar(.hidden, for: .navigationBar)
        .task { await search(force: false) }
        .onAppear { updateImmersive() }
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
                    L10n.text("flight_return_title", settings.language),
                    eyebrow: L10n.text("flight_return_eyebrow", settings.language),
                    subtitle: L10n.text("flight_return_body", settings.language)
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
                            Text(L10n.text("flight_view_package", settings.language))
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
            errorText = L10n.text("flight_select_outbound_first", settings.language)
            isLoading = false
            return
        }

        isLoading = true
        errorText = nil
        journey.errorMessage = nil
        do {
            offers = try await journey.flightService.searchReturn(trip: journey.trip, hotel: hotel, outbound: outbound)
            isLoading = false
            showingReadyAnimation = true
            IumrahHaptics.success()
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeInOut(duration: 0.28)) { showingReadyAnimation = false }
            return
        } catch {
            errorText = L10n.error(error, settings.language)
            journey.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
