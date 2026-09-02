import SwiftUI

struct FinalPackageView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @ObservedObject private var push = PushNotificationManager.shared

    @State private var isProfileSheetPresented = false
    @State private var isSubmitting = false
    @State private var createdSession: StoredBookingSession?
    @State private var errorMessage: String?
    @State private var showCreatedBooking = false
    @State private var isCalculatingPrice = false

    private var needsMadinah: Bool { journey.trip.scope == .makkahAndMadinah }
    private var canBook: Bool {
        journey.hasFinalGeneratorQuote &&
        journey.selectedHotel != nil &&
        journey.selectedOutbound?.isVerifiedForBooking == true &&
        (!journey.trip.isRoundTripFlight || journey.selectedInbound?.isVerifiedForBooking == true) &&
        (!needsMadinah || journey.selectedMadinahHotel != nil)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                IumrahFlowProgress(stage: .ready)

                if let createdSession {
                    successContent(createdSession)
                } else {
                    packageHeader
                    if let quote = journey.quote, journey.hasFinalGeneratorQuote {
                        premiumPriceCard(quote)
                    } else {
                        pricingStatusCard
                    }
                    includedServicesCard
                    reassuranceCard
                    notificationCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        isProfileSheetPresented = true
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(FlowCopy.text(.bookPackage, settings.language))
                            if !isSubmitting { Image(systemName: "arrow.right") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                    .disabled(!canBook || isSubmitting)
                    .opacity(canBook && !isSubmitting ? 1 : 0.45)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .ready)
        .task {
            if !journey.hasFinalGeneratorQuote { await recalculatePrice(forceHotelRefresh: false) }
            await push.refreshAndRegisterIfAllowed()
        }
        .sheet(isPresented: $isProfileSheetPresented) {
            BookingProfileCaptureSheet {
                Task { await createBooking() }
            }
            .environmentObject(settings)
        }
        .navigationDestination(isPresented: $showCreatedBooking) {
            if let createdSession {
                BookingDetailView(bookingID: createdSession.id)
            }
        }
    }

    private var pricingStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if isCalculatingPrice {
                    ProgressView()
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(isCalculatingPrice ? calculatingPriceTitle : pricingUnavailableTitle)
                        .font(.headline)
                    Text(isCalculatingPrice ? calculatingPriceBody : (journey.errorMessage ?? pricingUnavailableBody))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if !isCalculatingPrice {
                VStack(spacing: 10) {
                    Button(retryPricingTitle) {
                        Task { await recalculatePrice(forceHotelRefresh: true) }
                    }
                    .buttonStyle(IumrahSecondaryButtonStyle())

                    if isHotelVerificationFailure {
                        NavigationLink {
                            PrimaryHotelView()
                        } label: {
                            Text(changeHotelTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(IumrahSecondaryButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    @MainActor
    private func recalculatePrice(forceHotelRefresh: Bool) async {
        guard !isCalculatingPrice else { return }
        isCalculatingPrice = true
        await journey.buildQuote(forceHotelRefresh: forceHotelRefresh)
        isCalculatingPrice = false
        if journey.hasFinalGeneratorQuote { IumrahHaptics.success() }
    }

    private var calculatingPriceTitle: String {
        switch settings.language {
        case .russian: return "Рассчитываем цену пакета"
        case .english: return "Calculating your package price"
        case .uzbek: return "Paket narxi hisoblanmoqda"
        case .uzbekCyrillic: return "Пакет нархи ҳисобланмоқда"
        }
    }

    private var calculatingPriceBody: String {
        switch settings.language {
        case .russian: return journey.trip.isRoundTripFlight ? "Используем актуальную стоимость билета туда и обратно и текущие цены выбранных Primary Hotels." : "Используем актуальную стоимость билета в одну сторону и текущие цены выбранных Primary Hotels."
        case .english: return journey.trip.isRoundTripFlight ? "Using the current round-trip fare and current Primary Hotel prices." : "Using the current one-way fare and current Primary Hotel prices."
        case .uzbek: return journey.trip.isRoundTripFlight ? "Borish-qaytish chiptasi va Primary Hotel joriy narxlari asosida paket hisoblanadi." : "Bir tomonlama chipta va Primary Hotel joriy narxlari asosida paket hisoblanadi."
        case .uzbekCyrillic: return journey.trip.isRoundTripFlight ? "Бориш-қайтиш чиптаси ва Primary Hotel жорий нархлари асосида пакет ҳисобланади." : "Бир томонлама чипта ва Primary Hotel жорий нархлари асосида пакет ҳисобланади."
        }
    }

    private var pricingUnavailableTitle: String {
        switch settings.language {
        case .russian: return "Не удалось получить цену компонента"
        case .english: return "A component price is unavailable"
        case .uzbek: return "Komponent narxini olish imkoni bo‘lmadi"
        case .uzbekCyrillic: return "Компонент нархини олиш имкони бўлмади"
        }
    }

    private var pricingUnavailableBody: String {
        switch settings.language {
        case .russian: return "Найденный маршрут сохранён. Повторите получение цены отеля — поиск авиабилетов заново не запускается."
        case .english: return "Your selected journey is preserved. Retry the hotel price lookup; flight search will not restart."
        case .uzbek: return "Tanlangan yo‘nalish saqlanadi. Mehmonxona narxini qayta oling — reys qidiruvi qayta boshlanmaydi."
        case .uzbekCyrillic: return "Танланган йўналиш сақланади. Меҳмонхона нархини қайта олинг — рейс қидируви қайта бошланмайди."
        }
    }

    private var isHotelVerificationFailure: Bool {
        journey.errorMessage?.localizedCaseInsensitiveContains("Primary Hotel") == true
    }

    private var changeHotelTitle: String {
        switch settings.language {
        case .russian: return "Изменить отель"
        case .english: return "Change hotel"
        case .uzbek: return "Mehmonxonani o‘zgartirish"
        case .uzbekCyrillic: return "Меҳмонхонани ўзгартириш"
        }
    }

    private var retryPricingTitle: String {
        switch settings.language {
        case .russian: return "Повторить получение цены"
        case .english: return "Retry price lookup"
        case .uzbek: return "Narxni qayta olish"
        case .uzbekCyrillic: return "Нархни қайта олиш"
        }
    }

    private var packageHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(FlowCopy.text(.finalEyebrow, settings.language))
                .font(.caption.weight(.bold))
                .tracking(1.25)
                .foregroundStyle(.secondary)
            Text(FlowCopy.text(.finalTitle, settings.language))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.9)
            Text(FlowCopy.text(.finalBody, settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func premiumPriceCard(_ quote: PackageQuote) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Label(indicativePriceTitle, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<min(journey.trip.travelerCount, 3), id: \.self) { _ in
                        Image(systemName: "person.fill")
                            .font(.caption.weight(.bold))
                    }
                    Text("\(journey.trip.travelerCount)")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(Color.white.opacity(0.12), in: Capsule())
            }

            Text(money(quote.totalPackagePrice, quote.currency))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .tracking(-1.6)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(L10n.text("final_price_note", settings.language))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))

            if journey.trip.travelerCount == 2 {
                HStack(spacing: 10) {
                    travelerSplitChip(amount: quote.pricePerPerson, currency: quote.currency)
                    travelerSplitChip(amount: quote.pricePerPerson, currency: quote.currency)
                }
            } else {
                HStack(spacing: 10) {
                    Label(
                        "\(journey.trip.travelerCount) × \(money(quote.pricePerPerson, quote.currency))",
                        systemImage: "person.2.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.10), in: Capsule())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.19, blue: 0.16), Color(red: 0.03, green: 0.04, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 26, y: 12)
    }

    private func travelerSplitChip(amount: Decimal, currency: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill")
                .font(.caption.weight(.bold))
            Text(money(amount, currency))
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color.white.opacity(0.10), in: Capsule())
    }

    private var includedServicesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(FlowCopy.text(.includedTitle, settings.language))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .padding(.bottom, 12)

            if let outbound = journey.selectedOutbound {
                includedRow(.outboundFlight, value: "\(outbound.airlinesSummary) · \(outbound.flightNumbersSummary)", icon: "airplane.departure")
            }
            if let makkah = journey.selectedHotel {
                includedRow(.makkahHotel, value: makkah.name, icon: "building.2.fill")
            }
            if needsMadinah, let madinah = journey.selectedMadinahHotel {
                includedRow(.madinahHotel, value: madinah.name, icon: "building.2.fill")
            }
            if let inbound = journey.selectedInbound {
                includedRow(.returnFlight, value: "\(inbound.airlinesSummary) · \(inbound.flightNumbersSummary)", icon: "airplane.arrival")
            }

            includedRow(.fullTransfer, icon: "car.fill")
            includedRow(.ziyaratMakkah, icon: "mappin.and.ellipse")
            if needsMadinah { includedRow(.ziyaratMadinah, icon: "mappin.and.ellipse") }
            includedRow(.careSupport, icon: "heart.fill")
            includedRow(.guide, icon: "person.wave.2.fill")
            includedRow(.visa, icon: "doc.text.fill")
            includedRow(.meals, icon: "fork.knife")
            includedRow(.esim, icon: "simcard.fill")
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5) }
    }

    private func includedRow(_ key: FlowCopy.Key, value: String? = nil, icon: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(Color.iumrahCareLight.opacity(0.22))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.iumrahCareDark)
            }
            .frame(width: 30, height: 30)

            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 22)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(FlowCopy.text(key, settings.language))
                    .font(.subheadline.weight(.semibold))
                Text(value ?? FlowCopy.text(.included, settings.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private var reassuranceCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.iumrahCareDark)
                .frame(width: 44, height: 44)
                .background(Color.iumrahCareLight.opacity(0.28), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(FlowCopy.text(.noPaymentTitle, settings.language))
                    .font(.headline)
                Text(FlowCopy.text(.noPaymentBody, settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.iumrahCareLight.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.iumrahCareLight.opacity(0.25), lineWidth: 0.7) }
    }

    private var notificationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: push.isAuthorized ? "bell.badge.fill" : "bell.badge")
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(Color.iumrahRaisedBackground, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("notifications_title", settings.language)).font(.headline)
                Text(push.statusText(language: settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if !push.isAuthorized {
                Button { Task { await push.requestAuthorization() } } label: {
                    Image(systemName: "arrow.up.right")
                        .frame(width: 36, height: 36)
                        .background(Color.iumrahRaisedBackground, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func successContent(_ session: StoredBookingSession) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareLight)
                Text(FlowCopy.text(.bookingSuccessTitle, settings.language))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(FlowCopy.text(.bookingSuccessBody, settings.language))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let pilgrimID = session.displayPilgrimID {
                    Text("ID \(pilgrimID)")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 18)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            Button {
                showCreatedBooking = true
            } label: {
                Text(FlowCopy.text(.openBooking, settings.language)).frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())

            Button {
                // Close the whole builder destination before switching tabs so the
                // next visit starts from a clean booking root instead of reopening
                // the completed flow deep in the navigation stack.
                chrome.shouldStartTripBuilder = false
                journey.resetAfterTripChange()
                chrome.navigate(to: .home)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                    Text(FlowCopy.text(.home, settings.language))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
    }

    @MainActor
    private func createBooking() async {
        guard !isSubmitting,
              let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound,
              let quote = journey.quote else { return }
        let inbound = journey.selectedInbound
        guard outbound.isVerifiedForBooking,
              (!journey.trip.isRoundTripFlight || inbound?.isVerifiedForBooking == true) else {
            errorMessage = invalidFlightSelectionMessage
            IumrahHaptics.error()
            return
        }
        if needsMadinah && journey.selectedMadinahHotel == nil { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let profile = BookingPilgrimProfile(
                firstName: settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: settings.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                telegram: settings.telegram.trimmingCharacters(in: .whitespacesAndNewlines),
                whatsapp: settings.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let session = try await bookings.create(
                trip: journey.trip,
                hotel: hotel,
                madinahHotel: journey.selectedMadinahHotel,
                room: journey.selectedRoom,
                roomCategory: journey.selectedRoomCategory,
                madinahRoom: journey.selectedMadinahRoom,
                madinahRoomCategory: journey.selectedMadinahRoomCategory,
                outbound: outbound,
                inbound: inbound,
                quote: quote,
                language: settings.language,
                pilgrimProfile: profile
            )
            createdSession = session
            if let deviceToken = push.deviceToken {
                await bookings.syncPushSubscriptions(deviceToken: deviceToken, locale: settings.language.rawValue)
            }
            IumrahHaptics.success()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }


    private var invalidFlightSelectionMessage: String {
        switch settings.language {
        case .russian: return "Перед созданием заявки выберите актуальный маршрут с ценой от Ignav. Наличие подтвердит менеджер."
        case .english: return "Select a current Ignav itinerary and fare. Availability will be confirmed by a manager."
        case .uzbek: return "Ignav joriy yo‘nalishi va narxini tanlang. Mavjudlikni menejer tasdiqlaydi."
        case .uzbekCyrillic: return "Ignav жорий йўналиши ва нархини танланг. Мавжудликни менежер тасдиқлайди."
        }
    }

    private var indicativePriceTitle: String {
        switch settings.language {
        case .russian: return "Актуальная расчётная цена"
        case .english: return "Current indicative price"
        case .uzbek: return "Joriy hisoblangan narx"
        case .uzbekCyrillic: return "Жорий ҳисобланган нарх"
        }
    }

    private func money(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }
}
