import SwiftUI

struct UmrahCarePackageExplanationView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Image("CarePriceSupport")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .tracking(-0.7)
                        Text(intro)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    explanationRow(icon: "square.stack.3d.up.fill", title: stepOneTitle, body: stepOneBody)
                    explanationRow(icon: "airplane", title: stepTwoTitle, body: stepTwoBody)
                    explanationRow(icon: "building.2.fill", title: stepThreeTitle, body: stepThreeBody)
                    explanationRow(icon: "person.2.fill", title: stepFourTitle, body: stepFourBody)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(careTitle)
                            .font(.headline)
                        Text(careBody)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .background(Color.iumrahCareLight.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 38, height: 38)
                            .background(Color.iumrahRaisedBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func explanationRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var title: String {
        switch settings.language {
        case .russian: return "Как iumrah собирает вашу поездку"
        case .english: return "How iumrah builds your journey"
        case .uzbek: return "iumrah safaringizni qanday yig‘adi"
        case .uzbekCyrillic: return "iumrah сафарингизни қандай йиғади"
        }
    }

    private var intro: String {
        switch settings.language {
        case .russian: return "iumrah — не просто сервис бронирования. Мы собираем перелёты, проживание, трансферы, сопровождение и ключевые этапы Умры как одну связанную поездку, чтобы паломнику не приходилось самому сводить десятки отдельных деталей."
        case .english: return "iumrah is more than a booking service. Flights, stays, transfers, guidance and the key stages of Umrah are assembled as one connected journey so the pilgrim does not have to reconcile dozens of separate details."
        case .uzbek: return "iumrah oddiy bronlash xizmati emas. Parvozlar, turar joy, transferlar, yo‘riqnoma va Umraning asosiy bosqichlari yagona bog‘langan safar sifatida yig‘iladi."
        case .uzbekCyrillic: return "iumrah оддий бронлаш хизмати эмас. Парвозлар, турар жой, трансферлар, йўриқнома ва Умранинг асосий босқичлари ягона боғланган сафар сифатида йиғилади."
        }
    }

    private var stepOneTitle: String { localized("Поездка просчитывается как единая система", "The trip is calculated as one system", "Safar yagona tizim sifatida hisoblanadi", "Сафар ягона тизим сифатида ҳисобланади") }
    private var stepOneBody: String { localized("Даты, число паломников, ночи в Мекке и Медине и выбранные услуги связываются между собой заранее, чтобы не возникали лишние ночи, разрывы между городами или дублирование услуг.", "Dates, traveler count, nights in Makkah and Madinah and selected services are connected in advance to avoid extra nights, broken city transitions or duplicated services.", "Sanalar, ziyoratchilar soni, Makka va Madinadagi tunlar hamda xizmatlar oldindan bog‘lanadi.", "Саналар, зиёратчилар сони, Макка ва Мадинадаги тунлар ҳамда хизматлар олдиндан боғланади.") }

    private var stepTwoTitle: String { localized("Рейс оценивается внутри всей поездки", "Flights are evaluated inside the whole journey", "Reys butun safar ichida baholanadi", "Рейс бутун сафар ичида баҳоланади") }
    private var stepTwoBody: String { localized("Если найденный маршрут делает пакет заметно дороже или неудобнее, iumrah Care дополнительно проверяет более прямые и сбалансированные варианты, особенно когда даты гибкие.", "If a route makes the package noticeably more expensive or inconvenient, iumrah Care reviews more direct and balanced options, especially when dates are flexible.", "Agar yo‘nalish paketni ancha qimmat yoki noqulay qilsa, iumrah Care qulayroq variantlarni tekshiradi.", "Агар йўналиш пакетни анча қиммат ёки ноқулай қилса, iumrah Care қулайроқ вариантларни текширади.") }

    private var stepThreeTitle: String { localized("Отели закрепляются под реальные ночи", "Hotels are matched to the actual nights", "Mehmonxonalar haqiqiy tunlarga moslanadi", "Меҳмонхоналар ҳақиқий тунларга мосланади") }
    private var stepThreeBody: String { localized("При окончательном оформлении команда проверяет доступность выбранного отеля именно на даты вашего проживания. Если рядом доступен более удобный вариант сопоставимого уровня, его можно предложить до подтверждения.", "Before final confirmation, the team checks the selected hotel specifically for your stay dates. If a more convenient comparable option is available nearby, it can be suggested before confirmation.", "Yakuniy tasdiqdan oldin tanlangan mehmonxona aynan safar sanalari uchun tekshiriladi; zarur bo‘lsa, yaqinroq muqobil variant taklif qilinadi.", "Якуний тасдиқдан олдин танланган меҳмонхона айнан сафар саналари учун текширилади; зарур бўлса, яқинроқ муқобил вариант таклиф қилинади.") }

    private var stepFourTitle: String { localized("Сопровождение привязано к вашей Умре", "Guidance is attached to your Umrah", "Yo‘riqnoma Umrangizga biriktiriladi", "Йўриқнома Умрангизга бириктирилади") }
    private var stepFourBody: String { localized("Трансферы и гид координируются вокруг вашей фактической поездки — прилёта, переезда между городами, Умры и вылета домой.", "Transfers and guidance are coordinated around your actual journey: arrival, city transfer, Umrah and the flight home.", "Transfer va gid haqiqiy safaringiz — kelish, shaharlararo o‘tish, Umra va qaytish atrofida muvofiqlashtiriladi.", "Трансфер ва гид ҳақиқий сафарингиз — келиш, шаҳарлараро ўтиш, Умра ва қайтиш атрофида мувофиқлаштирилади.") }

    private var careTitle: String { localized("Наша задача — забота, а не просто бронь", "Our role is care, not just booking", "Vazifamiz — faqat bron emas, g‘amxo‘rlik", "Вазифамиз — фақат брон эмас, ғамхўрлик") }
    private var careBody: String { localized("Мы хотим, чтобы организационные детали не отвлекали вас от поклонения. Поэтому iumrah Care проверяет связность маршрута и помогает стабилизировать поездку до окончательного оформления.", "We want logistics to stay out of the way of worship. iumrah Care checks that the journey fits together and helps stabilize it before final confirmation.", "Tashkiliy masalalar ibodatdan chalg‘itmasligi uchun iumrah Care safarning uyg‘unligini tekshiradi.", "Ташкилий масалалар ибодатдан чалғитмаслиги учун iumrah Care сафарнинг уйғунлигини текширади.") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCyrl
        }
    }
}
