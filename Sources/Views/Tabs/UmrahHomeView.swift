import SwiftUI

struct UmrahHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahRootPageTitle(title: L10n.text("tab_umrah", settings.language))

                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 28, weight: .medium))
                        .frame(width: 64, height: 64)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Text(L10n.text("tab_umrah", settings.language))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(-0.5)

                    Text(L10n.text("umrah_coming", settings.language))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .iumrahMarketingCard()
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
