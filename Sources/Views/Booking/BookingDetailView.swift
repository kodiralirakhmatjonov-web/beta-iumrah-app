import SwiftUI

struct BookingDetailView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String

    @State private var outboundExpanded = false
    @State private var inboundExpanded = false
    @State private var hotelExpanded = false
    @State private var showHotelChange = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(spacing: 18) {
                        statusHero(session)
                        bookingMetaCard(session.booking)

                        BookingFlightDisclosureCard(
                            title: L10n.text("booking_outbound_flight", settings.language),
                            route: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)",
                            date: session.booking.input.startDate,
                            fallbackFlight: session.booking.flight,
                            offer: session.outboundFlight,
                            isExpanded: $outboundExpanded
                        )

                        BookingFlightDisclosureCard(
                            title: L10n.text("booking_return_flight", settings.language),
                            route: "\(session.booking.route.returnOrigin) → \(session.booking.route.originCode)",
                            date: session.booking.input.endDate,
                            fallbackFlight: session.booking.flight,
                            offer: session.inboundFlight,
                            isExpanded: $inboundExpanded
                        )

                        hotelCard(session)
                        contactCard(session)
                        careAction
                        destructiveActions
                    }
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 10)
                    .padding(.bottom, 54)
                }
                .background(Color.iumrahPageBackground)
                .task { await bookings.refreshAll(); await bookings.syncHotelSelectionIfNeeded(bookingID: bookingID) }
                .sheet(isPresented: $showHotelChange) {
                    BookingHotelChangeView(bookingID: bookingID)
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
                if let pilgrimID = session?.displayPilgrimID {
                    Text("ID \(pilgrimID)")
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
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

    private func hotelCard(_ session: StoredBookingSession) -> some View {
        let snapshot = session.hotelSelection
        let hotelName = snapshot?.hotelName ?? session.booking.hotelNames.makkah
        let roomDisplayName = snapshot?.roomCategory.map { L10n.text($0.titleKey, settings.language) } ?? snapshot?.roomName

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 14) {
                AsyncImage(url: AppConfig.absoluteURL(snapshot?.coverImageURL)) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default:
                        ZStack {
                            Color.iumrahRaisedBackground
                            Image(systemName: "building.2")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("detail_hotel", settings.language))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(hotelName)
                        .font(.headline)
                        .lineLimit(2)
                    if let roomDisplayName, !roomDisplayName.isEmpty {
                        Text(roomDisplayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    hotelExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(hotelExpanded ? L10n.text("collapse", settings.language) : L10n.text("expand", settings.language))
                    Spacer()
                    Image(systemName: hotelExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            if hotelExpanded {
                VStack(spacing: 10) {
                    if let city = snapshot?.city {
                        summaryRow(title: L10n.text("hotel_location_title", settings.language), value: L10n.city(city, settings.language))
                    }
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
                showHotelChange = true
            } label: {
                HStack {
                    Text(L10n.text("booking_change_hotel", settings.language))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .iumrahCard()
    }

    private func contactCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("booking_contacts", settings.language))
                .font(.headline)
            if let telegram = session.telegram, !telegram.isEmpty {
                summaryRow(title: "Telegram", value: telegram)
            }
            if let whatsapp = session.whatsapp, !whatsapp.isEmpty {
                summaryRow(title: "WhatsApp", value: whatsapp)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var careAction: some View {
        NavigationLink {
            BookingChatView(bookingID: bookingID)
        } label: {
            HStack(spacing: 14) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("iumrah Care")
                        .font(.headline)
                    Text(L10n.text("booking_care_body", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.bold))
            }
            .padding(18)
            .background(Color.iumrahCareLight.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.iumrahCareLight.opacity(0.28), lineWidth: 1)
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

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
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
                    AirlineLogoView(airlineCode: offer?.primaryAirlineCode, size: 42)
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
    case "COMPLETED": return "flag.checkered.circle.fill"
    default: return "clock.fill"
    }
}
