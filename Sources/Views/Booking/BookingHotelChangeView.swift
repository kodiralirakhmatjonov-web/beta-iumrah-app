import SwiftUI

struct BookingHotelChangeView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String
    let role: HotelSelectionRole

    @State private var hotels: [HotelSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = HotelCatalogService()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("booking_change_hotel_title", settings.language))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(L10n.text("booking_change_hotel_body", settings.language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isLoading && hotels.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                    }

                    ForEach(hotels) { hotel in
                        NavigationLink {
                            HotelDetailView(
                                hotel: hotel,
                                bookingID: bookingID,
                                selectionRole: role,
                                onSelectionSaved: {
                                    dismiss()
                                }
                            )
                        } label: {
                            HotelCard(hotel: hotel)
                        }
                        .buttonStyle(.plain)
                    }

                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(L10n.text("retry", settings.language)) {
                                Task { await load() }
                            }
                            .buttonStyle(IumrahSecondaryButtonStyle())
                        }
                        .iumrahCard()
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 46)
            }
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Color.iumrahRaisedBackground)
                            .clipShape(Circle())
                    }
                }
            }
            .task { await load() }
        }
    }

    @MainActor
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            hotels = try await service.listHotels(city: role == .madinah ? "Madinah" : "Makkah")
        } catch {
            errorMessage = L10n.text("hotels_load_error", settings.language)
        }
    }
}
