import SwiftUI

struct UmrahHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 34, weight: .medium))
                .frame(width: 72, height: 72)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(L10n.text("tab_umrah", settings.language))
                .font(.system(size: 31, weight: .bold, design: .rounded))

            Text(descriptionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var descriptionText: String {
        L10n.text("umrah_coming", settings.language)
    }

}
