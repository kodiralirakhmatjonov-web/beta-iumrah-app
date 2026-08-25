import SwiftUI

struct FlightSearchImmersiveView: View {
    enum Phase {
        case searching
        case ready
    }

    @EnvironmentObject private var settings: AppSettingsStore
    let state: Phase
    @State private var step = 0

    private var searchSteps: [String] {
        [
            L10n.text("flight_search_airlines", settings.language),
            L10n.text("flight_search_dates", settings.language),
            L10n.text("flight_search_reprice", settings.language),
            L10n.text("flight_search_almost", settings.language)
        ]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 34)

                Image("HeaderWordmarkDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168)
                    .padding(.bottom, 20)

                LoopingVideoView(resource: state == .searching ? "flight-search" : "flight-ready")
                    .frame(maxWidth: 390)
                    .frame(height: 330)
                    .clipped()

                Spacer(minLength: 22)

                VStack(spacing: 8) {
                    Text(state == .searching ? L10n.text("flight_search_hero", settings.language) : L10n.text("flight_ready_title", settings.language))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(state == .searching ? searchSteps[min(step, searchSteps.count - 1)] : L10n.text("flight_ready_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .task {
            guard state == .searching else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(760))
                withAnimation(.easeInOut(duration: 0.25)) {
                    step = min(step + 1, searchSteps.count - 1)
                }
            }
        }
    }
}
