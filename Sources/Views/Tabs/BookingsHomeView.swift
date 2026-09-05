import Foundation
import SwiftUI

struct BookingsHomeView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var pendingDeleteID: String?
    @State private var deleteError: String?

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
    }

    private var emptyBookingHome: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahRootPageTitle(
                    title: L10n.text("tab_booking", settings.language),
                    showsMakkahTime: true
                )
                builderHero
                noBookingsCard
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
    }

    private func activeBookingHub(_ session: StoredBookingSession) -> some View {
        ZStack {
            Image("MakkahBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.18), Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    IumrahRootPageTitle(
                        title: L10n.text("tab_booking", settings.language),
                        showsMakkahTime: true,
                        lightStyle: true,
                        usesBrandLogo: true
                    )

                    activeBookingOverview(session)
                    statusProgressCard(session)
                    BookingItineraryCalendarView(
                        bookingID: session.id,
                        startDate: session.booking.input.startDate,
                        endDate: session.booking.input.endDate,
                        booking: session.booking
                    )
                    tripActions(session)

                    if bookings.sessions.count > 1 {
                        otherTrips(excluding: session.id)
                    }

                    if let deleteError {
                        Text(deleteError)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 42)
            }
        }
    }

    private func activeBookingOverview(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeEyebrow)
                        .font(.caption.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(.secondary)
                    Text(L10n.status(session.effectiveStatus, settings.language))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 10)
                IumrahIconBadge(
                    systemName: statusIcon(session.effectiveStatus),
                    role: statusRole(session.effectiveStatus),
                    size: 48,
                    symbolSize: 19,
                    shape: .circle
                )
            }

            if let name = session.travelerName, !name.isEmpty {
                Text(name)
                    .font(.headline)
            }

            Text(L10n.format("booking_number_short", settings.language, session.displayBookingNumber))
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.iumrahRaisedBackground, in: Capsule())

            VStack(spacing: 11) {
                overviewRow(icon: "airplane", title: routeTitle, value: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                overviewRow(icon: "calendar", title: dateTitle, value: "\(L10n.date(session.booking.input.startDate, settings.language)) – \(L10n.date(session.booking.input.endDate, settings.language))")
                if !session.booking.hotelNames.makkah.isEmpty {
                    overviewRow(icon: "building.2.fill", title: hotelTitle, value: session.booking.hotelNames.makkah)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(priceTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PackagePriceView(amount: Decimal(session.booking.perPilgrimUsd), currency: "USD")
                }
                Spacer()
                Text("\(session.booking.input.travelers.totalPeople)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground, in: Capsule())
                    .overlay(alignment: .leading) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .offset(x: -22)
                    }
            }

            NavigationLink {
                BookingDetailView(bookingID: session.id)
            } label: {
                HStack {
                    Text(openBookingTitle)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.headline)
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color.iumrahPrimaryButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.iumrahPhotoCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private func statusProgressCard(_ session: StoredBookingSession) -> some View {
        let stages = ["AVAILABILITY_CHECK", "PAYMENT_PENDING", "BOOKING_CONFIRMED", "READY_TO_TRAVEL", "IN_TRIP", "COMPLETED"]
        let current = stages.firstIndex(of: session.effectiveStatus.uppercased()) ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            Text(statusTitle)
                .font(.system(size: 23, weight: .bold, design: .rounded))

            VStack(spacing: 9) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    HStack(spacing: 12) {
                        IumrahIconBadge(
                            systemName: index < current ? "checkmark" : (index == current ? "circle.fill" : "circle"),
                            role: index < current ? .success : (index == current ? .warning : .neutral),
                            size: 30,
                            symbolSize: index == current ? 8 : 11,
                            cornerRadius: 15,
                            shape: .circle
                        )

                        Text(L10n.status(stage, settings.language))
                            .font(.subheadline.weight(index == current ? .bold : .semibold))
                            .foregroundStyle(index > current ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(19)
        .background(Color.iumrahPhotoCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 9)
    }

    private func tripActions(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(actionsTitle)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                Button {
                    startNewTrip()
                } label: {
                    actionCard(icon: "moon.stars.fill", title: newUmrahTitle, subtitle: newUmrahSubtitle)
                }
                .buttonStyle(.plain)

                Button {
                    startNewTrip()
                } label: {
                    actionCard(icon: "plus.circle.fill", title: addTripTitle, subtitle: addTripSubtitle)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BookingChatView(bookingID: session.id)
                } label: {
                    actionCard(icon: "person.badge.plus", title: addPilgrimTitle, subtitle: addPilgrimSubtitle)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BookingDetailView(bookingID: session.id)
                } label: {
                    actionCard(icon: "slider.horizontal.3", title: manageTitle, subtitle: manageSubtitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            IumrahIconBadge(systemName: icon, size: 42, symbolSize: 19, cornerRadius: 14)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(16)
        .background(Color.iumrahPhotoCardBackground, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    }

    private func otherTrips(excluding bookingID: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(otherTripsTitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(bookings.sessions.filter { $0.id != bookingID }) { session in
                NavigationLink {
                    BookingDetailView(bookingID: session.id)
                } label: {
                    bookingCard(session)
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

    private func bookingCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.travelerName ?? L10n.text("booking_your_trip", settings.language))
                        .font(.headline)
                    Text(L10n.format("booking_number_short", settings.language, session.displayBookingNumber))
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(IumrahIconRole.booking.color)
                    Text(L10n.status(session.effectiveStatus, settings.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                IumrahIconBadge(
                    systemName: statusIcon(session.effectiveStatus),
                    role: statusRole(session.effectiveStatus),
                    size: 38,
                    symbolSize: 16,
                    shape: .circle
                )
            }

            Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Capsule())

            if !session.booking.hotelNames.makkah.isEmpty {
                HStack(spacing: 7) {
                    IumrahInlineIcon(systemName: "building.2", role: .hotel, size: 13)
                    Text(session.booking.hotelNames.makkah)
                }
                .font(.subheadline)
            }

            HStack {
                Text(L10n.date(session.booking.input.startDate, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                PackagePriceView(amount: Decimal(session.booking.perPilgrimUsd), currency: "USD")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
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

    private func overviewRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, size: 34, symbolSize: 14, cornerRadius: 17, shape: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func statusRole(_ status: String) -> IumrahIconRole {
        switch status.uppercased() {
        case "BOOKING_CONFIRMED", "READY_TO_TRAVEL", "COMPLETED": return .success
        case "PAYMENT_PENDING", "AVAILABILITY_CHECK": return .warning
        case "IN_TRIP": return .location
        case "CANCELLED": return .destructive
        default: return .booking
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

    private var activeEyebrow: String { localized("Активная поездка", "Active trip", "Faol safar", "Фаол сафар") }
    private var routeTitle: String { localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш") }
    private var dateTitle: String { localized("Даты", "Dates", "Sanalar", "Саналар") }
    private var hotelTitle: String { localized("Отель в Мекке", "Makkah hotel", "Makkadagi mehmonxona", "Маккадаги меҳмонхона") }
    private var priceTitle: String { localized("На паломника", "Per pilgrim", "Bir ziyoratchiga", "Бир зиёратчига") }
    private var openBookingTitle: String { localized("Открыть бронирование", "Open booking", "Bronni ochish", "Бронни очиш") }
    private var statusTitle: String { localized("Статус бронирования", "Booking status", "Bron holati", "Брон ҳолати") }
    private var actionsTitle: String { localized("Действия", "Actions", "Amallar", "Амаллар") }
    private var newUmrahTitle: String { localized("Новая Умра", "New Umrah", "Yangi Umra", "Янги Умра") }
    private var newUmrahSubtitle: String { localized("Собрать новый пакет", "Build a new package", "Yangi paket tuzish", "Янги пакет тузиш") }
    private var addTripTitle: String { localized("Добавить поездку", "Add trip", "Safar qo‘shish", "Сафар қўшиш") }
    private var addTripSubtitle: String { localized("Отдельное бронирование", "Separate booking", "Alohida bron", "Алоҳида брон") }
    private var addPilgrimTitle: String { localized("Добавить паломника", "Add pilgrim", "Ziyoratchi qo‘shish", "Зиёратчи қўшиш") }
    private var addPilgrimSubtitle: String { localized("Запрос через iumrah Care", "Request via iumrah Care", "iumrah Care orqali so‘rov", "iumrah Care орқали сўров") }
    private var manageTitle: String { localized("Управлять поездкой", "Manage trip", "Safarni boshqarish", "Сафарни бошқариш") }
    private var manageSubtitle: String { localized("Отели, данные и услуги", "Hotels, details and services", "Mehmonxona va xizmatlar", "Меҳмонхона ва хизматлар") }
    private var otherTripsTitle: String { localized("Другие поездки", "Other trips", "Boshqa safarlar", "Бошқа сафарлар") }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}
