import SwiftUI

struct FlightSearchFailureView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let message: String
    let challenge: FlightBotChallenge?
    let onRetry: () -> Void
    let onOpenChallenge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                L10n.text(challenge == nil ? "flight_search_failed" : "flight_challenge_title", settings.language),
                systemImage: challenge == nil ? "exclamationmark.triangle" : "person.crop.circle.badge.exclamationmark"
            )
            .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let challenge {
                Text(L10n.format("flight_challenge_body", settings.language, challenge.providerName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(L10n.text("challenge_open", settings.language)) {
                    onOpenChallenge()
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }

            Button(L10n.text("flight_retry", settings.language)) {
                onRetry()
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .iumrahCard()
    }
}
