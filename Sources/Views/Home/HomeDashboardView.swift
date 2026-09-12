import SwiftUI

/// Product discovery surface. The structure intentionally follows the Apple Store
/// merchandising rhythm (categories -> hero -> latest -> collections -> value -> help)
/// while keeping every iumrah data/service flow unchanged.
struct HomeDashboardView: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var account: IumrahAccountStore
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared

    @State private var expandedFAQ: Int?

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 32) {
                IumrahStorePageHeader(title: productsTitle, subtitle: copy.pageSubtitle)

                if !clientNotifications.homeNotifications.isEmpty {
                    SystemNotificationsCarouselView(
                        notifications: Array(clientNotifications.homeNotifications.prefix(3)),
                        onOpen: { openSystemNotification($0) },
                        onDismiss: { dismissSystemNotification($0) }
                    )
                }

                productCategories
                configuratorHero
                latestSection
                exploreByNeed
                differenceSection
                faqSection
                humanHelpCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 38)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .task { await bookings.refreshAll() }
    }

    // MARK: - Categories

    private var productCategories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                NavigationLink { IumrahConfiguratorStorePage() } label: {
                    IumrahStoreCategoryTile(systemName: "moon.stars.fill", title: umrahCategoryTitle, role: .umrah)
                }
                NavigationLink { IumrahServiceStorePage(kind: .flights) } label: {
                    IumrahStoreCategoryTile(systemName: "airplane", title: copy.flights, role: .travel)
                }
                NavigationLink { IumrahHotelsStorePage() } label: {
                    IumrahStoreCategoryTile(systemName: "building.2.fill", title: copy.hotels, role: .hotel)
                }
                NavigationLink { IumrahTransfersStorePage() } label: {
                    IumrahStoreCategoryTile(systemName: "car.fill", title: copy.transfer, role: .transfer)
                }
                NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                    IumrahStoreCategoryTile(systemName: "waveform.badge.mic", title: advisorCategoryTitle, role: .umrah)
                }
                NavigationLink { IumrahServiceStorePage(kind: .ziyarats) } label: {
                    IumrahStoreCategoryTile(systemName: "map.fill", title: ziyaratsCategoryTitle, role: .location)
                }
                NavigationLink { IumrahServiceStorePage(kind: .esim) } label: {
                    IumrahStoreCategoryTile(systemName: "simcard.fill", title: esimCategoryTitle, role: .connectivity)
                }
                NavigationLink { IumrahServiceStorePage(kind: .care) } label: {
                    IumrahStoreCategoryTile(systemName: "heart.fill", title: careCategoryTitle, role: .care)
                }
            }
            .padding(.horizontal, 1)
        }
        .buttonStyle(.plain)
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    // MARK: - Main hero

    private var configuratorHero: some View {
        NavigationLink {
            IumrahConfiguratorStorePage()
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.black)

                Image("StoreConfiguratorLine")
                    .resizable()
                    .scaledToFill()
                    .colorInvert()
                    .opacity(0.74)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .offset(y: -24)

                LinearGradient(
                    colors: [Color.black.opacity(0.02), Color.black.opacity(0.24), Color.black.opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 9) {
                    Text(configuratorLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.75)
                        .foregroundStyle(.white.opacity(0.60))

                    Text(copy.heroTitle)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(-0.95)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(copy.heroSubtitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        Text(copy.heroCTA)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 17)
                    .frame(height: 48)
                    .background(.white, in: Capsule())
                    .padding(.top, 6)
                }
                .padding(23)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 510)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.16), radius: 28, y: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Latest

    private var latestSection: some View {
        VStack(spacing: 17) {
            IumrahStoreSectionHeader(title: copy.latestTitle, subtitle: copy.latestSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                        IumrahStoreEditorialCard(
                            eyebrow: advisorBrandLabel,
                            title: copy.advisorTitle,
                            subtitle: copy.advisorSubtitle,
                            systemName: "waveform.badge.mic",
                            dark: true,
                            accent: .purple
                        )
                    }

                    NavigationLink { IumrahHotelsStorePage() } label: {
                        IumrahStoreEditorialCard(
                            eyebrow: hotelsBrandLabel,
                            title: copy.hotelTitle,
                            subtitle: copy.hotelSubtitle,
                            asset: "IumrahHotelsShowcaseHero"
                        )
                    }

                    NavigationLink { IumrahServiceStorePage(kind: .ziyarats) } label: {
                        IumrahStoreEditorialCard(
                            eyebrow: ziyaratsBrandLabel,
                            title: copy.ziyaratsTitle,
                            subtitle: copy.ziyaratsSubtitle,
                            asset: "ZiyaratQuba2"
                        )
                    }

                    NavigationLink { IumrahServiceStorePage(kind: .flights) } label: {
                        IumrahStoreEditorialCard(
                            eyebrow: flightsBrandLabel,
                            title: copy.flightTitle,
                            subtitle: copy.flightSubtitle,
                            asset: "IumrahFlightsShowcaseHero",
                            dark: true
                        )
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

    // MARK: - Collections

    private var exploreByNeed: some View {
        VStack(spacing: 17) {
            IumrahStoreSectionHeader(title: copy.exploreTitle, subtitle: copy.exploreSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    NavigationLink { IumrahConfiguratorStorePage() } label: { collectionChip("sparkles", copy.firstUmrah) }
                    NavigationLink { IumrahConfiguratorStorePage() } label: { collectionChip("person.3.fill", copy.family) }
                    NavigationLink { IumrahHotelsStorePage() } label: { collectionChip("location.fill", copy.nearHaram) }
                    NavigationLink { IumrahTransfersStorePage() } label: { collectionChip("car.fill", copy.privateTransfer) }
                    NavigationLink { IumrahConfiguratorStorePage() } label: { collectionChip("diamond.fill", copy.luxury) }
                }
                .padding(.horizontal, 1)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .buttonStyle(.plain)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    private func collectionChip(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Color.iumrahCardBackground, in: Capsule())
        .overlay { Capsule().strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7) }
    }

    // MARK: - Difference

    private var differenceSection: some View {
        VStack(spacing: 17) {
            IumrahStoreSectionHeader(title: copy.differenceTitle, subtitle: copy.differenceSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    differenceCard(icon: "dollarsign.circle.fill", role: .payment, title: copy.transparentTitle, body: copy.transparentBody)
                    differenceCard(icon: "link.circle.fill", role: .travel, title: copy.connectedTitle, body: copy.connectedBody)
                    differenceCard(icon: "heart.circle.fill", role: .care, title: copy.careTitle, body: copy.careBody)
                    differenceCard(icon: "slider.horizontal.3", role: .settings, title: copy.choiceTitle, body: copy.choiceBody)
                }
                .padding(.horizontal, 1)
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    private func differenceCard(icon: String, role: IumrahIconRole, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahIconBadge(systemName: icon, role: role, size: 48, symbolSize: 20, cornerRadius: 16)
            Spacer(minLength: 2)
            Text(title)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .tracking(-0.3)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 255, height: 225, alignment: .leading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(spacing: 17) {
            IumrahStoreSectionHeader(title: copy.faqTitle, subtitle: copy.faqSubtitle)

            VStack(spacing: 0) {
                ForEach(Array(copy.faq.enumerated()), id: \.offset) { index, item in
                    Button {
                        withAnimation(.snappy(duration: 0.28)) {
                            expandedFAQ = expandedFAQ == index ? nil : index
                        }
                        IumrahHaptics.selection()
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
                            .padding(.vertical, 17)

                            if expandedFAQ == index {
                                Text(item.1)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.bottom, 18)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            if index != copy.faq.count - 1 {
                                Divider()
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
    }

    // MARK: - Human help

    private var humanHelpCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(copy.helpTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .tracking(-0.45)
                    Text(copy.helpBody)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
            }

            Button {
                chrome.navigate(to: .care)
            } label: {
                HStack {
                    Text(copy.helpCTA)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
        .padding(21)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    // MARK: - Notifications

    private func dismissSystemNotification(_ notification: ClientSystemNotification) {
        IumrahHaptics.selection()
        clientNotifications.dismissFromHome(notification)
    }

    private func openSystemNotification(_ notification: ClientSystemNotification) {
        IumrahHaptics.selection()
        Task { await clientNotifications.markOpened(notification, accountToken: account.bearerToken) }
        switch notification.destination {
        case "hotels": chrome.navigate(to: .hotels)
        case "bookings": chrome.navigate(to: .booking)
        case "care": chrome.navigate(to: .care)
        case "account": chrome.navigate(to: .account)
        case "booking":
            if let bookingID = notification.destinationBookingID, bookings.booking(id: bookingID) != nil {
                chrome.openBooking(id: bookingID)
            } else {
                chrome.navigate(to: .booking)
            }
        default: chrome.navigate(to: .home)
        }
    }

    private var productsTitle: String { localized("Продукты", "Products", "Mahsulotlar", "Маҳсулотлар") }
    private var umrahCategoryTitle: String { localized("Умра", "Umrah", "Umra", "Умра") }
    private var advisorCategoryTitle: String { localized("Гид", "Advisor", "Yo‘l-yo‘riq", "Йўл-йўриқ") }
    private var ziyaratsCategoryTitle: String { localized("Зияраты", "Ziyarats", "Ziyoratlar", "Зиёратлар") }
    private var esimCategoryTitle: String { localized("eSIM", "eSIM", "eSIM", "eSIM") }
    private var careCategoryTitle: String { localized("Поддержка", "Care", "Yordam", "Ёрдам") }
    private var configuratorLabel: String { localized("iumrah Конфигуратор", "iumrah Configurator", "iumrah Konfigurator", "iumrah Конфигуратор") }
    private var advisorBrandLabel: String { localized("iumrah Голосовой гид", "iumrah Advisor", "iumrah Ovozli yo‘l-yo‘riq", "iumrah Овозли йўл-йўриқ") }
    private var hotelsBrandLabel: String { localized("iumrah Отели", "iumrah Hotels", "iumrah Mehmonxonalar", "iumrah Меҳмонхоналар") }
    private var ziyaratsBrandLabel: String { localized("iumrah Зияраты", "iumrah Ziyarats", "iumrah Ziyoratlar", "iumrah Зиёратлар") }
    private var flightsBrandLabel: String { localized("iumrah Перелёты", "iumrah Flights", "iumrah Parvozlar", "iumrah Парвозлар") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    // MARK: - Localized storefront copy

    private var copy: StoreCopy {
        switch settings.language {
        case .russian:
            return StoreCopy(
                pageSubtitle: "Всё для Вашей Умры — от идеи до возвращения.", flights: "Перелёт", hotels: "Отели", transfer: "Трансфер",
                heroTitle: "Ваша Умра. Собрана вокруг Вас.", heroSubtitle: "Перелёт, отели, трансфер, сопровождение и поддержка — в одном бронировании.", heroCTA: "Собрать мою Умру",
                latestTitle: "Откройте больше", latestSubtitle: "Продукты iumrah, которые работают вместе.",
                advisorTitle: "Умра с голосовым сопровождением.", advisorSubtitle: "Пошаговое голосовое сопровождение в нужный момент.",
                hotelTitle: "Остановитесь ближе.", hotelSubtitle: "Подборка отелей Мекки и Медины.",
                ziyaratsTitle: "Откройте Медину и Мекку.", ziyaratsSubtitle: "Точные точки, фотографии и маршруты.",
                flightTitle: "Перелёт как часть одной поездки.", flightSubtitle: "Перелёт остаётся связан с Вашим бронированием.",
                exploreTitle: "Выберите по потребности", exploreSubtitle: "Начните не с компонентов, а с того, какая поездка нужна Вам.",
                firstUmrah: "Первая Умра", family: "С семьёй", nearHaram: "Рядом с Харамом", privateTransfer: "Индивидуальный трансфер", luxury: "Люкс",
                differenceTitle: "Преимущество iumrah", differenceSubtitle: "Одна система вместо набора разрозненных сервисов.",
                transparentTitle: "Прозрачная стоимость", transparentBody: "Стоимость поездки показывается до бронирования, без необходимости запрашивать цену.",
                connectedTitle: "Всё связано", connectedBody: "Перелёт, отель, трансфер и сервисы остаются частью одной поездки.",
                careTitle: "Поддержка рядом", careBody: "Поддержка iumrah связана с конкретным бронированием до, во время и после Умры.",
                choiceTitle: "Вы выбираете", choiceBody: "Не большая группа, а поездка, которую Вы собираете под себя.",
                faqTitle: "Частые вопросы", faqSubtitle: "Главное, что стоит знать перед бронированием.",
                faq: [
                    ("Зачем создан iumrah?", "Чтобы самостоятельную Умру можно было собрать и вести как одну понятную поездку — без необходимости координировать каждый сервис отдельно."),
                    ("Чем iumrah отличается от обычного тура?", "Вы выбираете параметры своей поездки сами, а iumrah связывает выбранные компоненты и поддержку вокруг одного бронирования."),
                    ("Как подтверждаются отель и перелёт?", "После бронирования доступность и статусы компонентов проходят проверку и отображаются внутри Вашей поездки."),
                    ("Почему цена может измениться до подтверждения?", "Тарифы авиакомпаний и отелей динамические. Финальная стоимость фиксируется после подтверждения доступности соответствующего компонента."),
                    ("Что делает поддержка iumrah?", "Поддержка помогает по вопросам, связанным с Вашей поездкой, и сохраняет контекст конкретного бронирования.")
                ],
                helpTitle: "Нужна помощь с выбором?", helpBody: "Поддержка iumrah поможет разобраться с форматом поездки, отелем, перелётом и сервисами.", helpCTA: "Получить помощь"
            )
        case .english:
            return StoreCopy(
                pageSubtitle: "Everything for your Umrah, from planning to return.", flights: "Flights", hotels: "Hotels", transfer: "Transfer",
                heroTitle: "Your Umrah. Built around you.", heroSubtitle: "Flights, hotels, transfers, guidance and Care in one booking.", heroCTA: "Build my Umrah",
                latestTitle: "Discover more", latestSubtitle: "iumrah products designed to work together.",
                advisorTitle: "Umrah, guided by voice.", advisorSubtitle: "Step-by-step guidance when you need it.",
                hotelTitle: "Stay closer.", hotelSubtitle: "Curated stays in Makkah and Madinah.",
                ziyaratsTitle: "Explore Makkah and Madinah.", ziyaratsSubtitle: "Places, photography and routes.",
                flightTitle: "Fly as part of one trip.", flightSubtitle: "Your flight stays connected to your booking.",
                exploreTitle: "Explore by need", exploreSubtitle: "Start with the journey you want, not a list of components.",
                firstUmrah: "First Umrah", family: "With family", nearHaram: "Near Haram", privateTransfer: "Private transfer", luxury: "Luxury",
                differenceTitle: "The iumrah difference", differenceSubtitle: "One system instead of disconnected travel services.",
                transparentTitle: "Transparent pricing", transparentBody: "See your trip price before booking without having to request a quote.",
                connectedTitle: "Everything connected", connectedBody: "Flights, stays, transfers and services remain part of one journey.",
                careTitle: "Care stays with you", careBody: "Support stays linked to the booking before, during and after Umrah.",
                choiceTitle: "You choose", choiceBody: "Not a large group tour — a journey built around your preferences.",
                faqTitle: "Frequently asked questions", faqSubtitle: "What to know before you book.",
                faq: [
                    ("Why was iumrah created?", "To make independent Umrah feel like one clear journey instead of a set of services you have to coordinate yourself."),
                    ("How is iumrah different from a group tour?", "You choose the parameters of your journey while iumrah connects the selected components and support around one booking."),
                    ("How are hotels and flights confirmed?", "Availability and component statuses are verified after booking and remain visible inside your trip."),
                    ("Why can the price change before confirmation?", "Airline and hotel rates are dynamic. The final amount is fixed once the relevant availability is confirmed."),
                    ("What does iumrah Care do?", "Care helps with questions tied to your trip while keeping the context of the relevant booking.")
                ],
                helpTitle: "Need help deciding?", helpBody: "iumrah Care can help with your trip format, hotel, flight and services.", helpCTA: "Get help"
            )
        case .uzbek:
            return StoreCopy(
                pageSubtitle: "Umrangiz uchun hammasi — rejalashtirishdan qaytishgacha.", flights: "Parvoz", hotels: "Mehmonxonalar", transfer: "Transfer",
                heroTitle: "Umrangiz. Sizga mos yaratilgan.", heroSubtitle: "Parvoz, mehmonxona, transfer, yo‘l-yo‘riq va yordam — bitta bronlashda.", heroCTA: "Umramni yaratish",
                latestTitle: "Ko‘proq kashf eting", latestSubtitle: "Birgalikda ishlaydigan iumrah mahsulotlari.", advisorTitle: "Ovozli yo‘l-yo‘riq bilan Umra.", advisorSubtitle: "Kerakli paytda bosqichma-bosqich yordam.", hotelTitle: "Yaqinroq turing.", hotelSubtitle: "Makka va Madinadagi saralangan mehmonxonalar.", ziyaratsTitle: "Makka va Madinani kashf eting.", ziyaratsSubtitle: "Joylar, suratlar va yo‘nalishlar.", flightTitle: "Bitta safarning bir qismi sifatida uching.", flightSubtitle: "Parvozingiz bronlash bilan bog‘langan qoladi.", exploreTitle: "Ehtiyoj bo‘yicha tanlang", exploreSubtitle: "Komponentlardan emas, kerakli safardan boshlang.", firstUmrah: "Birinchi Umra", family: "Oila bilan", nearHaram: "Haram yaqinida", privateTransfer: "Shaxsiy transfer", luxury: "Hashamat", differenceTitle: "iumrah farqi", differenceSubtitle: "Alohida servislar o‘rniga bitta tizim.", transparentTitle: "Shaffof narx", transparentBody: "Bronlashdan oldin safar narxini ko‘ring.", connectedTitle: "Hammasi bog‘langan", connectedBody: "Parvoz, mehmonxona, transfer va servislar bitta safarda qoladi.", careTitle: "Yordam yoningizda", careBody: "iumrah yordami Umradan oldin, davomida va keyin bronlash bilan bog‘langan.", choiceTitle: "Siz tanlaysiz", choiceBody: "Katta guruh emas — sizga mos safar.", faqTitle: "Ko‘p so‘raladigan savollar", faqSubtitle: "Bronlashdan oldin bilish kerak bo‘lgan asosiy narsalar.", faq: [("iumrah nima uchun yaratilgan?", "Mustaqil Umrani alohida servislar to‘plami emas, bitta tushunarli safar sifatida tashkil qilish uchun."), ("iumrah oddiy turdan nimasi bilan farq qiladi?", "Safar parametrlarini o‘zingiz tanlaysiz, iumrah esa komponentlar va yordamni bitta bronlashga bog‘laydi."), ("Mehmonxona va parvoz qanday tasdiqlanadi?", "Bronlashdan keyin mavjudlik va statuslar tekshiriladi va safaringiz ichida ko‘rsatiladi."), ("Tasdiqlashdan oldin narx nega o‘zgarishi mumkin?", "Aviakompaniya va mehmonxona tariflari dinamik. Yakuniy narx mavjudlik tasdiqlangach belgilanadi."), ("iumrah yordami nima qiladi?", "Yordam safaringizga oid savollarda ko‘mak beradi va tegishli bronlash kontekstini saqlaydi.")], helpTitle: "Tanlashda yordam kerakmi?", helpBody: "iumrah yordami safar formati, mehmonxona, parvoz va servislarni tanlashga yordam beradi.", helpCTA: "Yordam olish"
            )
        case .uzbekCyrillic:
            return StoreCopy(
                pageSubtitle: "Умрангиз учун ҳаммаси — режалаштиришдан қайтишгача.", flights: "Парвоз", hotels: "Меҳмонхоналар", transfer: "Трансфер",
                heroTitle: "Умрангиз. Сизга мос яратилган.", heroSubtitle: "Парвоз, меҳмонхона, трансфер, йўл-йўриқ ва ёрдам — битта бронлашда.", heroCTA: "Умрамни яратиш",
                latestTitle: "Кўпроқ кашф этинг", latestSubtitle: "Биргаликда ишлайдиган iumrah маҳсулотлари.", advisorTitle: "Овозли йўл-йўриқ билан Умра.", advisorSubtitle: "Керакли пайтда босқичма-босқич ёрдам.", hotelTitle: "Яқинроқ туринг.", hotelSubtitle: "Макка ва Мадинадаги сараланган меҳмонхоналар.", ziyaratsTitle: "Макка ва Мадинани кашф этинг.", ziyaratsSubtitle: "Жойлар, суратлар ва йўналишлар.", flightTitle: "Битта сафарнинг бир қисми сифатида учинг.", flightSubtitle: "Парвозингиз бронлаш билан боғланган қолади.", exploreTitle: "Эҳтиёж бўйича танланг", exploreSubtitle: "Компонентлардан эмас, керакли сафардан бошланг.", firstUmrah: "Биринчи Умра", family: "Оила билан", nearHaram: "Ҳарам яқинида", privateTransfer: "Шахсий трансфер", luxury: "Ҳашамат", differenceTitle: "iumrah фарқи", differenceSubtitle: "Алоҳида сервислар ўрнига битта тизим.", transparentTitle: "Шаффоф нарх", transparentBody: "Бронлашдан олдин сафар нархини кўринг.", connectedTitle: "Ҳаммаси боғланган", connectedBody: "Парвоз, меҳмонхона, трансфер ва сервислар битта сафарда қолади.", careTitle: "Ёрдам ёнингизда", careBody: "iumrah ёрдами Умрадан олдин, давомида ва кейин бронлаш билан боғланган.", choiceTitle: "Сиз танлайсиз", choiceBody: "Катта гуруҳ эмас — сизга мос сафар.", faqTitle: "Кўп сўраладиган саволлар", faqSubtitle: "Бронлашдан олдин билиш керак бўлган асосий нарсалар.", faq: [("iumrah нима учун яратилган?", "Мустақил Умрани алоҳида сервислар тўплами эмас, битта тушунарли сафар сифатида ташкил қилиш учун."), ("iumrah оддий турдан нимаси билан фарқ қилади?", "Сафар параметрларини ўзингиз танлайсиз, iumrah эса компонентлар ва ёрдамни битта бронлашга боғлайди."), ("Меҳмонхона ва парвоз қандай тасдиқланади?", "Бронлашдан кейин мавжудлик ва статуслар текширилади ва сафарингиз ичида кўрсатилади."), ("Тасдиқлашдан олдин нарх нега ўзгариши мумкин?", "Авиакомпания ва меҳмонхона тарифлари динамик. Якуний нарх мавжудлик тасдиқлангач белгиланади."), ("iumrah ёрдами нима қилади?", "Ёрдам сафарингизга оид саволларда кўмак беради ва тегишли бронлаш контекстини сақлайди.")], helpTitle: "Танлашда ёрдам керакми?", helpBody: "iumrah ёрдами сафар формати, меҳмонхона, парвоз ва сервисларни танлашга ёрдам беради.", helpCTA: "Ёрдам олиш"
            )
        }
    }
}

private struct StoreCopy {
    let pageSubtitle: String
    let flights: String
    let hotels: String
    let transfer: String
    let heroTitle: String
    let heroSubtitle: String
    let heroCTA: String
    let latestTitle: String
    let latestSubtitle: String
    let advisorTitle: String
    let advisorSubtitle: String
    let hotelTitle: String
    let hotelSubtitle: String
    let ziyaratsTitle: String
    let ziyaratsSubtitle: String
    let flightTitle: String
    let flightSubtitle: String
    let exploreTitle: String
    let exploreSubtitle: String
    let firstUmrah: String
    let family: String
    let nearHaram: String
    let privateTransfer: String
    let luxury: String
    let differenceTitle: String
    let differenceSubtitle: String
    let transparentTitle: String
    let transparentBody: String
    let connectedTitle: String
    let connectedBody: String
    let careTitle: String
    let careBody: String
    let choiceTitle: String
    let choiceBody: String
    let faqTitle: String
    let faqSubtitle: String
    let faq: [(String, String)]
    let helpTitle: String
    let helpBody: String
    let helpCTA: String
}
