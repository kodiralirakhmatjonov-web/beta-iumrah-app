import SwiftUI

// MARK: - Apple Store-inspired storefront primitives

struct IumrahStorePageHeader: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1.1)
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 10)

            IumrahGlassIconButton(
                systemName: "person.crop.circle",
                size: 44,
                fontSize: 18,
                accessibilityLabel: accountAccessibilityLabel
            ) {
                chrome.navigate(to: .account)
            }
            .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountAccessibilityLabel: String {
        switch settings.language {
        case .russian: return "Аккаунт"
        case .english: return "Account"
        case .uzbek: return "Hisob"
        case .uzbekCyrillic: return "Ҳисоб"
        }
    }
}

struct IumrahStoreSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.55)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IumrahStoreCategoryTile: View {
    let systemName: String
    let title: String
    var role: IumrahIconRole = .neutral

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(role.color)
                .frame(width: 58, height: 58)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 76)
        .contentShape(Rectangle())
    }
}

struct IumrahStoreEditorialCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var asset: String? = nil
    var systemName: String? = nil
    var dark = false
    var accent: Color = .primary

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(dark ? Color.black : Color.iumrahCardBackground)

            if let asset {
                Image(asset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 292, height: 360)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [Color.clear, dark ? Color.black.opacity(0.76) : Color.black.opacity(0.52)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
            } else if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: 72, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accent.opacity(dark ? 0.82 : 0.72))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -28)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.85)
                    .foregroundStyle(dark || asset != nil ? Color.white.opacity(0.67) : Color.secondary)

                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                    .foregroundStyle(dark || asset != nil ? Color.white : Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(dark || asset != nil ? Color.white.opacity(0.72) : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(21)
        }
        .frame(width: 292, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(dark ? 0.04 : 0.055), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(dark ? 0.16 : 0.055), radius: 22, y: 10)
    }
}

struct IumrahStoreCompactRow: View {
    let systemName: String
    let title: String
    let subtitle: String
    var role: IumrahIconRole = .neutral

