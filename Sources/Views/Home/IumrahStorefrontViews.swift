import SwiftUI

// MARK: - Apple Store-inspired storefront primitives

/// Large leading title used by personalized and service tabs.
struct IumrahStorePageHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(-1.05)
                .foregroundStyle(.primary)

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

/// Apple Store Products uses a compact centered navigation title.
struct IumrahStoreCenteredHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
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
                .foregroundStyle(.primary)

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

/// Compact white product-family tile, matching the rhythm of Apple Store's
/// iPhone / Watch / iPad row. The entire tile is one white surface.
struct IumrahStoreProductFamilyTile: View {
    let title: String
    var assetName: String? = nil
    var systemName: String? = nil
    var role: IumrahIconRole = .neutral

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let assetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 9)
                        .padding(.top, 7)
                } else if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 34, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(role.color)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 11)
        .frame(width: 108, height: 128)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }
}

/// Main dark merchandising card. This is deliberately the only dominant black
/// product card on Products so Configurator owns the page visually.
struct IumrahStoreFeatureCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let assetName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.black

                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .colorInvert()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 18)
                    .opacity(0.95)
            }
            .frame(height: 258)

            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.85)
                    .foregroundStyle(.white.opacity(0.60))

                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .padding(21)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Color.black)
        }
        .frame(height: 428)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
        }
    }
}

/// Canonical white Store card: image first, white copy surface second.
/// Width is intentionally provided by the horizontal container so it adapts
/// to every iPhone rather than relying on a fixed 292/326pt card.
struct IumrahStoreMerchandisingCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let assetName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 258)
                .clipped()

            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.85)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .padding(21)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Color.iumrahCardBackground)
        }
        .frame(height: 428)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.035), radius: 12, y: 5)
    }
}

/// Compact white Store-style service card used in two-column/horizontal sets.
struct IumrahStoreServiceCard: View {
    let systemName: String
    let title: String
    let subtitle: String
    var role: IumrahIconRole = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IumrahIconBadge(systemName: systemName, role: role, size: 48, symbolSize: 20, cornerRadius: 16)

