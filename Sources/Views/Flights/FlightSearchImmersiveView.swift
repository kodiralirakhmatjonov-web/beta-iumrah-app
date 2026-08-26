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
            L10n.text("flight_wait_12", settings.language),
            L10n.text("flight_wait_long_01", settings.language),
            L10n.text("flight_wait_long_02", settings.language),
            L10n.text("flight_wait_long_03", settings.language),
            L10n.text("flight_wait_long_04", settings.language),
        ]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 42)

                Image("HeaderWordmarkDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190)
                    .accessibilityHidden(true)

                if state == .searching {
                    // The supplied animation expands upward from its source point.
                    // Rotate it so the source sits directly below the iumrah mark
                    // and the routes visually flow out of the brand into the screen.
                    LoopingVideoView(resource: "flight-search", gravity: .resizeAspect)
                        .frame(maxWidth: 430)
                        .frame(height: 350)
                        .rotationEffect(.degrees(180))
                        .clipped()
                        .padding(.top, -18)
                } else {
                    LoopingVideoView(resource: "flight-ready", gravity: .resizeAspect)
                        .frame(maxWidth: 390)
                        .frame(height: 320)
                        .clipped()
                        .padding(.top, 4)
                }

                Spacer(minLength: 14)

                VStack(spacing: 10) {
                    Text(state == .searching ? L10n.text("flight_search_hero", settings.language) : L10n.text("flight_ready_title", settings.language))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(state == .searching ? searchSteps[min(step, searchSteps.count - 1)] : L10n.text("flight_ready_body", settings.language))
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.35), value: step)
                        .padding(.horizontal, 28)

                    if state == .searching {
                        Text(L10n.text("flight_wait_average", settings.language))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.36))
                            .padding(.top, 5)
                    }
                }

                Spacer(minLength: 46)
            }
            .padding(.horizontal, 20)
        }
        .task(id: state) {
            guard state == .searching else { return }
            step = 0
            while !Task.isCancelled, step < searchSteps.count - 1 {
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    step += 1
                }
            }
        }
    }
}