    var body: some View {
        HStack(spacing: 14) {
            IumrahIconBadge(systemName: systemName, role: role, size: 48, symbolSize: 20, cornerRadius: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(15)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }
}

// MARK: - Product/category pages

struct IumrahConfiguratorStorePage: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                IumrahStoreBackHeader(title: configuratorTitle)

                VStack(alignment: .leading, spacing: 9) {
                    Text(copy.heroTitle)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1.0)
                    Text(copy.heroBody)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image("StoreConfiguratorPhones")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                IumrahStoreSectionHeader(title: copy.chooseTitle, subtitle: copy.chooseSubtitle)

                packageCards

                Button {
                    journey.resetAfterTripChange()
                    chrome.startNewTrip()
                } label: {
                    HStack {
                        Text(copy.cta)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())

                helpCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
    }

    private var packageCards: some View {
        VStack(spacing: 12) {
            packageCard(title: standardTitle, subtitle: copy.standard, icon: "sparkles", tint: .blue)
            packageCard(title: comfortTitle, subtitle: copy.comfort, icon: "star.fill", tint: .indigo)
            packageCard(title: luxuryTitle, subtitle: copy.luxury, icon: "diamond.fill", tint: .orange)
            packageCard(title: customTitle, subtitle: copy.custom, icon: "slider.horizontal.3", tint: .gray)
        }
    }

    private func packageCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy.helpTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(copy.helpBody)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Button(copy.helpCTA) {
                chrome.navigate(to: .care)
            }
            .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var configuratorTitle: String { localized("iumrah Конфигуратор", "iumrah Configurator", "iumrah Konfigurator", "iumrah Конфигуратор") }
    private var standardTitle: String { localized("Стандарт", "Standard", "Standart", "Стандарт") }
    private var comfortTitle: String { localized("Комфорт", "Comfort", "Qulay", "Қулай") }
    private var luxuryTitle: String { localized("Люкс", "Luxury", "Hashamat", "Ҳашамат") }
    private var customTitle: String { localized("Свой вариант", "Custom", "Individual", "Индивидуал") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var copy: (heroTitle: String, heroBody: String, chooseTitle: String, chooseSubtitle: String, standard: String, comfort: String, luxury: String, custom: String, cta: String, helpTitle: String, helpBody: String, helpCTA: String) {
        switch settings.language {
        case .russian:
            return ("Создайте Умру под себя.", "Выберите даты, уровень поездки и детали. iumrah соберёт перелёт, отели, трансфер и поддержку в одном бронировании.", "Выберите уровень", "Начните с готового уровня и измените всё, что важно Вам.", "Практичный пакет с прозрачной стоимостью.", "Больше комфорта в отелях и поездке.", "Премиальные отели, транспорт и сервис.", "Соберите каждый компонент самостоятельно.", "Открыть конфигуратор", "Нужна помощь с выбором?", "Поддержка iumrah поможет выбрать формат поездки до бронирования.", "Перейти к подготовке")
        case .english:
            return ("Build Umrah around you.", "Choose your dates, trip level and preferences. iumrah brings flights, hotels, transfers and support into one booking.", "Choose your level", "Start with a ready-made level, then change what matters to you.", "A practical trip with transparent pricing.", "More comfort across your stay and journey.", "Premium hotels, transport and service.", "Choose every component yourself.", "Open Configurator", "Need help deciding?", "iumrah Care can help you choose before you book.", "Open Gear")
        case .uzbek:
            return ("Umrani o‘zingizga mos yarating.", "Sana, safar darajasi va istaklaringizni tanlang. iumrah parvoz, mehmonxona, transfer va yordamni bitta bronlashga birlashtiradi.", "Darajani tanlang", "Tayyor darajadan boshlang va muhim qismlarni o‘zgartiring.", "Shaffof narxli amaliy safar.", "Safar davomida ko‘proq qulaylik.", "Premium mehmonxona, transport va servis.", "Har bir qismni o‘zingiz tanlang.", "Konfiguratorni ochish", "Tanlashda yordam kerakmi?", "iumrah yordami bronlashdan oldin safar formatini tanlashga yordam beradi.", "Tayyorgarlikni ochish")
        case .uzbekCyrillic:
            return ("Умрани ўзингизга мос яратинг.", "Сана, сафар даражаси ва истакларингизни танланг. iumrah парвоз, меҳмонхона, трансфер ва ёрдамни битта бронлашга бирлаштиради.", "Даражани танланг", "Тайёр даражадан бошланг ва муҳим қисмларни ўзгартиринг.", "Шаффоф нархли амалий сафар.", "Сафар давомида кўпроқ қулайлик.", "Премиум меҳмонхона, транспорт ва сервис.", "Ҳар бир қисмни ўзингиз танланг.", "Конфигураторни очиш", "Танлашда ёрдам керакми?", "iumrah ёрдами бронлашдан олдин сафар форматини танлашга ёрдам беради.", "Тайёргарликни очиш")
        }
    }
}

struct IumrahTransfersStorePage: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var journey: JourneyStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                IumrahStoreBackHeader(title: copy.title)

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.headline)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1)
                    Text(copy.body)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                transferCard(asset: "TransferMalibu", title: "Chevrolet Malibu", subtitle: copy.sedan)
                transferCard(asset: "TransferCarnival", title: "Kia Carnival", subtitle: copy.family)
                transferCard(asset: "TransferYukon", title: "GMC Yukon", subtitle: copy.premium)

                Button {
                    journey.resetAfterTripChange()
                    chrome.startNewTrip()
                } label: {
                    HStack {
                        Text(copy.cta)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
    }

    private func transferCard(asset: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(height: 245)
                .frame(maxWidth: .infinity)
                .clipped()

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(18)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private var copy: (title: String, headline: String, body: String, sedan: String, family: String, premium: String, cta: String) {
        switch settings.language {
        case .russian: return ("Трансферы", "Двигайтесь спокойно.", "Выберите класс автомобиля для аэропорта, поездок между Меккой и Мединой и индивидуальных маршрутов.", "Комфортный седан для 1–3 пассажиров.", "Просторный вариант для семьи и багажа.", "Премиальный внедорожник для индивидуальной поездки.", "Добавить трансфер в Умру")
        case .english: return ("Transfers", "Move with ease.", "Choose a vehicle class for the airport, Makkah–Madinah travel and private routes.", "Comfortable sedan for 1–3 travellers.", "Roomy option for families and luggage.", "Premium SUV for a private journey.", "Add transfer to Umrah")
        case .uzbek: return ("Transferlar", "Xotirjam harakatlaning.", "Aeroport, Makka–Madina va shaxsiy yo‘nalishlar uchun avtomobil sinfini tanlang.", "1–3 yo‘lovchi uchun qulay sedan.", "Oila va yuklar uchun keng variant.", "Shaxsiy safar uchun premium yo‘ltanlamas.", "Transferni Umraga qo‘shish")
        case .uzbekCyrillic: return ("Трансферлар", "Хотиржам ҳаракатланинг.", "Аэропорт, Макка–Мадина ва шахсий йўналишлар учун автомобиль синфини танланг.", "1–3 йўловчи учун қулай седан.", "Оила ва юклар учун кенг вариант.", "Шахсий сафар учун премиум йўлтанламас.", "Трансферни Умрага қўшиш")
        }
    }
}

struct IumrahHotelsStorePage: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                IumrahStoreBackHeader(title: copy.title)

                Image("IumrahHotelsShowcaseHero")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 360)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .center, endPoint: .bottom)
                            .overlay(alignment: .bottomLeading) {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(copy.headline)
                                        .font(.system(size: 31, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(copy.body)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.74))
                                }
                                .padding(22)
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                VStack(spacing: 12) {
                    IumrahStoreCompactRow(systemName: "location.fill", title: copy.haram, subtitle: copy.haramSub, role: .location)
                    IumrahStoreCompactRow(systemName: "star.fill", title: copy.fiveStar, subtitle: copy.fiveStarSub, role: .rating)
                    IumrahStoreCompactRow(systemName: "person.3.fill", title: copy.family, subtitle: copy.familySub, role: .profile)
                }

                Button {
                    chrome.navigate(to: .hotels)
                } label: {
                    HStack {
                        Text(copy.cta)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
    }

    private var copy: (title: String, headline: String, body: String, haram: String, haramSub: String, fiveStar: String, fiveStarSub: String, family: String, familySub: String, cta: String) {
        switch settings.language {
        case .russian: return ("Отели", "Остановитесь ближе.", "Подборка отелей в Мекке и Медине, собранная для поездки на Умру.", "Рядом с Харамом", "Отели для тех, кому важна пешая доступность.", "5-звёздочные отели", "Премиальные варианты для более комфортной поездки.", "Для семьи", "Номера и размещение для нескольких паломников.", "Открыть все отели")
        case .english: return ("Hotels", "Stay closer.", "A curated selection of Makkah and Madinah stays built around Umrah travel.", "Near the Haram", "Stays for travellers who value walkability.", "5-star stays", "Premium options for a more comfortable journey.", "For families", "Rooms and stays for multiple pilgrims.", "Browse all hotels")
        case .uzbek: return ("Mehmonxonalar", "Yaqinroq turing.", "Umra safari uchun Makka va Madinadagi saralangan mehmonxonalar.", "Haram yaqinida", "Piyoda yaqinlik muhim bo‘lganlar uchun.", "5 yulduzli mehmonxonalar", "Qulayroq safar uchun premium variantlar.", "Oila uchun", "Bir nechta ziyoratchi uchun xonalar.", "Barcha mehmonxonalarni ochish")
        case .uzbekCyrillic: return ("Меҳмонхоналар", "Яқинроқ туринг.", "Умра сафари учун Макка ва Мадинадаги сараланган меҳмонхоналар.", "Ҳарам яқинида", "Пиёда яқинлик муҳим бўлганлар учун.", "5 юлдузли меҳмонхоналар", "Қулайроқ сафар учун премиум вариантлар.", "Оила учун", "Бир нечта зиёратчи учун хоналар.", "Барча меҳмонхоналарни очиш")
        }
    }
}

