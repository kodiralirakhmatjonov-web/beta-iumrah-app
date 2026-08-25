import SwiftUI

struct CareHomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SectionHeader(
                    "iumrah Care",
                    eyebrow: "Поддержка",
                    subtitle: "Помощь до поездки, во время Умры и после возвращения — в одном месте."
                )

                careCard(
                    icon: "message.fill",
                    title: "Чат с поддержкой",
                    subtitle: "Live Chat подключим к уже существующей Cloudflare системе на следующем этапе."
                )

                careCard(
                    icon: "bell.and.waves.left.and.right.fill",
                    title: "Помощь в поездке",
                    subtitle: "Статусы, важные уведомления и поддержка по маршруту будут отображаться здесь."
                )

                careCard(
                    icon: "person.crop.circle.badge.questionmark",
                    title: "Связаться с iumrah",
                    subtitle: "Быстрый доступ к персональной поддержке без поиска контактов и переписок."
                )
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func careCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }
}
