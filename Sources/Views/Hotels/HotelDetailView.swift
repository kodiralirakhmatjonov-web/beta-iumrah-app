import SwiftUI
import MapKit

struct HotelDetailView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @Environment(\.dismiss) private var dismiss

    let hotel: HotelSummary
    var bookingID: String? = nil
    var onRoomSelected: ((HotelRoom) -> Void)? = nil

    @State private var detail: HotelDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedImageIndex = 0
    @State private var isGalleryPresented = false
    @State private var selectedRoomID: String?
    @State private var isSavingSelection = false
    @State private var selectionError: String?

    private let service = HotelCatalogService()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                mediaHero

                VStack(alignment: .leading, spacing: 28) {
                    identitySection

                    if let detail {
                        ratingAndHighlights(detail)
                        amenitiesSection(detail)
                        descriptionSection(detail)
                        mapSection(detail)
                        roomsSection(detail)
                        practicalSection(detail)
                    } else if isLoading {
                        loadingSection
                    } else if let errorMessage {
                        errorSection(errorMessage)
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 24)
                .padding(.bottom, 54)
            }
        }
        .background(Color.iumrahPageBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            compactTopBar
        }
        .task { await load() }
        .fullScreenCover(isPresented: $isGalleryPresented) {
            HotelGalleryView(hotelName: hotel.name, images: detail?.images ?? [])
                .environmentObject(settings)
        }
    }

    private var compactTopBar: some View {
        HStack {
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

            Spacer()

            Text(hotel.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: 230)

            Spacer()

            Button {
                isGalleryPresented = true
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled((detail?.images.isEmpty ?? true))
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var mediaHero: some View {
        let images = detail?.images.sorted(by: imageSort) ?? []
        if !images.isEmpty {
            ZStack(alignment: .bottomTrailing) {
                TabView(selection: $selectedImageIndex) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        hotelImage(image.url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 360)

                Button {
                    isGalleryPresented = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "square.grid.2x2")
                        Text(L10n.format("hotel_all_photos_count", settings.language, images.count))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 13)
                    .frame(height: 38)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(18)
            }
        } else {
            AsyncImage(url: AppConfig.absoluteURL(hotel.coverImageURL)) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color.iumrahRaisedBackground
                        Image(systemName: "building.2")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 320)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(hotel.name)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                if let stars = hotel.stars {
                    Text(String(repeating: "★", count: stars))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            Label(L10n.city(hotel.city, settings.language), systemImage: "mappin.and.ellipse")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let detail, !detail.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(detail.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func ratingAndHighlights(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let rating = detail.rating {
                    Text(String(format: "%.1f", rating))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 48)
                        .background(Color.iumrahCareDark)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(ratingTitle(detail.rating))
                        .font(.headline)
                    if let count = detail.reviewCount {
                        Text(L10n.format("hotel_reviews_count", settings.language, count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            let highlights = Array(detail.amenities.prefix(4))
            if !highlights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(highlights, id: \.self) { item in
                            Label(localizedAmenity(item), systemImage: amenityIcon(item))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(Color.iumrahRaisedBackground)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func amenitiesSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(L10n.text("hotel_amenities_title", settings.language))
            if detail.amenities.isEmpty {
                Text(L10n.text("hotel_amenities_empty", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(detail.amenities, id: \.self) { amenity in
                        HStack(spacing: 10) {
                            Image(systemName: amenityIcon(amenity))
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .background(Color.iumrahRaisedBackground)
                                .clipShape(Circle())
                            Text(localizedAmenity(amenity))
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func descriptionSection(_ detail: HotelDetail) -> some View {
        if !detail.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(L10n.text("hotel_about_title", settings.language))
                Text(detail.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
                }

                if let url = AppConfig.absoluteURL(detail.googleMapsURL) {
                    Link(destination: url) {
                        HStack {
                            Label(L10n.text("hotel_open_map", settings.language), systemImage: "arrow.triangle.turn.up.right.diamond")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                    .buttonStyle(IumrahSecondaryButtonStyle())
                }
            }
        }
    }

    private func roomsSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(L10n.text("hotel_rooms_title", settings.language))
            Text(L10n.text("hotel_rooms_subtitle", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if detail.rooms.isEmpty {
                Text(L10n.text("hotel_rooms_empty", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .iumrahCard()
            } else {
                ForEach(detail.rooms) { room in
                    HotelRoomSelectionCard(
                        room: room,
                        images: roomImages(room, in: detail),
                        isSelected: isRoomSelected(room),
                        isSaving: isSavingSelection && selectedRoomID == room.id,
                        action: { select(room) }
                    )
                    .environmentObject(settings)
                }
                if let selectionError {
                    Text(selectionError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func practicalSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(L10n.text("hotel_practical_title", settings.language))
            VStack(spacing: 12) {
                if let checkIn = detail.checkIn, !checkIn.isEmpty {
                    infoRow(L10n.text("hotel_checkin", settings.language), checkIn)
                }
                if let checkOut = detail.checkOut, !checkOut.isEmpty {
                    infoRow(L10n.text("hotel_checkout", settings.language), checkOut)
                }
                if let type = detail.propertyType, !type.isEmpty {
                    infoRow(L10n.text("hotel_property_type", settings.language), type)
                }
            }
            .iumrahCard()
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(L10n.text("hotel_loading_detail", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(L10n.text("retry", settings.language)) {
                Task { await load() }
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .iumrahCard()
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 23, weight: .bold, design: .rounded))
            .tracking(-0.3)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
        if let bookingID {
            selectedRoomID = room.id
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
            selectedRoomID = room.id
            journey.chooseHotel(hotel)
            journey.chooseRoom(room)
            onRoomSelected?(room)
            IumrahHaptics.success()
        }
    }

    private func roomImages(_ room: HotelRoom, in detail: HotelDetail) -> [HotelImage] {
        let roomName = room.name.lowercased()
        let exact = detail.images.filter { image in
            image.roomName?.lowercased() == roomName ||
            image.label?.lowercased().contains(roomName) == true
        }
        if !exact.isEmpty { return exact.sorted(by: imageSort) }
        let generic = detail.images.filter { $0.category.lowercased().contains("room") }
        return Array((generic.isEmpty ? detail.images : generic).sorted(by: imageSort).prefix(8))
    }

    private func imageSort(_ lhs: HotelImage, _ rhs: HotelImage) -> Bool {
        if lhs.isCover != rhs.isCover { return lhs.isCover && !rhs.isCover }
        return lhs.position < rhs.position
    }

    private func hotelImage(_ rawURL: String) -> some View {
        AsyncImage(url: AppConfig.absoluteURL(rawURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                ZStack { Color.iumrahRaisedBackground; ProgressView() }
            default:
                ZStack {
                    Color.iumrahRaisedBackground
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
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

private struct HotelRoomSelectionCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let room: HotelRoom
    let images: [HotelImage]
    let isSelected: Bool
    let isSaving: Bool
    let action: () -> Void

    @State private var page = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            roomMedia

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(room.name)
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 10)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.iumrahCareDark)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if let maxGuests = room.maxGuests {
                        featureRow("person.2", L10n.format("room_sleeps", settings.language, maxGuests))
                    }
                    if let size = room.sizeM2 {
                        featureRow("arrow.up.left.and.arrow.down.right", L10n.format("room_size", settings.language, size))
                    }
                    if let beds = room.beds, !beds.isEmpty {
                        featureRow("bed.double", beds)
                    }
                    if let view = room.view, !view.isEmpty {
                        featureRow("eye", view)
                    }
                    ForEach(room.amenities.prefix(5), id: \.self) { amenity in
                        featureRow("checkmark.circle", amenity)
                    }
                }

                if let description = room.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: action) {
                    if isSaving {
                        ProgressView().tint(Color.iumrahPrimaryButtonText)
                    } else {
                        Text(isSelected ? L10n.text("room_selected", settings.language) : L10n.text("room_select", settings.language))
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(isSaving)
            }
            .padding(18)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(isSelected ? Color.iumrahCareLight.opacity(0.75) : Color.primary.opacity(0.06), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
    }

    @ViewBuilder
    private var roomMedia: some View {
        if images.isEmpty {
            ZStack {
                Color.iumrahRaisedBackground
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 220)
        } else {
            TabView(selection: $page) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    AsyncImage(url: AppConfig.absoluteURL(image.url)) { phase in
                        switch phase {
                        case .success(let value): value.resizable().scaledToFill()
                        default: Color.iumrahRaisedBackground
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 240)
            .clipped()
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}

struct HotelGalleryView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    let hotelName: String
    let images: [HotelImage]

    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(images.sorted(by: { $0.position < $1.position })) { image in
                        AsyncImage(url: AppConfig.absoluteURL(image.url)) { phase in
                            switch phase {
                            case .success(let value): value.resizable().scaledToFill()
                            default: Color.iumrahRaisedBackground
                            }
                        }
                        .frame(height: 180)
                        .clipped()
                    }
                }
            }
            .background(Color.black)
            .navigationTitle(hotelName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("close", settings.language)) { dismiss() }
                }
            }
        }
    }
}
