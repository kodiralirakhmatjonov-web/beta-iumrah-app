import SwiftUI

struct IumrahStoryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ПРОЕКТ, РОЖДЁННЫЙ В МЕККЕ")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Text("Почему iumrah Project")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(-0.9)
                    Text("iumrah появилась не из идеи создать ещё один туристический сервис. Она появилась из опыта.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                storyParagraph("Проведя больше года в Мекке и находясь рядом с паломниками, мы снова и снова видели одну проблему: поездка, ради которой человек преодолевает тысячи километров, слишком часто становилась зависимой от большой группы, посредников и чужого расписания.")

                storyParagraph("Мы захотели построить другой путь — чтобы человек мог совершить Умру самостоятельно, с семьёй или друзьями, но при этом не оставался один на один с организацией поездки.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Почему Project")
                        .font(.title2.weight(.bold))
                    Text("Потому что этот путь не должен однажды считаться законченным. С каждой поездкой, каждым вопросом и каждой новой потребностью паломника iumrah должна становиться лучше.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .iumrahMarketingCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Наша задача")
                        .font(.title2.weight(.bold))
                    Text("Не заставлять паломника разбираться в системе. Система должна разбираться в его поездке.")
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
        .navigationTitle("История")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func storyParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
