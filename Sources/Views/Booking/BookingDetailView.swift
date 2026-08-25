import SwiftUI

struct BookingDetailView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    let bookingID: String

    var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(spacing: 22) {
                        hero(session.booking, name: session.travelerName)
                        packageSummary(session.booking)
                        tripSummary(session.booking)
                        contactCard(session)
                        NavigationLink {
                            BookingChatView(bookingID: bookingID)
                        } label: {
                            HStack {
                                Text(L10n.text("detail_chat_cta", settings.language))
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                        }
                        .buttonStyle(IumrahPrimaryButtonStyle())
                    }
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 42)
                }
                .background(Color.iumrahPageBackground)
                .task { await bookings.refreshAll() }
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hero(_ booking: RemoteBooking, name: String?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name ?? booking.id)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(booking.id)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: statusIcon(booking.status))
                    .font(.title2)
            }
            Text(L10n.status(booking.status, settings.language))
                .font(.headline)
            Text(L10n.text("detail_updates", settings.language))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard(dark: true)
    }

    private func packageSummary(_ booking: RemoteBooking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("detail_booking", settings.language))
                .font(.headline)
            summaryRow(title: L10n.text("route_label", settings.language), value: "\(booking.route.originCode) → \(booking.route.outboundDestination)")
            summaryRow(title: L10n.text("route_return", settings.language), value: booking.route.returnOrigin)
            summaryRow(title: booking.hotelNames.makkah, value: booking.input.startDate)
            HStack {
                Text("\(L10n.text("total_for", settings.language)) \(booking.input.travelers.totalPeople) \(L10n.text("travelers", settings.language))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                PackagePriceView(amount: Decimal(booking.totalUsd), currency: "USD")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func tripSummary(_ booking: RemoteBooking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(booking.flight)
                .font(.headline)
            Text("\(booking.input.startDate) — \(booking.input.endDate)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(booking.hotelNames.madinah.isEmpty ? booking.hotelNames.makkah : "\(booking.hotelNames.makkah) · \(booking.hotelNames.madinah)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func contactCard(_ session: StoredBookingSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
