import SwiftUI

struct BookingsHomeView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var pendingDeleteID: String?
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahRootPageTitle(
                    title: L10n.text("tab_booking", settings.language),
                    showsMakkahTime: true
                )
                builderHero

                if !bookings.sessions.isEmpty {
                    SectionHeader(
                        L10n.text("tab_booking", settings.language),
                        eyebrow: L10n.text("booking_hero_kicker", settings.language),
                        subtitle: L10n.text("booking_home_subtitle", settings.language)
                    )

                    ForEach(bookings.sessions) { session in
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

                    if let deleteError {
                        Text(deleteError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    noBookingsCard
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
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
                Task {
                    do {
                        try await bookings.deleteBooking(id: id)
                        deleteError = nil
                        IumrahHaptics.success()
                    } catch {
                        deleteError = L10n.error(error, settings.language)
                        IumrahHaptics.error()
                    }
                }
            }
            Button(L10n.text("cancel", settings.language), role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text(L10n.text("booking_delete_confirm_body", settings.language))
        }
        .navigationDestination(isPresented: $chrome.shouldStartTripBuilder) {
            TripBuilderView()
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
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Circle())
            }

            Text(L10n.text("booking_hero_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                chrome.shouldStartTripBuilder = true
                IumrahHaptics.selection()
            } label: {
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
                    if let pilgrimID = session.displayPilgrimID {
                        Text("ID \(pilgrimID)")
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(L10n.status(session.effectiveStatus, settings.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: statusIcon(session.effectiveStatus))
                    .font(.title3)
                    .foregroundStyle(Color.iumrahCareDark)
            }

            HStack(spacing: 8) {
                Text(localizedPlan(session.booking.planId))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Capsule())
                Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Capsule())
            }

            if !session.booking.hotelNames.makkah.isEmpty {
                Label(session.booking.hotelNames.makkah, systemImage: "building.2")
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
            Image(systemName: "suitcase")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 46, height: 46)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())
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

    private func localizedPlan(_ value: String) -> String {
        guard let tier = PackageTier(rawValue: value.lowercased()) else { return value }
        return tier.title(settings.language)
    }

}
