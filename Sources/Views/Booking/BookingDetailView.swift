import SwiftUI

struct BookingDetailView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String

    @State private var outboundExpanded = false
    @State private var inboundExpanded = false
    @State private var makkahHotelExpanded = false
    @State private var madinahHotelExpanded = false
    @State private var showMakkahHotelChange = false
    @State private var showMadinahHotelChange = false
    @State private var showContactEdit = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var ziyaratMakkah = true
    @State private var ziyaratMadinah = false
    @State private var isSavingZiyarat = false
    @State private var mutationError: String?
    @State private var isRequestingConfirmation = false
    @State private var confirmationSent = false

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        Group {
            if let session {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        statusHero(session)
                        bookingMetaCard(session.booking)
                        BookingItineraryCalendarView(
                            bookingID: session.id,
                            startDate: session.booking.input.startDate,
                            endDate: session.booking.input.endDate
                        )

                        BookingFlightDisclosureCard(
                            title: L10n.text("booking_outbound_flight", settings.language),
                            route: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)",
                            date: session.booking.input.startDate,
                            fallbackFlight: outboundFallback(session),
                            offer: session.outboundFlight,
                            isExpanded: $outboundExpanded
                        )

                        BookingFlightDisclosureCard(
                            title: L10n.text("booking_return_flight", settings.language),
                            route: "\(session.booking.route.returnOrigin) → \(session.booking.route.originCode)",
                            date: session.booking.input.endDate,
                            fallbackFlight: inboundFallback(session),
                            offer: session.inboundFlight,
                            isExpanded: $inboundExpanded
                        )

                        hotelCard(session, role: .makkah, isExpanded: $makkahHotelExpanded)

                        if session.booking.input.includeMadinah {
                            hotelCard(session, role: .madinah, isExpanded: $madinahHotelExpanded)
                        }

                        transferCard(session)
                        guideCard(session)
                        ziyaratCard(session)
                        contactCard(session)

                        if session.pendingChangeConfirmation == true || confirmationSent {
                            confirmationCard(session)
                        }

                        careAction
                        destructiveActions
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 56)
                }
                .background(Color.iumrahPageBackground)
                .task {
                    await bookings.refreshAll()
                    await bookings.syncHotelSelectionIfNeeded(bookingID: bookingID)
                    loadZiyaratDraft()
                }
                .sheet(isPresented: $showMakkahHotelChange) {
                    BookingHotelChangeView(bookingID: bookingID, role: .makkah)
                        .environmentObject(settings)
                        .environmentObject(bookings)
                }
                .sheet(isPresented: $showMadinahHotelChange) {
                    BookingHotelChangeView(bookingID: bookingID, role: .madinah)
                        .environmentObject(settings)
                        .environmentObject(bookings)
                }
                .sheet(isPresented: $showContactEdit) {
                    BookingContactEditSheet(
                        bookingID: bookingID,
                        telegram: session.telegram ?? "",
                        whatsapp: session.whatsapp ?? ""
                    )
                    .environmentObject(settings)
                    .environmentObject(bookings)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(L10n.text("detail_not_found", settings.language))
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.iumrahPageBackground)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .confirmationDialog(
            L10n.text("booking_delete_confirm_title", settings.language),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("booking_delete_confirm_action", settings.language), role: .destructive) {
                Task { await deleteBooking() }
            }
            Button(L10n.text("cancel", settings.language), role: .cancel) {}
        } message: {
            Text(L10n.text("booking_delete_confirm_body", settings.language))
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                IumrahHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("booking_detail_title", settings.language))
                    .font(.headline)
                if let session {
                    HStack(spacing: 7) {
                        Text("Бронь \(session.displayBookingNumber)")
                        if let pilgrimID = session.displayPilgrimID {
                            Text("·")
                            Text("Iumrah ID \(pilgrimID)")
                        }
                    }
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func outboundFallback(_ session: StoredBookingSession) -> String {
        if let trace = session.booking.generatorTrace?.outbound {
            let value = [trace.airline, trace.flightNumbers].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " · ")
            if !value.isEmpty { return value }
        }
        return session.booking.flight
    }

    private func inboundFallback(_ session: StoredBookingSession) -> String {
        if let trace = session.booking.generatorTrace?.inbound {
            let value = [trace.airline, trace.flightNumbers].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " · ")
            if !value.isEmpty { return value }
        }
        return session.booking.flight
    }

    private func statusHero(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.travelerName ?? L10n.text("booking_your_trip", settings.language))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(L10n.status(session.effectiveStatus, settings.language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: statusIcon(session.effectiveStatus))
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Circle())
            }

            Text(L10n.text("detail_updates", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if shouldShowCheckoutEntry(for: session) {
                NavigationLink {
                    PilgrimCheckoutView(bookingID: bookingID)
                } label: {
                    HStack(spacing: 13) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 42, height: 42)

                            Image(systemName: "person.text.rectangle.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(checkoutCTA)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Text(checkoutCTASubtitle)
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(checkoutCTA)
            } else if ["BOOKING_CONFIRMED", "READY_TO_TRAVEL", "IN_TRIP"].contains(session.effectiveStatus) {
                NavigationLink {
                    PilgrimCheckoutView(bookingID: bookingID)
                } label: {
                    HStack {
                        Label(tripDocumentsTitle, systemImage: "doc.text.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func shouldShowCheckoutEntry(for session: StoredBookingSession) -> Bool {
        let candidates = [
            session.effectiveStatus,
            session.operationStatus ?? "",
            session.booking.status
        ]

        return candidates.contains { raw in
            let normalized = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "-", with: "_")
                .uppercased()

            return [
                "PAYMENT_PENDING",
                "PENDING_PAYMENT",
                "WAITING_PAYMENT",
                "AWAITING_PAYMENT",
                "PAYMENT_AND_DATA_PENDING",
                "AWAITING_PAYMENT_AND_DATA"
            ].contains(normalized)
        }
    }

    private var checkoutCTA: String {
        switch settings.language {
        case .russian: return "Заполнить данные и оплатить"
        case .english: return "Complete details and pay"
        case .uzbek: return "Ma’lumotlarni to‘ldirish va to‘lash"
        case .uzbekCyrillic: return "Маълумотларни тўлдириш ва тўлаш"
        }
    }

    private var checkoutCTASubtitle: String {
        switch settings.language {
        case .russian: return "iumrah ID · анкеты · реквизиты · чек"
        case .english: return "iumrah ID · pilgrim forms · payment · receipt"
        case .uzbek: return "iumrah ID · anketalar · to‘lov · chek"
        case .uzbekCyrillic: return "iumrah ID · анкеталар · тўлов · чек"
        }
    }

    private var tripDocumentsTitle: String {
        switch settings.language {
        case .russian: return "Данные и документы поездки"
        case .english: return "Trip details and documents"
        case .uzbek: return "Safar ma’lumotlari va hujjatlar"
        case .uzbekCyrillic: return "Сафар маълумотлари ва ҳужжатлар"
        }
    }

    private func bookingMetaCard(_ booking: RemoteBooking) -> some View {
        VStack(spacing: 13) {
            summaryRow(
                title: L10n.text("detail_dates", settings.language),
                value: "\(L10n.date(booking.input.startDate, settings.language)) — \(L10n.date(booking.input.endDate, settings.language))"
            )
            summaryRow(
                title: L10n.text("travelers", settings.language),
                value: "\(booking.input.travelers.totalPeople)"
            )
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("booking_total_package", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("booking_all_in_one_price", settings.language))
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                PackagePriceView(amount: Decimal(booking.totalUsd), currency: "USD", showsPerPerson: false)
            }
        }
        .iumrahCard()
    }

    private func hotelCard(_ session: StoredBookingSession, role: HotelSelectionRole, isExpanded: Binding<Bool>) -> some View {
        let snapshot = role == .madinah ? session.madinahHotelSelection : session.hotelSelection
        let hotelName = snapshot?.hotelName ?? (role == .madinah ? session.booking.hotelNames.madinah : session.booking.hotelNames.makkah)
        let roomDisplayName = snapshot?.roomCategory.map { L10n.text($0.titleKey, settings.language) } ?? snapshot?.roomName
        let title = role == .madinah ? L10n.text("booking_madinah_hotel", settings.language) : L10n.text("booking_makkah_hotel", settings.language)
        let nights: Int? = role == .madinah ? session.booking.stay.madinahNights : session.booking.stay.makkahNights

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    AsyncImage(url: AppConfig.absoluteURL(snapshot?.coverImageURL)) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default:
                            ZStack {
                                Color.iumrahRaisedBackground
                                Image(systemName: role == .madinah ? "moon.stars.fill" : "building.2.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(hotelName.isEmpty ? L10n.text("booking_hotel_pending", settings.language) : hotelName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    if let roomDisplayName, !roomDisplayName.isEmpty {
                        Label(roomDisplayName, systemImage: "bed.double.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if let nights, nights > 0 {
                    servicePill(icon: "moon.fill", text: L10n.format("booking_nights_count", settings.language, nights))
                }
                if let city = snapshot?.city, !city.isEmpty {
                    servicePill(icon: "mappin", text: L10n.city(city, settings.language))
                }
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(isExpanded.wrappedValue ? L10n.text("collapse", settings.language) : L10n.text("expand", settings.language))
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(spacing: 10) {
                    if let beds = snapshot?.roomBeds, !beds.isEmpty {
                        summaryRow(title: L10n.text("room_beds", settings.language), value: beds)
                    }
                    if let size = snapshot?.roomSizeM2 {
                        summaryRow(title: L10n.text("room_area", settings.language), value: L10n.format("room_size", settings.language, size))
                    }
                    if let guests = snapshot?.roomMaxGuests {
                        summaryRow(title: L10n.text("room_capacity", settings.language), value: L10n.format("room_sleeps", settings.language, guests))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                if role == .madinah { showMadinahHotelChange = true }
                else { showMakkahHotelChange = true }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(L10n.text("booking_change_hotel", settings.language))
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .iumrahCard()
    }

    private func transferCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            serviceHeader(
                icon: "car.side.fill",
                title: L10n.text("booking_transfer_title", settings.language),
                subtitle: L10n.text("booking_transfer_body", settings.language),
                badge: L10n.text("booking_included", settings.language)
            )

            VStack(spacing: 11) {
                serviceRouteRow(icon: "airplane.arrival", text: L10n.format("booking_transfer_arrival", settings.language, session.booking.input.arrivalAirportCode))
                serviceRouteRow(icon: "building.2.fill", text: L10n.text("booking_transfer_makkah", settings.language))
                if session.booking.input.includeMadinah {
                    serviceRouteRow(icon: "arrow.left.arrow.right", text: L10n.text("booking_transfer_intercity", settings.language))
                    serviceRouteRow(icon: "moon.stars.fill", text: L10n.text("booking_transfer_madinah", settings.language))
                }
                if currentZiyaratMakkah(session) || currentZiyaratMadinah(session) {
                    serviceRouteRow(icon: "sparkles", text: L10n.text("booking_transfer_ziyarat", settings.language))
                }
                serviceRouteRow(icon: "airplane.departure", text: L10n.format("booking_transfer_departure", settings.language, session.booking.route.returnOrigin))
            }
        }
        .iumrahCard()
    }

    private func guideCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            serviceHeader(
                icon: "person.badge.shield.checkmark.fill",
                title: L10n.text("booking_guide_title", settings.language),
                subtitle: session.guide == nil ? L10n.text("booking_guide_pending", settings.language) : L10n.text("booking_guide_assigned", settings.language),
                badge: nil
            )

            if let guide = session.guide {
                VStack(alignment: .leading, spacing: 8) {
                    Text(guide.displayName)
                        .font(.title3.weight(.bold))
                    if !guide.roleTitle.isEmpty {
                        Text(guide.roleTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !guide.whatsapp.isEmpty {
                        summaryRow(title: "WhatsApp", value: guide.whatsapp)
                    } else if !guide.phoneSA.isEmpty {
                        summaryRow(title: L10n.text("booking_phone", settings.language), value: guide.phoneSA)
                    } else if !guide.phoneUZ.isEmpty {
                        summaryRow(title: L10n.text("booking_phone", settings.language), value: guide.phoneUZ)
                    }
                }
                .padding(15)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Text(L10n.text("booking_guide_care_note", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    private func ziyaratCard(_ session: StoredBookingSession) -> some View {
        let savedMakkah = currentZiyaratMakkah(session)
        let savedMadinah = currentZiyaratMadinah(session)
        let hasChanges = ziyaratMakkah != savedMakkah || ziyaratMadinah != savedMadinah

        return VStack(alignment: .leading, spacing: 16) {
            serviceHeader(
                icon: "sparkles",
                title: L10n.text("booking_ziyarat_title", settings.language),
                subtitle: L10n.text("booking_ziyarat_body", settings.language),
                badge: nil
            )

            Toggle(isOn: $ziyaratMakkah) {
                Label(L10n.text("booking_ziyarat_makkah", settings.language), systemImage: "building.columns.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(Color.iumrahCareLight)

            if session.booking.input.includeMadinah {
                Divider()
                Toggle(isOn: $ziyaratMadinah) {
                    Label(L10n.text("booking_ziyarat_madinah", settings.language), systemImage: "moon.stars.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Color.iumrahCareLight)
            }

            if hasChanges {
                Button {
                    Task { await saveZiyarat() }
                } label: {
                    HStack {
                        if isSavingZiyarat { ProgressView().tint(.primary) }
                        Text(L10n.text("booking_save_changes", settings.language))
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
                .disabled(isSavingZiyarat)
            }

            if let mutationError {
                Text(mutationError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    private func contactCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.text("booking_contacts", settings.language))
                    .font(.headline)
                Spacer()
                Button {
                    showContactEdit = true
                } label: {
                    Label(L10n.text("booking_contact_edit", settings.language), systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let telegram = session.telegram, !telegram.isEmpty {
                summaryRow(title: "Telegram", value: telegram)
            }
            if let whatsapp = session.whatsapp, !whatsapp.isEmpty {
                summaryRow(title: "WhatsApp", value: whatsapp)
            }
            if (session.telegram ?? "").isEmpty && (session.whatsapp ?? "").isEmpty {
                Text(L10n.text("booking_contact_empty", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func confirmationCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: confirmationSent ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 27, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text(confirmationSent ? L10n.text("booking_request_sent", settings.language) : L10n.text("booking_changes_pending_title", settings.language))
                        .font(.headline)
                    Text(L10n.text("booking_changes_pending_body", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if session.pendingChangeConfirmation == true {
                Button {
                    Task { await requestConfirmation() }
                } label: {
                    HStack {
                        if isRequestingConfirmation { ProgressView().tint(.white) }
                        Text(L10n.text("booking_request_confirmation", settings.language))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isRequestingConfirmation)
            }
        }
        .padding(18)
        .background(Color.iumrahCareLight.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.iumrahCareLight.opacity(0.28), lineWidth: 1)
        }
    }

    private var careAction: some View {
        NavigationLink {
            BookingChatView(bookingID: bookingID)
        } label: {
            HStack(spacing: 15) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .padding(9)
                    .frame(width: 58, height: 58)
                    .background(.white, in: Circle())
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("iumrah Care")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(L10n.text("booking_care_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text("booking_open_care", settings.language))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 2)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.iumrahCareDark.opacity(0.96), Color.iumrahCareLight.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var destructiveActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let deleteError {
                Text(deleteError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    if isDeleting { ProgressView().tint(.red) }
                    Text(L10n.text("booking_cancel_and_delete", settings.language))
                    Spacer()
                    Image(systemName: "trash")
                }
                .font(.headline)
                .foregroundStyle(.red)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Color.red.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .disabled(isDeleting)
        }
    }

    private func serviceHeader(icon: String, title: String, subtitle: String, badge: String?) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(Color.iumrahCareLight.opacity(0.16), in: Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func serviceRouteRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.iumrahRaisedBackground, in: Circle())
            Text(text)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.iumrahCareLight)
        }
    }

    private func servicePill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func currentZiyaratMakkah(_ session: StoredBookingSession) -> Bool {
        session.ziyaratMakkahOverride ?? session.booking.customization?.ziyaratMakkah ?? true
    }

    private func currentZiyaratMadinah(_ session: StoredBookingSession) -> Bool {
        session.ziyaratMadinahOverride ?? session.booking.customization?.ziyaratMadinah ?? session.booking.input.includeMadinah
    }

    private func loadZiyaratDraft() {
        guard let session else { return }
        ziyaratMakkah = currentZiyaratMakkah(session)
        ziyaratMadinah = currentZiyaratMadinah(session)
    }

    @MainActor
    private func saveZiyarat() async {
        guard !isSavingZiyarat else { return }
        isSavingZiyarat = true
        mutationError = nil
        defer { isSavingZiyarat = false }
        do {
            try await bookings.updateZiyarat(
                bookingID: bookingID,
                makkah: ziyaratMakkah,
                madinah: session?.booking.input.includeMadinah == true ? ziyaratMadinah : false
            )
            IumrahHaptics.success()
        } catch {
            mutationError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func requestConfirmation() async {
        guard !isRequestingConfirmation else { return }
        isRequestingConfirmation = true
        mutationError = nil
        defer { isRequestingConfirmation = false }
        do {
            try await bookings.requestChangeConfirmation(
                bookingID: bookingID,
                message: L10n.text("booking_change_confirmation_message", settings.language)
            )
            confirmationSent = true
            IumrahHaptics.success()
        } catch {
            mutationError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func deleteBooking() async {
        guard !isDeleting else { return }
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            try await bookings.deleteBooking(id: bookingID)
            IumrahHaptics.success()
            dismiss()
        } catch {
            deleteError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }
}

private struct BookingContactEditSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String
    @State private var telegram: String
    @State private var whatsapp: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(bookingID: String, telegram: String, whatsapp: String) {
        self.bookingID = bookingID
        _telegram = State(initialValue: telegram)
        _whatsapp = State(initialValue: whatsapp)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.text("booking_contact_edit_title", settings.language))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(L10n.text("booking_contact_edit_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Telegram", text: $telegram)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    TextField("WhatsApp", text: $whatsapp)
                        .keyboardType(.phonePad)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(L10n.text("booking_save_changes", settings.language))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isSaving || (telegram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && whatsapp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                Spacer()
            }
            .padding(20)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.iumrahRaisedBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await bookings.updateContacts(bookingID: bookingID, telegram: telegram, whatsapp: whatsapp)
            IumrahHaptics.success()
            dismiss()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }
}

private struct BookingFlightDisclosureCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let title: String
    let route: String
    let date: String
    let fallbackFlight: String
    let offer: FlightOffer?
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 13) {
                    AirlineLogoView(airlineCode: offer?.primaryAirlineCode ?? fallbackAirlineCode, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(route)
                            .font(.title3.weight(.bold))
                        Text(offer.map { "\($0.airlinesSummary) · \($0.flightNumbersSummary)" } ?? fallbackFlight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Text(L10n.date(date, settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isExpanded ? L10n.text("collapse", settings.language) : L10n.text("expand", settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                Divider()
                if let offer {
                    offerDetails(offer)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(fallbackFlight)
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.text("booking_legacy_flight_note", settings.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .iumrahCard()
    }

    private var fallbackAirlineCode: String? {
        let pattern = #"\b([A-Z0-9]{2})[\s-]?\d{1,4}\b"#
        guard let range = fallbackFlight.uppercased().range(of: pattern, options: .regularExpression) else { return nil }
        let match = String(fallbackFlight.uppercased()[range])
        return FlightReferenceCatalog.airlineCode(from: match)
    }

    private func offerDetails(_ offer: FlightOffer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(offer.displaySegments.enumerated()), id: \.element.id) { index, segment in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(FlightReferenceCatalog.airlineName(code: segment.airlineCode, fallback: segment.airline)) · \(segment.flightNumber)")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(durationText(segment.durationMinutes))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(segment.origin.code)
                                .font(.title3.weight(.bold))
                            Text(segment.origin.displayCity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "airplane")
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(segment.destination.code)
                                .font(.title3.weight(.bold))
                            Text(segment.destination.displayCity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text(time(segment.departureAt, zone: segment.origin.timeZoneIdentifier))
                        Spacer()
                        Text(time(segment.arrivalAt, zone: segment.destination.timeZoneIdentifier))
                    }
                    .font(.subheadline.monospacedDigit().weight(.semibold))

                    if let terminal = segment.origin.terminal {
                        detailLine(L10n.text("flight_departure_terminal", settings.language), terminal)
                    }
                    if let terminal = segment.destination.terminal {
                        detailLine(L10n.text("flight_arrival_terminal", settings.language), terminal)
                    }
                    if let aircraft = segment.aircraft {
                        detailLine(L10n.text("flight_detail_aircraft", settings.language), aircraft)
                    }
                    if let cabin = segment.cabin {
                        detailLine(L10n.text("flight_detail_cabin", settings.language), cabin)
                    }
                }

                if index < offer.layovers.count {
                    let layover = offer.layovers[index]
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.format("flight_layover_title", settings.language, layover.airport.displayCity))
                                .font(.subheadline.weight(.semibold))
                            Text(durationText(layover.durationMinutes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }

    private func durationText(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return L10n.format("flight_minutes_short", settings.language, m) }
        if m == 0 { return L10n.format("flight_hours_short", settings.language, h) }
        return L10n.format("flight_duration_short", settings.language, h, m)
    }

    private func time(_ date: Date, zone: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let zone, let timeZone = TimeZone(identifier: zone) { formatter.timeZone = timeZone }
        return formatter.string(from: date)
    }
}

func statusIcon(_ status: String) -> String {
    switch status.uppercased() {
    case "BOOKING_CONFIRMED": return "checkmark.seal.fill"
    case "PAYMENT_PENDING": return "creditcard.fill"
    case "READY_TO_TRAVEL": return "airplane.circle.fill"
    case "IN_TRIP": return "location.fill"
    case "COMPLETED": return "flag.checkered.circle.fill"
    case "CANCELLED": return "xmark.circle.fill"
    default: return "clock.fill"
    }
}
