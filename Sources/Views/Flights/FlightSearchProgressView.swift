import SwiftUI

struct FlightSearchProgressView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var step = 0

    private var labels: [String] {
        [
            L10n.text("flight_search_airlines", settings.language),
            L10n.text("flight_search_dates", settings.language),
            L10n.text("flight_search_reprice", settings.language),
            L10n.text("flight_search_almost", settings.language)
        ]
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottom) {
                LoopingVideoView(resource: "flight-search")
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Image("HeaderWordmarkDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118)
                    .padding(.bottom, 22)
            }

            VStack(spacing: 6) {
                Text(L10n.text("flight_search_hero", settings.language))
                    .font(.title3.weight(.bold))
                Text(labels[min(step, labels.count - 1)])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(750))
                withAnimation(.easeInOut(duration: 0.25)) {
                    step = min(step + 1, labels.count - 1)
                }
            }
        }
    }
}
