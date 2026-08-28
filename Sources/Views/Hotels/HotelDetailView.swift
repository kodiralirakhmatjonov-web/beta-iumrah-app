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
    var selectionRole: HotelSelectionRole = .makkah
    var onSelectionSaved: (() -> Void)? = nil

    @State private var detail: HotelDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedImageIndex = 0
    @State private var isGalleryPresented = false
    @State private var selectedRoomID: String?
    @State private var selectedRoomCategory: IumrahRoomCategoryOption?
    @State private var roomCategories: [IumrahRoomCategoryOption] = []
    @State private var isLoadingRoomCategories = false
    @State private var roomCategoryError: String?
    @State private var isSavingSelection = false
    @State private var selectionError: String?

    private let service = HotelCatalogService()
    private let packageEngine = RemotePackageEngineClient()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroCarousel

                VStack(alignment: .leading, spacing: 30) {
                    identitySection

                    if let detail {
                        qualitySection(detail)
                        amenitiesSection(detail)
                        primaryRoomSection(detail)
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
                .padding(.top, 24)
                .padding(.bottom, shouldShowSelectionBar ? 128 : 48)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topLeading) { floatingBackButton }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowSelectionBar, let selectedName = currentSelectionName {
                selectionBar(selectedName)
            }
        }
        .task {
            await load()
            await loadRoomCategories()
        }
        .fullScreenCover(isPresented: $isGalleryPresented) {
            HotelGalleryView(hotelName: hotel.name, images: detail?.images ?? [])
                .environmentObject(settings)
        }
    }

    private var canSelectRooms: Bool { selectionFlow || bookingID != nil }
    private var shouldShowSelectionBar: Bool { bookingID == nil && selectionFlow && currentSelectionName != nil }

    private var currentSelectionName: String? {
        if let selectedRoomCategory { return selectedRoomCategory.displayName }
        if let selectedRoomID, let room = detail?.rooms.first(where: { $0.id == selectedRoomID }) { return room.name }

        switch selectionRole {
        case .makkah:
            guard journey.selectedHotel?.id == hotel.id else { return nil }
            return journey.selectedRoom?.name ?? journey.selectedRoomCategory?.displayName
        case .madinah:
            guard journey.selectedMadinahHotel?.id == hotel.id else { return nil }
            return journey.selectedMadinahRoom?.name ?? journey.selectedMadinahRoomCategory?.displayName
        }
    }

    // MARK: - Hero

    private var sortedImages: [HotelImage] {
        let all = (detail?.images ?? []).sorted(by: imageSort)
        let propertyImages = all.filter { image in
            let roomName = (image.roomName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let category = normalize(image.category)
            return roomName.isEmpty && !category.contains("room")
        }
        return propertyImages.isEmpty ? all : propertyImages
    }

    private var heroCarousel: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if sortedImages.isEmpty {
                    hotelImage(hotel.coverImageURL)
                } else {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(sortedImages.enumerated()), id: \.element.id) { index, image in
                            hotelImage(image.url).tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
            .frame(height: 380)
            .clipped()

            if !sortedImages.isEmpty {
                Button {
                    isGalleryPresented = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("\(min(selectedImageIndex + 1, sortedImages.count))/\(sortedImages.count)")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(.black.opacity(0.38), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .padding(.trailing, 16)
            }
        }
    }

    private var floatingBackButton: some View {
        Button {
            IumrahHaptics.soft()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
        .padding(.leading, 18)
        .padding(.top, 10)
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let stars = hotel.stars {
                Text(String(repeating: "★", count: stars))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(hotel.name)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.9)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                Image(systemName: "mappin.and.ellipse")
                Text(L10n.city(hotel.city, settings.language))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            if let address = detail?.address.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hotel facts

    private func qualitySection(_ detail: HotelDetail) -> some View {
        HStack(spacing: 14) {
            if let rating = detail.rating {
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(ratingTitle(rating))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 96, height: 88)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text("hotel_selected_quality", settings.language))
                    .font(.headline)
                if let count = detail.reviewCount {
                    Text(L10n.format("hotel_reviews_count", settings.language, count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(L10n.text("hotels_note", settings.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5) }
    }

    @ViewBuilder
    private func amenitiesSection(_ detail: HotelDetail) -> some View {
        if !detail.amenities.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(FlowCopy.text(.amenities, settings.language))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(detail.amenities, id: \.self) { amenity in
                        HStack(spacing: 10) {
                            Image(systemName: amenityIcon(amenity))
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .background(Color.iumrahRaisedBackground, in: Circle())
                            Text(localizedAmenity(amenity))
                                .font(.footnote.weight(.semibold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 11)
                        .frame(minHeight: 54)
                        .background(Color.iumrahCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Rooms

    private func primaryRoomSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(FlowCopy.text(.roomsPrepared, settings.language))
            Text(FlowCopy.text(.roomsPreparedBody, settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isLoadingRoomCategories && roomCategories.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(FlowCopy.text(.roomsLoading, settings.language))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
            } else if let roomCategoryError, roomCategories.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(roomCategoryError)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(L10n.text("retry", settings.language)) { Task { await loadRoomCategories() } }
                        .buttonStyle(IumrahSecondaryButtonStyle())
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(roomCategories) { option in
                            primaryRoomCard(option)
                                .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 14)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 4, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func primaryRoomCard(_ option: IumrahRoomCategoryOption) -> some View {
        let selected = isCategorySelected(option)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.16))
                    Image(systemName: categoryIcon(option.category))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(option.displayName)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(roomCategoryBody(option.category))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                roomFactPill(icon: "person.2.fill", text: "\(option.maxGuests)")
                roomFactPill(icon: "bed.double.fill", text: option.bedConfiguration)
            }

            if canSelectRooms {
                Button { select(option) } label: {
                    HStack {
                        Text(selected ? FlowCopy.text(.roomChosen, settings.language) : FlowCopy.text(.chooseRoom, settings.language))
                        Spacer()
                        Image(systemName: selected ? "checkmark" : "arrow.right")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(.white.opacity(selected ? 0.96 : 0.9), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSavingSelection)
            }
        }
        .padding(24)
        .frame(minHeight: canSelectRooms ? 326 : 266, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: tone(for: option.category),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0.56 : 0.12), lineWidth: selected ? 1.5 : 0.6)
        }
        .shadow(color: .black.opacity(0.09), radius: 18, y: 9)
    }

    private func actualRoomsSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(FlowCopy.text(.hotelRooms, settings.language))
            Text(FlowCopy.text(.hotelRoomsBody, settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if detail.rooms.isEmpty {
                Text(L10n.text("hotel_rooms_empty", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.iumrahCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(detail.rooms) { room in
                            actualRoomCard(room, detail: detail)
                                .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 14)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 4, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }

            if let selectionError {
                Text(selectionError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actualRoomCard(_ room: HotelRoom, detail: HotelDetail) -> some View {
        let selected = isRoomSelected(room)
        let roomImages = images(for: room, detail: detail)
        let cleanDescription = cleanRoomDescription(room.description)

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let first = roomImages.first {
                    hotelImage(first.url)
                        .frame(height: 210)
                } else {
                    ZStack {
                        Color.iumrahRaisedBackground
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 180)
                }

                if roomImages.count > 1 {
                    Label("\(roomImages.count)", systemImage: "photo.on.rectangle")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(.black.opacity(0.42), in: Capsule())
                        .padding(16)
                }
            }
            .clipped()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Text(room.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.iumrahCareLight)
                    }
                }

                HStack(spacing: 8) {
                    if let guests = room.maxGuests {
                        compactFact(icon: "person.2.fill", text: "\(guests)")
                    }
                    if let beds = cleanFact(room.beds) {
                        compactFact(icon: "bed.double.fill", text: beds)
                    }
                    if let size = room.sizeM2 {
                        compactFact(icon: "ruler", text: "\(Int(size)) m²")
                    }
                }

                if let cleanDescription {
                    Text(cleanDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if canSelectRooms {
                    Button { select(room) } label: {
                        HStack {
                            Text(selected ? FlowCopy.text(.roomChosen, settings.language) : FlowCopy.text(.chooseRoom, settings.language))
                            Spacer()
                            Image(systemName: selected ? "checkmark" : "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RoomSelectButtonStyle(selected: selected))
                    .disabled(isSavingSelection)
                }
            }
            .padding(20)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(selected ? Color.iumrahCareLight.opacity(0.68) : Color.primary.opacity(0.06), lineWidth: selected ? 1.4 : 0.6)
        }
        .shadow(color: .black.opacity(0.055), radius: 16, y: 8)
    }

    private func roomFactPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(.white.opacity(0.14), in: Capsule())
    }

    private func compactFact(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private func categoryIcon(_ category: IumrahRoomCategory) -> String {
        switch category {
        case .double: return "bed.double.fill"
        case .triple: return "person.3.fill"
        case .quadruple: return "person.3.fill"
        }
    }

    private func cleanFact(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 80 else { return nil }
        let normalized = " \(value.lowercased()) "
        let pollutedTokens = [" sar ", "current price", "previous price", "select room", "% off", "taxes", "non-refundable"]
        guard !pollutedTokens.contains(where: normalized.contains) else { return nil }
        return value
    }

    private func cleanRoomDescription(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let pollutedTokens = [
            "the current price", "the previous price", "select room", "non-refundable",
            "total includes taxes", "we have ", "% off", " sar ", "double room double",
            "triple room triple", "quadruple room quadruple", "our lowest price"
        ]
        let normalized = " \(value.lowercased()) "
        guard !pollutedTokens.contains(where: normalized.contains) else { return nil }

        if value.count <= 190 { return value }
        let prefix = String(value.prefix(190))
        if let boundary = prefix.lastIndex(of: " ") {
            return String(prefix[..<boundary]) + "…"
        }
        return prefix + "…"
    }

    // MARK: - Remaining details

    private func aboutSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L10n.text("hotel_about_title", settings.language))
            Text(detail.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(18)
                .background(Color.iumrahCardBackground)
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
                .frame(height: 245)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                if let url = AppConfig.absoluteURL(detail.googleMapsURL) {
                    Link(destination: url) {
                        HStack {
                            Label(L10n.text("hotel_open_map", settings.language), systemImage: "map.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func practicalSection(_ detail: HotelDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(L10n.text("hotel_practical_title", settings.language))
            VStack(spacing: 0) {
                if let checkIn = detail.checkIn, !checkIn.isEmpty { practicalRow(L10n.text("hotel_checkin", settings.language), checkIn) }
                if let checkOut = detail.checkOut, !checkOut.isEmpty { Divider(); practicalRow(L10n.text("hotel_checkout", settings.language), checkOut) }
                if let type = detail.propertyType, !type.isEmpty { Divider(); practicalRow(L10n.text("hotel_property_type", settings.language), type) }
            }
            .padding(.horizontal, 18)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 12) { ProgressView(); Text(L10n.text("hotel_loading_detail", settings.language)).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, minHeight: 210)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Button(L10n.text("retry", settings.language)) { Task { await load() } }
                .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func selectionBar(_ selectedName: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(FlowCopy.text(.selectedRoom, settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(selectedName)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                IumrahHaptics.success()
                onSelectionSaved?()
                dismiss()
            } label: {
                Text(FlowCopy.text(.done, settings.language))
                    .padding(.horizontal, 20)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .tracking(-0.4)
    }

    private func practicalRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer(minLength: 12)
            Text(value).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 15)
    }

    // MARK: - Selection

    private func isRoomSelected(_ room: HotelRoom) -> Bool {
        if selectedRoomID == room.id && selectedRoomCategory == nil { return true }
        if let bookingID,
           let session = bookings.booking(id: bookingID),
           let snapshot = selectionRole == .madinah ? session.madinahHotelSelection : session.hotelSelection,
           snapshot.hotelId == hotel.id,
           snapshot.roomId == room.id,
           snapshot.roomCategory == nil { return true }

        switch selectionRole {
        case .makkah:
            return journey.selectedHotel?.id == hotel.id && journey.selectedRoom?.id == room.id && journey.selectedRoomCategory == nil
        case .madinah:
            return journey.selectedMadinahHotel?.id == hotel.id && journey.selectedMadinahRoom?.id == room.id && journey.selectedMadinahRoomCategory == nil
        }
    }

    private func isCategorySelected(_ option: IumrahRoomCategoryOption) -> Bool {
        if selectedRoomCategory?.category == option.category { return true }
        if let bookingID,
           let session = bookings.booking(id: bookingID),
           let snapshot = selectionRole == .madinah ? session.madinahHotelSelection : session.hotelSelection,
           snapshot.hotelId == hotel.id,
           snapshot.roomCategory == option.category { return true }

        switch selectionRole {
        case .makkah:
            return journey.selectedHotel?.id == hotel.id && journey.selectedRoomCategory?.category == option.category
        case .madinah:
            return journey.selectedMadinahHotel?.id == hotel.id && journey.selectedMadinahRoomCategory?.category == option.category
        }
    }

    private func select(_ room: HotelRoom) {
        guard canSelectRooms else { return }
        selectionError = nil
        selectedRoomID = room.id
        selectedRoomCategory = nil

        if let bookingID {
            isSavingSelection = true
            Task { @MainActor in
                defer { isSavingSelection = false }
                do {
                    try await bookings.updateHotelSelection(bookingID: bookingID, role: selectionRole, hotel: hotel, room: room, roomCategory: nil)
                    onSelectionSaved?()
                    IumrahHaptics.success()
                } catch {
                    selectedRoomID = nil
                    selectionError = L10n.error(error, settings.language)
                    IumrahHaptics.error()
                }
            }
        } else {
            if selectionRole == .makkah {
                journey.chooseHotel(hotel)
                journey.chooseRoom(room)
            } else {
                journey.chooseMadinahHotel(hotel)
                journey.chooseMadinahRoom(room)
            }
            IumrahHaptics.selection()
        }
    }

    private func select(_ option: IumrahRoomCategoryOption) {
        guard canSelectRooms else { return }
        selectionError = nil
        selectedRoomID = nil
        selectedRoomCategory = option

        if let bookingID {
            isSavingSelection = true
            Task { @MainActor in
                defer { isSavingSelection = false }
                do {
                    try await bookings.updateHotelSelection(bookingID: bookingID, role: selectionRole, hotel: hotel, room: nil, roomCategory: option)
                    onSelectionSaved?()
                    IumrahHaptics.success()
                } catch {
                    selectedRoomCategory = nil
                    selectionError = L10n.error(error, settings.language)
                    IumrahHaptics.error()
                }
            }
        } else {
            if selectionRole == .makkah {
                journey.chooseHotel(hotel)
                journey.chooseRoomCategory(option)
            } else {
                journey.chooseMadinahHotel(hotel)
                journey.chooseMadinahRoomCategory(option)
            }
            IumrahHaptics.selection()
        }
    }

    // MARK: - Images

    private func images(for room: HotelRoom, detail: HotelDetail) -> [HotelImage] {
        let roomName = normalize(room.name)
        let strong = detail.images.filter { image in
            let candidate = normalize([image.roomName, image.label].compactMap { $0 }.joined(separator: " "))
            return !candidate.isEmpty && (candidate.contains(roomName) || roomName.contains(candidate))
        }
        if !strong.isEmpty { return strong.sorted(by: imageSort) }

        let tokens = meaningfulTokens(room.name)
        let tokenMatches = detail.images.filter { image in
            let candidate = normalize([image.roomName, image.label, image.category].compactMap { $0 }.joined(separator: " "))
            return tokens.contains(where: { candidate.contains($0) })
        }
        if !tokenMatches.isEmpty { return tokenMatches.sorted(by: imageSort) }

        // Do not show a random room photo just to fill the card. If the backend
        // does not provide enough metadata for a safe match, the card uses the
        // deliberate room placeholder instead of misleading the pilgrim.
        return []
    }

    private func images(for category: IumrahRoomCategory, detail: HotelDetail) -> [HotelImage] {
        let terms: [String]
        switch category {
        case .double: terms = ["double", "king", "couple"]
        case .triple: terms = ["triple", "three", "3 bed"]
        case .quadruple: terms = ["quad", "four", "4 bed", "family"]
        }
        return detail.images.filter { image in
            let candidate = normalize([image.roomName, image.label, image.category].compactMap { $0 }.joined(separator: " "))
            return terms.contains(where: { candidate.contains($0) })
        }.sorted(by: imageSort)
    }

    private func roomCategoryBody(_ category: IumrahRoomCategory) -> String {
        switch category {
        case .double: return FlowCopy.text(.doubleRoomBody, settings.language)
        case .triple: return FlowCopy.text(.tripleRoomBody, settings.language)
        case .quadruple: return FlowCopy.text(.quadrupleRoomBody, settings.language)
        }
    }

    private func meaningfulTokens(_ value: String) -> [String] {
        let normalized = normalize(value)
        return ["double", "triple", "quad", "king", "twin", "suite", "deluxe", "family", "standard", "executive"]
            .filter { normalized.contains($0) }
    }

    private func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
    }

    private func imageSort(_ lhs: HotelImage, _ rhs: HotelImage) -> Bool {
        if lhs.isCover != rhs.isCover { return lhs.isCover && !rhs.isCover }
        return lhs.position < rhs.position
    }

    private func hotelImage(_ rawURL: String?) -> some View {
        AsyncImage(url: AppConfig.absoluteURL(rawURL)) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .empty: ZStack { Color.iumrahRaisedBackground; ProgressView() }
            default:
                ZStack {
                    Color.iumrahRaisedBackground
                    Image(systemName: "photo")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func tone(for category: IumrahRoomCategory) -> [Color] {
        switch category {
        case .double: return [Color(red: 0.77, green: 0.39, blue: 0.12), Color(red: 0.42, green: 0.20, blue: 0.07)]
        case .triple: return [Color(red: 0.48, green: 0.27, blue: 0.74), Color(red: 0.24, green: 0.13, blue: 0.38)]
        case .quadruple: return [Color(red: 0.18, green: 0.43, blue: 0.76), Color(red: 0.08, green: 0.20, blue: 0.38)]
        }
    }

    private func ratingTitle(_ rating: Double) -> String {
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
    private func loadRoomCategories() async {
        guard !isLoadingRoomCategories else { return }
        isLoadingRoomCategories = true
        roomCategoryError = nil
        defer { isLoadingRoomCategories = false }
        do {
            roomCategories = try await packageEngine.roomCategories(hotelID: hotel.id)
        } catch {
            roomCategories = []
            roomCategoryError = FlowCopy.text(.roomsError, settings.language)
        }
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

private struct RoomSelectButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(selected ? Color.iumrahCareDark : Color.primary)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(selected ? Color.iumrahCareLight.opacity(0.26) : Color.iumrahRaisedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct HotelGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    let hotelName: String
    let images: [HotelImage]
    @State private var index = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if images.isEmpty {
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                TabView(selection: $index) {
                    ForEach(Array(images.sorted(by: imageSort).enumerated()), id: \.element.id) { offset, image in
                        AsyncImage(url: AppConfig.absoluteURL(image.url)) { phase in
                            switch phase {
                            case .success(let loaded): loaded.resizable().scaledToFit()
                            case .empty: ProgressView().tint(.white)
                            default: Image(systemName: "photo").foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(18)
        }
        .overlay(alignment: .topTrailing) {
            if !images.isEmpty {
                Text("\(index + 1)/\(images.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(22)
            }
        }
    }

    private func imageSort(_ lhs: HotelImage, _ rhs: HotelImage) -> Bool {
        if lhs.isCover != rhs.isCover { return lhs.isCover && !rhs.isCover }
        return lhs.position < rhs.position
    }
}
