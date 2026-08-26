import SwiftUI
import MapKit

struct HotelDetailView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @Environment(\.dismiss) private var dismiss

    let hotel: HotelSummary
    var bookingID: String? = nil
    var selectionFlow: Bool = false
    var onRoomSelected: ((HotelRoom) -> Void)? = nil

    @State private var detail: HotelDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedImageIndex = 0
    @State private var isGalleryPresented = false
    @State private var selectedRoomID: String?
    @State private var isSavingSelection = false
    @State private var selectionError: String?
    @State private var navigateToFlights = false

    private let service = HotelCatalogService()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection

                VStack(alignment: .leading, spacing: 26) {
                    if let detail {
                        factsSection(detail)
                        primaryRoomSection
                        actualRoomsSection(detail)
                        if !detail.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            aboutSection(detail)
                        }
                        mapSection(detail)
                        practicalSection(detail)
                    } else if isLoading {
                        loadingSection
                    } else if let errorMessage {
                        errorSection(errorMessage)
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 22)
                .padding(.bottom, 120)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topLeading) {
            topBackButton
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowContinueBar, let selectedRoom = currentSelectedRoom {
                continueBar(selectedRoom)
            }
        }
        .task { await load() }
        .fullScreenCover(isPresented: $isGalleryPresented) {
            HotelGalleryView(hotelName: hotel.name, images: detail?.images ?? [])
                .environmentObject(settings)
        }
        .navigationDestination(isPresented: $navigateToFlights) {
            OutboundFlightView()
        }
    }

    private var shouldShowContinueBar: Bool {
        bookingID == nil && selectionFlow && currentSelectedRoom != nil
    }

    private var currentSelectedRoom: HotelRoom? {
        if let selectedRoomID {
            if let curated = curatedRoomOptions.first(where: { $0.id == selectedRoomID }) {
                return curated.asRoom
            }
            if let room = detail?.rooms.first(where: { $0.id == selectedRoomID }) {
                return room
            }
        }
        if journey.selectedHotel?.id == hotel.id {
            return journey.selectedRoom
        }
        return nil
    }

    private var topBackButton: some View {
        Button {
            IumrahHaptics.soft()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .padding(.leading, 18)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var heroSection: some View {
        let images = sortedImages
        ZStack(alignment: .bottomLeading) {
            Group {
                if !images.isEmpty {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                            heroImage(image.url)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                } else {
                    heroImage(hotel.coverImageURL)
                }
            }
            .frame(height: 470)
            .overlay(alignment: .topTrailing) {
                if !images.isEmpty {
                    paginationBadge(total: images.count)
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                }
            }

            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.18), Color.black.opacity(0.84), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 14) {
                    if let stars = hotel.stars {
                        Text(String(repeating: "★", count: stars))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Text(hotel.name)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.city(hotel.city, settings.language))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))

                    if let detail, !detail.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(detail.address)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.54))
                            .lineLimit(2)
                    }

                    ZStack {
                        RadialGradient(
                            colors: [Color.orange.opacity(0.32), Color.orange.opacity(0.0)],
                            center: .center,
                            startRadius: 12,
                            endRadius: 94
                        )
                        .frame(width: 230, height: 94)

                        Button {
                            isGalleryPresented = true
                        } label: {
                            HStack(spacing: 10) {
                                Text(L10n.text("hotel_view_all_photos", settings.language))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 26)
                            .frame(height: 56)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.bottom, 22)
            }
            .frame(height: 245)
        }
        .frame(maxWidth: .infinity)
    }

    private var sortedImages: [HotelImage] {
        (detail?.images ?? []).sorted(by: imageSort)
    }

    private func paginationBadge(total: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.on.rectangle.angled")
            Text("\(selectedImageIndex + 1)/\(max(total, 1))")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func factsSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if let rating = detail.rating {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", rating))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.black)
                        Text(ratingTitle(detail.rating))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.68))
                            .lineLimit(1)
                    }
                    .frame(width: 84, height: 84)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("hotel_selected_quality", settings.language))
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let count = detail.reviewCount {
                        Text(L10n.format("hotel_reviews_count", settings.language, count))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Text(L10n.text("hotels_note", settings.language))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(3)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(detail.amenities.prefix(10)), id: \.self) { amenity in
                        HotelHighlightPill(title: localizedAmenity(amenity), icon: amenityIcon(amenity))
                    }
                }
            }
        }
    }

    private var primaryRoomSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("hotel_primary_rooms_title", settings.language))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(L10n.text("hotel_primary_rooms_body", settings.language))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(curatedRoomOptions) { option in
                        PrimaryRoomQuickPickCard(
                            option: option,
                            isSelected: selectedRoomID == option.id || (journey.selectedHotel?.id == hotel.id && journey.selectedRoom?.id == option.id),
                            action: { select(option.asRoom) }
                        )
                        .environmentObject(settings)
                        .frame(width: 270)
                    }
                }
                .padding(.trailing, 6)
            }
        }
    }

    private func actualRoomsSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("hotel_real_rooms_title", settings.language))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(L10n.text("hotel_real_rooms_body", settings.language))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))

            if detail.rooms.isEmpty {
                Text(L10n.text("hotel_rooms_empty", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(detail.rooms) { room in
                            HotelActualRoomCard(
                                room: room,
                                isSelected: isRoomSelected(room),
                                action: { select(room) }
                            )
                            .environmentObject(settings)
                            .frame(width: 300)
                        }
                    }
                    .padding(.trailing, 6)
                }
            }

            if let selectionError {
                Text(selectionError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func aboutSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.text("hotel_about_title", settings.language))
            Text(detail.description)
                .font(.body)
                .foregroundStyle(.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
                .padding(18)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    @ViewBuilder
    private func mapSection(_ detail: HotelDetail) -> some View {
        if let latitude = detail.latitude, let longitude = detail.longitude {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L10n.text("hotel_location_title", settings.language))
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                ))) {
                    Marker(hotel.name, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }

                if let url = AppConfig.absoluteURL(detail.googleMapsURL) {
                    Link(destination: url) {
                        HStack {
                            Label(L10n.text("hotel_open_map", settings.language), systemImage: "arrow.triangle.turn.up.right.diamond")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(DarkOutlineButtonStyle())
                }
            }
        }
    }

    private func practicalSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(L10n.text("hotel_practical_title", settings.language))
            VStack(spacing: 12) {
                if let checkIn = detail.checkIn, !checkIn.isEmpty {
                    practicalRow(L10n.text("hotel_checkin", settings.language), checkIn)
                }
                if let checkOut = detail.checkOut, !checkOut.isEmpty {
                    practicalRow(L10n.text("hotel_checkout", settings.language), checkOut)
                }
                if let type = detail.propertyType, !type.isEmpty {
                    practicalRow(L10n.text("hotel_property_type", settings.language), type)
                }
            }
            .padding(18)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.white)
            Text(L10n.text("hotel_loading_detail", settings.language))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
            Button(L10n.text("retry", settings.language)) {
                Task { await load() }
            }
            .buttonStyle(DarkOutlineButtonStyle())
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func continueBar(_ room: HotelRoom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("hotel_room_chosen", settings.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.52))
                    Text(room.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                if isSavingSelection {
                    ProgressView().tint(.white)
                } else {
                    Button {
                        navigateToFlights = true
                    } label: {
                        Text(L10n.text("hotel_continue_flights", settings.language))
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.86))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
    }

    private func practicalRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.trailing)
        }
    }

    private func isRoomSelected(_ room: HotelRoom) -> Bool {
        if selectedRoomID == room.id { return true }
        if let bookingID,
           let snapshot = bookings.booking(id: bookingID)?.hotelSelection,
           snapshot.hotelId == hotel.id,
           snapshot.roomId == room.id {
            return true
        }
        return journey.selectedHotel?.id == hotel.id && journey.selectedRoom?.id == room.id
    }

    private func select(_ room: HotelRoom) {
        selectionError = nil
        selectedRoomID = room.id

        if let bookingID {
            isSavingSelection = true
            Task { @MainActor in
                defer { isSavingSelection = false }
                do {
                    try await bookings.updateHotelSelection(bookingID: bookingID, hotel: hotel, room: room)
                    onRoomSelected?(room)
                    IumrahHaptics.success()
                } catch {
                    selectedRoomID = nil
                    selectionError = L10n.error(error, settings.language)
                    IumrahHaptics.error()
                }
            }
        } else {
            journey.chooseHotel(hotel)
            journey.chooseRoom(room)
            IumrahHaptics.success()
        }
    }

    private func imageSort(_ lhs: HotelImage, _ rhs: HotelImage) -> Bool {
        if lhs.isCover != rhs.isCover { return lhs.isCover && !rhs.isCover }
        return lhs.position < rhs.position
    }

    private func heroImage(_ rawURL: String?) -> some View {
        AsyncImage(url: AppConfig.absoluteURL(rawURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                ZStack { Color(red: 0.13, green: 0.13, blue: 0.14); ProgressView().tint(.white) }
            default:
                ZStack {
                    Color(red: 0.13, green: 0.13, blue: 0.14)
                    Image(systemName: "building.2")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func ratingTitle(_ rating: Double?) -> String {
        guard let rating else { return L10n.text("hotel_selected_quality", settings.language) }
        if rating >= 9 { return L10n.text("hotel_rating_exceptional", settings.language) }
        if rating >= 8 { return L10n.text("hotel_rating_very_good", settings.language) }
        if rating >= 7 { return L10n.text("hotel_rating_good", settings.language) }
        return L10n.text("hotel_selected_quality", settings.language)
    }

    private func localizedAmenity(_ raw: String) -> String {
        let normalized = raw.lowercased()
        if normalized.contains("breakfast") { return L10n.text("amenity_breakfast", settings.language) }
        if normalized.contains("transfer") || normalized.contains("shuttle") { return L10n.text("amenity_transfer", settings.language) }
        if normalized.contains("wifi") || normalized.contains("wi-fi") { return L10n.text("amenity_wifi", settings.language) }
        if normalized.contains("parking") { return L10n.text("amenity_parking", settings.language) }
        if normalized.contains("restaurant") { return L10n.text("amenity_restaurant", settings.language) }
        if normalized.contains("air condition") { return L10n.text("amenity_air_conditioning", settings.language) }
        if normalized.contains("family") { return L10n.text("amenity_family_rooms", settings.language) }
        if normalized.contains("24") || normalized.contains("reception") { return L10n.text("amenity_reception", settings.language) }
        if normalized.contains("lift") || normalized.contains("elevator") { return L10n.text("amenity_elevator", settings.language) }
        if normalized.contains("laundry") { return L10n.text("amenity_laundry", settings.language) }
        return raw
    }

    private func amenityIcon(_ raw: String) -> String {
        let normalized = raw.lowercased()
        if normalized.contains("breakfast") || normalized.contains("restaurant") { return "fork.knife" }
        if normalized.contains("transfer") || normalized.contains("shuttle") { return "bus.fill" }
        if normalized.contains("wifi") || normalized.contains("wi-fi") { return "wifi" }
        if normalized.contains("parking") { return "parkingsign.circle" }
        if normalized.contains("air condition") { return "snowflake" }
        if normalized.contains("family") { return "person.2.fill" }
        if normalized.contains("24") || normalized.contains("reception") { return "bell.fill" }
        if normalized.contains("lift") || normalized.contains("elevator") { return "arrow.up.arrow.down" }
        if normalized.contains("laundry") { return "tshirt.fill" }
        return "checkmark.circle.fill"
    }

    private var curatedRoomOptions: [CuratedRoomOption] {
        [
            CuratedRoomOption(
                id: "iumrah-double-room",
                titleKey: "room_type_double",
                subtitleKey: "room_type_double_body",
                badgeKey: "hotel_primary_room_badge",
                icon: "bed.double.fill",
                maxGuests: 2,
                beds: "1 King Bed",
                tone: .orange
            ),
            CuratedRoomOption(
                id: "iumrah-triple-room",
                titleKey: "room_type_triple",
                subtitleKey: "room_type_triple_body",
                badgeKey: "hotel_primary_room_badge",
                icon: "person.3.fill",
                maxGuests: 3,
                beds: "3 Single Beds",
                tone: .purple
            ),
            CuratedRoomOption(
                id: "iumrah-quad-room",
                titleKey: "room_type_quad",
                subtitleKey: "room_type_quad_body",
                badgeKey: "hotel_primary_room_badge",
                icon: "square.grid.2x2.fill",
                maxGuests: 4,
                beds: "4 Single Beds",
                tone: .blue
            )
        ]
    }

    @MainActor
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await service.hotelDetail(id: hotel.id)
        } catch {
            errorMessage = L10n.text("hotels_load_error", settings.language)
        }
    }
}

private struct HotelHighlightPill: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

private enum PrimaryRoomTone {
    case orange
    case purple
    case blue

    var colors: [Color] {
        switch self {
        case .orange:
            return [Color(red: 0.83, green: 0.42, blue: 0.16), Color(red: 0.38, green: 0.18, blue: 0.08)]
        case .purple:
            return [Color(red: 0.53, green: 0.25, blue: 0.78), Color(red: 0.20, green: 0.12, blue: 0.33)]
        case .blue:
            return [Color(red: 0.22, green: 0.52, blue: 0.92), Color(red: 0.11, green: 0.21, blue: 0.40)]
        }
    }
}

private struct CuratedRoomOption: Identifiable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let badgeKey: String
    let icon: String
    let maxGuests: Int
    let beds: String
    let tone: PrimaryRoomTone

    var asRoom: HotelRoom {
        HotelRoom(
            id: id,
            name: titleKey == "room_type_double" ? "Double Room" : titleKey == "room_type_triple" ? "Triple Room" : "Quadruple Room",
            maxGuests: maxGuests,
            sizeM2: nil,
            beds: beds,
            view: nil,
            description: nil,
            amenities: []
        )
    }
}

private struct PrimaryRoomQuickPickCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let option: CuratedRoomOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text(option.badgeKey, settings.language))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.74))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 4)

            Image(systemName: option.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text(option.titleKey, settings.language))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(L10n.text(option.subtitleKey, settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                factRow(icon: "person.2.fill", text: L10n.format("room_sleeps", settings.language, option.maxGuests))
                factRow(icon: "bed.double.fill", text: option.beds)
            }
            .foregroundStyle(.white.opacity(0.86))

            Button(action: action) {
                Text(isSelected ? L10n.text("room_selected", settings.language) : L10n.text("room_select", settings.language))
            }
            .buttonStyle(PrimaryRoomButtonStyle(selected: isSelected))
        }
        .padding(20)
        .frame(height: 270)
        .background(
            LinearGradient(colors: option.tone.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.14), lineWidth: isSelected ? 2 : 1)
        }
    }

    private func factRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
    }
}

private struct PrimaryRoomButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(selected ? Color.white : Color.black)
            .background(selected ? Color.white.opacity(0.18) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private struct HotelActualRoomCard: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let room: HotelRoom
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(room.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if isSelected {
                        Text(L10n.text("selected", settings.language))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                Spacer(minLength: 8)
            }

            VStack(alignment: .leading, spacing: 10) {
                if let maxGuests = room.maxGuests {
                    feature(icon: "person.2.fill", text: L10n.format("room_sleeps", settings.language, maxGuests))
                }
                if let beds = room.beds, !beds.isEmpty {
                    feature(icon: "bed.double.fill", text: beds)
                }
                if let size = room.sizeM2 {
                    feature(icon: "arrow.up.left.and.arrow.down.right", text: L10n.format("room_size", settings.language, size))
                }
                if let view = room.view, !view.isEmpty {
                    feature(icon: "eye", text: view)
                }
                ForEach(Array(room.amenities.prefix(4)), id: \.self) { amenity in
                    feature(icon: "checkmark.circle.fill", text: amenity)
                }
            }

            Spacer(minLength: 4)

            Button(action: action) {
                Text(isSelected ? L10n.text("room_selected", settings.language) : L10n.text("room_select", settings.language))
            }
            .buttonStyle(DarkSolidButtonStyle(selected: isSelected))
        }
        .padding(20)
        .frame(minHeight: 250)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.85) : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        }
    }

    private func feature(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(.white.opacity(0.84))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DarkSolidButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(selected ? Color.black : Color.white)
            .background(selected ? Color.white : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(selected ? 0.0 : 0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

private struct DarkOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white.opacity(configuration.isPressed ? 0.10 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct HotelGalleryView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    let hotelName: String
    let images: [HotelImage]

    private let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(hotelName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 76)

                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(images.sorted(by: { $0.position < $1.position })) { image in
                            AsyncImage(url: AppConfig.absoluteURL(image.url)) { phase in
                                switch phase {
                                case .success(let value): value.resizable().scaledToFill()
                                default: Color.white.opacity(0.06)
                                }
                            }
                            .frame(height: 190)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
            .padding(.top, 16)
        }
    }
}
