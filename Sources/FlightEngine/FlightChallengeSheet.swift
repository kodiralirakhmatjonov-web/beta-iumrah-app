import SwiftUI

struct FlightChallengeSheet: View {
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
                        Button("Закрыть") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") {
                            dismiss()
                            onCompleted()
                        }
                    }
                }
        }
    }
}
