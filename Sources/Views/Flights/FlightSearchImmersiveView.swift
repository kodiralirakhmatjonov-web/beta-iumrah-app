import SwiftUI

struct FlightSearchImmersiveView: View {
    enum Phase {
        case searching
        case ready
    }

    @EnvironmentObject private var settings: AppSettingsStore
    let state: Phase
    var liveStatus: GeneratorSearchStage? = nil

    @State private var stepIndex = 0

    private var regularSteps: [String] {
        [
            L10n.text("flight_wait_01", settings.language),
            L10n.text("flight_wait_02", settings.language),
            L10n.text("flight_wait_03", settings.language),
            L10n.text("flight_wait_04", settings.language),
            L10n.text("flight_wait_05", settings.language),
            L10n.text("flight_wait_06", settings.language),
            L10n.text("flight_wait_07", settings.language),
            L10n.text("flight_wait_08", settings.language),
            L10n.text("flight_wait_09", settings.language),
            L10n.text("flight_wait_10", settings.language),
            L10n.text("flight_wait_11", settings.language),
            L10n.text("flight_wait_12", settings.language)
        ]
    }

    private var longSteps: [String] {
        [
            L10n.text("flight_wait_long_01", settings.language),
            L10n.text("flight_wait_long_02", settings.language),
            L10n.text("flight_wait_long_03", settings.language),
            L10n.text("flight_wait_long_04", settings.language)
        ]
    }

    private var currentSearchMessage: String {
        if stepIndex < regularSteps.count {
            return regularSteps[stepIndex]
        }
        let longIndex = min(stepIndex - regularSteps.count, max(longSteps.count - 1, 0))
        return longSteps[longIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                LoopingVideoView(resource: state == .searching ? "flight-search" : "flight-ready")
                    .frame(maxWidth: 390)
                    .frame(height: 380)
                    .clipped()

                Image("HeaderWordmarkDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 188)
                    .padding(.top, -20)
                    .padding(.bottom, 22)

                VStack(spacing: 10) {
                    Text(state == .searching ? (liveStatus?.text(settings.language) ?? currentSearchMessage) : L10n.text("flight_ready_title", settings.language))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 24)

                    Text(state == .searching ? L10n.text("flight_wait_average", settings.language) : L10n.text("flight_ready_body", settings.language))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 32)
                }

                Spacer(minLength: 70)
            }
            .padding(.horizontal, 20)
        }
        .task {
            guard state == .searching else { return }
            stepIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                withAnimation(.easeInOut(duration: 0.3)) {
                    let maxIndex = regularSteps.count + longSteps.count - 1
                    stepIndex = min(stepIndex + 1, maxIndex)
                }
            }
        }
    }
}
