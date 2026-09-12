import Foundation
import SwiftUI

struct BookingsHomeView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var pendingDeleteID: String?
    @State private var deleteError: String?
    @State private var showZiyarats = false

    private var activeSession: StoredBookingSession? {
        bookings.sessions.first { session in
            !["COMPLETED", "CANCELLED"].contains(session.effectiveStatus.uppercased())
        } ?? bookings.sessions.first
    }

    var body: some View {
        Group {
            if let activeSession {
                activeBookingHub(activeSession)
            } else {
                emptyBookingHome
            }
        }
        .refreshable { await bookings.refreshAll() }
        .task { await bookings.refreshAll() }
        .confirmationDialog(
            L10n.text("booking_delete_confirm_title", settings.language),
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("booking_delete_confirm_action", settings.language), role: .destructive) {
                guard let id = pendingDeleteID else { return }
                pendingDeleteID = nil
                Task { await deleteBooking(id) }
            }
            Button(L10n.text("cancel", settings.language), role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text(L10n.text("booking_delete_confirm_body", settings.language))
        }
        .navigationDestination(isPresented: $chrome.shouldStartTripBuilder) {
            TripBuilderView()
        }
        .navigationDestination(isPresented: Binding(
            get: { chrome.requestedBookingID != nil },
            set: { if !$0 { chrome.requestedBookingID = nil } }
        )) {
            if let bookingID = chrome.requestedBookingID, bookings.booking(id: bookingID) != nil {
                BookingDetailView(bookingID: bookingID)
            } else {
                EmptyView()
            }
        }
        .fullScreenCover(isPresented: $showZiyarats) {
            ZiyaratJourneyView()
                .environmentObject(settings)
                .environmentObject(chrome)
        }
    }

    // MARK: - Active booking

    private func activeBookingHub(_ session: StoredBookingSession) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                IumrahStorePageHeader(title: forYouTitle, subtitle: forYouSubtitle)
                    .padding(.bottom, 24)

                forYouJourneyCard(session)
                    .padding(.bottom, 34)

                bookingProgress(session)
                    .padding(.bottom, 38)

                tripPlanPreview(session)
                    .padding(.bottom, 34)

                tripManagement(session)
                    .padding(.bottom, 34)

                forYouRecommendations
                    .padding(.bottom, bookings.sessions.count > 1 ? 36 : 12)

                if bookings.sessions.count > 1 {
                    otherTrips(excluding: session.id)
                        .padding(.bottom, 12)
                }

                if let deleteError {
                    Text(deleteError)
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .systemRed))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(uiColor: .systemRed).opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground.ignoresSafeArea())
        .animation(.snappy(duration: 0.34), value: session.effectiveStatus)
    }

    private func forYouJourneyCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text(forYouTripEyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(IumrahBookingStatusVisual.color(for: session.effectiveStatus))
                        .frame(width: 7, height: 7)
                    Text(L10n.status(session.effectiveStatus, settings.language))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(Color.iumrahRaisedBackground, in: Capsule())
            }

            bookingIdentity(session)

            Divider()

            NavigationLink {
                BookingDetailView(bookingID: session.id)
            } label: {
                HStack {
                    Text(activeActionTitle(for: session.effectiveStatus))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(height: 52)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    /// The trip identity is kept intact and simply merchandised inside For You.
    private func bookingIdentity(_ session: StoredBookingSession) -> some View {
        VStack(spacing: 17) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.iumrahRaisedBackground)
                    .frame(width: 94, height: 94)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.065), lineWidth: 0.7)
                    }

                Image(systemName: "suitcase.fill")
                    .font(.system(size: 34, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(activeEyebrow)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.9)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
                    .lineLimit(1)

                Text("\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                identityPill(L10n.format("booking_number_short", settings.language, session.displayBookingNumber))
                identityPill(pilgrimCountText(session.booking.input.travelers.totalPeople), systemName: "person.2.fill")
            }

            if let name = session.travelerName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func identityPill(_ text: String, systemName: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .frame(height: 31)
        .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    // MARK: - Booking progress

    private func bookingProgress(_ session: StoredBookingSession) -> some View {
        let stages = progressStages
        let current = progressIndex(for: session.effectiveStatus)
        let isCancelled = session.effectiveStatus.uppercased() == "CANCELLED"

        return VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: statusTitle,
                trailing: isCancelled ? cancelledText : progressCounter(current: current, total: stages.count)
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    processStep(
                        stage,
                        index: index,
                        current: current,
                        isLast: index == stages.count - 1,
                        session: session,
                        isCancelled: isCancelled
                    )
                }
            }
        }
    }

    private func processStep(
        _ stage: BookingProgressStage,
        index: Int,
        current: Int,
        isLast: Bool,
        session: StoredBookingSession,
        isCancelled: Bool
    ) -> some View {
        let completed = isCancelled ? index == 0 : index < current
        let active = index == current
        let future = index > current
        let effectiveStage = isCancelled && active ? cancelledStage : stage
        let nodeColor = active
            ? IumrahBookingStatusVisual.color(for: session.effectiveStatus)
            : (completed ? Color(uiColor: .systemGreen) : Color(uiColor: .secondaryLabel).opacity(0.62))
        let lineColor = completed
            ? Color(uiColor: .systemGreen).opacity(0.36)
            : Color.primary.opacity(0.12)

        return HStack(alignment: .top, spacing: 17) {
            ZStack {
                Circle()
                    .fill(completed || active ? nodeColor : Color.iumrahPageBackground)
                    .frame(width: 25, height: 25)
                    .overlay {
                        if future {
                            Circle()
                                .strokeBorder(Color(uiColor: .secondaryLabel).opacity(0.52), lineWidth: 1.6)
                        }
                    }

                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                } else if active {
                    Circle()
                        .fill(activeNodeForeground(for: session.effectiveStatus))
                        .frame(width: 7, height: 7)
                }
            }
            .frame(width: 26, height: 25, alignment: .top)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(effectiveStage.title)
                        .font(.system(size: active ? 18 : 17, weight: active ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(future ? Color(uiColor: .secondaryLabel) : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if index == 0, let created = createdDateText(session.booking.createdAt) {
                        Text(created)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else if active {
                        Text(effectiveStage.activeSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if active {
                    activeStageCard(session, stage: effectiveStage)
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : 13)
        }
        .overlay(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 1)
                    .padding(.top, 25)
                    .offset(x: 12.5)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func activeStageCard(_ session: StoredBookingSession, stage: BookingProgressStage) -> some View {
        let tint = IumrahBookingStatusVisual.color(for: session.effectiveStatus)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 34, height: 34)
                    Image(systemName: IumrahBookingStatusVisual.symbol(for: session.effectiveStatus))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(activeNodeForeground(for: session.effectiveStatus))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.cardTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(-0.25)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stage.cardBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Divider()
                .overlay(Color.primary.opacity(0.05))

            VStack(spacing: 13) {
                progressFact(title: routeTitle, value: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                progressFact(title: dateTitle, value: "\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))")
                if !session.booking.hotelNames.makkah.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    progressFact(title: hotelTitle, value: session.booking.hotelNames.makkah)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(priceTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PackagePriceView(amount: Decimal(session.booking.perPilgrimUsd), currency: "USD", showsPerPerson: false)
                }

                Spacer(minLength: 12)

                Text(pilgrimCountText(session.booking.input.travelers.totalPeople))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                BookingDetailView(bookingID: session.id)
            } label: {
                HStack(spacing: 10) {
                    Text(activeActionTitle(for: session.effectiveStatus))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 17)
                .frame(height: 53)
                .background(Color.iumrahPrimaryButtonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.iumrahCardBackground)
                .overlay {
                    LinearGradient(
                        colors: [tint.opacity(0.13), tint.opacity(0.025), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.8)
        }
    }

    private func progressFact(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cancelledStage: BookingProgressStage {
        BookingProgressStage(
            title: localized("Бронирование отменено", "Booking cancelled", "Bron bekor qilindi", "Брон бекор қилинди"),
            activeSubtitle: localized("Поездка остановлена", "The trip has been stopped", "Safar to‘xtatildi", "Сафар тўхтатилди"),
            cardTitle: localized("Бронирование отменено", "Booking cancelled", "Bron bekor qilindi", "Брон бекор қилинди"),
            cardBody: localized("Откройте бронирование, чтобы посмотреть сохранённые детали поездки и доступные действия.", "Open the booking to review the saved trip details and available actions.", "Saqlangan safar tafsilotlari va mavjud amallarni ko‘rish uchun bronni oching.", "Сақланган сафар тафсилотлари ва мавжуд амалларни кўриш учун бронни очинг.")
        )
    }

    private var progressStages: [BookingProgressStage] {
        [
            BookingProgressStage(
                title: createdTitle,
                activeSubtitle: createdSubtitle,
                cardTitle: createdTitle,
                cardBody: createdSubtitle
            ),
            BookingProgressStage(
                title: availabilityTitle,
                activeSubtitle: availabilitySubtitle,
                cardTitle: availabilityCardTitle,
                cardBody: availabilityCardBody
            ),
            BookingProgressStage(
                title: paymentStageTitle,
                activeSubtitle: paymentStageSubtitle,
                cardTitle: paymentCardTitle,
                cardBody: paymentCardBody
            ),
            BookingProgressStage(
                title: confirmedStageTitle,
                activeSubtitle: confirmedStageSubtitle,
                cardTitle: confirmedCardTitle,
                cardBody: confirmedCardBody
            ),
            BookingProgressStage(
                title: documentsStageTitle,
                activeSubtitle: documentsStageSubtitle,
                cardTitle: documentsCardTitle,
                cardBody: documentsCardBody
            ),
            BookingProgressStage(
                title: inTripStageTitle,
                activeSubtitle: inTripStageSubtitle,
                cardTitle: inTripCardTitle,
                cardBody: inTripCardBody
            ),
            BookingProgressStage(
                title: completedStageTitle,
                activeSubtitle: completedStageSubtitle,
                cardTitle: completedCardTitle,
                cardBody: completedCardBody
            )
        ]
    }

    private func progressIndex(for status: String) -> Int {
        switch status.uppercased() {
        case "NEW", "AVAILABILITY_CHECK": return 1
        case "PAYMENT_PENDING": return 2
        case "PAID", "BOOKING_CONFIRMED": return 3
        case "DOCUMENTS_READY", "READY_TO_TRAVEL": return 4
        case "IN_TRIP": return 5
        case "COMPLETED": return 6
        case "CANCELLED": return 1
        default: return 1
        }
    }

    private func progressCounter(current: Int, total: Int) -> String {
        localized("\(current + 1) из \(total)", "\(current + 1) of \(total)", "\(current + 1) / \(total)", "\(current + 1) / \(total)")
    }

    private func activeNodeForeground(for status: String) -> Color {
        switch IumrahBookingStatusVisual.role(for: status) {
        case .waiting, .warning, .rating:
            return Color.black.opacity(0.78)
        default:
            return .white
        }
    }

    // MARK: - Trip plan preview

    private func tripPlanPreview(_ session: StoredBookingSession) -> some View {
        let items = previewItineraryItems(session)

        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: tripPlanTitle, trailing: nil)

            VStack(spacing: 0) {
                if items.isEmpty {
                    Text(tripPlanEmptyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                        .padding(.horizontal, 17)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        tripPlanRow(item)
                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }

                Divider()
                    .padding(.leading, 17)

                NavigationLink {
                    BookingDetailView(bookingID: session.id)
                } label: {
                    HStack {
                        Text(openFullPlanTitle)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 17)
                    .frame(height: 54)
                }
                .buttonStyle(.plain)
            }
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
    }

    private func tripPlanRow(_ item: BookingItineraryItem) -> some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.iumrahRaisedBackground)
                    .frame(width: 39, height: 39)
                Image(systemName: safeIcon(item.icon))
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(compactDate(item.dateLocal))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                }

                if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.location)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
    }

    private func previewItineraryItems(_ session: StoredBookingSession) -> [BookingItineraryItem] {
        let remote = bookings.itineraries[session.id] ?? []
        let source: [BookingItineraryItem]
        let distinctRemoteDays = Set(remote.map(\.dateLocal)).count
        if distinctRemoteDays >= 2 {
            source = remote.sorted { lhs, rhs in
                if lhs.dateLocal == rhs.dateLocal { return lhs.sortOrder < rhs.sortOrder }
                return lhs.dateLocal < rhs.dateLocal
            }
        } else {
            source = BookingItineraryPlanner.make(booking: session.booking, language: settings.language)
        }

        guard !source.isEmpty else { return [] }
        let today = Self.riyadhDayFormatter.string(from: Date())
        let upcoming = source.filter { $0.dateLocal >= today }
        if !upcoming.isEmpty { return Array(upcoming.prefix(3)) }
        return Array(source.suffix(3))
    }

    // MARK: - Management

    private func tripManagement(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: manageSectionTitle, trailing: nil)

            VStack(spacing: 0) {
                NavigationLink {
                    BookingDetailView(bookingID: session.id)
                } label: {
                    managementRow(icon: "slider.horizontal.3", title: manageTitle, subtitle: manageSubtitle)
                }
                .buttonStyle(.plain)

                managementDivider

                NavigationLink {
                    BookingChatView(bookingID: session.id)
                } label: {
                    managementRow(icon: "person.badge.plus", title: addPilgrimTitle, subtitle: addPilgrimSubtitle)
                }
                .buttonStyle(.plain)

                managementDivider

                Button {
                    showZiyarats = true
                } label: {
                    managementRow(icon: "map", title: ziyaratsBookingTitle, subtitle: ziyaratsBookingSubtitle)
                }
                .buttonStyle(.plain)

                managementDivider

                Button {
                    startNewTrip()
                } label: {
                    managementRow(icon: "plus", title: newUmrahTitle, subtitle: newUmrahSubtitle)
                }
                .buttonStyle(.plain)
            }
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
    }

    private var managementDivider: some View {
        Divider().padding(.leading, 65)
    }

    private func managementRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.iumrahRaisedBackground)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    // MARK: - Other trips

    private func otherTrips(excluding bookingID: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: otherTripsTitle, trailing: nil)

            VStack(spacing: 10) {
                ForEach(bookings.sessions.filter { $0.id != bookingID }) { session in
                    NavigationLink {
                        BookingDetailView(bookingID: session.id)
                    } label: {
                        compactBookingCard(session)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteID = session.id
                        } label: {
                            Label(L10n.text("booking_delete", settings.language), systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func compactBookingCard(_ session: StoredBookingSession) -> some View {
        HStack(alignment: .center, spacing: 13) {
            Circle()
                .fill(IumrahBookingStatusVisual.color(for: session.effectiveStatus))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                        .font(.subheadline.weight(.bold))
                    Text(session.displayBookingNumber)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                Text(L10n.status(session.effectiveStatus, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let name = session.travelerName, !name.isEmpty {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPrice(session.booking.perPilgrimUsd))
                    .font(.subheadline.weight(.bold))
                Text(L10n.date(session.booking.input.startDate, settings.language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - For You discovery

    private var forYouRecommendations: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: forYouRecommendedTitle, subtitle: forYouRecommendedSubtitle)

            VStack(spacing: 10) {
                Button { chrome.navigate(to: .hotels) } label: {
                    IumrahStoreCompactRow(systemName: "building.2.fill", title: forYouHotelsTitle, subtitle: forYouHotelsBody, role: .hotel)
                }
                Button { chrome.navigate(to: .care) } label: {
                    IumrahStoreCompactRow(systemName: "waveform.badge.mic", title: forYouGearTitle, subtitle: forYouGearBody, role: .umrah)
                }
                Button { chrome.presentESIM() } label: {
                    IumrahStoreCompactRow(systemName: "simcard.fill", title: "iumrah eSIM", subtitle: forYouESIMBody, role: .connectivity)
                }
                Button { showZiyarats = true } label: {
                    IumrahStoreCompactRow(systemName: "map.fill", title: forYouZiyaratsTitle, subtitle: forYouZiyaratsBody, role: .location)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var forYouEmptySuggestions: some View {
        VStack(alignment: .leading, spacing: 16) {
            IumrahStoreSectionHeader(title: forYouExploreTitle, subtitle: forYouExploreSubtitle)

            HStack(spacing: 10) {
                Button {
                    startNewTrip()
                } label: {
                    forYouMiniCard(icon: "sparkles", title: forYouFirstTitle, role: .umrah)
                }

                Button {
                    chrome.navigate(to: .hotels)
                } label: {
                    forYouMiniCard(icon: "building.2.fill", title: forYouHotelsTitle, role: .hotel)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func forYouMiniCard(icon: String, title: String, role: IumrahIconRole) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            IumrahIconBadge(systemName: icon, role: role, size: 44, symbolSize: 18, cornerRadius: 15)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(17)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
    }

    // MARK: - Empty state

    private var emptyBookingHome: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahStorePageHeader(title: forYouTitle, subtitle: forYouSubtitle)
                builderHero
                forYouEmptySuggestions
                noBookingsCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
    }

    private var builderHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("booking_hero_kicker", settings.language))
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(L10n.text("booking_hero_title", settings.language))
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                }
                Spacer()
                IumrahIconBadge(systemName: "plus", role: .accent, size: 44, symbolSize: 19, shape: .circle)
            }

            Text(L10n.text("booking_hero_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { startNewTrip() } label: {
                Text(L10n.text("booking_hero_cta", settings.language))
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }

    private var noBookingsCard: some View {
        HStack(spacing: 14) {
            IumrahIconBadge(systemName: "suitcase", role: .booking, size: 46, symbolSize: 20, shape: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("booking_empty_title", settings.language))
                    .font(.headline)
                Text(L10n.text("booking_empty_body", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .iumrahCard()
    }

    // MARK: - Shared helpers

    private func sectionHeader(title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(-0.35)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startNewTrip() {
        journey.resetAfterTripChange()
        chrome.startNewTrip()
    }

    @MainActor
    private func deleteBooking(_ id: String) async {
        do {
            try await bookings.deleteBooking(id: id)
            deleteError = nil
            IumrahHaptics.success()
        } catch {
            deleteError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    private func safeIcon(_ value: String) -> String {
        let icon = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return icon.isEmpty ? "calendar" : icon
    }

    private func compactDate(_ raw: String) -> String {
        guard let date = Self.dayParser.date(from: raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func createdDateText(_ raw: String) -> String? {
        guard let date = Self.isoDate(raw) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMM · HH:mm"
        return formatter.string(from: date)
    }

    private func formatPrice(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        let value = formatter.string(from: NSNumber(value: amount)) ?? String(Int(amount.rounded()))
        return "\(value) $"
    }

    private func pilgrimCountText(_ count: Int) -> String {
        switch settings.language {
        case .russian:
            let mod10 = count % 10
            let mod100 = count % 100
            if mod10 == 1 && mod100 != 11 { return "\(count) паломник" }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(count) паломника" }
            return "\(count) паломников"
        case .english:
            return count == 1 ? "1 pilgrim" : "\(count) pilgrims"
        case .uzbek:
            return "\(count) ziyoratchi"
        case .uzbekCyrillic:
            return "\(count) зиёратчи"
        }
    }

    private func activeActionTitle(for status: String) -> String {
        switch status.uppercased() {
        case "PAYMENT_PENDING":
            return localized("Продолжить", "Continue", "Davom etish", "Давом этиш")
        case "READY_TO_TRAVEL", "DOCUMENTS_READY":
            return localized("Открыть документы", "Open documents", "Hujjatlarni ochish", "Ҳужжатларни очиш")
        case "IN_TRIP":
            return localized("Открыть поездку", "Open trip", "Safarni ochish", "Сафарни очиш")
        default:
            return openBookingTitle
        }
    }

    private static func isoDate(_ raw: String) -> Date? {
        if let date = isoFormatterFractional.date(from: raw) { return date }
        return isoFormatter.date(from: raw)
    }

    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let riyadhDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Copy

    private var forYouTitle: String { localized("Для Вас", "For You", "Siz uchun", "Сиз учун") }
    private var forYouGearTitle: String { localized("Подготовка", "Gear", "Tayyorgarlik", "Тайёргарлик") }
    private var forYouSubtitle: String { localized("Ваша поездка, статусы и то, что пригодится дальше.", "Your trip, its status and what may be useful next.", "Safaringiz, uning holati va keyingi foydali narsalar.", "Сафарингиз, унинг ҳолати ва кейинги фойдали нарсалар.") }
    private var forYouTripEyebrow: String { localized("Ваша поездка", "Your trip", "Safaringiz", "Сафарингиз") }
    private var forYouRecommendedTitle: String { localized("Для Вашей поездки", "For your trip", "Safaringiz uchun", "Сафарингиз учун") }
    private var forYouRecommendedSubtitle: String { localized("Быстрый доступ к сервисам, которые могут понадобиться дальше.", "Quick access to services you may need next.", "Keyingi kerak bo‘lishi mumkin bo‘lgan servislar.", "Кейинги керак бўлиши мумкин бўлган сервислар.") }
    private var forYouHotelsTitle: String { localized("Отели", "Hotels", "Mehmonxonalar", "Меҳмонхоналар") }
    private var forYouHotelsBody: String { localized("Посмотрите варианты в Мекке и Медине.", "Explore stays in Makkah and Madinah.", "Makka va Madinadagi variantlarni ko‘ring.", "Макка ва Мадинадаги вариантларни кўринг.") }
    private var forYouGearBody: String { localized("Голосовой гид, поддержка, eSIM и подготовка к поездке.", "Advisor, Care, eSIM and trip preparation.", "Ovozli yo‘l-yo‘riq, yordam, eSIM va safarga tayyorgarlik.", "Овозли йўл-йўриқ, ёрдам, eSIM ва сафарга тайёргарлик.") }
    private var forYouESIMBody: String { localized("Подготовьте связь до прибытия.", "Prepare connectivity before arrival.", "Yetib kelishdan oldin aloqani tayyorlang.", "Етиб келишдан олдин алоқани тайёрланг.") }
    private var forYouZiyaratsTitle: String { localized("iumrah Зияраты", "iumrah Ziyarats", "iumrah Ziyoratlar", "iumrah Зиёратлар") }
    private var forYouZiyaratsBody: String { localized("Точки и маршруты Мекки и Медины.", "Places and routes in Makkah and Madinah.", "Makka va Madinadagi joylar va yo‘nalishlar.", "Макка ва Мадинадаги жойлар ва йўналишлар.") }
    private var forYouExploreTitle: String { localized("Начните с себя", "Start with what fits you", "O‘zingizga mosidan boshlang", "Ўзингизга мосидан бошланг") }
    private var forYouExploreSubtitle: String { localized("Соберите поездку или сначала изучите отели.", "Build a trip or explore hotels first.", "Safar yarating yoki avval mehmonxonalarni ko‘ring.", "Сафар яратинг ёки аввал меҳмонхоналарни кўринг.") }
    private var forYouFirstTitle: String { localized("Собрать Умру", "Build Umrah", "Umra yaratish", "Умра яратиш") }

    private var activeEyebrow: String { localized("Ваша Умра", "Your Umrah", "Sizning Umrangiz", "Сизнинг Умрангиз") }
    private var routeTitle: String { localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш") }
    private var dateTitle: String { localized("Даты", "Dates", "Sanalar", "Саналар") }
    private var hotelTitle: String { localized("Отель", "Hotel", "Mehmonxona", "Меҳмонхона") }
    private var priceTitle: String { localized("На паломника", "Per pilgrim", "Bir ziyoratchiga", "Бир зиёратчига") }
    private var openBookingTitle: String { localized("Открыть бронирование", "Open booking", "Bronni ochish", "Бронни очиш") }
    private var statusTitle: String { localized("Статус бронирования", "Booking status", "Bron holati", "Брон ҳолати") }
    private var cancelledText: String { localized("Отменено", "Cancelled", "Bekor qilingan", "Бекор қилинган") }

    private var createdTitle: String { localized("Пакет создан", "Package created", "Paket yaratildi", "Пакет яратилди") }
    private var createdSubtitle: String { localized("Поездка добавлена в iumrah", "Trip added to iumrah", "Safar iumrah'ga qo‘shildi", "Сафар iumrah'га қўшилди") }

    private var availabilityTitle: String { localized("Проверка наличия", "Availability check", "Mavjudlik tekshiruvi", "Мавжудлик текшируви") }
    private var availabilitySubtitle: String { localized("Подтверждаем перелёт, отель и услуги", "Confirming flight, hotel and services", "Parvoz, mehmonxona va xizmatlar tasdiqlanmoqda", "Парвоз, меҳмонхона ва хизматлар тасдиқланмоқда") }
    private var availabilityCardTitle: String { localized("Проверяем ваш пакет", "Checking your package", "Paketingiz tekshirilmoqda", "Пакетингиз текширилмоқда") }
    private var availabilityCardBody: String { localized("iumrah подтверждает выбранные позиции. Пока от вас ничего не требуется.", "iumrah is confirming the selected items. No action is required from you yet.", "iumrah tanlangan xizmatlarni tasdiqlamoqda. Hozircha sizdan hech narsa talab qilinmaydi.", "iumrah танланган хизматларни тасдиқламоқда. Ҳозирча сиздан ҳеч нарса талаб қилинмайди.") }

    private var paymentStageTitle: String { localized("Оплата и данные паломников", "Payment and pilgrim details", "To‘lov va ziyoratchi ma’lumotlari", "Тўлов ва зиёратчи маълумотлари") }
    private var paymentStageSubtitle: String { localized("Наличие подтверждено · требуется действие", "Availability confirmed · action required", "Mavjudlik tasdiqlandi · amal kerak", "Мавжудлик тасдиқланди · амал керак") }
    private var paymentCardTitle: String { localized("Наличие подтверждено", "Availability confirmed", "Mavjudlik tasdiqlandi", "Мавжудлик тасдиқланди") }
    private var paymentCardBody: String { localized("Проверьте данные паломников и перейдите к оплате, чтобы закрепить бронирование.", "Review pilgrim details and continue to payment to secure the booking.", "Bronni mustahkamlash uchun ziyoratchilar ma’lumotlarini tekshiring va to‘lovga o‘ting.", "Бронни мустаҳкамлаш учун зиёратчилар маълумотларини текширинг ва тўловга ўтинг.") }

    private var confirmedStageTitle: String { localized("Бронирование подтверждено", "Booking confirmed", "Bron tasdiqlandi", "Брон тасдиқланди") }
    private var confirmedStageSubtitle: String { localized("Позиции закреплены за вами", "Your trip components are secured", "Safar xizmatlari siz uchun band qilindi", "Сафар хизматлари сиз учун банд қилинди") }
    private var confirmedCardTitle: String { confirmedStageTitle }
    private var confirmedCardBody: String { localized("Перелёт, проживание и выбранные услуги закреплены. Все детали доступны внутри бронирования.", "Flight, stay and selected services are secured. Full details are available inside the booking.", "Parvoz, yashash va tanlangan xizmatlar band qilindi. Barcha tafsilotlar bron ichida mavjud.", "Парвоз, яшаш ва танланган хизматлар банд қилинди. Барча тафсилотлар брон ичида мавжуд.") }

    private var documentsStageTitle: String { localized("Документы готовы", "Documents ready", "Hujjatlar tayyor", "Ҳужжатлар тайёр") }
    private var documentsStageSubtitle: String { localized("Всё готово к поездке", "Everything is ready for travel", "Safar uchun hammasi tayyor", "Сафар учун ҳаммаси тайёр") }
    private var documentsCardTitle: String { localized("Готово к поездке", "Ready to travel", "Safarga tayyor", "Сафарга тайёр") }
    private var documentsCardBody: String { localized("Проверьте билеты, бронирования и документы перед выездом.", "Review tickets, reservations and travel documents before departure.", "Jo‘nashdan oldin chiptalar, bronlar va hujjatlarni tekshiring.", "Жўнашдан олдин чипталар, бронлар ва ҳужжатларни текширинг.") }

    private var inTripStageTitle: String { localized("Паломник в поездке", "Pilgrim in trip", "Ziyoratchi safarda", "Зиёратчи сафарда") }
    private var inTripStageSubtitle: String { localized("iumrah сопровождает вашу поездку", "iumrah is accompanying your trip", "iumrah safaringizga hamroh", "iumrah сафарингизга ҳамроҳ") }
    private var inTripCardTitle: String { localized("Ваша Умра продолжается", "Your Umrah is underway", "Umrangiz davom etmoqda", "Умрангиз давом этмоқда") }
    private var inTripCardBody: String { localized("Маршрут, отель, расписание и помощь iumrah остаются под рукой на протяжении поездки.", "Your route, hotel, schedule and iumrah support stay close throughout the trip.", "Yo‘nalish, mehmonxona, jadval va iumrah yordami safar davomida doimo yoningizda.", "Йўналиш, меҳмонхона, жадвал ва iumrah ёрдами сафар давомида доимо ёнингизда.") }

    private var completedStageTitle: String { localized("Поездка завершена", "Trip completed", "Safar yakunlandi", "Сафар якунланди") }
    private var completedStageSubtitle: String { localized("История поездки сохранена", "Your trip history is saved", "Safar tarixi saqlandi", "Сафар тарихи сақланди") }
    private var completedCardTitle: String { completedStageTitle }
    private var completedCardBody: String { localized("Бронирование и история поездки останутся доступны в iumrah.", "The booking and trip history remain available in iumrah.", "Bron va safar tarixi iumrah'da saqlanadi.", "Брон ва сафар тарихи iumrah'да сақланади.") }

    private var tripPlanTitle: String { localized("План поездки", "Trip plan", "Safar rejasi", "Сафар режаси") }
    private var tripPlanEmptyText: String { localized("События поездки появятся после подтверждения деталей.", "Trip events will appear after the details are confirmed.", "Tafsilotlar tasdiqlangach safar voqealari paydo bo‘ladi.", "Тафсилотлар тасдиқлангач сафар воқеалари пайдо бўлади.") }
    private var openFullPlanTitle: String { localized("Открыть полное расписание", "Open full schedule", "To‘liq jadvalni ochish", "Тўлиқ жадвални очиш") }

    private var manageSectionTitle: String { localized("Управление поездкой", "Trip management", "Safarni boshqarish", "Сафарни бошқариш") }
    private var newUmrahTitle: String { localized("Новая Умра", "New Umrah", "Yangi Umra", "Янги Умра") }
    private var newUmrahSubtitle: String { localized("Собрать новый пакет", "Build a new package", "Yangi paket tuzish", "Янги пакет тузиш") }
    private var addPilgrimTitle: String { localized("Добавить паломника", "Add pilgrim", "Ziyoratchi qo‘shish", "Зиёратчи қўшиш") }
    private var addPilgrimSubtitle: String { localized("Запрос через поддержку iumrah", "Request via iumrah Care", "iumrah yordami orqali so‘rov", "iumrah ёрдами орқали сўров") }
    private var manageTitle: String { localized("Управлять бронированием", "Manage booking", "Bronni boshqarish", "Бронни бошқариш") }
    private var manageSubtitle: String { localized("Отели, данные, услуги и документы", "Hotels, details, services and documents", "Mehmonxona, ma’lumotlar, xizmatlar va hujjatlar", "Меҳмонхона, маълумотлар, хизматлар ва ҳужжатлар") }
    private var otherTripsTitle: String { localized("Другие поездки", "Other trips", "Boshqa safarlar", "Бошқа сафарлар") }
    private var ziyaratsBookingTitle: String { localized("Зияраты", "Ziyarat", "Ziyorat", "Зиёрат") }
    private var ziyaratsBookingSubtitle: String { localized("Маршрут и места посещения", "Route and places to visit", "Yo‘nalish va tashrif joylari", "Йўналиш ва ташриф жойлари") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private struct BookingProgressStage {
    let title: String
    let activeSubtitle: String
    let cardTitle: String
    let cardBody: String
}
