import SwiftUI

struct FlightSearchReadyView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                LoopingVideoView(resource: "flight-ready")
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Image("HeaderWordmarkDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112)
                    .padding(.bottom, 20)
            }

            VStack(spacing: 5) {
                Text(L10n.text("flight_ready_title", settings.language))
                    .font(.title2.weight(.bold))
                Text(L10n.text("flight_ready_body", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
    }
}
