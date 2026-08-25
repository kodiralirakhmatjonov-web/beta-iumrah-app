import SwiftUI

struct FlightChallengeSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let challenge: FlightBotChallenge
    let onCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FlightChallengeWebView(challenge: challenge)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(challenge.providerName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.text("close", settings.language)) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.text("flight_ready_title", settings.language)) {
                            dismiss()
                            onCompleted()
                        }
                    }
                }
        }
    }
}
