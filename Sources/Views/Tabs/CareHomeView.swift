import SwiftUI

/// Gear is the service/preparation surface. It reuses the existing Care, Advisor,
/// eSIM and Ziyarat flows without changing their data or backend architecture.
struct CareHomeView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore

    @State private var showZiyarats = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 30) {
                IumrahStorePageHeader(title: copy.pageTitle, subtitle: copy.pageSubtitle)

                gettingStartedCard
                getMoreSection
                didYouKnowCard
                suggestedSection
                careSection
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .task { await bookings.refreshAll() }
        .fullScreenCover(isPresented: $showZiyarats) {
            ZiyaratJourneyView()
                .environmentObject(settings)
                .environmentObject(chrome)
        }
    }

    // MARK: - Get started

    private var gettingStartedCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 0) {
                gearGlyph("iphone", role: .device)
                connector
                gearGlyph("doc.text.fill", role: .document)
                connector
                gearGlyph("suitcase.fill", role: .booking)
                connector
                gearGlyph("moon.stars.fill", role: .umrah)
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(copy.startTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                Text(copy.startBody)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                chrome.navigate(to: .booking)
            } label: {
                HStack(spacing: 8) {
                    Text(copy.startCTA)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private func gearGlyph(_ icon: String, role: IumrahIconRole) -> some View {
        IumrahIconBadge(systemName: icon, role: role, size: 48, symbolSize: 19, cornerRadius: 16)
    }

    private var connector: some View {
        Capsule()
            .fill(Color.primary.opacity(0.12))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
            .padding(.horizontal, 7)
    }

    // MARK: - Get more

    private var getMoreSection: some View {
        VStack(spacing: 17) {
            IumrahStoreSectionHeader(title: copy.moreTitle, subtitle: copy.moreSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                        IumrahStoreEditorialCard(
                            eyebrow: advisorBrandTitle,
                            title: copy.advisorTitle,
                            subtitle: copy.advisorBody,
                            systemName: "waveform.badge.mic",
                            dark: true,
                            accent: .purple
                        )
                    }

                    Button {
                        showZiyarats = true
                    } label: {
                        IumrahStoreEditorialCard(
                            eyebrow: ziyaratsBrandTitle,
                            title: copy.ziyaratsTitle,
                            subtitle: copy.ziyaratsBody,
                            asset: "ZiyaratQuba2"
                        )
                    }

                    Button {
                        chrome.presentESIM()
                    } label: {
                        IumrahStoreEditorialCard(
                            eyebrow: "iumrah eSIM",
                            title: copy.esimTitle,
                            subtitle: copy.esimBody,
                            systemName: "simcard.fill",
                            accent: .cyan
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

    // MARK: - Did you know

    private var didYouKnowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.didYouKnowEyebrow.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.secondary)

            Text(copy.didYouKnowTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.55)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.didYouKnowBody)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                Text(copy.didYouKnowCTA)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color.iumrahCardBackground, Color(uiColor: .systemIndigo).opacity(0.075)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    // MARK: - Suggestions

    private var suggestedSection: some View {
        VStack(spacing: 17) {
            IumrahStoreSectionHeader(title: copy.suggestedTitle, subtitle: copy.suggestedSubtitle)

            VStack(spacing: 10) {
                Button { chrome.presentESIM() } label: {
                    IumrahStoreCompactRow(systemName: "simcard.fill", title: "iumrah eSIM", subtitle: copy.esimRow, role: .connectivity)
                }

                NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                    IumrahStoreCompactRow(systemName: "waveform.badge.mic", title: advisorBrandTitle, subtitle: copy.advisorRow, role: .umrah)
                }

                Button { showZiyarats = true } label: {
                    IumrahStoreCompactRow(systemName: "map.fill", title: ziyaratsBrandTitle, subtitle: copy.ziyaratsRow, role: .location)
                }

                Button { chrome.navigate(to: .booking) } label: {
                    IumrahStoreCompactRow(systemName: "doc.text.fill", title: copy.documentsTitle, subtitle: copy.documentsBody, role: .document)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Care

    private var careSection: some View {
        VStack(spacing: 17) {
            IumrahStoreSectionHeader(title: careBrandTitle, subtitle: copy.careSubtitle)

            if bookings.sessions.isEmpty {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image("CareMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                        Spacer()
                        Label("24/7", systemImage: "message.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(copy.careLockedTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(copy.careLockedBody)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button(copy.careLockedCTA) {
                        chrome.navigate(to: .booking)
                    }
                    .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(21)
                .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(bookings.sessions) { session in
                        NavigationLink {
                            BookingChatView(bookingID: session.id)
                        } label: {
                            careChatRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func careChatRow(_ session: StoredBookingSession) -> some View {
        HStack(spacing: 14) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(careBrandTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination) · \(session.displayBookingNumber)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    private var advisorBrandTitle: String { localized("iumrah Голосовой гид", "iumrah Advisor", "iumrah Ovozli yo‘l-yo‘riq", "iumrah Овозли йўл-йўриқ") }
    private var ziyaratsBrandTitle: String { localized("iumrah Зияраты", "iumrah Ziyarats", "iumrah Ziyoratlar", "iumrah Зиёратлар") }
    private var careBrandTitle: String { localized("iumrah Поддержка", "iumrah Care", "iumrah Yordam", "iumrah Ёрдам") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var copy: GearCopy {
        switch settings.language {
        case .russian:
            return GearCopy(
                pageTitle: "Подготовка", pageSubtitle: "Поможем начать и подготовить всё к поездке.",
                startTitle: "Подготовим всё до поездки.", startBody: "Документы, связь, полезные сервисы и поддержка — соберите всё, что понадобится перед вылетом.", startCTA: "Открыть мою поездку",
                moreTitle: "Получите больше от поездки", moreSubtitle: "Сервисы, которые становятся полезнее, когда работают вместе.",
                advisorTitle: "Пройдите Умру с голосовым помощником.", advisorBody: "Голосовые подсказки во время самой Умры.", ziyaratsTitle: "Откройте места рядом.", ziyaratsBody: "Зияраты Мекки и Медины в одном маршруте.", esimTitle: "Будьте на связи.", esimBody: "Подготовьте eSIM до прибытия.",
                didYouKnowEyebrow: "Знаете ли Вы", didYouKnowTitle: "Поддержка iumrah остаётся связана с той же поездкой.", didYouKnowBody: "Вместо нового объяснения ситуации каждый раз поддержка работает в контексте конкретного бронирования.", didYouKnowCTA: "Подробнее о поддержке",
                suggestedTitle: "Рекомендуем для поездки", suggestedSubtitle: "Быстрый доступ к тому, что пригодится до и во время Умры.",
                esimRow: "Мобильный интернет внутри Вашего пакета Умры.", advisorRow: "Голосовой гид по этапам Умры.", ziyaratsRow: "Точки и маршруты Мекки и Медины.", documentsTitle: "Документы поездки", documentsBody: "Статусы и документы остаются рядом с бронированием.",
                careSubtitle: "Помощь, связанная с Вашей поездкой.", careLockedTitle: "Поддержка iumrah включается вместе с поездкой.", careLockedBody: "После создания бронирования здесь появится чат, связанный именно с ним.", careLockedCTA: "Создать поездку"
            )
        case .english:
            return GearCopy(
                pageTitle: "Gear", pageSubtitle: "We'll help get you started.",
                startTitle: "Get everything ready before you go.", startBody: "Documents, connectivity, useful services and support — prepare the essentials before departure.", startCTA: "Open my trip",
                moreTitle: "Get more from your trip", moreSubtitle: "Services that become more useful when they work together.", advisorTitle: "Go through Umrah with Advisor.", advisorBody: "Voice guidance during the Umrah itself.", ziyaratsTitle: "Explore places around you.", ziyaratsBody: "Makkah and Madinah Ziyarats in one route.", esimTitle: "Stay connected.", esimBody: "Prepare eSIM before you arrive.", didYouKnowEyebrow: "Did you know", didYouKnowTitle: "Care can stay connected to the same trip.", didYouKnowBody: "Instead of explaining the context again, support can work with the relevant booking in view.", didYouKnowCTA: "Learn about Care", suggestedTitle: "Suggested for your trip", suggestedSubtitle: "Quick access to what is useful before and during Umrah.", esimRow: "Mobile data inside your Umrah package.", advisorRow: "Voice guidance through the stages of Umrah.", ziyaratsRow: "Places and routes in Makkah and Madinah.", documentsTitle: "Trip documents", documentsBody: "Statuses and documents stay beside your booking.", careSubtitle: "Help connected to your journey.", careLockedTitle: "Care starts with your trip.", careLockedBody: "Once a booking is created, a chat tied to that trip appears here.", careLockedCTA: "Create a trip"
            )
        case .uzbek:
            return GearCopy(
                pageTitle: "Tayyorgarlik", pageSubtitle: "Boshlash va safarga tayyorlanishda yordam beramiz.",
                startTitle: "Safardan oldin hammasini tayyorlang.", startBody: "Hujjatlar, aloqa, foydali servislar va yordam — jo‘nashdan oldin kerakli narsalarni tayyorlang.", startCTA: "Safarimni ochish", moreTitle: "Safardan ko‘proq oling", moreSubtitle: "Birga ishlaganda foydaliroq bo‘ladigan servislar.", advisorTitle: "Ovozli yordamchi bilan Umradan o‘ting.", advisorBody: "Umraning o‘zida ovozli ko‘rsatmalar.", ziyaratsTitle: "Atrofdagi joylarni kashf eting.", ziyaratsBody: "Makka va Madina ziyoratlari bitta yo‘nalishda.", esimTitle: "Aloqada qoling.", esimBody: "Yetib kelishdan oldin eSIM tayyorlang.", didYouKnowEyebrow: "Bilasizmi", didYouKnowTitle: "iumrah yordami shu safarning o‘zi bilan bog‘lanib qoladi.", didYouKnowBody: "Vaziyatni qayta tushuntirish o‘rniga yordam tegishli bronlash kontekstida ishlaydi.", didYouKnowCTA: "Yordam haqida", suggestedTitle: "Safaringiz uchun tavsiya", suggestedSubtitle: "Umradan oldin va davomida kerak bo‘ladigan narsalarga tez kirish.", esimRow: "Umra paketingiz ichidagi mobil internet.", advisorRow: "Umra bosqichlari bo‘yicha ovozli gid.", ziyaratsRow: "Makka va Madinadagi joylar va yo‘nalishlar.", documentsTitle: "Safar hujjatlari", documentsBody: "Status va hujjatlar bronlash bilan birga qoladi.", careSubtitle: "Safaringizga bog‘langan yordam.", careLockedTitle: "iumrah yordami safar bilan birga boshlanadi.", careLockedBody: "Bronlash yaratilgach, unga bog‘langan chat shu yerda paydo bo‘ladi.", careLockedCTA: "Safar yaratish"
            )
        case .uzbekCyrillic:
            return GearCopy(
                pageTitle: "Тайёргарлик", pageSubtitle: "Бошлаш ва сафарга тайёрланишда ёрдам берамиз.",
                startTitle: "Сафардан олдин ҳаммасини тайёрланг.", startBody: "Ҳужжатлар, алоқа, фойдали сервислар ва ёрдам — жўнашдан олдин керакли нарсаларни тайёрланг.", startCTA: "Сафаримни очиш", moreTitle: "Сафардан кўпроқ олинг", moreSubtitle: "Бирга ишлаганда фойдалироқ бўладиган сервислар.", advisorTitle: "Овозли ёрдамчи билан Умрадан ўтинг.", advisorBody: "Умранинг ўзида овозли кўрсатмалар.", ziyaratsTitle: "Атрофдаги жойларни кашф этинг.", ziyaratsBody: "Макка ва Мадина зиёратлари битта йўналишда.", esimTitle: "Алоқада қолинг.", esimBody: "Етиб келишдан олдин eSIM тайёрланг.", didYouKnowEyebrow: "Биласизми", didYouKnowTitle: "iumrah ёрдами шу сафарнинг ўзи билан боғланиб қолади.", didYouKnowBody: "Вазиятни қайта тушунтириш ўрнига ёрдам тегишли бронлаш контекстида ишлайди.", didYouKnowCTA: "Ёрдам ҳақида", suggestedTitle: "Сафарингиз учун тавсия", suggestedSubtitle: "Умрадан олдин ва давомида керак бўладиган нарсаларга тез кириш.", esimRow: "Умра пакетингиз ичидаги мобил интернет.", advisorRow: "Умра босқичлари бўйича овозли гид.", ziyaratsRow: "Макка ва Мадинадаги жойлар ва йўналишлар.", documentsTitle: "Сафар ҳужжатлари", documentsBody: "Статус ва ҳужжатлар бронлаш билан бирга қолади.", careSubtitle: "Сафарингизга боғланган ёрдам.", careLockedTitle: "iumrah ёрдами сафар билан бирга бошланади.", careLockedBody: "Бронлаш яратилгач, унга боғланган чат шу ерда пайдо бўлади.", careLockedCTA: "Сафар яратиш"
            )
        }
    }
}

private struct GearCopy {
    let pageTitle: String
    let pageSubtitle: String
    let startTitle: String
    let startBody: String
    let startCTA: String
    let moreTitle: String
    let moreSubtitle: String
    let advisorTitle: String
    let advisorBody: String
    let ziyaratsTitle: String
    let ziyaratsBody: String
    let esimTitle: String
    let esimBody: String
    let didYouKnowEyebrow: String
    let didYouKnowTitle: String
    let didYouKnowBody: String
    let didYouKnowCTA: String
    let suggestedTitle: String
    let suggestedSubtitle: String
    let esimRow: String
    let advisorRow: String
    let ziyaratsRow: String
    let documentsTitle: String
    let documentsBody: String
    let careSubtitle: String
    let careLockedTitle: String
    let careLockedBody: String
    let careLockedCTA: String
}