            Text(title)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 238, height: 214, alignment: .topLeading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
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
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(copy.heroTitle)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1.0)
                    Text(copy.heroBody)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image("StoreConfiguratorPhones")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
                    }

                IumrahStoreSectionHeader(title: copy.chooseTitle, subtitle: copy.chooseSubtitle)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        packageCard(title: standardTitle, subtitle: copy.standard, icon: "sparkles", role: .travel)
                        packageCard(title: comfortTitle, subtitle: copy.comfort, icon: "star.fill", role: .hotel)
                        packageCard(title: luxuryTitle, subtitle: copy.luxury, icon: "diamond.fill", role: .rating)
                        packageCard(title: customTitle, subtitle: copy.custom, icon: "slider.horizontal.3", role: .settings)
                    }
                    .padding(.horizontal, 1)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 0, for: .scrollContent)

                IumrahStoreSectionHeader(title: copy.essentialsTitle)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        essentialChip("airplane", copy.flightChip)
                        essentialChip("building.2.fill", copy.hotelChip)
                        essentialChip("car.fill", copy.transferChip)
                        essentialChip("heart.fill", "Care")
                        essentialChip("simcard.fill", "eSIM")
                    }
                    .padding(.horizontal, 1)
                }

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
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .storeProductDetailChrome(title: configuratorTitle)
    }

    private func packageCard(title: String, subtitle: String, icon: String, role: IumrahIconRole) -> some View {
        Button {
            journey.resetAfterTripChange()
            chrome.startNewTrip()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Color.iumrahCardBackground
                    Image(systemName: icon)
                        .font(.system(size: 68, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(role.color)
                }
                .frame(height: 170)

                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Text(copy.chooseAction)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            }
            .frame(width: 272, height: 330)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private func essentialChip(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.iumrahCardBackground, in: Capsule())
    }

    private var helpCard: some View {
        Button {
            chrome.navigate(to: .care)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.helpTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(copy.helpBody)
                        .font(.system(size: 14.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "phone.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .frame(width: 52, height: 52)
                    .background(Color.iumrahRaisedBackground, in: Circle())
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var configuratorTitle: String { localized("iumrah Конфигуратор", "iumrah Configurator", "iumrah Konfigurator", "iumrah Конфигуратор") }
    private var standardTitle: String { localized("Стандарт", "Standard", "Standart", "Стандарт") }
    private var comfortTitle: String { localized("Комфорт", "Comfort", "Qulay", "Қулай") }
    private var luxuryTitle: String { localized("Люкс", "Luxury", "Hashamat", "Ҳашамат") }
    private var customTitle: String { localized("Свой вариант", "Custom", "Shaxsiy", "Шахсий") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var copy: (heroTitle: String, heroBody: String, chooseTitle: String, chooseSubtitle: String, standard: String, comfort: String, luxury: String, custom: String, essentialsTitle: String, flightChip: String, hotelChip: String, transferChip: String, chooseAction: String, cta: String, helpTitle: String, helpBody: String) {
        switch settings.language {
        case .russian:
            return ("Соберите свою Умру.", "Выберите даты, уровень поездки и детали. iumrah соединит нужные компоненты в одном бронировании.", "Выберите формат", "Начните с подходящего уровня и измените то, что важно именно Вам.", "Практичный формат с прозрачной стоимостью.", "Больше комфорта в проживании и поездке.", "Премиальные отели, транспорт и сервис.", "Соберите компоненты самостоятельно.", "Всё необходимое", "Перелёт", "Отели", "Трансфер", "Выбрать", "Открыть конфигуратор", "Нужна помощь с выбором?", "iumrah Care поможет выбрать формат поездки до бронирования.")
        case .english:
            return ("Build your Umrah.", "Choose dates, trip level and details. iumrah connects the right components into one booking.", "Choose your format", "Start with the level that fits and change what matters to you.", "A practical format with transparent pricing.", "More comfort across stays and transport.", "Premium hotels, transport and service.", "Choose the components yourself.", "All the essentials", "Flights", "Hotels", "Transfer", "Choose", "Open Configurator", "Still need help deciding?", "iumrah Care can help you choose the right journey format before booking.")
        case .uzbek:
            return ("Umrangizni yig‘ing.", "Sanalar, safar darajasi va tafsilotlarni tanlang. iumrah kerakli qismlarni bitta bronlashga bog‘laydi.", "Formatni tanlang", "Mos darajadan boshlang va Siz uchun muhim narsalarni o‘zgartiring.", "Shaffof narxli amaliy format.", "Yashash va safarda ko‘proq qulaylik.", "Premium mehmonxona, transport va servis.", "Komponentlarni o‘zingiz tanlang.", "Barcha kerakli narsalar", "Parvoz", "Mehmonxonalar", "Transfer", "Tanlash", "Konfiguratorni ochish", "Tanlashda yordam kerakmi?", "iumrah Care bronlashdan oldin mos safar formatini tanlashga yordam beradi.")
        case .uzbekCyrillic:
            return ("Умрангизни йиғинг.", "Саналар, сафар даражаси ва тафсилотларни танланг. iumrah керакли қисмларни битта бронлашга боғлайди.", "Форматни танланг", "Мос даражадан бошланг ва Сиз учун муҳим нарсаларни ўзгартиринг.", "Шаффоф нархли амалий формат.", "Яшаш ва сафарда кўпроқ қулайлик.", "Премиум меҳмонхона, транспорт ва сервис.", "Компонентларни ўзингиз танланг.", "Барча керакли нарсалар", "Парвоз", "Меҳмонхоналар", "Трансфер", "Танлаш", "Конфигураторни очиш", "Танлашда ёрдам керакми?", "iumrah Care бронлашдан олдин мос сафар форматини танлашга ёрдам беради.")
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

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.headline)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1)
                    Text(copy.body)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        transferCard(asset: "TransferMalibu", title: "Chevrolet Malibu", subtitle: copy.sedan)
                        transferCard(asset: "TransferCarnival", title: "Kia Carnival", subtitle: copy.family)
                        transferCard(asset: "TransferYukon", title: "GMC Yukon", subtitle: copy.premium)
                    }
                    .padding(.horizontal, 1)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 0, for: .scrollContent)

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
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .storeProductDetailChrome(title: copy.title)
    }

    private func transferCard(asset: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: 316, height: 225)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(chooseTitle)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.top, 5)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        }
        .frame(width: 316, height: 367)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }


    private var chooseTitle: String {
        switch settings.language {
        case .russian: return "Выбрать"
        case .english: return "Choose"
        case .uzbek: return "Tanlash"
        case .uzbekCyrillic: return "Танлаш"
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
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .storeProductDetailChrome(title: copy.title)
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
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .storeProductDetailChrome(title: content.brand)
    }

    @ViewBuilder
    private var heroBackground: some View {
        switch kind {
        case .flights:
            Image("IumrahFlightsShowcaseHero")
                .resizable()
                .scaledToFill()
        case .care:
            LinearGradient(
                colors: [Color.black, Color.iumrahCareDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 112, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.86))
            }
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
                localized("Открыть голосовой гид в Care", "Open Advisor in Care", "Ovozli yo‘l-yo‘riqni Care bo‘limida ochish", "Овозли йўл-йўриқни Care бўлимида очиш")
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
                localized("Открыть в Care", "Open in Care", "Care bo‘limida ochish", "Care бўлимида очиш")
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
                localized("Открыть поддержку в Care", "Open Care", "Yordamni Care bo‘limida ochish", "Ёрдамни Care бўлимида очиш")
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


private struct IumrahStoreProductDetailChrome: ViewModifier {
    @EnvironmentObject private var chrome: AppChromeStore
    @State private var registered = false
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .onAppear {
                guard !registered else { return }
                registered = true
                chrome.beginInternalNavigation()
            }
            .onDisappear {
                guard registered else { return }
                registered = false
                chrome.endInternalNavigation()
            }
    }
}

private extension View {
    func storeProductDetailChrome(title: String) -> some View {
        modifier(IumrahStoreProductDetailChrome(title: title))
    }
}
