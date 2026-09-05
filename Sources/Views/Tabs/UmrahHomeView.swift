import SwiftUI

struct UmrahHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahRootPageTitle(title: L10n.text("tab_umrah", settings.language))

                VStack(alignment: .leading, spacing: 18) {
                    IumrahIconBadge(systemName: "book.closed.fill", role: .umrah, size: 64, symbolSize: 28, cornerRadius: 22)

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
