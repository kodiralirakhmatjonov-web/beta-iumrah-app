import SwiftUI

private enum FinalPackageServiceSection: Hashable {
    case outboundFlight
    case makkahHotel
    case madinahHotel
    case returnFlight
    case transfer
    case haramain
    case visa
    case meals
}

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
    @State private var showCareExplanation = false
    @State private var expandedService: FinalPackageServiceSection?

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
                    IumrahRefundPolicyCard(component: .package, compact: false)
                    IumrahManualPaymentNotice()
                    careReassuranceCard
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
        .iumrahInternalNavigation(progress: .ready, showsGeneratorAmbient: true)
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
        .sheet(isPresented: $showCareExplanation) {
            UmrahCarePackageExplanationView()
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
        case .russian: return "Собираем выбранные перелёты, отели и услуги в одну итоговую цену поездки."
        case .english: return "Combining your selected flights, hotels and services into one trip price."
        case .uzbek: return "Tanlangan reyslar, mehmonxonalar va xizmatlarni safarning yagona narxiga birlashtiramiz."
        case .uzbekCyrillic: return "Танланган рейслар, меҳмонхоналар ва хизматларни сафарнинг ягона нархига бирлаштирамиз."
        }
    }

    private var pricingUnavailableTitle: String {
        switch settings.language {
        case .russian: return "Не удалось обновить пакет"
        case .english: return "The package could not be refreshed"
        case .uzbek: return "Paketni yangilab bo‘lmadi"
        case .uzbekCyrillic: return "Пакетни янгилаб бўлмади"
        }
    }

    private var pricingUnavailableBody: String {
        switch settings.language {
        case .russian: return "Ваш выбор сохранён. Повторная проверка обновит доступность выбранных отелей и пересчитает поездку без потери маршрута."
        case .english: return "Your selections are preserved. Retry will refresh hotel availability and recalculate the trip without losing your route."
        case .uzbek: return "Tanlovlaringiz saqlanadi. Qayta tekshirish mehmonxona mavjudligini yangilaydi va yo‘nalishni yo‘qotmasdan safarni qayta hisoblaydi."
        case .uzbekCyrillic: return "Танловларингиз сақланади. Қайта текшириш меҳмонхона мавжудлигини янгилайди ва йўналишни йўқотмасдан сафарни қайта ҳисоблайди."
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
        case .russian: return "Повторно проверить пакет"
        case .english: return "Recheck package"
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
                expandableServiceRow(
                    .outboundFlight,
                    title: FlowCopy.text(.outboundFlight, settings.language),
                    subtitle: "\(outbound.airlinesSummary) · \(outbound.flightNumbersSummary)",
                    icon: "airplane.departure"
                ) {
                    flightExpandedContent(outbound)
                }
            }

            if let makkah = journey.selectedHotel {
                expandableServiceRow(
                    .makkahHotel,
                    title: FlowCopy.text(.makkahHotel, settings.language),
                    subtitle: makkah.name,
                    icon: "building.2.fill"
                ) {
                    hotelExpandedContent(makkah, cityLabel: "Makkah", roomName: journey.selectedRoom?.name ?? journey.selectedRoomCategory?.displayName)
                }
            }

            if needsMadinah, let madinah = journey.selectedMadinahHotel {
                expandableServiceRow(
                    .madinahHotel,
                    title: FlowCopy.text(.madinahHotel, settings.language),
                    subtitle: madinah.name,
                    icon: "building.2.fill"
                ) {
                    hotelExpandedContent(madinah, cityLabel: "Madinah", roomName: journey.selectedMadinahRoom?.name ?? journey.selectedMadinahRoomCategory?.displayName)
                }
            }

            if let inbound = journey.selectedInbound {
                expandableServiceRow(
                    .returnFlight,
                    title: FlowCopy.text(.returnFlight, settings.language),
                    subtitle: "\(inbound.airlinesSummary) · \(inbound.flightNumbersSummary)",
                    icon: "airplane.arrival"
                ) {
                    flightExpandedContent(inbound)
                }
            }

            expandableServiceRow(
                .transfer,
                title: FlowCopy.text(.fullTransfer, settings.language),
                subtitle: journey.selectedTransferVehicle?.modelName ?? "Kia Carnival",
                icon: "car.fill"
            ) {
                transferExpandedContent
            }

            if journey.haramainTrainSelected {
                expandableServiceRow(
                    .haramain,
                    title: "Haramain High Speed Railway",
                    subtitle: haramainIncludedSubtitle,
                    customImage: "HaramainMark"
                ) {
                    haramainExpandedContent
                }
            }

            staticIncludedRow(.ziyaratMakkah, icon: "mappin.and.ellipse")
            if needsMadinah { staticIncludedRow(.ziyaratMadinah, icon: "mappin.and.ellipse") }
            staticIncludedRow(.careSupport, icon: "heart.fill")
            staticIncludedRow(.guide, icon: "person.2.fill")

            expandableServiceRow(
                .visa,
                title: FlowCopy.text(.visa, settings.language),
                subtitle: FlowCopy.text(.included, settings.language),
                icon: "doc.text.fill"
            ) {
                visaExpandedContent
            }

            expandableServiceRow(
                .meals,
                title: FlowCopy.text(.meals, settings.language),
                subtitle: mealsSummary,
                icon: "fork.knife"
            ) {
                mealsExpandedContent
            }

            esimIncludedRow
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5) }
    }

    @ViewBuilder
    private func expandableServiceRow<Content: View>(
        _ section: FinalPackageServiceSection,
        title: String,
        subtitle: String,
        icon: String? = nil,
        customImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let expanded = expandedService == section

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.90)) {
                    expandedService = expanded ? nil : section
                }
                IumrahHaptics.selection()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    IumrahIconBadge(
                        systemName: "checkmark",
                        role: .success,
                        size: 30,
                        symbolSize: 12,
                        shape: .circle
                    )

                    if let customImage {
                        Image(customImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else if let icon {
                        IumrahInlineIcon(systemName: icon, size: 15)
                            .frame(width: 22)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(expanded ? 3 : 2)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.iumrahRaisedBackground, in: Circle())
                }
                .contentShape(Rectangle())
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.leading, 42)
                content()
                    .padding(.leading, 42)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func staticIncludedRow(_ key: FlowCopy.Key, value: String? = nil, icon: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            IumrahIconBadge(systemName: "checkmark", role: .success, size: 30, symbolSize: 12, shape: .circle)
            IumrahInlineIcon(systemName: icon, size: 15)
                .frame(width: 22)
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

    private func flightExpandedContent(_ offer: FlightOffer) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.origin)
                        .font(.title3.weight(.bold))
                    Text(shortFlightDate(offer.departureAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shortFlightTime(offer.departureAt))
                        .font(.headline.monospacedDigit())
                }

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.system(size: 17, weight: .semibold))
                    Text(durationText(offer.durationMinutes))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 3)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(offer.destination)
                        .font(.title3.weight(.bold))
                    Text(shortFlightDate(offer.arrivalAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(shortFlightTime(offer.arrivalAt))
                        .font(.headline.monospacedDigit())
                }
            }

            HStack(spacing: 8) {
                bookingDetailChip(icon: "airplane.circle", text: offer.stops == 0 ? directFlightTitle : "\(offer.stops) stop")
                if let rawCabin = offer.cabinClass {
                    let cabin = rawCabin.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cabin.isEmpty {
                        bookingDetailChip(icon: "seat.recline.normal", text: cabin)
                    }
                }
                if let checked = offer.baggage?.checked {
                    bookingDetailChip(icon: "suitcase.fill", text: "\(checked) kg")
                }
            }

            if let segments = offer.segments, segments.count > 1 {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(segments) { segment in
                        HStack {
                            Text("\(segment.origin.code) → \(segment.destination.code)")
                                .font(.caption.weight(.bold))
                            Spacer()
                            Text("\(segment.airline) · \(segment.flightNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func hotelExpandedContent(_ hotel: HotelSummary, cityLabel: String, roomName: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                HotelCachedImage(rawURL: hotel.coverImageURL, placeholderSystemName: "building.2.fill")
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(hotel.name).font(.headline)
                    Text(cityLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let stars = hotel.stars {
                    Label("\(stars)", systemImage: "star.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
            }

            if let roomName, !roomName.isEmpty {
                bookingDetailChip(icon: "bed.double.fill", text: roomName)
            }
        }
    }

    private var transferExpandedContent: some View {
        let vehicle = journey.selectedTransferVehicle ?? .carnival
        return VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(vehicle == .yukon ? Color.black : Color.iumrahRaisedBackground)
                if vehicle == .yukon {
                    RadialGradient(colors: [.white.opacity(0.55), .white.opacity(0.12), .clear], center: .center, startRadius: 8, endRadius: 150)
                }
                Image(vehicle.assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            }
            .frame(height: 180)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.modelName).font(.headline)
                    Text(vehicle == .yukon ? "VIP Transfer" : "iumrah Transfer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                bookingDetailChip(icon: "person.2.fill", text: "\(journey.trip.travelerCount)/\(vehicle.passengerCapacity)")
            }

            transferRouteSummary
        }
    }

    private var transferRouteSummary: some View {
        HStack(spacing: 0) {
            bookingRouteStop("airplane.arrival", label: journey.trip.arrivalAirport.rawValue)
            bookingRouteLine
            bookingRouteStop("building.2.fill", label: "Makkah")
            if needsMadinah {
                bookingRouteLine
                bookingRouteStop(journey.haramainTrainSelected ? "train.side.front.car" : "car.fill", label: journey.haramainTrainSelected ? "Train" : "Intercity")
                bookingRouteLine
                bookingRouteStop("building.2.fill", label: "Madinah")
            }
            bookingRouteLine
            bookingRouteStop("airplane.departure", label: journey.trip.returnOriginCode)
        }
        .padding(12)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var haramainExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(["HaramainHero", "HaramainGalleryStation", "HaramainGalleryInterior", "HaramainGalleryTrain"], id: \.self) { name in
                        Image(name)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 210, height: 125)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }

            HStack(spacing: 8) {
                bookingDetailChip(icon: "speedometer", text: "300 km/h")
                bookingDetailChip(icon: "clock.fill", text: "≈ 2h 20m")
                bookingDetailChip(icon: "wifi", text: "Wi‑Fi")
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Standard").font(.subheadline.weight(.bold))
                    Text("\(max(1, journey.haramainTicketCount)) × $150")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("+$\(haramainAmountNumber)")
                    .font(.headline.monospacedDigit())
            }
        }
    }

    private var visaExpandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(visaMultipleEntryTitle, systemImage: "checkmark.seal.fill")
                .font(.headline)
            Text(visaExplanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                bookingDetailChip(icon: "calendar", text: visaOneYearTitle)
                bookingDetailChip(icon: "arrow.triangle.2.circlepath", text: visaMultipleTitle)
                bookingDetailChip(icon: "clock", text: visaNinetyDaysTitle)
            }
        }
        .padding(14)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var mealsExpandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(mealGalleryURLs, id: \.absoluteString) { url in
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            default:
                                ZStack {
                                    LinearGradient(colors: [Color.orange.opacity(0.18), Color.iumrahRaisedBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    Image(systemName: "fork.knife.circle.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 205, height: 132)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }

            HStack(spacing: 8) {
                mealCountPill(city: localizedMealCity(.makkah), count: makkahMealCount)
                if needsMadinah { mealCountPill(city: localizedMealCity(.madinah), count: madinahMealCount) }
            }

            Text(mealsExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func bookingDetailChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func bookingRouteStop(_ icon: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(label).font(.caption2.weight(.semibold)).lineLimit(1)
        }
        .frame(minWidth: 46)
    }

    private var bookingRouteLine: some View {
        Capsule().fill(Color.primary.opacity(0.18)).frame(width: 18, height: 2).offset(y: -8)
    }

    private func mealCountPill(city: String, count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "fork.knife")
            Text("\(city) · \(count)×")
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private var mealGalleryURLs: [URL] {
        [
            "https://images.unsplash.com/photo-1679312061521-d7d619a8cfb7?auto=format&fit=crop&w=900&q=78",
            "https://images.unsplash.com/photo-1679312182375-28464cfc00d7?auto=format&fit=crop&w=900&q=78",
            "https://images.unsplash.com/photo-1760594308930-06b631dd916b?auto=format&fit=crop&w=900&q=78"
        ].compactMap { URL(string: $0) }
    }

    private var mealsSummary: String {
        if needsMadinah {
            return localizedFinal(
                "Мекка · \(russianMealsPerDay(makkahMealCount)) · Медина · \(russianMealsPerDay(madinahMealCount))",
                "Makkah · \(makkahMealCount) meals/day · Madinah · \(madinahMealCount) meals/day",
                "Makka · kuniga \(makkahMealCount) mahal · Madina · kuniga \(madinahMealCount) mahal",
                "Макка · кунига \(makkahMealCount) маҳал · Мадина · кунига \(madinahMealCount) маҳал"
            )
        }
        return localizedFinal(
            "Мекка · \(russianMealsPerDay(makkahMealCount))",
            "Makkah · \(makkahMealCount) meals/day",
            "Makka · kuniga \(makkahMealCount) mahal",
            "Макка · кунига \(makkahMealCount) маҳал"
        )
    }

    private var mealsExplanation: String {
        if journey.hasSelectableHotelMeals {
            return localizedFinal(
                "Завтрак включён без доплаты. В цену пакета входят только выбранные Вами обеды и ужины; отключённые позиции сразу исключаются из расчёта.",
                "Breakfast is included at no extra charge. Only the lunches and dinners you selected are included in the package price; disabled items are removed from pricing immediately.",
                "Nonushta qo‘shimcha to‘lovsiz kiritilgan. Paket narxiga faqat Siz tanlagan tushlik va kechki ovqatlar kiradi; o‘chirilgan variantlar hisobdan darhol chiqariladi.",
                "Нонушта қўшимча тўловсиз киритилган. Пакет нархига фақат Сиз танлаган тушлик ва кечки овқатлар киради; ўчирилган вариантлар ҳисобдан дарҳол чиқарилади."
            )
        }
        return localizedFinal(
            "Питание включено в программу пакета. Конкретные рестораны и время приёмов пищи подтверждаются в деталях поездки.",
            "Meals are included in the package program. Specific restaurants and meal times are confirmed in your trip details.",
            "Ovqatlanish paket dasturiga kiritilgan. Aniq restoranlar va vaqtlar safar tafsilotlarida tasdiqlanadi.",
            "Овқатланиш пакет дастурига киритилган. Аниқ ресторанлар ва вақтлар сафар тафсилотларида тасдиқланади."
        )
    }

    private func russianMealsPerDay(_ count: Int) -> String {
        count == 1 ? "1 раз в день" : "\(count) раза в день"
    }

    private var makkahMealCount: Int {
        guard journey.hasSelectableHotelMeals else { return 3 }
        var count = 1 // Breakfast is always included.
        if journey.isMealEnabled(.lunch, city: .makkah) { count += 1 }
        if journey.isMealEnabled(.dinner, city: .makkah) { count += 1 }
        return count
    }

    private var madinahMealCount: Int {
        guard journey.hasSelectableHotelMeals else { return 2 }
        var count = 1 // Breakfast is always included; Madinah has no lunch option.
        if journey.isMealEnabled(.dinner, city: .madinah) { count += 1 }
        return count
    }

    private func localizedMealCity(_ city: HotelMealCity) -> String {
        switch (settings.language, city) {
        case (.russian, .makkah): return "Мекка"
        case (.russian, .madinah): return "Медина"
        case (.english, .makkah): return "Makkah"
        case (.english, .madinah): return "Madinah"
        case (.uzbek, .makkah): return "Makka"
        case (.uzbek, .madinah): return "Madina"
        case (.uzbekCyrillic, .makkah): return "Макка"
        case (.uzbekCyrillic, .madinah): return "Мадина"
        }
    }

    private var directFlightTitle: String { localizedFinal("Прямой", "Direct", "To‘g‘ridan-to‘g‘ri", "Тўғридан-тўғри") }

    private var haramainIncludedSubtitle: String {
        let tickets = max(1, journey.haramainTicketCount)
        return localizedFinal("Мекка ↔ Медина · Standard · \(tickets) бил.", "Makkah ↔ Madinah · Standard · \(tickets) tickets", "Makka ↔ Madina · Standard · \(tickets) chipta", "Макка ↔ Мадина · Standard · \(tickets) чипта")
    }

    private var haramainAmountNumber: String {
        let value = NSDecimalNumber(decimal: journey.haramainTrainAddOnUsd).doubleValue
        return String(format: "%.0f", value)
    }

    private func shortFlightDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private func shortFlightTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func durationText(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private var visaMultipleEntryTitle: String { localizedFinal("Туристическая eVisa", "Tourist eVisa", "Turistik eVisa", "Туристик eVisa") }
    private var visaOneYearTitle: String { localizedFinal("1 год", "1 year", "1 yil", "1 йил") }
    private var visaMultipleTitle: String { localizedFinal("Многократный въезд", "Multiple entry", "Ko‘p martalik kirish", "Кўп марталик кириш") }
    private var visaNinetyDaysTitle: String { localizedFinal("до 90 дней", "up to 90 days", "90 kungacha", "90 кунгача") }
    private var visaExplanation: String {
        localizedFinal(
            "Электронная туристическая виза Саудовской Аравии действует один год с даты выдачи и предусматривает многократный въезд, если в самой визе не указано иное. Максимальный разрешённый срок пребывания по eVisa — до 90 дней.",
            "Saudi Arabia's tourist eVisa is valid for one year from issuance and permits multiple entries unless the issued visa states otherwise. The maximum permitted stay under the eVisa is up to 90 days.",
            "Saudiya Arabistonining turistik eVisa-si berilgan kundan boshlab bir yil amal qiladi va vizada boshqacha ko‘rsatilmagan bo‘lsa, ko‘p martalik kirishga ruxsat beradi. eVisa bo‘yicha maksimal qolish muddati 90 kungacha.",
            "Саудия Арабистонининг туристик eVisa-си берилган кундан бошлаб бир йил амал қилади ва визада бошқача кўрсатилмаган бўлса, кўп марталик киришга рухсат беради. eVisa бўйича максимал қолиш муддати 90 кунгача."
        )
    }

    private func localizedFinal(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var esimIncludedRow: some View {
        HStack(alignment: .center, spacing: 12) {
            IumrahIconBadge(
                systemName: "checkmark",
                role: .success,
                size: 30,
                symbolSize: 12,
                shape: .circle
            )

            Image("UmrahMobileLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("iumrah Mobile eSIM")
                    .font(.subheadline.weight(.semibold))
                Text(FlowCopy.text(.included, settings.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private var careReassuranceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("CarePriceSupport")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color.black)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 5) {
                    IumrahInlineIcon(systemName: "heart.fill", role: .care, size: 11)
                    Text("iumrah Care")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(IumrahIconRole.care.color)

                Text(careCardTitle)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Text(careCardBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showCareExplanation = true
                    IumrahHaptics.soft()
                } label: {
                    HStack {
                        Text(careHowItWorks)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var careCardTitle: String {
        switch settings.language {
        case .russian: return "Мы проверим баланс цены и маршрута"
        case .english: return "We review the balance between price and itinerary"
        case .uzbek: return "Narx va yo‘nalish muvozanatini tekshiramiz"
        case .uzbekCyrillic: return "Нарх ва йўналиш мувозанатини текширамиз"
        }
    }

    private var careCardBody: String {
        switch settings.language {
        case .russian: return "Если текущая цена выше ожидаемой или даты гибкие, специалисты iumrah Care дополнительно проверят более удобные прямые рейсы, логичное распределение ночей и отели ближе к ключевым местам — без потери качества поездки."
        case .english: return "If the current price is higher than expected or your dates are flexible, iumrah Care will review more convenient direct flights, sensible night allocation and closer hotels without compromising the journey."
        case .uzbek: return "Agar joriy narx kutilganidan yuqori bo‘lsa yoki sanalaringiz moslashuvchan bo‘lsa, iumrah Care qulayroq to‘g‘ridan-to‘g‘ri reyslar, tunlarning mantiqiy taqsimoti va yaqinroq mehmonxonalarni qo‘shimcha tekshiradi."
        case .uzbekCyrillic: return "Агар жорий нарх кутилганидан юқори бўлса ёки саналарингиз мослашувчан бўлса, iumrah Care қулайроқ тўғридан-тўғри рейслар, тунларнинг мантиқий тақсимоти ва яқинроқ меҳмонхоналарни қўшимча текширади."
        }
    }

    private var careHowItWorks: String {
        switch settings.language {
        case .russian: return "Как это работает"
        case .english: return "How it works"
        case .uzbek: return "Qanday ishlaydi"
        case .uzbekCyrillic: return "Қандай ишлайди"
        }
    }

    private var notificationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(
                systemName: push.isAuthorized ? "bell.badge.fill" : "bell.badge",
                role: .notification,
                size: 42,
                symbolSize: 18,
                shape: .circle
            )
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
                        .contentShape(Circle())
                        .iumrahGlass(in: Circle(), interactive: true)
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
                intercityTransport: needsMadinah ? (journey.haramainTrainSelected ? .haramainTrain : .road) : nil,
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
        case .russian: return "Выберите актуальный маршрут. Система автоматически свяжет его с вашим Umrah-пакетом."
        case .english: return "Select a current itinerary. The system will automatically connect it to your Umrah package."
        case .uzbek: return "Joriy yo‘nalishni tanlang. Tizim uni Umra paketingiz bilan avtomatik bog‘laydi."
        case .uzbekCyrillic: return "Жорий йўналишни танланг. Тизим уни Умра пакетингиз билан автоматик боғлайди."
        }
    }

    private var indicativePriceTitle: String {
        switch settings.language {
        case .russian: return "Цена вашего Umrah-пакета"
        case .english: return "Your Umrah package price"
        case .uzbek: return "Umra paketingiz narxi"
        case .uzbekCyrillic: return "Умра пакетингиз нархи"
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
