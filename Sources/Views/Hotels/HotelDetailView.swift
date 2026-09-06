import SwiftUI
import MapKit

struct HotelDetailView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var storefront: HotelStorefrontStore
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
    @State private var roomImageIndices: [String: Int] = [:]
    @State private var selectionError: String?
    @State private var storefrontTier: PackageTier = .standard
    @State private var carePresented = false

    private let service = HotelCatalogService()
    private let packageEngine = RemotePackageEngineClient()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroCarousel

                VStack(alignment: .leading, spacing: 30) {
                    identitySection

                    if !selectionFlow && bookingID == nil {
                        storefrontPackageSection
                    }

                    if let detail {
                        qualitySection(detail)
                        receptionClocksSection
                        photoOverviewSection(detail)
                        amenitiesSection(detail)
                        primaryRoomSection(detail)
                        actualRoomsSection(detail)
                        if !detail.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            aboutSection(detail)
                        }
                        mapSection(detail)
                        practicalSection(detail)
                        HotelCareShowcaseCard(language: settings.language) { carePresented = true }
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
        .navigationTitle(hotel.name)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: storefront.shareURL(for: hotel)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(settings.language == .russian ? "Поделиться отелем" : "Share hotel")
                Button { storefront.toggleFavorite(hotel) } label: {
                    Image(systemName: storefront.isFavorite(hotel) ? "heart.fill" : "heart")
                }
                .accessibilityLabel(settings.language == .russian
                                    ? (storefront.isFavorite(hotel) ? "Убрать из избранного" : "Добавить в избранное")
                                    : (storefront.isFavorite(hotel) ? "Remove from favorites" : "Add to favorites"))
            }
        }
        .iumrahInternalNavigation()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowSelectionBar, let selectedName = currentSelectionName {
                selectionBar(selectedName)
            }
        }
        .task {
            await storefront.prepareIfNeeded()
            await load()
            await loadRoomCategories()
        }
        .fullScreenCover(isPresented: $isGalleryPresented) {
            HotelGalleryView(hotelName: hotel.name, images: detail?.images ?? [])
                .environmentObject(settings)
        }
        .sheet(isPresented: $carePresented) {
            HotelCareContactSheet()
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
                    .iumrahGlass(in: Capsule(), interactive: true, tint: .black.opacity(0.22), chrome: true)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .padding(.trailing, 16)
            }
        }
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

            Label("iumrah Hotels", systemImage: "building.2.fill")
                .font(.caption.weight(.semibold))
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

    // MARK: - Storefront package

    private var storefrontPackageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(settings.language == .russian ? "Ваша Умра с этим отелем" : "Your Umrah with this hotel")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(settings.language == .russian ? "Готовая цена до выбора дат" : "Ready price before choosing dates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("IUMRAH")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Picker("Package", selection: $storefrontTier) {
                Text(PackageTier.standard.title(settings.language)).tag(PackageTier.standard)
                Text(PackageTier.luxury.title(settings.language)).tag(PackageTier.luxury)
            }
            .pickerStyle(.segmented)
            .onChange(of: storefrontTier) { _, _ in IumrahHaptics.selection() }

            if let quote = storefront.quote(for: hotel, tier: storefrontTier) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(money(quote.packageQuote.pricePerPerson))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .tracking(-0.8)
                        Text(settings.language == .russian ? "на паломника" : "per pilgrim")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(money(quote.packageQuote.totalPackagePrice))
                            .font(.headline)
                        Text(settings.language == .russian ? "за пакет на \(quote.travelers)" : "package total for \(quote.travelers)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    packageFact(icon: "airplane", text: "TAS → MED · JED → TAS")
                    packageFact(
                        icon: "building.2.fill",
                        text: settings.language == .russian
                            ? "\(hotel.name) · \(quote.hotelNights) ноч."
                            : "\(hotel.name) · \(quote.hotelNights) nights"
                    )
                    packageFact(icon: "fork.knife", text: settings.language == .russian ? "Питание · трансферы · виза" : "Meals · transfers · visa")
                    packageFact(icon: "heart.fill", text: "iumrah Care")
                }

                if storefrontTier == .standard {
                    Button {
                        storefrontTier = .luxury
                        IumrahHaptics.selection()
                    } label: {
                        Label(settings.language == .russian ? "Перейти на Luxury" : "Upgrade to Luxury", systemImage: "sparkles")
                    }
                    .buttonStyle(IumrahSecondaryButtonStyle())
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(settings.language == .russian ? "Подготавливаем актуальную цену…" : "Preparing current price…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            }

            Text(settings.language == .russian
                 ? "Standard используется по умолчанию для всех отелей, включая 5★. Luxury включается только по вашему выбору."
                 : "Standard is the default for every hotel, including 5★. Luxury is applied only when you choose it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahCard()
    }

    private func packageFact(icon: String, text: String) -> some View {
        HStack(spacing: 9) {
            IumrahInlineIcon(systemName: icon, size: 14)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var receptionClocksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(settings.language == .russian ? "Время в пути" : "Hotel time")
            Text(settings.language == .russian
                 ? "Как на стойке ресепшена — время дома и в городах вашей Умры."
                 : "Reception-style clocks for home and your Umrah cities.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ReceptionClock(city: "TASHKENT", timeZoneID: "Asia/Tashkent")
                ReceptionClock(city: "MAKKAH", timeZoneID: "Asia/Riyadh")
                ReceptionClock(city: "MADINAH", timeZoneID: "Asia/Riyadh")
                ReceptionClock(city: "MOSCOW", timeZoneID: "Europe/Moscow")
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func photoOverviewSection(_ detail: HotelDetail) -> some View {
        let photos = detail.images.sorted(by: imageSort)
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    sectionTitle(settings.language == .russian ? "Фотографии" : "Photos")
                    Spacer()
                    Button {
                        isGalleryPresented = true
                    } label: {
                        Text(settings.language == .russian ? "Посмотреть все \(photos.count)" : "View all \(photos.count)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    HotelCachedImage(rawURL: photos[0].url)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    VStack(spacing: 4) {
                        HotelCachedImage(rawURL: photos[safe: 1]?.url ?? photos[0].url)
                            .clipped()
                        HotelCachedImage(rawURL: photos[safe: 2]?.url ?? photos[0].url)
                            .clipped()
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .onTapGesture { isGalleryPresented = true }
            }
        }
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
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
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(detail.amenities, id: \.self) { amenity in
                        HStack(spacing: 10) {
                            IumrahIconBadge(
                                systemName: amenityIcon(amenity),
                                size: 28,
                                symbolSize: 13,
                                shape: .circle
                            )
                            Text(localizedAmenity(amenity))
                                .font(.footnote.weight(.semibold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 11)
                        .frame(minHeight: 50)
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
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .scrollTargetLayout()
                }
                .padding(.horizontal, -IumrahDesign.pagePadding)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func primaryRoomCard(_ option: IumrahRoomCategoryOption) -> some View {
        let selected = isCategorySelected(option)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: categoryIcon(option.category))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .iumrahGlass(in: Circle(), tint: Color.white.opacity(0.16))

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
                    .iumrahGlass(
                        in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                        interactive: true,
                        tint: selected ? Color.white.opacity(0.24) : nil
                    )
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
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .scrollTargetLayout()
                }
                .padding(.horizontal, -IumrahDesign.pagePadding)
                .contentMargins(.horizontal, 0, for: .scrollContent)
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
                if roomImages.isEmpty {
                    ZStack {
                        Color.iumrahRaisedBackground
                        VStack(spacing: 10) {
                            Image(systemName: "bed.double.fill")
                                .font(.system(size: 34, weight: .light))
                            Text(FlowCopy.text(.hotelRooms, settings.language))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .frame(height: 196)
                } else {
                    TabView(selection: roomImageSelectionBinding(for: room.id)) {
                        ForEach(Array(roomImages.enumerated()), id: \.offset) { index, image in
                            hotelImage(image.url)
                                .frame(height: 196)
                                .tag(index)
                        }
                    }
                    .frame(height: 196)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }

                if roomImages.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Label("\(roomImages.count)", systemImage: "photo.on.rectangle")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(.black.opacity(0.42), in: Capsule())
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            ForEach(Array(roomImages.indices), id: \.self) { index in
                                Capsule()
                                    .fill(index == (roomImageIndices[room.id] ?? 0) ? Color.white : Color.white.opacity(0.42))
                                    .frame(width: index == (roomImageIndices[room.id] ?? 0) ? 13 : 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(.black.opacity(0.28), in: Capsule())
                    }
                    .padding(14)
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 196)
            .clipped()

            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top, spacing: 10) {
                    Text(room.name)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .tracking(-0.25)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Color.iumrahCareLight)
                    }
                }
                .frame(minHeight: 50, alignment: .top)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) { roomFacts(room) }
                    VStack(alignment: .leading, spacing: 7) { roomFacts(room) }
                }

                Group {
                    if let cleanDescription {
                        Text(cleanDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 36, alignment: .topLeading)

                Spacer(minLength: 0)

                if canSelectRooms {
                    Button { select(room) } label: {
                        HStack(spacing: 10) {
                            Text(selected ? FlowCopy.text(.roomChosen, settings.language) : FlowCopy.text(.chooseRoom, settings.language))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            Spacer(minLength: 8)
                            Image(systemName: selected ? "checkmark" : "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RoomSelectButtonStyle(selected: selected))
                    .disabled(isSavingSelection)
                    .padding(.top, 2)
                }
            }
            .frame(height: canSelectRooms ? 218 : 158, alignment: .topLeading)
            .padding(18)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(selected ? Color.iumrahCareLight.opacity(0.62) : Color.primary.opacity(0.055), lineWidth: selected ? 1.2 : 0.6)
        }
        .shadow(color: .black.opacity(0.05), radius: 14, y: 7)
    }

    @ViewBuilder
    private func roomFacts(_ room: HotelRoom) -> some View {
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

    private func roomImageSelectionBinding(for roomID: String) -> Binding<Int> {
        Binding(
            get: { roomImageIndices[roomID] ?? 0 },
            set: { roomImageIndices[roomID] = $0 }
        )
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
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous), interactive: true)
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
        .background(Color.iumrahCardBackground)
        .overlay(alignment: .top) { Divider().opacity(0.18) }
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
                    dismiss()
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
            IumrahHaptics.success()
            onSelectionSaved?()
            dismiss()
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
                    dismiss()
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
            IumrahHaptics.success()
            onSelectionSaved?()
            dismiss()
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
        HotelCachedImage(rawURL: rawURL)
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
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 17, style: .continuous),
                interactive: true,
                tint: selected ? Color.iumrahCareLight.opacity(0.22) : nil
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
    }
}

private struct ReceptionClock: View {
    let city: String
    let timeZoneID: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 7) {
                clockFace(date: context.date)
                    .frame(width: 66, height: 66)
                Text(city)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(timeText(context.date))
                    .font(.caption2.weight(.semibold).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func clockFace(date: Date) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2

            let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(Color.iumrahCardBackground))
            context.stroke(circle, with: .color(Color.primary.opacity(0.13)), lineWidth: 0.8)

            for tick in 0..<12 {
                let angle = Double(tick) * .pi / 6 - .pi / 2
                let outer = CGPoint(x: center.x + cos(angle) * (radius - 6), y: center.y + sin(angle) * (radius - 6))
                let inner = CGPoint(x: center.x + cos(angle) * (radius - (tick % 3 == 0 ? 12 : 9)), y: center.y + sin(angle) * (radius - (tick % 3 == 0 ? 12 : 9)))
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                context.stroke(path, with: .color(Color.primary.opacity(tick % 3 == 0 ? 0.72 : 0.36)), lineWidth: tick % 3 == 0 ? 1.4 : 0.8)
            }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let hour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
            let minute = Double(components.minute ?? 0)
            drawHand(context: &context, center: center, radius: radius * 0.48, angle: hour / 12 * 2 * .pi - .pi / 2, width: 2.5)
            drawHand(context: &context, center: center, radius: radius * 0.68, angle: minute / 60 * 2 * .pi - .pi / 2, width: 1.5)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)), with: .color(.primary))
        }
    }

    private func drawHand(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double, width: CGFloat) {
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        var path = Path()
        path.move(to: center)
        path.addLine(to: point)
        context.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneID)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct HotelGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    let hotelName: String
    let images: [HotelImage]

    @State private var selectedCategory = "all"
    @State private var viewerImage: HotelImage?

    private var sortedImages: [HotelImage] { images.sorted(by: imageSort) }

    private var categories: [String] {
        var values = ["all"]
        for image in sortedImages {
            let category = image.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !category.isEmpty && !values.contains(category) { values.append(category) }
        }
        return values
    }

    private var filteredImages: [HotelImage] {
        guard selectedCategory != "all" else { return sortedImages }
        return sortedImages.filter { $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                    IumrahHaptics.selection()
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(categoryTitle(category))
                                            .font(.subheadline.weight(.semibold))
                                        Text("\(count(for: category))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 15)
                                    .frame(height: 56)
                                    .background(
                                        selectedCategory == category ? Color.iumrahRaisedBackground : Color.iumrahCardBackground,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(selectedCategory == category ? Color.primary.opacity(0.38) : Color.primary.opacity(0.07), lineWidth: selectedCategory == category ? 1.2 : 0.7)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, IumrahDesign.pagePadding)
                    }
                    .padding(.horizontal, -IumrahDesign.pagePadding)

                    Text(selectedCategory == "all"
                         ? (settings.language == .russian ? "Все фото (\(filteredImages.count))" : "All photos (\(filteredImages.count))")
                         : "\(categoryTitle(selectedCategory)) (\(filteredImages.count))")
                        .font(.system(size: 27, weight: .bold, design: .rounded))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                        ForEach(filteredImages) { image in
                            Button {
                                viewerImage = image
                            } label: {
                                HotelCachedImage(rawURL: image.url)
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .navigationTitle(hotelName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.language == .russian ? "Готово" : "Done") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $viewerImage) { image in
            HotelImageViewer(images: filteredImages, initialImageID: image.id)
        }
    }

    private func count(for category: String) -> Int {
        category == "all" ? sortedImages.count : sortedImages.filter { $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == category }.count
    }

    private func categoryTitle(_ category: String) -> String {
        guard category != "all" else { return settings.language == .russian ? "Все фото" : "All photos" }
        let normalized = category.lowercased()
        if normalized.contains("room") { return settings.language == .russian ? "Номера" : "Rooms" }
        if normalized.contains("bath") { return settings.language == .russian ? "Ванная" : "Bathroom" }
        if normalized.contains("restaurant") || normalized.contains("food") { return settings.language == .russian ? "Ресторан" : "Restaurant" }
        if normalized.contains("lobby") || normalized.contains("reception") { return settings.language == .russian ? "Лобби" : "Lobby" }
        if normalized.contains("view") || normalized.contains("exterior") { return settings.language == .russian ? "Вид" : "View" }
        return category.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func imageSort(_ lhs: HotelImage, _ rhs: HotelImage) -> Bool {
        if lhs.isCover != rhs.isCover { return lhs.isCover && !rhs.isCover }
        return lhs.position < rhs.position
    }
}

private struct HotelImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let images: [HotelImage]
    @State private var index: Int

    init(images: [HotelImage], initialImageID: String) {
        self.images = images
        _index = State(initialValue: images.firstIndex(where: { $0.id == initialImageID }) ?? 0)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if images.isEmpty {
                Image(systemName: "photo")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                TabView(selection: $index) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { offset, image in
                        ZoomableHotelImage(rawURL: image.url)
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .contentShape(Circle())
                    .iumrahGlass(in: Circle(), interactive: true, tint: .black.opacity(0.22), chrome: true)
            }
            .buttonStyle(.plain)
            .padding(18)
        }
        .overlay(alignment: .topTrailing) {
            if !images.isEmpty {
                Text("\(min(index + 1, images.count))/\(images.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .iumrahGlass(in: Capsule(), tint: .black.opacity(0.22), allowsStaticGlass: true, chrome: true)
                    .padding(22)
            }
        }
    }
}

private struct ZoomableHotelImage: View {
    let rawURL: String
    @State private var scale: CGFloat = 1
    @State private var previousScale: CGFloat = 1

    var body: some View {
        HotelCachedImage(rawURL: rawURL, contentMode: .fit, placeholderSystemName: "photo")
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(4, max(1, previousScale * value))
                    }
                    .onEnded { _ in
                        previousScale = scale
                        if scale < 1.05 {
                            scale = 1
                            previousScale = 1
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scale = scale > 1 ? 1 : 2
                    previousScale = scale
                }
            }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
