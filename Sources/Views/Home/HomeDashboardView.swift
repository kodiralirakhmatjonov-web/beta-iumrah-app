import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                confidenceStrip
                philosophyCard
                hotelCard
                careCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.text("home_hero_kicker", settings.language))
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.88))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("home_hero_title", settings.language))
                    .font(.system(size: 39, weight: .bold, design: .rounded))
                    .tracking(-1.1)
                    .foregroundStyle(.white)
                Text(L10n.text("home_hero_body", settings.language))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Button {
                chrome.startNewTrip()
            } label: {
                HStack {
                    Text(L10n.text("home_hero_cta", settings.language))
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

            Label(L10n.text("home_hero_badge", settings.language), systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .iumrahMarketingCard(dark: true)
    }

    private var confidenceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(icon: "building.2.fill", text: L10n.text("tab_hotels", settings.language))
                chip(icon: "airplane", text: L10n.text("step_flight", settings.language))
                chip(icon: "heart.fill", text: "Aiomra Care")
            }
        }
    }

    private func chip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color.iumrahCardBackground)
            .clipShape(Capsule())
            .overlay { Capsule().strokeBorder(.primary.opacity(0.05), lineWidth: 1) }
    }

    private var philosophyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iumrah")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Capsule())
            Text(settings.language == .english ? "Not a tour. A more personal Umrah." : settings.language == .uzbek ? "Bu oddiy tur emas. Bu sizga mos Umra." : settings.language == .uzbekCyrillic ? "Бу оддий тур эмас. Бу сизга мос Умра." : "Не тур. Более личная Умра.")
                .font(.system(size: 29, weight: .bold, design: .rounded))
            Text(settings.language == .english ? "Aiomra helps you organize the trip for yourself, your family or your friends — with a cleaner interface, a simpler flow and support connected to the same booking." : settings.language == .uzbek ? "Aiomra safarni o‘zingiz, oilangiz yoki do‘stlaringiz uchun tartibga solishga yordam beradi — tozaroq interfeys, soddaroq oqim va shu safarga bog‘langan yordam bilan." : settings.language == .uzbekCyrillic ? "Aiomra сафарни ўзингиз, оилангиз ёки дўстларингиз учун тартибга солишга ёрдам беради — тозароқ интерфейс, соддароқ оқим ва шу сафарга боғланган ёрдам билан." : "Aiomra помогает организовать поездку для себя, семьи или друзей — с более чистым интерфейсом, простым сценарием и поддержкой, связанной с тем же бронированием.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var hotelCard: some View {
        Button {
            chrome.navigate(to: .hotels)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color.iumrahCareLight.opacity(0.35), Color.iumrahRaisedBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .overlay(Image(systemName: "building.2").font(.system(size: 28, weight: .medium)).foregroundStyle(Color.iumrahCareDark))
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.text("hotels_title", settings.language))
                        .font(.headline)
                    Text(L10n.text("hotels_subtitle", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }

    private var careCard: some View {
        Button {
            chrome.navigate(to: .care)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 7) {
                    Text("Aiomra Care")
                        .font(.headline)
                    Text(L10n.text("care_subtitle", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }
}
