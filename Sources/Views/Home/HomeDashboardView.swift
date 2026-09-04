import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var account: IumrahAccountStore
    @ObservedObject private var clientNotifications = ClientNotificationCenter.shared

    private var activeSession: StoredBookingSession? {
        bookings.sessions.first { $0.effectiveStatus.uppercased() != "COMPLETED" }
    }

    var body: some View {
        marketingHome
            .task(id: activeSession?.id) {
                await bookings.refreshAll()
                while !Task.isCancelled {
                    if let activeSession { _ = try? await bookings.loadESIMs(for: activeSession.id) }
                    try? await Task.sleep(nanoseconds: 120_000_000_000)
                }
            }
    }

    private var marketingHome: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahRootPageTitle(title: L10n.text("tab_home", settings.language), usesBrandLogo: true, brandScale: 1.25, showsConnectivityStatus: true)
                if !clientNotifications.homeNotifications.isEmpty {
                    SystemNotificationsCarouselView(
                        notifications: Array(clientNotifications.homeNotifications.prefix(5)),
                        onOpen: { openSystemNotification($0) },
                        onDismiss: { dismissSystemNotification($0) }
                    )
                }
                HomeEmotionalJourneyPrompt()
                HomeVideoCarousel()
                IumrahBackendSystemHomeCard()
                hero
                friendsHomeCard
                UmrahAdvisorHomeCard()
                confidenceStrip
                philosophyCard
                connectedTripCard
                esimHomeCard
                careCard
                hotelCard
                flightsHomeCard
                flightsWorldFooter
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 0)
        }
        .background(Color.iumrahPageBackground)
    }


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

    private func activeJourneyHome(_ session: StoredBookingSession) -> some View {
        ZStack {
            Image("MakkahBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.48), Color.black.opacity(0.12), Color.black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    IumrahRootPageTitle(
                        title: L10n.text("tab_home", settings.language),
                        showsMakkahTime: true,
                        lightStyle: true,
                        usesBrandLogo: true,
                        showsConnectivityStatus: true
                    )

                    activeBookingCard(session)
                    activeCareCard(session)

                    Color.clear
                        .frame(height: 330)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
    }

    private func activeBookingCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center) {
                Label(L10n.text("home_hero_kicker", settings.language), systemImage: "moon.stars.fill")
                    .font(.caption.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Color.black.opacity(0.58))

                Spacer()

                Image(systemName: statusIcon(session.effectiveStatus))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareDark)
                    .frame(width: 36, height: 36)
                    .background(Color.iumrahCareLight.opacity(0.18))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.status(session.effectiveStatus, settings.language))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(Color.black)

                if let travelerName = session.travelerName, !travelerName.isEmpty {
                    Text(travelerName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.58))
                }
            }

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)

            VStack(spacing: 12) {
                journeySummaryRow(
                    icon: "airplane",
                    title: L10n.text("route_label", settings.language),
                    value: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)"
                )
                journeySummaryRow(
                    icon: "calendar",
                    title: L10n.text("detail_dates", settings.language),
                    value: "\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))"
                )
                if !session.booking.hotelNames.makkah.isEmpty {
                    journeySummaryRow(
                        icon: "building.2.fill",
                        title: L10n.text("detail_hotel", settings.language),
                        value: session.booking.hotelNames.makkah
                    )
                }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("final_price", settings.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.50))
                    Text(money(session.booking.perPilgrimUsd))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black)
                }
                Spacer()
                if let pilgrimID = session.displayPilgrimID {
                    Text("ID \(pilgrimID)")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.42))
                }
            }

            NavigationLink {
                BookingDetailView(bookingID: session.id)
            } label: {
                HStack {
                    Text(L10n.text("open_booking", settings.language))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 28, y: 14)
    }

    private func journeySummaryRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.iumrahCareDark)
                .frame(width: 34, height: 34)
                .background(Color.iumrahCareLight.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.48))
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private func activeCareCard(_ session: StoredBookingSession) -> some View {
        Button {
            chrome.navigate(to: .care)
        } label: {
            HStack(spacing: 14) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .padding(5)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("iumrah Care")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.text("care_subtitle", settings.language))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(16)
            .background {
                LinearGradient(
                    colors: [Color.iumrahCareDark.opacity(0.96), Color.iumrahCareLight.opacity(0.88)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.iumrahCareDark.opacity(0.22), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityHint(session.displayPilgrimID.map { "ID \($0)" } ?? "")
    }

    private var flightsHomeCard: some View {
        NavigationLink {
            IumrahFlightsView()
        } label: {
            Image("IumrahFlightsHomeCard")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("iumrah Flights")
    }

    private var flightsWorldFooter: some View {
        let pageBackground = Color.iumrahPageBackground

        return VStack(spacing: 0) {
            Text("From the world to Mecca")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 8)
                .allowsHitTesting(false)

            ZStack {
                IumrahInteractiveGlobe(presentation: .worldToMakkah)
                    .frame(height: 390)
                    // Fade the complete MapKit surface itself, including its black sky,
                    // so no rectangular map boundary survives against Home's background.
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: .white.opacity(0.16), location: 0.08),
                                .init(color: .white, location: 0.25),
                                .init(color: .white, location: 0.73),
                                .init(color: .white.opacity(0.20), location: 0.93),
                                .init(color: .clear, location: 1.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                // A second two-sided blend uses the exact Home page background color.
                // This keeps the transition seamless in both light and dark appearance.
                LinearGradient(
                    stops: [
                        .init(color: pageBackground, location: 0.00),
                        .init(color: pageBackground.opacity(0.82), location: 0.07),
                        .init(color: .clear, location: 0.24),
                        .init(color: .clear, location: 0.74),
                        .init(color: pageBackground.opacity(0.78), location: 0.93),
                        .init(color: pageBackground, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(height: 350)
            .clipped()
            .padding(.bottom, 84)
        }
        .frame(maxWidth: .infinity)
        .background(pageBackground)
        .padding(.horizontal, -IumrahDesign.pagePadding)
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
                .foregroundColor(.black)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Label(L10n.text("home_hero_badge", settings.language), systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .iumrahMarketingCard(dark: true)
    }

    private var friendsHomeCard: some View {
        NavigationLink {
            IumrahGiftCardsView()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .frame(width: 82, height: 82)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Text("3")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(.white, in: Circle())
                        .offset(x: 5, y: -5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text("iUmrah Gift Cards")
                            .font(.headline)
                        Text("3 × $100")
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(friendsHomeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }

    private var friendsHomeSubtitle: String {
        switch settings.language {
        case .russian: return "Подарочные карты для близких · $100 на умру и $100 iumrah Credit после подтверждения и оплаты."
        case .english: return "Gift cards for someone close · $100 toward Umrah and $100 iumrah Credit after confirmation and payment."
        case .uzbek: return "Yaqinlar uchun Gift Card · Umrah uchun $100 va tasdiqlanib to‘langach $100 iumrah Credit."
        case .uzbekCyrillic: return "Яқинлар учун Gift Card · Умра учун $100 ва тасдиқланиб тўлангач $100 iumrah Credit."
        }
    }

    private var confidenceStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(icon: "building.2.fill", text: L10n.text("tab_hotels", settings.language))
                chip(icon: "airplane", text: L10n.text("step_flight", settings.language))
                chip(icon: "heart.fill", text: "iumrah Care")
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
            .overlay { Capsule().strokeBorder(Color.primary.opacity(0.05), lineWidth: 1) }
    }

    private var philosophyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iumrah")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Capsule())
            Text(L10n.text("home_philosophy_title", settings.language))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(L10n.text("home_philosophy_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var connectedTripCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                journeyIcon("airplane")
                connector
                journeyIcon("building.2.fill")
                connector
                journeyIcon("car.fill")
                connector
                journeyIcon("moon.stars.fill")
                connector
                journeyIcon("heart.fill")
            }

            Text(L10n.text("home_connected_title", settings.language))
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text(L10n.text("home_connected_body", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var esimHomeCard: some View {
        Button { chrome.presentESIM() } label: {
            HStack(spacing: 16) {
                if let session = activeSession, let profile = bookings.primaryESIM(for: session.id) {
                    ZStack {
                        Circle().stroke(Color.primary.opacity(0.08), lineWidth: 8)
                        if profile.usageAvailable {
                            Circle()
                                .trim(from: 0, to: profile.remainingFraction)
                                .stroke(Color.iumrahCareDark, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text(homeDataText(profile.remainingMB))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Text(homeESIMCopy(.left))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("AUTO")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("iumrah eSIM")
                            .font(.headline)
                        Text(profile.hasActivationData ? homeESIMCopy(.ready) : homeESIMCopy(.assigned))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(profile.hasActivationData ? homeESIMCopy(.activate) : homeESIMCopy(.open))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.iumrahCareDark)
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.iumrahCareLight.opacity(0.20))
                        Image(systemName: "simcard.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(Color.iumrahCareDark)
                    }
                    .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("iumrah eSIM")
                            .font(.headline)
                        Text(homeESIMCopy(.packageOnly))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Text(homeESIMCopy(.details))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.iumrahCareDark)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }

    private enum HomeESIMCopyKey { case left, ready, assigned, activate, open, packageOnly, details }

    private func homeESIMCopy(_ key: HomeESIMCopyKey) -> String {
        switch (settings.language, key) {
        case (.russian, .left): return "осталось"
        case (.russian, .ready): return "Профиль готов. Активируйте eSIM на iPhone."
        case (.russian, .assigned): return "eSIM привязана к вашей поездке."
        case (.russian, .activate): return "Активировать eSIM"
        case (.russian, .open): return "Открыть eSIM"
        case (.russian, .packageOnly): return "В первой версии eSIM доступна только внутри Umrah-пакета."
        case (.russian, .details): return "Тарифы и активация"
        case (.english, .left): return "left"
        case (.english, .ready): return "Your profile is ready. Activate eSIM on iPhone."
        case (.english, .assigned): return "eSIM is assigned to your trip."
        case (.english, .activate): return "Activate eSIM"
        case (.english, .open): return "Open eSIM"
        case (.english, .packageOnly): return "In V1, eSIM is available only inside an Umrah package."
        case (.english, .details): return "Plans & activation"
        case (.uzbek, .left): return "qoldi"
        case (.uzbek, .ready): return "Profil tayyor. iPhone’da eSIM’ni faollashtiring."
        case (.uzbek, .assigned): return "eSIM safaringizga biriktirilgan."
        case (.uzbek, .activate): return "eSIM’ni faollashtirish"
        case (.uzbek, .open): return "eSIM’ni ochish"
        case (.uzbek, .packageOnly): return "V1’da eSIM faqat Umra paketi tarkibida mavjud."
        case (.uzbek, .details): return "Tariflar va faollashtirish"
        case (.uzbekCyrillic, .left): return "қолди"
        case (.uzbekCyrillic, .ready): return "Профил тайёр. iPhone’да eSIM’ни фаоллаштиринг."
        case (.uzbekCyrillic, .assigned): return "eSIM сафарингизга бириктирилган."
        case (.uzbekCyrillic, .activate): return "eSIM’ни фаоллаштириш"
        case (.uzbekCyrillic, .open): return "eSIM’ни очиш"
        case (.uzbekCyrillic, .packageOnly): return "V1’да eSIM фақат Умра пакети таркибида мавжуд."
        case (.uzbekCyrillic, .details): return "Тарифлар ва фаоллаштириш"
        }
    }

    private func homeDataText(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        return "\(Int(max(0, mb).rounded())) MB"
    }

    private func journeyIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 34, height: 34)
            .background(Color.iumrahRaisedBackground)
            .clipShape(Circle())
    }

    private var connector: some View {
        Capsule()
            .fill(Color.primary.opacity(0.10))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
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
                    Text("iumrah Care")
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

    private func money(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount.rounded()))"
    }
}
