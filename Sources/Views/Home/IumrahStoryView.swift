import SwiftUI

struct IumrahStoryView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("story_kicker", settings.language))
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("story_title", settings.language))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(-0.9)
                    Text(L10n.text("story_intro", settings.language))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                storyParagraph(L10n.text("story_p1", settings.language))
                storyParagraph(L10n.text("story_p2", settings.language))

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("story_why_project_title", settings.language))
                        .font(.title2.weight(.bold))
                    Text(L10n.text("story_why_project_body", settings.language))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .iumrahMarketingCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("story_mission_title", settings.language))
                        .font(.title2.weight(.bold))
                    Text(L10n.text("story_mission_body", settings.language))
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .iumrahMarketingCard(dark: true)
                .foregroundStyle(.white)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .accessibilityIdentifier("iumrah.story")
        .iumrahInternalNavigation()
    }

    private func storyParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
