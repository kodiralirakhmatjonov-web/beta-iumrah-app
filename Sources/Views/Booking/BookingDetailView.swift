import SwiftUI

struct BookingDetailView: View {
    @EnvironmentObject private var bookings: BookingStore
    let bookingID: String

    private var session: StoredBookingSession? {
        bookings.session(id: bookingID)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let session {
                    SectionHeader(
                        session.id,
                        eyebrow: "Booking",
                        subtitle: statusTitle(session.booking.status)
                    )

                    statusCard(session.booking)
                    tripCard(session.booking)

                    NavigationLink {
                        BookingChatView(bookingID: session.id)
                    } label: {
                        Label("Чат с iumrah Care", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                } else {
                    ContentUnavailableView("Booking не найден", systemImage: "suitcase")
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await bookings.refresh(id: bookingID) }
        .task { await bookings.refresh(id: bookingID) }
    }

    private func statusCard(_ booking: RemoteBooking) -> some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon(booking.status))
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(Color.iumrahRaisedBackground)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle(booking.status))
                    .font(.headline)
                Text("Статус обновляется из Cloudflare Booking DB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .iumrahCard()
    }

    private func tripCard(_ booking: RemoteBooking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(booking.route.originCode) → \(booking.route.outboundDestination)")
                .font(.title3.weight(.bold))
            Text("\(booking.input.startDate) — \(booking.input.endDate)")
                .foregroundStyle(.secondary)
            if !booking.hotelNames.makkah.isEmpty {
                Label(booking.hotelNames.makkah, systemImage: "building.2")
                    .font(.subheadline)
            }
            if !booking.flight.isEmpty {
                Label(booking.flight, systemImage: "airplane")
                    .font(.subheadline)
            }
            Divider()
            PackagePriceView(amount: booking.perPilgrimUsd, currency: "USD")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }
}

func statusTitle(_ status: String) -> String {
    switch status {
    case "AVAILABILITY_CHECK": return "Проверяем наличие"
    case "PAYMENT_PENDING": return "Ожидает оплаты"
    case "BOOKING_CONFIRMED": return "Бронирование подтверждено"
    case "READY_TO_TRAVEL": return "Готово к поездке"
    case "COMPLETED": return "Поездка завершена"
    default: return status.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

func statusIcon(_ status: String) -> String {
    switch status {
    case "AVAILABILITY_CHECK": return "clock.badge.checkmark"
    case "PAYMENT_PENDING": return "creditcard"
    case "BOOKING_CONFIRMED": return "checkmark.seal.fill"
    case "READY_TO_TRAVEL": return "airplane.circle.fill"
    case "COMPLETED": return "checkmark.circle.fill"
    default: return "suitcase"
    }
}