struct IumrahServiceStorePage: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    enum Kind {
        case flights
        case advisor
        case ziyarats
        case esim
        case care
    }

    let kind: Kind

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                IumrahStoreBackHeader(title: content.brand)

                ZStack(alignment: .bottomLeading) {
                    heroBackground
                    LinearGradient(colors: [.clear, .black.opacity(0.74)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(content.eyebrow.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.65))
                        Text(content.title)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-0.8)
                            .foregroundStyle(.white)
                        Text(content.body)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                }
                .frame(height: 410)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))

                IumrahStoreSectionHeader(title: content.sectionTitle, subtitle: content.sectionSubtitle)

                VStack(spacing: 12) {
                    ForEach(Array(content.points.enumerated()), id: \.offset) { _, point in
                        IumrahStoreCompactRow(systemName: point.0, title: point.1, subtitle: point.2, role: point.3)
                    }
                }

                Button(content.cta) {
                    performCTA()
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private var heroBackground: some View {
        switch kind {
        case .flights:
            Image("IumrahFlightsShowcaseHero")
                .resizable()
                .scaledToFill()
        case .care:
            Image("IumrahCareShowcaseCard")
                .resizable()
                .scaledToFill()
        case .advisor:
            LinearGradient(colors: [Color.black, Color.purple.opacity(0.82), Color.orange.opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ziyarats:
            Image("ZiyaratQuba2")
                .resizable()
                .scaledToFill()
        case .esim:
            LinearGradient(colors: [Color.cyan.opacity(0.86), Color.blue.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Image(systemName: "simcard.fill")
                        .font(.system(size: 112, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
        }
    }

    private func performCTA() {
        switch kind {
        case .flights:
            chrome.startNewTrip()
        case .advisor, .ziyarats, .care:
            if chrome.currentTab == .care {
                dismiss()
            } else {
                chrome.navigate(to: .care)
            }
        case .esim:
            chrome.presentESIM()
        }
    }

    private typealias Point = (String, String, String, IumrahIconRole)

    private var content: (brand: String, eyebrow: String, title: String, body: String, sectionTitle: String, sectionSubtitle: String, points: [Point], cta: String) {
        switch kind {
        case .flights:
            return (
                localized("iumrah Перелёты", "iumrah Flights", "iumrah Parvozlar", "iumrah Парвозлар"),
                localized("Перелёты", "Flights", "Parvozlar", "Парвозлар"),
                localized("Перелёт — часть одной поездки.", "Flights, connected to your trip.", "Parvoz safaringiz bilan bog‘langan.", "Парвоз сафарингиз билан боғланган."),
                localized("Подберите перелёт в Саудовскую Аравию и держите его рядом с отелем, трансфером и бронированием.", "Choose your flight to Saudi Arabia and keep it connected to your hotel, transfer and booking.", "Saudiya Arabistoniga parvozni tanlang va uni mehmonxona, transfer hamda bronlash bilan birga saqlang.", "Саудия Арабистонига парвозни танланг ва уни меҳмонхона, трансфер ҳамда бронлаш билан бирга сақланг."),
                localized("Лететь проще", "A simpler way to fly", "Parvoz qilish osonroq", "Парвоз қилиш осонроқ"),
                localized("Главное собрано в одном месте.", "The essentials stay in one place.", "Asosiy ma’lumotlar bir joyda.", "Асосий маълумотлар бир жойда."),
                [
                    ("airplane.departure", localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш"), localized("Город вылета и аэропорт прибытия.", "Departure city and arrival airport.", "Jo‘nash shahri va yetib borish aeroporti.", "Жўнаш шаҳри ва етиб бориш аэропорти."), .travel),
                    ("calendar", localized("Даты", "Dates", "Sanalar", "Саналар"), localized("Перелёт связан с датами Вашей Умры.", "Flights stay aligned with your Umrah dates.", "Parvoz Umra sanalaringiz bilan moslashtiriladi.", "Парвоз Умра саналарингиз билан мослаштирилади."), .calendar),
                    ("checkmark.seal.fill", localized("Проверка", "Verification", "Tekshiruv", "Текширув"), localized("Статус остаётся внутри бронирования.", "Status remains visible inside your booking.", "Holat bronlash ichida ko‘rinadi.", "Ҳолат бронлаш ичида кўринади."), .security)
                ],
                localized("Подобрать перелёт", "Find a flight", "Parvozni tanlash", "Парвозни танлаш")
            )
        case .advisor:
            return (
                localized("iumrah Голосовой гид", "iumrah Advisor", "iumrah Ovozli yo‘l-yo‘riq", "iumrah Овозли йўл-йўриқ"),
                localized("Голосовой гид", "Voice Guide", "Ovozli yo‘l-yo‘riq", "Овозли йўл-йўриқ"),
                localized("Ваша Умра. С голосовым сопровождением.", "Your Umrah. Guided by voice.", "Umrangiz. Ovozli yo‘l-yo‘riq bilan.", "Умрангиз. Овозли йўл-йўриқ билан."),
                localized("Голосовой гид iumrah помогает пройти этапы Умры последовательно и спокойно.", "Advisor helps you move through each stage of Umrah with clear voice guidance.", "iumrah ovozli yo‘l-yo‘riq xizmati Umraning har bir bosqichidan aniq ko‘rsatmalar bilan o‘tishga yordam beradi.", "iumrah овозли йўл-йўриқ хизмати Умранинг ҳар бир босқичидан аниқ кўрсатмалар билан ўтишга ёрдам беради."),
                localized("Создан для самой Умры", "Built for the Umrah itself", "Umraning o‘zi uchun yaratilgan", "Умранинг ўзи учун яратилган"),
                localized("Не отдельный аудиофайл, а последовательное сопровождение.", "Not a loose audio file — a guided sequence.", "Oddiy audio emas — ketma-ket yo‘l-yo‘riq.", "Оддий аудио эмас — кетма-кет йўл-йўриқ."),
                [
                    ("waveform", localized("Голос", "Voice", "Ovoz", "Овоз"), localized("Подсказки в нужный момент.", "Guidance at the moment you need it.", "Kerakli paytda ovozli ko‘rsatmalar.", "Керакли пайтда овозли кўрсатмалар."), .umrah),
                    ("globe", localized("Языки", "Languages", "Tillar", "Тиллар"), localized("Выберите удобный язык сопровождения.", "Choose the language that works for you.", "O‘zingizga qulay tilni tanlang.", "Ўзингизга қулай тилни танланг."), .language),
                    ("book.closed.fill", localized("Этапы", "Stages", "Bosqichlar", "Босқичлар"), localized("Таваф, Сафа и Марва и завершение.", "Tawaf, Safa & Marwa and completion.", "Tavof, Safo va Marva hamda yakunlash.", "Тавоф, Сафо ва Марва ҳамда якунлаш."), .umrah)
                ],
                localized("Открыть голосовой гид в разделе подготовки", "Open Advisor in Gear", "Ovozli yo‘l-yo‘riqni Tayyorgarlik bo‘limida ochish", "Овозли йўл-йўриқни Тайёргарлик бўлимида очиш")
            )
        case .ziyarats:
            return (
                localized("iumrah Зияраты", "iumrah Ziyarats", "iumrah Ziyoratlar", "iumrah Зиёратлар"),
                localized("Мекка и Медина", "Makkah & Madinah", "Makka va Madina", "Макка ва Мадина"),
                localized("Места, которые стоит знать.", "Places worth knowing.", "Bilishga arziydigan joylar.", "Билишга арзийдиган жойлар."),
                localized("Точные точки, фотографии и маршруты для зияратов в Мекке и Медине.", "Curated places, photography and routes for Ziyarats in Makkah and Madinah.", "Makka va Madinadagi ziyoratlar uchun aniq joylar, suratlar va yo‘nalishlar.", "Макка ва Мадинадаги зиёратлар учун аниқ жойлар, суратлар ва йўналишлар."),
                localized("Откройте город со смыслом", "Explore with context", "Mazmun bilan kashf eting", "Мазмун билан кашф этинг"),
                localized("Каждая точка оформлена как самостоятельная история.", "Every stop is presented as a focused story.", "Har bir nuqta alohida hikoya sifatida taqdim etiladi.", "Ҳар бир нуқта алоҳида ҳикоя сифатида тақдим этилади."),
                [
                    ("map.fill", localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш"), localized("Точки собраны в понятной последовательности.", "Stops arranged into a clear route.", "Nuqtalar tushunarli ketma-ketlikda jamlangan.", "Нуқталар тушунарли кетма-кетликда жамланган."), .location),
                    ("photo.on.rectangle", localized("Фотографии", "Photos", "Suratlar", "Суратлар"), localized("Узнавайте место до прибытия.", "Recognise the place before you arrive.", "Yetib borishdan oldin joyni tanib oling.", "Етиб боришдан олдин жойни таниб олинг."), .travel),
                    ("book.closed.fill", localized("Контекст", "Context", "Izoh", "Изоҳ"), localized("Краткое объяснение каждой точки.", "A concise explanation for every stop.", "Har bir nuqta uchun qisqa tushuntirish.", "Ҳар бир нуқта учун қисқа тушунтириш."), .umrah)
                ],
                localized("Открыть в разделе подготовки", "Open in Gear", "Tayyorgarlik bo‘limida ochish", "Тайёргарлик бўлимида очиш")
            )
        case .esim:
            return (
                "iumrah eSIM",
                localized("Связь", "Connectivity", "Aloqa", "Алоқа"),
                localized("Связь с момента прибытия.", "Connected from arrival.", "Yetib kelgan zahoti aloqa.", "Етиб келган заҳоти алоқа."),
                localized("Добавьте мобильный интернет к своей поездке и держите активацию рядом с бронированием.", "Add mobile data to your trip and keep activation beside your booking.", "Mobil internetni safaringizga qo‘shing va faollashtirishni bronlash bilan birga saqlang.", "Мобил интернетни сафарингизга қўшинг ва фаоллаштиришни бронлаш билан бирга сақланг."),
                localized("Без отдельной SIM-карты", "No separate SIM stop", "Alohida SIM uchun borish shart emas", "Алоҳида SIM учун бориш шарт эмас"),
                localized("Подготовьте связь ещё до поездки.", "Prepare connectivity before you travel.", "Aloqani safardan oldin tayyorlang.", "Алоқани сафардан олдин тайёрланг."),
                [
                    ("simcard.fill", "eSIM", localized("Цифровая активация на совместимом устройстве.", "Digital activation on a compatible device.", "Mos qurilmada raqamli faollashtirish.", "Мос қурилмада рақамли фаоллаштириш."), .connectivity),
                    ("antenna.radiowaves.left.and.right", localized("Интернет", "Data", "Internet", "Интернет"), localized("Тариф связан с Вашей поездкой.", "Your plan stays tied to the trip.", "Tarif safaringiz bilan bog‘langan.", "Тариф сафарингиз билан боғланган."), .connectivity),
                    ("checkmark.circle.fill", localized("Готовность", "Ready", "Tayyor", "Тайёр"), localized("Проверьте статус перед вылетом.", "Check status before departure.", "Jo‘nashdan oldin holatni tekshiring.", "Жўнашдан олдин ҳолатни текширинг."), .success)
                ],
                localized("Открыть eSIM", "Open eSIM", "eSIM’ni ochish", "eSIM’ни очиш")
            )
        case .care:
            return (
                localized("iumrah Поддержка", "iumrah Care", "iumrah Yordam", "iumrah Ёрдам"),
                localized("Поддержка", "Support", "Yordam", "Ёрдам"),
                localized("Помощь остаётся с Вашей поездкой.", "Support that stays with your trip.", "Yordam safaringiz bilan birga qoladi.", "Ёрдам сафарингиз билан бирга қолади."),
                localized("Поддержка iumrah связана с конкретным бронированием — до поездки, во время неё и после.", "Care keeps support attached to the booking before, during and after the trip.", "iumrah yordami bronlashga safardan oldin, davomida va undan keyin bog‘lanadi.", "iumrah ёрдами бронлашга сафардан олдин, давомида ва ундан кейин боғланади."),
                localized("Не объясняйте всё заново", "No need to repeat the context", "Vaziyatni qayta tushuntirish shart emas", "Вазиятни қайта тушунтириш шарт эмас"),
                localized("Команда видит поездку, к которой относится обращение.", "Your conversation stays connected to the relevant trip.", "Muloqot tegishli safar bilan bog‘langan bo‘ladi.", "Мулоқот тегишли сафар билан боғланган бўлади."),
                [
                    ("message.fill", localized("Чат", "Chat", "Chat", "Чат"), localized("Поддержка внутри приложения.", "Support inside the app.", "Ilova ichidagi yordam.", "Илова ичидаги ёрдам."), .message),
                    ("suitcase.fill", localized("Поездка", "Trip", "Safar", "Сафар"), localized("Контекст бронирования остаётся рядом.", "Booking context remains attached.", "Bronlash konteksti saqlanadi.", "Бронлаш контексти сақланади."), .booking),
                    ("heart.fill", localized("iumrah Поддержка", "iumrah Care", "iumrah Yordam", "iumrah Ёрдам"), localized("До, во время и после Умры.", "Before, during and after Umrah.", "Umradan oldin, davomida va keyin.", "Умрадан олдин, давомида ва кейин."), .care)
                ],
                localized("Открыть поддержку в разделе подготовки", "Open Care in Gear", "Yordamni Tayyorgarlik bo‘limida ochish", "Ёрдамни Тайёргарлик бўлимида очиш")
            )
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private struct IumrahStoreBackHeader: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            IumrahGlassIconButton(systemName: "chevron.left", size: 42, fontSize: 15, accessibilityLabel: backAccessibilityLabel) {
                dismiss()
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var backAccessibilityLabel: String {
        switch settings.language {
        case .russian: return "Назад"
        case .english: return "Back"
        case .uzbek: return "Orqaga"
        case .uzbekCyrillic: return "Орқага"
        }
    }
}
