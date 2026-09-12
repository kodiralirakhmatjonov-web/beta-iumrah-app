import SwiftUI

/// Products is the commerce/discovery surface. The merchandising order mirrors
/// Apple Store's Products rhythm while preserving all iumrah navigation/data flows.
struct HomeDashboardView: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var expandedFAQ: Int?

    private var copy: ProductsCopy { ProductsCopy.make(for: settings.language) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 30) {
                IumrahStoreCenteredHeader(title: copy.pageTitle)
                productFamilies
                serviceFilters
                discoverSection
                differenceSection
                moreSection
                faqSection
                helpSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Product families

    private var productFamilies: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink { IumrahConfiguratorStorePage() } label: {
                    IumrahStoreProductFamilyTile(
                        title: copy.familyConfigurator,
                        assetName: "StoreConfiguratorPhones"
                    )
                }
                NavigationLink { IumrahServiceStorePage(kind: .flights) } label: {
                    IumrahStoreProductFamilyTile(
                        title: copy.familyFlights,
                        systemName: "airplane",
                        role: .travel
                    )
                }
                NavigationLink { IumrahHotelsStorePage() } label: {
                    IumrahStoreProductFamilyTile(
                        title: copy.familyHotels,
                        systemName: "building.2.fill",
                        role: .hotel
                    )
                }
                NavigationLink { IumrahTransfersStorePage() } label: {
                    IumrahStoreProductFamilyTile(
                        title: copy.familyTransfers,
                        systemName: "car.fill",
                        role: .transfer
                    )
                }
                NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                    IumrahStoreProductFamilyTile(
                        title: copy.familyAdvisor,
                        systemName: "waveform.badge.mic",
                        role: .umrah
                    )
                }
                NavigationLink { IumrahServiceStorePage(kind: .ziyarats) } label: {
                    IumrahStoreProductFamilyTile(
                        title: copy.familyZiyarats,
                        systemName: "map.fill",
                        role: .location
                    )
                }
                NavigationLink { IumrahServiceStorePage(kind: .care) } label: {
                    IumrahStoreProductFamilyTile(
                        title: "Care",
                        assetName: "CareMark"
                    )
                }
            }
            .padding(.horizontal, 1)
        }
        .buttonStyle(.plain)
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    // MARK: - Accessories rhythm / service filters

    private var serviceFilters: some View {
        VStack(alignment: .leading, spacing: 14) {
            IumrahStoreSectionHeader(title: copy.filtersTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    NavigationLink { IumrahConfiguratorStorePage() } label: { filterChip(copy.filterPackages) }
                    NavigationLink { IumrahServiceStorePage(kind: .flights) } label: { filterChip(copy.filterFlights) }
                    NavigationLink { IumrahHotelsStorePage() } label: { filterChip(copy.filterHotels) }
                    NavigationLink { IumrahTransfersStorePage() } label: { filterChip(copy.filterTransfers) }
                    NavigationLink { IumrahServiceStorePage(kind: .ziyarats) } label: { filterChip(copy.filterZiyarats) }
                    Button { chrome.presentESIM() } label: { filterChip("eSIM") }
                }
                .padding(.horizontal, 1)
            }
            .buttonStyle(.plain)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    private func filterChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(Color.iumrahCardBackground, in: Capsule())
    }

    // MARK: - Discover what's new

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: copy.discoverTitle, subtitle: copy.discoverSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    NavigationLink { IumrahConfiguratorStorePage() } label: {
                        IumrahStoreFeatureCard(
                            eyebrow: copy.configuratorEyebrow,
                            title: copy.configuratorTitle,
                            subtitle: copy.configuratorBody,
                            assetName: "StoreConfiguratorLine"
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 14)

                    NavigationLink { IumrahHotelsStorePage() } label: {
                        IumrahStoreMerchandisingCard(
                            eyebrow: copy.hotelsEyebrow,
                            title: copy.hotelsTitle,
                            subtitle: copy.hotelsBody,
                            assetName: "IumrahHotelsShowcaseHero"
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 14)

                    NavigationLink { IumrahServiceStorePage(kind: .flights) } label: {
                        IumrahStoreMerchandisingCard(
                            eyebrow: copy.flightsEyebrow,
                            title: copy.flightsTitle,
                            subtitle: copy.flightsBody,
                            assetName: "IumrahFlightsShowcaseHero"
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 14)

                    NavigationLink { IumrahTransfersStorePage() } label: {
                        IumrahStoreMerchandisingCard(
                            eyebrow: copy.transfersEyebrow,
                            title: copy.transfersTitle,
                            subtitle: copy.transfersBody,
                            assetName: "TransferYukon"
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 14)

                    NavigationLink { IumrahServiceStorePage(kind: .ziyarats) } label: {
                        IumrahStoreMerchandisingCard(
                            eyebrow: copy.ziyaratsEyebrow,
                            title: copy.ziyaratsTitle,
                            subtitle: copy.ziyaratsBody,
                            assetName: "ZiyaratQuba2"
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 14)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .buttonStyle(.plain)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    // MARK: - Difference

    private var differenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: copy.differenceTitle, subtitle: copy.differenceSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    IumrahStoreServiceCard(systemName: "eye.fill", title: copy.diffPriceTitle, subtitle: copy.diffPriceBody, role: .payment)
                    IumrahStoreServiceCard(systemName: "link", title: copy.diffConnectedTitle, subtitle: copy.diffConnectedBody, role: .travel)
                    IumrahStoreServiceCard(systemName: "heart.fill", title: copy.diffCareTitle, subtitle: copy.diffCareBody, role: .care)
                    IumrahStoreServiceCard(systemName: "slider.horizontal.3", title: copy.diffChoiceTitle, subtitle: copy.diffChoiceBody, role: .umrah)
                }
                .padding(.horizontal, 1)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    // MARK: - Get more

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: copy.moreTitle, subtitle: copy.moreSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                        IumrahStoreServiceCard(systemName: "waveform.badge.mic", title: copy.advisorTitle, subtitle: copy.advisorBody, role: .umrah)
                    }
                    NavigationLink { IumrahServiceStorePage(kind: .care) } label: {
                        IumrahStoreServiceCard(systemName: "heart.fill", title: "iumrah Care", subtitle: copy.careBody, role: .care)
                    }
                    Button { chrome.presentESIM() } label: {
                        IumrahStoreServiceCard(systemName: "simcard.fill", title: "iumrah eSIM", subtitle: copy.esimBody, role: .connectivity)
                    }
                    NavigationLink { IumrahServiceStorePage(kind: .ziyarats) } label: {
                        IumrahStoreServiceCard(systemName: "map.fill", title: copy.ziyaratsServiceTitle, subtitle: copy.ziyaratsServiceBody, role: .location)
                    }
                }
                .padding(.horizontal, 1)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .buttonStyle(.plain)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            IumrahStoreSectionHeader(title: copy.faqTitle, subtitle: copy.faqSubtitle)

            VStack(spacing: 1) {
                ForEach(Array(copy.faq.enumerated()), id: \.offset) { index, item in
                    Button {
                        withAnimation(.snappy(duration: 0.28)) {
                            expandedFAQ = expandedFAQ == index ? nil : index
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                Text(item.0)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 10)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(expandedFAQ == index ? 180 : 0))
                            }
                            .padding(.horizontal, 18)
                            .frame(minHeight: 58)

                            if expandedFAQ == index {
                                Text(item.1)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 18)
                                    .padding(.bottom, 17)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.iumrahCardBackground)
                    }
                    .buttonStyle(.plain)

                    if index < copy.faq.count - 1 {
                        Divider().padding(.leading, 18)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
    }

    // MARK: - Help

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            IumrahStoreSectionHeader(title: copy.helpTitle)

            Button {
                chrome.navigate(to: .care)
            } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(copy.helpCardTitle)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(copy.helpCardBody)
                            .font(.system(size: 14.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image("CareMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
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
    }
}

private struct ProductsCopy {
    let pageTitle: String
    let familyConfigurator: String
    let familyFlights: String
    let familyHotels: String
    let familyTransfers: String
    let familyAdvisor: String
    let familyZiyarats: String
    let filtersTitle: String
    let filterPackages: String
    let filterFlights: String
    let filterHotels: String
    let filterTransfers: String
    let filterZiyarats: String
    let discoverTitle: String
    let discoverSubtitle: String
    let configuratorEyebrow: String
    let configuratorTitle: String
    let configuratorBody: String
    let hotelsEyebrow: String
    let hotelsTitle: String
    let hotelsBody: String
    let flightsEyebrow: String
    let flightsTitle: String
    let flightsBody: String
    let transfersEyebrow: String
    let transfersTitle: String
    let transfersBody: String
    let ziyaratsEyebrow: String
    let ziyaratsTitle: String
    let ziyaratsBody: String
    let differenceTitle: String
    let differenceSubtitle: String
    let diffPriceTitle: String
    let diffPriceBody: String
    let diffConnectedTitle: String
    let diffConnectedBody: String
    let diffCareTitle: String
    let diffCareBody: String
    let diffChoiceTitle: String
    let diffChoiceBody: String
    let moreTitle: String
    let moreSubtitle: String
    let advisorTitle: String
    let advisorBody: String
    let careBody: String
    let esimBody: String
    let ziyaratsServiceTitle: String
    let ziyaratsServiceBody: String
    let faqTitle: String
    let faqSubtitle: String
    let faq: [(String, String)]
    let helpTitle: String
    let helpCardTitle: String
    let helpCardBody: String

    static func make(for language: AppSettingsStore.Language) -> ProductsCopy {
        switch language {
        case .russian:
            return ProductsCopy(
                pageTitle: "Продукты",
                familyConfigurator: "Конфигуратор", familyFlights: "Перелёты", familyHotels: "Отели", familyTransfers: "Трансфер", familyAdvisor: "Голосовой гид", familyZiyarats: "Зияраты",
                filtersTitle: "Сервисы", filterPackages: "Пакеты Умры", filterFlights: "Перелёты", filterHotels: "Отели", filterTransfers: "Трансфер", filterZiyarats: "Зияраты",
                discoverTitle: "Откройте новое", discoverSubtitle: "Продукты iumrah, собранные вокруг одной поездки.",
                configuratorEyebrow: "iumrah Конфигуратор", configuratorTitle: "Соберите Умру под себя.", configuratorBody: "Даты, перелёт, отели, трансфер и сервисы — в одной структуре бронирования.",
                hotelsEyebrow: "iumrah Отели", hotelsTitle: "Остановитесь ближе.", hotelsBody: "Подберите проживание в Мекке и Медине по уровню и расположению.",
                flightsEyebrow: "iumrah Перелёты", flightsTitle: "Перелёт в той же поездке.", flightsBody: "Рейс остаётся связан с Вашим бронированием и статусами.",
                transfersEyebrow: "iumrah Трансфер", transfersTitle: "Передвигайтесь спокойно.", transfersBody: "Выберите автомобиль под Ваш формат поездки и количество пассажиров.",
                ziyaratsEyebrow: "iumrah Зияраты", ziyaratsTitle: "Места, которые стоит знать.", ziyaratsBody: "Точки, фотографии и маршруты Мекки и Медины.",
                differenceTitle: "Почему iumrah", differenceSubtitle: "Одна поездка вместо набора разрозненных сервисов.",
                diffPriceTitle: "Прозрачная стоимость", diffPriceBody: "Вы видите стоимость поездки до бронирования.",
                diffConnectedTitle: "Всё связано", diffConnectedBody: "Компоненты остаются частью одной поездки и одного статуса.",
                diffCareTitle: "Care рядом", diffCareBody: "Поддержка сохраняет контекст конкретного бронирования.",
                diffChoiceTitle: "Вы выбираете", diffChoiceBody: "Поездка строится вокруг Ваших дат, уровня и предпочтений.",
                moreTitle: "Получите больше от iumrah", moreSubtitle: "Сервисы, которые становятся полезнее, когда работают вместе.",
                advisorTitle: "Голосовой гид", advisorBody: "Пошаговое голосовое сопровождение во время Умры.",
                careBody: "Поддержка, связанная с Вашей конкретной поездкой.", esimBody: "Связь, которую можно подготовить ещё до прибытия.",
                ziyaratsServiceTitle: "Зияраты", ziyaratsServiceBody: "Маршруты, фотографии и контекст важных мест.",
                faqTitle: "Частые вопросы", faqSubtitle: "Коротко о том, как работает iumrah.",
                faq: [
                    ("Зачем создан iumrah?", "Чтобы самостоятельная Умра ощущалась как одна понятная поездка, а не как набор сервисов, которые нужно связывать вручную."),
                    ("Чем iumrah отличается от обычного тура?", "Вы выбираете параметры поездки сами, а iumrah связывает выбранные компоненты и поддержку вокруг одного бронирования."),
                    ("Как подтверждаются отель и перелёт?", "После бронирования доступность и статусы компонентов проверяются и отображаются внутри Вашей поездки."),
                    ("Почему цена может измениться до подтверждения?", "Тарифы авиакомпаний и отелей динамические. Итоговая стоимость фиксируется после подтверждения соответствующего компонента."),
                    ("Что делает iumrah Care?", "Care помогает по вопросам Вашей поездки и сохраняет контекст конкретного бронирования.")
                ],
                helpTitle: "Нужна помощь с выбором?", helpCardTitle: "Мы поможем Вам начать.", helpCardBody: "Откройте Care, если хотите обсудить формат поездки, отель, перелёт или сервисы."
            )
        case .english:
            return ProductsCopy(
                pageTitle: "Products",
                familyConfigurator: "Configurator", familyFlights: "Flights", familyHotels: "Hotels", familyTransfers: "Transfer", familyAdvisor: "Advisor", familyZiyarats: "Ziyarats",
                filtersTitle: "Services", filterPackages: "Umrah Packages", filterFlights: "Flights", filterHotels: "Hotels", filterTransfers: "Transfer", filterZiyarats: "Ziyarats",
                discoverTitle: "Discover what's new", discoverSubtitle: "iumrah products built around one journey.",
                configuratorEyebrow: "iumrah Configurator", configuratorTitle: "Build Umrah around you.", configuratorBody: "Dates, flights, hotels, transfers and services in one booking structure.",
                hotelsEyebrow: "iumrah Hotels", hotelsTitle: "Stay closer.", hotelsBody: "Choose stays in Makkah and Madinah by level and location.",
                flightsEyebrow: "iumrah Flights", flightsTitle: "Fly as part of one trip.", flightsBody: "Your flight remains connected to the same booking and status flow.",
                transfersEyebrow: "iumrah Transfer", transfersTitle: "Move with ease.", transfersBody: "Choose a vehicle around your journey and group size.",
                ziyaratsEyebrow: "iumrah Ziyarats", ziyaratsTitle: "Places worth knowing.", ziyaratsBody: "Places, photography and routes across Makkah and Madinah.",
                differenceTitle: "The iumrah difference", differenceSubtitle: "One journey instead of disconnected travel services.",
                diffPriceTitle: "Transparent pricing", diffPriceBody: "See the trip price before you book.",
                diffConnectedTitle: "Everything connected", diffConnectedBody: "Components remain part of one journey and one status flow.",
                diffCareTitle: "Care stays with you", diffCareBody: "Support keeps the context of the relevant booking.",
                diffChoiceTitle: "You choose", diffChoiceBody: "The journey is built around your dates, level and preferences.",
                moreTitle: "Get more from iumrah", moreSubtitle: "Services that become more useful when they work together.",
                advisorTitle: "Advisor", advisorBody: "Step-by-step voice guidance during Umrah.",
                careBody: "Support connected to your specific journey.", esimBody: "Connectivity you can prepare before arrival.",
                ziyaratsServiceTitle: "Ziyarats", ziyaratsServiceBody: "Routes, photography and context for important places.",
                faqTitle: "Frequently asked questions", faqSubtitle: "A quick guide to how iumrah works.",
                faq: [
                    ("Why was iumrah created?", "To make independent Umrah feel like one clear journey rather than a set of services you have to coordinate yourself."),
                    ("How is iumrah different from a group tour?", "You choose the journey parameters while iumrah connects the selected components and support around one booking."),
                    ("How are hotels and flights confirmed?", "After booking, availability and component status are verified and shown inside your trip."),
                    ("Why can the price change before confirmation?", "Airline and hotel rates are dynamic. The final amount is fixed after the relevant component is confirmed."),
                    ("What does iumrah Care do?", "Care helps with questions tied to your journey and keeps the context of the relevant booking.")
                ],
                helpTitle: "Still need help deciding?", helpCardTitle: "We'll help get you started.", helpCardBody: "Open Care to talk through your trip format, hotel, flight or services."
            )
        case .uzbek:
            return ProductsCopy(
                pageTitle: "Mahsulotlar",
                familyConfigurator: "Konfigurator", familyFlights: "Parvozlar", familyHotels: "Mehmonxonalar", familyTransfers: "Transfer", familyAdvisor: "Ovozli gid", familyZiyarats: "Ziyoratlar",
                filtersTitle: "Servislar", filterPackages: "Umra paketlari", filterFlights: "Parvozlar", filterHotels: "Mehmonxonalar", filterTransfers: "Transfer", filterZiyarats: "Ziyoratlar",
                discoverTitle: "Yangiliklarni kashf eting", discoverSubtitle: "Bitta safar atrofida qurilgan iumrah mahsulotlari.",
                configuratorEyebrow: "iumrah Konfigurator", configuratorTitle: "Umrani o‘zingizga mos yig‘ing.", configuratorBody: "Sanalar, parvoz, mehmonxona, transfer va servislar bitta bronlash tuzilmasida.",
                hotelsEyebrow: "iumrah Mehmonxonalar", hotelsTitle: "Yaqinroq turing.", hotelsBody: "Makka va Madinadagi yashash variantlarini daraja va joylashuv bo‘yicha tanlang.",
                flightsEyebrow: "iumrah Parvozlar", flightsTitle: "Parvoz bitta safarning qismi.", flightsBody: "Parvozingiz shu bronlash va statuslar bilan bog‘langan qoladi.",
                transfersEyebrow: "iumrah Transfer", transfersTitle: "Xotirjam harakatlaning.", transfersBody: "Safaringiz va yo‘lovchilar soniga mos avtomobil tanlang.",
                ziyaratsEyebrow: "iumrah Ziyoratlar", ziyaratsTitle: "Bilishga arziydigan joylar.", ziyaratsBody: "Makka va Madinadagi joylar, suratlar va yo‘nalishlar.",
                differenceTitle: "iumrah farqi", differenceSubtitle: "Tarqoq servislar o‘rniga bitta safar.",
                diffPriceTitle: "Shaffof narx", diffPriceBody: "Bronlashdan oldin safar narxini ko‘rasiz.",
                diffConnectedTitle: "Hammasi bog‘langan", diffConnectedBody: "Komponentlar bitta safar va bitta status tizimida qoladi.",
                diffCareTitle: "Care yoningizda", diffCareBody: "Yordam tegishli bronlash kontekstini saqlaydi.",
                diffChoiceTitle: "Siz tanlaysiz", diffChoiceBody: "Safar sanalaringiz, daraja va istaklaringiz atrofida tuziladi.",
                moreTitle: "iumrah’dan ko‘proq oling", moreSubtitle: "Birga ishlaganda yanada foydali bo‘ladigan servislar.",
                advisorTitle: "Ovozli gid", advisorBody: "Umra davomida bosqichma-bosqich ovozli yo‘l-yo‘riq.",
                careBody: "Aynan Sizning safaringizga bog‘langan yordam.", esimBody: "Yetib kelishdan oldin tayyorlash mumkin bo‘lgan aloqa.",
                ziyaratsServiceTitle: "Ziyoratlar", ziyaratsServiceBody: "Muhim joylar uchun yo‘nalish, surat va izohlar.",
                faqTitle: "Ko‘p so‘raladigan savollar", faqSubtitle: "iumrah qanday ishlashi haqida qisqacha.",
                faq: [
                    ("iumrah nima uchun yaratilgan?", "Mustaqil Umrani alohida servislar to‘plami emas, bitta tushunarli safar sifatida tashkil qilish uchun."),
                    ("iumrah oddiy turdan nimasi bilan farq qiladi?", "Safar parametrlarini o‘zingiz tanlaysiz, iumrah esa komponentlar va yordamni bitta bronlashga bog‘laydi."),
                    ("Mehmonxona va parvoz qanday tasdiqlanadi?", "Bronlashdan keyin mavjudlik va statuslar tekshiriladi va safaringiz ichida ko‘rsatiladi."),
                    ("Tasdiqlashdan oldin narx nega o‘zgarishi mumkin?", "Aviakompaniya va mehmonxona tariflari dinamik. Yakuniy narx tegishli komponent tasdiqlangach belgilanadi."),
                    ("iumrah Care nima qiladi?", "Care safaringizga oid savollarda yordam beradi va tegishli bronlash kontekstini saqlaydi.")
                ],
                helpTitle: "Tanlashda yordam kerakmi?", helpCardTitle: "Boshlashingizga yordam beramiz.", helpCardBody: "Safar formati, mehmonxona, parvoz yoki servislarni muhokama qilish uchun Care’ni oching."
            )
        case .uzbekCyrillic:
            return ProductsCopy(
                pageTitle: "Маҳсулотлар",
                familyConfigurator: "Конфигуратор", familyFlights: "Парвозлар", familyHotels: "Меҳмонхоналар", familyTransfers: "Трансфер", familyAdvisor: "Овозли гид", familyZiyarats: "Зиёратлар",
                filtersTitle: "Сервислар", filterPackages: "Умра пакетлари", filterFlights: "Парвозлар", filterHotels: "Меҳмонхоналар", filterTransfers: "Трансфер", filterZiyarats: "Зиёратлар",
                discoverTitle: "Янгиликларни кашф этинг", discoverSubtitle: "Битта сафар атрофида қурилган iumrah маҳсулотлари.",
                configuratorEyebrow: "iumrah Конфигуратор", configuratorTitle: "Умрани ўзингизга мос йиғинг.", configuratorBody: "Саналар, парвоз, меҳмонхона, трансфер ва сервислар битта бронлаш тузилмасида.",
                hotelsEyebrow: "iumrah Меҳмонхоналар", hotelsTitle: "Яқинроқ туринг.", hotelsBody: "Макка ва Мадинадаги яшаш вариантларини даража ва жойлашув бўйича танланг.",
                flightsEyebrow: "iumrah Парвозлар", flightsTitle: "Парвоз битта сафарнинг қисми.", flightsBody: "Парвозингиз шу бронлаш ва статуслар билан боғланган қолади.",
                transfersEyebrow: "iumrah Трансфер", transfersTitle: "Хотиржам ҳаракатланинг.", transfersBody: "Сафарингиз ва йўловчилар сонига мос автомобиль танланг.",
                ziyaratsEyebrow: "iumrah Зиёратлар", ziyaratsTitle: "Билишга арзийдиган жойлар.", ziyaratsBody: "Макка ва Мадинадаги жойлар, суратлар ва йўналишлар.",
                differenceTitle: "iumrah фарқи", differenceSubtitle: "Тарқоқ сервислар ўрнига битта сафар.",
                diffPriceTitle: "Шаффоф нарх", diffPriceBody: "Бронлашдан олдин сафар нархини кўрасиз.",
                diffConnectedTitle: "Ҳаммаси боғланган", diffConnectedBody: "Компонентлар битта сафар ва битта статус тизимида қолади.",
                diffCareTitle: "Care ёнингизда", diffCareBody: "Ёрдам тегишли бронлаш контекстини сақлайди.",
                diffChoiceTitle: "Сиз танлайсиз", diffChoiceBody: "Сафар саналарингиз, даража ва истакларингиз атрофида тузилади.",
                moreTitle: "iumrah’дан кўпроқ олинг", moreSubtitle: "Бирга ишлаганда янада фойдали бўладиган сервислар.",
                advisorTitle: "Овозли гид", advisorBody: "Умра давомида босқичма-босқич овозли йўл-йўриқ.",
                careBody: "Айнан Сизнинг сафарингизга боғланган ёрдам.", esimBody: "Етиб келишдан олдин тайёрлаш мумкин бўлган алоқа.",
                ziyaratsServiceTitle: "Зиёратлар", ziyaratsServiceBody: "Муҳим жойлар учун йўналиш, сурат ва изоҳлар.",
                faqTitle: "Кўп сўраладиган саволлар", faqSubtitle: "iumrah қандай ишлаши ҳақида қисқача.",
                faq: [
                    ("iumrah нима учун яратилган?", "Мустақил Умрани алоҳида сервислар тўплами эмас, битта тушунарли сафар сифатида ташкил қилиш учун."),
                    ("iumrah оддий турдан нимаси билан фарқ қилади?", "Сафар параметрларини ўзингиз танлайсиз, iumrah эса компонентлар ва ёрдамни битта бронлашга боғлайди."),
                    ("Меҳмонхона ва парвоз қандай тасдиқланади?", "Бронлашдан кейин мавжудлик ва статуслар текширилади ва сафарингиз ичида кўрсатилади."),
                    ("Тасдиқлашдан олдин нарх нега ўзгариши мумкин?", "Авиакомпания ва меҳмонхона тарифлари динамик. Якуний нарх тегишли компонент тасдиқлангач белгиланади."),
                    ("iumrah Care нима қилади?", "Care сафарингизга оид саволларда ёрдам беради ва тегишли бронлаш контекстини сақлайди.")
                ],
                helpTitle: "Танлашда ёрдам керакми?", helpCardTitle: "Бошлашингизга ёрдам берамиз.", helpCardBody: "Сафар формати, меҳмонхона, парвоз ёки сервисларни муҳокама қилиш учун Care’ни очинг."
            )
        }
    }
}
