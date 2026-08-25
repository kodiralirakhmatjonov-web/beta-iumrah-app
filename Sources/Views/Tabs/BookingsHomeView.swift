import SwiftUI

struct BookingsHomeView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
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
                    }
                } else {
                    noBookingsCard
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .refreshable { await bookings.refreshAll() }
        .task { await bookings.refreshAll() }
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
                    Text(session.travelerName ?? session.id)
                        .font(.headline)
                    Text(session.id)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.status(session.booking.status, settings.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: statusIcon(session.booking.status))
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
