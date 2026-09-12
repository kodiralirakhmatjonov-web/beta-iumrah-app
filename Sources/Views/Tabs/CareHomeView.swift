import SwiftUI

/// Care stays the support destination. Its presentation mirrors the Apple Store
/// "Go Further" rhythm: setup help, useful services, discovery, and personal support.
struct CareHomeView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore

    @State private var showZiyarats = false

    private var copy: CareCopy { CareCopy.make(for: settings.language) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 30) {
                IumrahStorePageHeader(title: "Care", subtitle: nil)
                getStartedSection
                getMoreSection
                didYouKnowSection
                suggestedSection
                linkedCareSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .task { await bookings.refreshAll() }
        .fullScreenCover(isPresented: $showZiyarats) {
            ZiyaratJourneyView()
                .environmentObject(settings)
                .environmentObject(chrome)
        }
    }

    // MARK: - We'll help get you started

    private var getStartedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: copy.startedSectionTitle)

            VStack(alignment: .leading, spacing: 0) {
                CareSetupIllustration()
                    .frame(height: 252)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 7) {
                    Text(copy.startedCardTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(copy.startedCardBody)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(21)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.iumrahCardBackground)
            }
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
            }
        }
    }

    // MARK: - Get the most out of your journey

    private var getMoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: copy.moreTitle, subtitle: copy.moreSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                        CareSymbolMerchCard(
                            systemName: "waveform.badge.mic",
                            role: .umrah,
                            eyebrow: copy.advisorEyebrow,
                            title: copy.advisorTitle,
                            subtitle: copy.advisorBody
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 14)

                    Button { showZiyarats = true } label: {
                        IumrahStoreMerchandisingCard(
                            eyebrow: copy.ziyaratsEyebrow,
                            title: copy.ziyaratsTitle,
                            subtitle: copy.ziyaratsBody,
                            assetName: "ZiyaratQuba2"
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 14)

                    Button { chrome.presentESIM() } label: {
                        CareSymbolMerchCard(
                            systemName: "simcard.fill",
                            role: .connectivity,
                            eyebrow: "iumrah eSIM",
                            title: copy.esimTitle,
                            subtitle: copy.esimBody
                        )
                    }
                    .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 14)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .buttonStyle(.plain)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    // MARK: - Did you know

    private var didYouKnowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy.didYouKnowEyebrow.uppercased())
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .tracking(0.85)
                .foregroundStyle(.secondary)

            Text(copy.didYouKnowTitle)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .tracking(-0.45)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.didYouKnowBody)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 205, alignment: .topLeading)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    // MARK: - Suggested services

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: copy.suggestedTitle, subtitle: copy.suggestedSubtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button { chrome.navigate(to: .booking) } label: {
                        CareSuggestedCard(systemName: "doc.text.fill", title: copy.documentsTitle, subtitle: copy.documentsBody, role: .document)
                    }
                    Button { chrome.presentESIM() } label: {
                        CareSuggestedCard(systemName: "simcard.fill", title: "iumrah eSIM", subtitle: copy.suggestedESIMBody, role: .connectivity)
                    }
                    NavigationLink { IumrahServiceStorePage(kind: .advisor) } label: {
                        CareSuggestedCard(systemName: "waveform.badge.mic", title: copy.suggestedAdvisorTitle, subtitle: copy.suggestedAdvisorBody, role: .umrah)
                    }
                    Button { showZiyarats = true } label: {
                        CareSuggestedCard(systemName: "map.fill", title: copy.suggestedZiyaratsTitle, subtitle: copy.suggestedZiyaratsBody, role: .location)
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

    // MARK: - Linked Care chats

    private var linkedCareSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: copy.linkedTitle, subtitle: copy.linkedSubtitle)

            if bookings.sessions.isEmpty {
                Button { chrome.navigate(to: .booking) } label: {
                    HStack(alignment: .top, spacing: 16) {
                        Image("CareMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(copy.lockedTitle)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(copy.lockedBody)
                                .font(.system(size: 14.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
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
            } else {
                VStack(spacing: 10) {
                    ForEach(bookings.sessions) { session in
                        NavigationLink {
                            BookingChatView(bookingID: session.id)
                        } label: {
                            HStack(spacing: 14) {
                                Image("CareMark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 46, height: 46)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("iumrah Care")
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct CareSetupIllustration: View {
    private let blue = Color(uiColor: .systemBlue)

    var body: some View {
        ZStack {
            Color.iumrahCardBackground

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(blue, lineWidth: 4)
                .frame(width: 142, height: 102)
                .offset(y: 16)

            Capsule()
                .fill(blue)
                .frame(width: 174, height: 5)
                .offset(y: 70)

            Image(systemName: "heart.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(blue)
                .offset(y: 12)

            setupSymbol("message.fill", size: 36, x: -92, y: -58)
            setupSymbol("checkmark.shield.fill", size: 32, x: 94, y: -62)
            setupSymbol("iphone", size: 38, x: -118, y: 28)
            setupSymbol("simcard.fill", size: 30, x: 116, y: 35)
            setupSymbol("airplane", size: 31, x: -54, y: -94)
            setupSymbol("doc.text.fill", size: 28, x: 53, y: -96)
            setupSymbol("waveform.badge.mic", size: 31, x: 0, y: 104)
        }
    }

    private func setupSymbol(_ systemName: String, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(blue)
            .offset(x: x, y: y)
    }
}

private struct CareSymbolMerchCard: View {
    let systemName: String
    let role: IumrahIconRole
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.iumrahCardBackground
                Image(systemName: systemName)
                    .font(.system(size: 84, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(role.color)
            }
            .frame(height: 258)

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
        }
        .frame(height: 428)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }
}

private struct CareSuggestedCard: View {
    let systemName: String
    let title: String
    let subtitle: String
    let role: IumrahIconRole

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.iumrahRaisedBackground
                Image(systemName: systemName)
                    .font(.system(size: 62, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(role.color)
            }
            .frame(height: 170)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(Color.iumrahCardBackground)
        }
        .frame(width: 238, height: 318)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }
}

private struct CareCopy {
    let startedSectionTitle: String
    let startedCardTitle: String
    let startedCardBody: String
    let moreTitle: String
    let moreSubtitle: String
    let advisorEyebrow: String
    let advisorTitle: String
    let advisorBody: String
    let ziyaratsEyebrow: String
    let ziyaratsTitle: String
    let ziyaratsBody: String
    let esimTitle: String
    let esimBody: String
    let didYouKnowEyebrow: String
    let didYouKnowTitle: String
    let didYouKnowBody: String
    let suggestedTitle: String
    let suggestedSubtitle: String
    let documentsTitle: String
    let documentsBody: String
    let suggestedESIMBody: String
    let suggestedAdvisorTitle: String
    let suggestedAdvisorBody: String
    let suggestedZiyaratsTitle: String
    let suggestedZiyaratsBody: String
    let linkedTitle: String
    let linkedSubtitle: String
    let lockedTitle: String
    let lockedBody: String

    static func make(for language: AppSettingsStore.Language) -> CareCopy {
        switch language {
        case .russian:
            return CareCopy(
                startedSectionTitle: "Мы поможем Вам начать",
                startedCardTitle: "Подготовьте поездку вместе с iumrah Care.",
                startedCardBody: "От первых вопросов и документов до связи и сопровождения — нужные сервисы остаются рядом с Вашей поездкой.",
                moreTitle: "Получите больше от поездки", moreSubtitle: "Сервисы, которые помогают до и во время Умры.",
                advisorEyebrow: "iumrah Голосовой гид", advisorTitle: "Умра с голосовым сопровождением.", advisorBody: "Пошаговая помощь именно в тот момент, когда она нужна.",
                ziyaratsEyebrow: "iumrah Зияраты", ziyaratsTitle: "Откройте город со смыслом.", ziyaratsBody: "Места, фотографии и маршруты Мекки и Медины.",
                esimTitle: "Будьте на связи с момента прибытия.", esimBody: "Подготовьте мобильный интернет заранее и держите его рядом с поездкой.",
                didYouKnowEyebrow: "Знаете ли Вы", didYouKnowTitle: "Care остаётся связан с той же поездкой.", didYouKnowBody: "Вам не нужно каждый раз объяснять ситуацию заново: поддержка работает в контексте конкретного бронирования.",
                suggestedTitle: "Рекомендуемые сервисы для Вас", suggestedSubtitle: "Быстрый доступ к тому, что может пригодиться дальше.",
                documentsTitle: "Мои поездки", documentsBody: "Статусы, документы и управление бронированием.",
                suggestedESIMBody: "Мобильная связь для Вашей поездки.",
                suggestedAdvisorTitle: "Голосовой гид", suggestedAdvisorBody: "Сопровождение по этапам Умры.",
                suggestedZiyaratsTitle: "Зияраты", suggestedZiyaratsBody: "Маршруты и контекст важных мест.",
                linkedTitle: "Ваш Care", linkedSubtitle: "Чаты поддержки, привязанные к конкретным поездкам.",
                lockedTitle: "Care откроется вместе с Вашей поездкой.", lockedBody: "После создания бронирования здесь появится чат, связанный именно с ним."
            )
        case .english:
            return CareCopy(
                startedSectionTitle: "We'll help get you started",
                startedCardTitle: "Set up your journey with iumrah Care.",
                startedCardBody: "From first questions and documents to connectivity and guidance, the services you need stay beside your trip.",
                moreTitle: "Get the most out of your journey", moreSubtitle: "Services designed to help before and during Umrah.",
                advisorEyebrow: "iumrah Advisor", advisorTitle: "Umrah with voice guidance.", advisorBody: "Step-by-step help at the moment you need it.",
                ziyaratsEyebrow: "iumrah Ziyarats", ziyaratsTitle: "Explore the city with context.", ziyaratsBody: "Places, photography and routes across Makkah and Madinah.",
                esimTitle: "Stay connected from arrival.", esimBody: "Prepare mobile data in advance and keep it beside your trip.",
                didYouKnowEyebrow: "Did you know", didYouKnowTitle: "Care stays connected to the same trip.", didYouKnowBody: "You don't have to explain the context again each time: support works with the relevant booking in view.",
                suggestedTitle: "Suggested services for you", suggestedSubtitle: "Quick access to what may be useful next.",
                documentsTitle: "My trips", documentsBody: "Statuses, documents and booking management.",
                suggestedESIMBody: "Mobile connectivity for your journey.",
                suggestedAdvisorTitle: "Advisor", suggestedAdvisorBody: "Guidance through the stages of Umrah.",
                suggestedZiyaratsTitle: "Ziyarats", suggestedZiyaratsBody: "Routes and context for important places.",
                linkedTitle: "Your Care", linkedSubtitle: "Support conversations tied to individual trips.",
                lockedTitle: "Care opens with your journey.", lockedBody: "Once you create a booking, a support chat linked to that trip appears here."
            )
        case .uzbek:
            return CareCopy(
                startedSectionTitle: "Boshlashingizga yordam beramiz",
                startedCardTitle: "Safaringizni iumrah Care bilan tayyorlang.",
                startedCardBody: "Birinchi savollar va hujjatlardan aloqa hamda yo‘l-yo‘riqqacha — kerakli servislar safaringiz yonida qoladi.",
                moreTitle: "Safardan ko‘proq oling", moreSubtitle: "Umradan oldin va davomida foydali servislar.",
                advisorEyebrow: "iumrah Ovozli gid", advisorTitle: "Ovozli yo‘l-yo‘riq bilan Umra.", advisorBody: "Kerakli paytda bosqichma-bosqich yordam.",
                ziyaratsEyebrow: "iumrah Ziyoratlar", ziyaratsTitle: "Shaharni mazmun bilan kashf eting.", ziyaratsBody: "Makka va Madinadagi joylar, suratlar va yo‘nalishlar.",
                esimTitle: "Yetib kelgan zahoti aloqada bo‘ling.", esimBody: "Mobil internetni oldindan tayyorlang va safaringiz bilan birga saqlang.",
                didYouKnowEyebrow: "Bilasizmi", didYouKnowTitle: "Care shu safarning o‘zi bilan bog‘langan qoladi.", didYouKnowBody: "Har safar vaziyatni qayta tushuntirish shart emas: yordam tegishli bronlash kontekstida ishlaydi.",
                suggestedTitle: "Siz uchun tavsiya etilgan servislar", suggestedSubtitle: "Keyin kerak bo‘lishi mumkin bo‘lgan narsalarga tez kirish.",
                documentsTitle: "Safarlarim", documentsBody: "Statuslar, hujjatlar va bronlash boshqaruvi.",
                suggestedESIMBody: "Safaringiz uchun mobil aloqa.",
                suggestedAdvisorTitle: "Ovozli gid", suggestedAdvisorBody: "Umra bosqichlari bo‘yicha yo‘l-yo‘riq.",
                suggestedZiyaratsTitle: "Ziyoratlar", suggestedZiyaratsBody: "Muhim joylar uchun yo‘nalish va izohlar.",
                linkedTitle: "Sizning Care", linkedSubtitle: "Alohida safarlarga bog‘langan yordam chatlari.",
                lockedTitle: "Care safaringiz bilan birga ochiladi.", lockedBody: "Bronlash yaratilgach, aynan shu safarga bog‘langan yordam chati shu yerda paydo bo‘ladi."
            )
        case .uzbekCyrillic:
            return CareCopy(
                startedSectionTitle: "Бошлашингизга ёрдам берамиз",
                startedCardTitle: "Сафарингизни iumrah Care билан тайёрланг.",
                startedCardBody: "Биринчи саволлар ва ҳужжатлардан алоқа ҳамда йўл-йўриққача — керакли сервислар сафарингиз ёнида қолади.",
                moreTitle: "Сафардан кўпроқ олинг", moreSubtitle: "Умрадан олдин ва давомида фойдали сервислар.",
                advisorEyebrow: "iumrah Овозли гид", advisorTitle: "Овозли йўл-йўриқ билан Умра.", advisorBody: "Керакли пайтда босқичма-босқич ёрдам.",
                ziyaratsEyebrow: "iumrah Зиёратлар", ziyaratsTitle: "Шаҳарни мазмун билан кашф этинг.", ziyaratsBody: "Макка ва Мадинадаги жойлар, суратлар ва йўналишлар.",
                esimTitle: "Етиб келган заҳоти алоқада бўлинг.", esimBody: "Мобил интернетни олдиндан тайёрланг ва сафарингиз билан бирга сақланг.",
                didYouKnowEyebrow: "Биласизми", didYouKnowTitle: "Care шу сафарнинг ўзи билан боғланган қолади.", didYouKnowBody: "Ҳар сафар вазиятни қайта тушунтириш шарт эмас: ёрдам тегишли бронлаш контекстида ишлайди.",
                suggestedTitle: "Сиз учун тавсия этилган сервислар", suggestedSubtitle: "Кейин керак бўлиши мумкин бўлган нарсаларга тез кириш.",
                documentsTitle: "Сафарларим", documentsBody: "Статуслар, ҳужжатлар ва бронлаш бошқаруви.",
                suggestedESIMBody: "Сафарингиз учун мобил алоқа.",
                suggestedAdvisorTitle: "Овозли гид", suggestedAdvisorBody: "Умра босқичлари бўйича йўл-йўриқ.",
                suggestedZiyaratsTitle: "Зиёратлар", suggestedZiyaratsBody: "Муҳим жойлар учун йўналиш ва изоҳлар.",
                linkedTitle: "Сизнинг Care", linkedSubtitle: "Алоҳида сафарларга боғланган ёрдам чатлари.",
                lockedTitle: "Care сафарингиз билан бирга очилади.", lockedBody: "Бронлаш яратилгач, айнан шу сафарга боғланган ёрдам чати шу ерда пайдо бўлади."
            )
        }
    }
}
