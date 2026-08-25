import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var chrome: AppChromeStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                confidenceStrip
                independentCard
                connectedJourneyCard
                careCard
                storyCard
                finalCTA
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("ВАША УМРА")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.88))
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("Ваша Умра.\nВаш путь.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1.1)
                    .foregroundStyle(.white)
                Text("iumrah собирает перелёт, отель и поддержку вокруг вашей поездки — не вас вокруг большой группы.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                chrome.startNewTrip()
            } label: {
                HStack {
                    Text("Собрать мою Умру")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .foregroundStyle(.black)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Label("Итоговая стоимость показывается до бронирования", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .iumrahMarketingCard(dark: true)
    }

    private var confidenceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                confidenceChip(icon: "building.2.fill", text: "Отели из каталога iumrah")
                confidenceChip(icon: "airplane", text: "Маршрут под ваши даты")
                confidenceChip(icon: "heart.fill", text: "Поддержка связана с поездкой")
            }
        }
    }

    private func confidenceChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color.iumrahCardBackground)
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(.primary.opacity(0.05), lineWidth: 1) }
    }

    private var independentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            MarketingIcon(systemName: "person.2.fill")
            Text("Не тур. Ваша собственная Умра.")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text("Путешествуйте самостоятельно, с семьёй или друзьями. iumrah строит поездку вокруг вас и оставляет выбор за вами.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var connectedJourneyCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Одна поездка. Всё связано.")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text("Не нужно собирать поездку по разным сервисам и считать её по частям.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                journeyRow(icon: "airplane.departure", title: "Перелёт", subtitle: "Подходящие рейсы на ваши даты")
                journeyDivider
                journeyRow(icon: "building.2", title: "Отель", subtitle: "Рекомендованный вариант из каталога iumrah")
                journeyDivider
                journeyRow(icon: "car.fill", title: "Трансфер", subtitle: "Связан с маршрутом поездки")
                journeyDivider
                journeyRow(icon: "heart.fill", title: "iumrah Care", subtitle: "Помощь остаётся рядом")
            }
            .padding(.horizontal, 14)
            .background(Color.iumrahRaisedBackground.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Одна итоговая стоимость")
                        .font(.headline)
                    Text("без отдельных цен компонентов")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var journeyDivider: some View {
        Divider().padding(.leading, 48)
    }

    private func journeyRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.iumrahCardBackground)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private var careCard: some View {
        Button {
            chrome.navigate(to: .care)
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    Image("CareMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 68)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Spacer()
                    Text("ПЕРВЫЙ ГОД БЕСПЛАТНО")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("iumrah Care")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Забота на каждом этапе вашей поездки")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.92))
                    Text("Отвечает на вопросы, помогает с поездкой и остаётся в контексте вашего бронирования. В течение первого года сервис доступен бесплатно каждому паломнику.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text("Узнать о поддержке")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahMarketingCard(dark: true)
        }
        .buttonStyle(.plain)
    }

    private var storyCard: some View {
        NavigationLink {
            IumrahStoryView()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    MarketingIcon(systemName: "moon.stars.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Text("Почему iumrah Project")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                Text("Проект, рождённый в Мекке из опыта рядом с паломниками. Мы решили построить путь, в котором человек получает больше самостоятельности, ясности и внимания.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Наша история")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahMarketingCard()
        }
        .buttonStyle(.plain)
    }

    private var finalCTA: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ваша следующая Умра может начаться здесь.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.6)
            Text("Скажите, когда хотите отправиться. Мы поможем собрать понятную поездку вокруг ваших дат и предпочтений.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                chrome.startNewTrip()
            } label: {
                Text("Создать мою Умру")
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }
}

private struct MarketingIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .semibold))
            .frame(width: 46, height: 46)
            .background(Color.iumrahRaisedBackground)
            .clipShape(Circle())
    }
}
