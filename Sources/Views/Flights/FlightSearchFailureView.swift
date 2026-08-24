import SwiftUI

struct FlightSearchFailureView: View {
    let message: String
    let challenge: FlightBotChallenge?
    let onRetry: () -> Void
    let onOpenChallenge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(challenge == nil ? "Поиск не завершён" : "Нужна проверка", systemImage: challenge == nil ? "exclamationmark.triangle" : "person.crop.circle.badge.exclamationmark")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let challenge {
                Text("\(challenge.providerName) запросил человеческую проверку. Пройдите её и повторите поиск — cookies и сессия сохраняются на этом iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Пройти проверку") {
                    onOpenChallenge()
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }

            Button("Повторить поиск") {
                onRetry()
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .iumrahCard()
    }
}
