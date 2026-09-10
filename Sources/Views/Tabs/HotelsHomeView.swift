import SwiftUI

struct HotelsHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var storefront: HotelStorefrontStore

    @State private var board: HotelsShowcaseBoard = .hotels
    @State private var selectedHotel: HotelSummary?
    @State private var selectedFlightPackage: StorefrontFlightPackagePreview?
    @State private var carePresented = false
    @State private var flightOriginFilter: String? = nil
    @State private var flightDestinationFilter: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                IumrahRootPageTitle(title: pageTitle)

                Picker(L10n.text("hotel_storefront_section", settings.language), selection: $board) {
                    Text(L10n.text("tab_hotels", settings.language)).tag(HotelsShowcaseBoard.hotels)
                    Text(L10n.text("hotel_storefront_flights", settings.language)).tag(HotelsShowcaseBoard.flights)
                    Text(L10n.text("hotel_storefront_weekend", settings.language)).tag(HotelsShowcaseBoard.sundayClub)
                }
                .pickerStyle(.segmented)
                .onChange(of: board) { _, _ in IumrahHaptics.selection() }

                switch board {
                case .hotels:
                    hotelsBoard
                case .flights:
                    flightsBoard
                case .sundayClub:
                    sundayClubBoard
                }

            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .refreshable { await storefront.refresh() }
        .task { await storefront.prepareIfNeeded() }
        .onChange(of: chrome.requestedHotelID) { _, hotelID in
            openRequestedHotel(hotelID)
        }
        .onChange(of: storefront.allHotels.map(\.id)) { _, _ in
            openRequestedHotel(chrome.requestedHotelID)
        }
        .navigationDestination(item: $selectedHotel) { hotel in
            HotelDetailView(hotel: hotel)
        }
        .navigationDestination(item: $selectedFlightPackage) { preview in
            StorefrontUmrahPackageDetailView(preview: preview)
        }
        .sheet(isPresented: $carePresented) {
            HotelCareContactSheet()
                .environmentObject(settings)
        }
    }

    private var pageTitle: String {
        switch board {
        case .hotels: return L10n.text("tab_hotels", settings.language)
        case .flights: return L10n.text("hotel_storefront_flights", settings.language)
        case .sundayClub: return "Sunday Umrah Club"
        }
    }

    // MARK: - Hotels

    private var hotelsBoard: some View {
        VStack(alignment: .leading, spacing: 24) {
            ShowcaseHero(
                asset: "IumrahHotelsShowcaseHero",
                title: "iumrah Hotel Space",
                description: L10n.text("hotel_storefront_hero_body", settings.language),
                note: L10n.text("hotel_storefront_hero_note", settings.language)
            )

            hotelCitySection(
                title: L10n.text("hotels_makkah", settings.language),
                hotels: storefront.makkahHotels
            )
            hotelCitySection(
                title: L10n.text("hotels_madinah", settings.language),
                hotels: storefront.madinahHotels
            )

            if storefront.isLoading && storefront.allHotels.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.text("hotel_storefront_loading", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 92)
            }

            if let error = storefront.errorMessage, storefront.allHotels.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .iumrahCard()
            }

            HotelCareShowcaseCard(language: settings.language) {
                carePresented = true
            }
        }
    }

    private func hotelCitySection(title: String, hotels: [HotelSummary]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !hotels.isEmpty {
                SectionHeader(title, eyebrow: L10n.text("hotels_selected_badge", settings.language), subtitle: nil)
                ForEach(hotels) { hotel in
                    HotelStorefrontCard(
                        hotel: hotel,
                        images: storefront.previewImages(for: hotel),
                        quote: storefront.quote(for: hotel, tier: .standard),
                        language: settings.language,
                        isFavorite: storefront.isFavorite(hotel),
                        shareURL: storefront.shareURL(for: hotel),
                        onOpen: { selectedHotel = hotel },
                        onFavorite: { storefront.toggleFavorite(hotel) }
                    )
                }
            }
        }
    }

    // MARK: - Flights

    private var flightOptions: [StorefrontFlightOption] {
        storefront.flightBoard?.options ?? []
    }

    private var flightOrigins: [String] {
        var values = Set(flightOptions.map { $0.outbound.origin.uppercased() })
        for option in flightOptions {
            if let inbound = option.inbound { values.insert(inbound.origin.uppercased()) }
        }
        return values.sorted()
    }

    private var flightDestinations: [String] {
        var values = Set(flightOptions.map { $0.outbound.destination.uppercased() })
        for option in flightOptions {
            if let inbound = option.inbound { values.insert(inbound.destination.uppercased()) }
        }
        return values.sorted()
    }

    private var filteredFlightOptions: [StorefrontFlightOption] {
        flightOptions.filter { option in
            var legs = [option.outbound]
            if let inbound = option.inbound { legs.append(inbound) }
            return legs.contains { leg in
                let originMatches = flightOriginFilter.map { leg.origin.caseInsensitiveCompare($0) == .orderedSame } ?? true
                let destinationMatches = flightDestinationFilter.map { leg.destination.caseInsensitiveCompare($0) == .orderedSame } ?? true
                return originMatches && destinationMatches
            }
        }
    }

    private var flightsBoard: some View {
        VStack(alignment: .leading, spacing: 24) {
            ShowcaseHero(
                asset: "IumrahFlightsShowcaseHero",
                title: "iumrah Flights",
                description: L10n.text("hotel_storefront_flights_hero_body", settings.language),
                note: L10n.text("hotel_storefront_flights_hero_note", settings.language)
            )

            if !flightOptions.isEmpty {
                SectionHeader(
                    L10n.text("hotel_storefront_published_flights", settings.language),
                    eyebrow: L10n.text("hotel_storefront_current", settings.language),
                    subtitle: nil
                )

                flightAirportFilters

                if filteredFlightOptions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(noFlightsForFilterText)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(changeAirportFilterText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .iumrahCard()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredFlightOptions) { option in
                            let preview = storefront.packagePreview(for: option)
                            StorefrontFlightOptionCard(
                                option: option,
                                packagePreview: preview,
                                isCalculating: storefront.isLoading,
                                language: settings.language,
                                onOpen: {
                                    guard let preview else { return }
                                    IumrahHaptics.selection()
                                    selectedFlightPackage = preview
                                }
                            )
                        }
                    }
                }
            } else if storefront.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
    }

    private var flightAirportFilters: some View {
        HStack(spacing: 10) {
            airportFilterMenu(
                title: fromAirportText,
                selection: flightOriginFilter,
                values: flightOrigins
            ) { value in
                flightOriginFilter = value
                IumrahHaptics.selection()
            }

            airportFilterMenu(
                title: toAirportText,
                selection: flightDestinationFilter,
                values: flightDestinations
            ) { value in
                flightDestinationFilter = value
                IumrahHaptics.selection()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func airportFilterMenu(
        title: String,
        selection: String?,
        values: [String],
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        Menu {
            Button(allAirportsText) { onSelect(nil) }
            Divider()
            ForEach(values, id: \.self) { value in
                Button {
                    onSelect(value)
                } label: {
                    if selection == value {
                        Label(value, systemImage: "checkmark")
                    } else {
                        Text(value)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(selection ?? allAirportsText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var fromAirportText: String {
        switch settings.language {
        case .russian: return "Откуда"
        case .english: return "From"
        case .uzbek: return "Qayerdan"
        case .uzbekCyrillic: return "Қаердан"
        }
    }

    private var toAirportText: String {
        switch settings.language {
        case .russian: return "Куда"
        case .english: return "To"
        case .uzbek: return "Qayerga"
        case .uzbekCyrillic: return "Қаерга"
        }
    }

    private var allAirportsText: String {
        switch settings.language {
        case .russian: return "Все"
        case .english: return "All"
        case .uzbek: return "Barchasi"
        case .uzbekCyrillic: return "Барчаси"
        }
    }

    private var noFlightsForFilterText: String {
        switch settings.language {
        case .russian: return "iumrah Flights Scanner не нашёл рейсов по этому маршруту"
        case .english: return "iumrah Flights Scanner found no flights for this route"
        case .uzbek: return "iumrah Flights Scanner bu yo‘nalishda reys topmadi"
        case .uzbekCyrillic: return "iumrah Flights Scanner бу йўналишда рейс топмади"
        }
    }

    private var changeAirportFilterText: String {
        switch settings.language {
        case .russian: return "Измените аэропорт отправления или прибытия."
        case .english: return "Change the departure or arrival airport."
        case .uzbek: return "Jo‘nash yoki yetib borish aeroportini o‘zgartiring."
        case .uzbekCyrillic: return "Жўнаш ёки етиб бориш аэропортини ўзгартиринг."
        }
    }

    // MARK: - Sunday Club

    private var sundayClubBoard: some View {
        VStack(alignment: .leading, spacing: 20) {
            ShowcaseHero(
                asset: "SundayUmrahClubShowcaseHero",
                title: "Sunday Umrah Club",
                description: L10n.text("hotel_storefront_weekend_body", settings.language),
                note: L10n.text("hotel_storefront_weekend_note", settings.language),
                imageBackground: .white
            )
        }
    }

    private func openRequestedHotel(_ hotelID: String?) {
        guard let hotelID, let hotel = storefront.hotel(id: hotelID) else { return }
        selectedHotel = hotel
        chrome.requestedHotelID = nil
    }

}

// MARK: - Storefront components

private struct ShowcaseHero: View {
    let asset: String
    let title: String
    let description: String
    let note: String
    var imageBackground: Color = .black

    var bodyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(imageBackground)
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 9) {
                    IumrahInlineIcon(systemName: "checkmark.seal.fill", role: .umrah, size: 15)
                    Text(note)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }

    var body: some View {
        bodyContent
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.055), radius: 20, y: 8)
    }
}

private struct HotelStorefrontCard: View {
    let hotel: HotelSummary
    let images: [String]
    let quote: HotelStorefrontQuote?
    let language: AppSettingsStore.Language
    let isFavorite: Bool
    let shareURL: URL
    let onOpen: () -> Void
    let onFavorite: () -> Void

    private let cardHeight: CGFloat = 204

    var body: some View {
        GeometryReader { proxy in
            let mediaWidth = min(max(proxy.size.width * 0.31, 108), 122)

            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    HotelStorefrontCollage(images: images, fallback: hotel.coverImageURL)
                        .frame(width: mediaWidth, height: cardHeight)

                    HStack(spacing: 6) {
                        Button(action: onFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isFavorite ? Color.iumrahCareLight : Color.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.34), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.text(isFavorite ? "hotel_storefront_favorite_remove" : "hotel_storefront_favorite_add", language))

                        ShareLink(
                            item: shareURL,
                            subject: Text(hotel.name),
                            message: Text(L10n.text("hotel_storefront_share", language))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.34), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.text("hotel_storefront_share", language))
                    }
                    .padding(9)
                }
                .frame(width: mediaWidth, height: cardHeight)
                .clipped()

                VStack(alignment: .leading, spacing: 7) {
                    Text(hotel.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(-0.2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        if let stars = hotel.stars {
                            Text(String(repeating: "★", count: max(1, min(5, stars))))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(IumrahIconRole.rating.color)
                        }
                        if let rating = hotel.rating {
                            Text(String(format: "%.1f", rating))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Label(L10n.city(hotel.city, language), systemImage: "mappin.and.ellipse")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    if let quote {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(money(quote.packageQuote.pricePerPerson))
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .tracking(-0.55)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                            Spacer(minLength: 2)
                            Text(L10n.text("hotel_storefront_per_pilgrim", language))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Text(L10n.format("hotel_storefront_package_total_fmt", language, money(quote.packageQuote.totalPackagePrice)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } else {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text(L10n.text("hotel_storefront_calculating", language))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(minHeight: 38, alignment: .leading)
                    }

                    HStack(spacing: 5) {
                        Text(L10n.text("hotel_storefront_includes", language))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                        Spacer(minLength: 2)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: cardHeight)
        }
        .frame(height: cardHeight)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            IumrahHaptics.selection()
            onOpen()
        }
        .accessibilityAddTraits(.isButton)
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }
}

private struct HotelStorefrontCollage: View {
    let images: [String]
    let fallback: String?

    private var resolved: [String?] {
        var list = images.map(Optional.some)
        if list.isEmpty { list.append(fallback) }
        while list.count < 3 { list.append(list.first ?? fallback) }
        return Array(list.prefix(3))
    }

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 3
            let heroHeight = ((proxy.size.height - gap) * 0.63)
            let thumbnailHeight = max(0, proxy.size.height - heroHeight - gap)
            let thumbnailWidth = max(0, (proxy.size.width - gap) / 2)

            VStack(spacing: gap) {
                HotelCachedImage(rawURL: resolved[0])
                    .frame(width: proxy.size.width, height: heroHeight)
                    .clipped()

                HStack(spacing: gap) {
                    HotelCachedImage(rawURL: resolved[1])
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipped()
                    HotelCachedImage(rawURL: resolved[2])
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipped()
                }
                .frame(width: proxy.size.width, height: thumbnailHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .clipped()
    }
}

private struct StorefrontFlightOptionCard: View {
    let option: StorefrontFlightOption
    let packagePreview: StorefrontFlightPackagePreview?
    let isCalculating: Bool
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            media
                .frame(height: 118)
                .clipped()

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routeTitle)
                            .font(.headline)
                        Text(airlineTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    packagePrice
                }

                HStack(spacing: 12) {
                    flightTime(option.outbound)
                    if let inbound = option.inbound {
                        Divider().frame(height: 34)
                        flightTime(inbound)
                    }
                }

                if let packagePreview {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.fill")
                            .font(.caption2.weight(.bold))
                        Text(packageRouteText(packagePreview))
                            .lineLimit(2)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(generatedStampText, systemImage: "seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(packagePreview == nil ? Color.secondary : IumrahIconRole.umrah.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.iumrahRaisedBackground, in: Capsule())

                    Spacer(minLength: 4)
                    if packagePreview != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if packagePreview != nil { onOpen() }
        }
        .accessibilityAddTraits(.isButton)
    }

    private var media: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let imageURL = packagePreview?.primaryHotel?.coverImageURL, !imageURL.isEmpty {
                    HotelCachedImage(rawURL: imageURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Image("IumrahFlightsShowcaseHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: 10) {
                    HStack(spacing: 6) {
                        AirlineLogoView(airlineCode: option.outbound.airlineCode, size: 40)
                        if let preview = packagePreview,
                           preview.inbound.airlineCode.uppercased() != option.outbound.airlineCode.uppercased() {
                            AirlineLogoView(airlineCode: preview.inbound.airlineCode, size: 40)
                        }
                    }

                    Spacer(minLength: 8)

                    if let preview = packagePreview {
                        Text(packageTypeText(preview))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.36), in: Capsule())
                    }
                }
                .padding(13)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private var packagePrice: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let packagePreview {
                Text(money(packagePreview.pricePerPerson))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(packagePerPersonText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            } else if isCalculating {
                ProgressView()
                    .controlSize(.small)
                Text(calculatingPackageText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(packageUnavailableText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 132, alignment: .trailing)
    }

    private var routeTitle: String {
        if let inbound = option.inbound {
            return "\(option.outbound.origin) → \(option.outbound.destination) · \(inbound.origin) → \(inbound.destination)"
        }
        return "\(option.outbound.origin) → \(option.outbound.destination)"
    }

    private var airlineTitle: String {
        let first = "\(option.outbound.airline) \(option.outbound.flightNumber)"
        guard let inbound = option.inbound else { return first }
        return first + " · \(inbound.airline) \(inbound.flightNumber)"
    }

    private func flightTime(_ leg: StorefrontFlightLeg) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day(leg.departureAt))
                .font(.caption.weight(.semibold))
            Text("\(clock(leg.departureAt))  \(leg.origin) → \(leg.destination)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func packageRouteText(_ preview: StorefrontFlightPackagePreview) -> String {
        let route = "\(preview.outbound.origin) → \(preview.outbound.destination) + \(preview.inbound.origin) → \(preview.inbound.destination)"
        switch language {
        case .russian: return "\(route) · \(preview.durationDays) дн. · \(packageScopeText(preview))"
        case .english: return "\(route) · \(preview.durationDays) days · \(packageScopeText(preview))"
        case .uzbek: return "\(route) · \(preview.durationDays) kun · \(packageScopeText(preview))"
        case .uzbekCyrillic: return "\(route) · \(preview.durationDays) кун · \(packageScopeText(preview))"
        }
    }

    private func packageTypeText(_ preview: StorefrontFlightPackagePreview) -> String {
        "\(packageScopeText(preview)) · \(preview.tier.title(language))"
    }

    private func packageScopeText(_ preview: StorefrontFlightPackagePreview) -> String {
        switch (preview.kind, language) {
        case (.makkahComfortShort, .russian): return "Только Мекка"
        case (.makkahComfortShort, .english): return "Makkah only"
        case (.makkahComfortShort, .uzbek): return "Faqat Makka"
        case (.makkahComfortShort, .uzbekCyrillic): return "Фақат Макка"
        case (.makkahMadinahStandard, .russian): return "Мекка + Медина"
        case (.makkahMadinahStandard, .english): return "Makkah + Madinah"
        case (.makkahMadinahStandard, .uzbek): return "Makka + Madina"
        case (.makkahMadinahStandard, .uzbekCyrillic): return "Макка + Мадина"
        }
    }

    private var generatedStampText: String {
        switch language {
        case .russian: return packagePreview == nil ? "iumrah Flights Scanner" : "Сгенерировано iumrah Package System"
        case .english: return packagePreview == nil ? "iumrah Flights Scanner" : "Generated by iumrah Package System"
        case .uzbek: return packagePreview == nil ? "iumrah Flights Scanner" : "iumrah Package System yaratdi"
        case .uzbekCyrillic: return packagePreview == nil ? "iumrah Flights Scanner" : "iumrah Package System яратди"
        }
    }

    private var packagePerPersonText: String {
        switch language {
        case .russian: return "пакет · 1 человек"
        case .english: return "package · 1 person"
        case .uzbek: return "paket · 1 kishi"
        case .uzbekCyrillic: return "пакет · 1 киши"
        }
    }

    private var calculatingPackageText: String {
        switch language {
        case .russian: return "Считаем пакет"
        case .english: return "Calculating package"
        case .uzbek: return "Paket hisoblanmoqda"
        case .uzbekCyrillic: return "Пакет ҳисобланмоқда"
        }
    }

    private var packageUnavailableText: String {
        switch language {
        case .russian: return "нет пары 2–15 дней"
        case .english: return "no 2–15 day pair"
        case .uzbek: return "2–15 kunlik juftlik yo‘q"
        case .uzbekCyrillic: return "2–15 кунлик жуфтлик йўқ"
        }
    }
}

private struct StorefrontUmrahPackageDetailView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let preview: StorefrontFlightPackagePreview

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                packageHero
                overviewCard

                SectionHeader(flightsTitle, eyebrow: "iumrah Flights Scanner", subtitle: nil)
                PackageFlightLegDetailCard(leg: preview.outbound, direction: outboundTitle, language: settings.language)
                PackageFlightLegDetailCard(leg: preview.inbound, direction: returnTitle, language: settings.language)

                SectionHeader(hotelsTitle, eyebrow: "iumrah Hotels", subtitle: nil)
                ForEach(preview.hotels) { hotel in
                    PackageHotelDetailCard(hotel: hotel, language: settings.language)
                }

                SectionHeader(includedTitle, eyebrow: "iumrah", subtitle: nil)
                servicesCard

                IumrahRefundPolicyCard(component: .package, compact: true)
                priceCard

                Label(generatedStamp, systemImage: "seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(IumrahIconRole.umrah.color)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 34)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(packageNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var packageHero: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if let imageURL = preview.primaryHotel?.coverImageURL, !imageURL.isEmpty {
                    HotelCachedImage(rawURL: imageURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Image("IumrahFlightsShowcaseHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Label("iumrah Package", systemImage: "shippingbox.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("\(preview.outbound.origin) → \(preview.outbound.destination) · \(preview.inbound.origin) → \(preview.inbound.destination)")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(money(preview.pricePerPerson))
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(perPersonShort)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .padding(20)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "airplane.departure", role: .travel, size: 46, symbolSize: 18, cornerRadius: 15)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(preview.durationDays) \(daysWord) · \(scopeTitle)")
                        .font(.headline)
                    Text(preview.tier.title(settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if preview.usesTashkentReturnFallback {
                Divider()
                Label(returnFallbackText, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    private var servicesCard: some View {
        VStack(spacing: 0) {
            serviceRow(icon: "checkmark.document.fill", title: visaTitle, role: .document)
            Divider().padding(.leading, 54)
            serviceRow(icon: "car.side.fill", title: transferTitle, role: .transfer)
            Divider().padding(.leading, 54)
            serviceRow(icon: "fork.knife", title: mealsTitle, role: .hotel)
            Divider().padding(.leading, 54)
            serviceRow(icon: "person.2.fill", title: accompanimentTitle, role: .care)
            Divider().padding(.leading, 54)
            serviceRow(icon: "mappin.and.ellipse", title: makkahZiyaratTitle, role: .location)
            if preview.kind == .makkahMadinahStandard {
                Divider().padding(.leading, 54)
                serviceRow(icon: "mappin.circle.fill", title: madinahZiyaratTitle, role: .location)
            }
            Divider().padding(.leading, 54)
            serviceRow(icon: "heart.fill", title: "iumrah Care", role: .care)
        }
        .iumrahCard()
    }

    private func serviceRow(icon: String, title: String, role: IumrahIconRole) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(systemName: icon, role: role, size: 40, symbolSize: 15, cornerRadius: 13)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(IumrahIconRole.success.color)
        }
        .padding(.vertical, 11)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(finalPriceTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .lastTextBaseline) {
                Text(money(preview.pricePerPerson))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                Spacer()
                Text(perPersonLong)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(priceIncludesText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahCard()
    }

    private func money(_ value: Decimal) -> String {
        String(format: "$%.0f", NSDecimalNumber(decimal: value).doubleValue)
    }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }

    private var packageNavigationTitle: String { tr("Пакет Умры", "Umrah package", "Umra paketi", "Умра пакети") }
    private var flightsTitle: String { tr("Перелёты", "Flights", "Parvozlar", "Парвозлар") }
    private var hotelsTitle: String { tr("Отели", "Hotels", "Mehmonxonalar", "Меҳмонхоналар") }
    private var includedTitle: String { tr("Что включено", "What's included", "Nimalar kiradi", "Нималар киради") }
    private var outboundTitle: String { tr("Туда", "Outbound", "Borish", "Бориш") }
    private var returnTitle: String { tr("Обратно", "Return", "Qaytish", "Қайтиш") }
    private var scopeTitle: String {
        preview.kind == .makkahComfortShort
            ? tr("Только Мекка", "Makkah only", "Faqat Makka", "Фақат Макка")
            : tr("Мекка + Медина", "Makkah + Madinah", "Makka + Madina", "Макка + Мадина")
    }
    private var daysWord: String { tr("дней", "days", "kun", "кун") }
    private var returnFallbackText: String {
        tr(
            "Для этого пакета обратный рейс приходит в Ташкент, потому что подходящего возврата в \(preview.outbound.origin) в выбранном диапазоне нет.",
            "This package returns to Tashkent because no suitable flight back to \(preview.outbound.origin) is available in the package window.",
            "Bu paket Toshkentga qaytadi, chunki paket oralig‘ida \(preview.outbound.origin) ga mos qaytish reysi topilmadi.",
            "Бу пакет Тошкентга қайтади, чунки пакет оралиғида \(preview.outbound.origin) га мос қайтиш рейси топилмади."
        )
    }
    private var visaTitle: String { tr("Виза", "Visa", "Viza", "Виза") }
    private var transferTitle: String {
        preview.kind == .makkahComfortShort
            ? tr("Аэропортовый трансфер", "Airport transfer", "Aeroport transferi", "Аэропорт трансфери")
            : tr("Трансферы и переезд между городами", "Transfers and intercity journey", "Transferlar va shaharlararo yo‘l", "Трансферлар ва шаҳарлараро йўл")
    }
    private var mealsTitle: String {
        preview.kind == .makkahComfortShort
            ? tr("Питание Comfort · завтрак, обед и ужин", "Comfort meals · breakfast, lunch and dinner", "Comfort ovqatlanish · nonushta, tushlik va kechki ovqat", "Comfort овқатланиш · нонушта, тушлик ва кечки овқат")
            : tr("Питание Standard", "Standard meals", "Standard ovqatlanish", "Standard овқатланиш")
    }
    private var accompanimentTitle: String { tr("Сопровождение iumrah", "iumrah assistance", "iumrah hamrohligi", "iumrah ҳамроҳлиги") }
    private var makkahZiyaratTitle: String { tr("Зияраты в Мекке", "Makkah ziyarat", "Makka ziyoratlari", "Макка зиёратлари") }
    private var madinahZiyaratTitle: String { tr("Зияраты в Медине", "Madinah ziyarat", "Madina ziyoratlari", "Мадина зиёратлари") }
    private var finalPriceTitle: String { tr("Итоговая цена пакета", "Final package price", "Paketning yakuniy narxi", "Пакетнинг якуний нархи") }
    private var perPersonShort: String { tr("за 1 человека", "for 1 person", "1 kishi uchun", "1 киши учун") }
    private var perPersonLong: String { tr("на 1 человека", "per person", "1 kishi uchun", "1 киши учун") }
    private var priceIncludesText: String { tr("Одна цена включает выбранную пару рейсов, отели и сервисы iumrah. Стоимость отдельных компонентов не показывается.", "One price includes the selected flight pair, hotels and iumrah services. Individual component prices are not shown.", "Bitta narx tanlangan reyslar juftligi, mehmonxonalar va iumrah xizmatlarini o‘z ichiga oladi. Alohida komponent narxlari ko‘rsatilmaydi.", "Битта нарх танланган рейслар жуфтлиги, меҳмонхоналар ва iumrah хизматларини ўз ичига олади. Алоҳида компонент нархлари кўрсатилмайди.") }
    private var generatedStamp: String { tr("Сгенерировано iumrah Package System", "Generated by iumrah Package System", "iumrah Package System yaratdi", "iumrah Package System яратди") }
}

private struct PackageFlightLegDetailCard: View {
    let leg: StorefrontFlightLeg
    let direction: String
    let language: AppSettingsStore.Language

    var body: some View {
        HStack(spacing: 14) {
            AirlineLogoView(airlineCode: leg.airlineCode, size: 50)

            VStack(alignment: .leading, spacing: 5) {
                Text(direction.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(leg.origin) → \(leg.destination)")
                    .font(.headline)
                Text("\(leg.airline) \(leg.flightNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(day(leg.departureAt)) · \(clock(leg.departureAt))")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "airplane")
                    .font(.headline)
                    .foregroundStyle(IumrahIconRole.travel.color)
                Text(directText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .iumrahCard()
    }

    private var directText: String {
        switch language {
        case .russian: return leg.stops == 0 ? "прямой" : "\(leg.stops) пересад."
        case .english: return leg.stops == 0 ? "direct" : "\(leg.stops) stops"
        case .uzbek: return leg.stops == 0 ? "to‘g‘ridan-to‘g‘ri" : "\(leg.stops) ulanish"
        case .uzbekCyrillic: return leg.stops == 0 ? "тўғридан-тўғри" : "\(leg.stops) уланиш"
        }
    }
}

private struct PackageHotelDetailCard: View {
    let hotel: StorefrontPackageHotel
    let language: AppSettingsStore.Language

    var body: some View {
        GeometryReader { proxy in
            let mediaWidth = min(max(proxy.size.width * 0.31, 108), 124)
            HStack(spacing: 0) {
                ZStack {
                    if let imageURL = hotel.coverImageURL, !imageURL.isEmpty {
                        HotelCachedImage(rawURL: imageURL)
                            .frame(width: mediaWidth, height: 136)
                    } else {
                        Color.iumrahRaisedBackground
                            .overlay {
                                Image(systemName: "building.2.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: mediaWidth, height: 136)
                .clipped()

                VStack(alignment: .leading, spacing: 7) {
                    Text(hotel.name)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if let stars = hotel.stars {
                            Text(String(repeating: "★", count: max(1, min(5, stars))))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(IumrahIconRole.rating.color)
                        }
                        Text(cityTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Label(nightsText, systemImage: "moon.stars.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: 136)
        }
        .frame(height: 136)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.6)
        }
    }

    private var cityTitle: String { L10n.city(hotel.city, language) }
    private var nightsText: String {
        switch language {
        case .russian: return "\(hotel.nights) ноч."
        case .english: return "\(hotel.nights) nights"
        case .uzbek: return "\(hotel.nights) tun"
        case .uzbekCyrillic: return "\(hotel.nights) тун"
        }
    }
}

struct HotelCareShowcaseCard: View {
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("IumrahCareShowcaseCard")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.015, green: 0.035, blue: 0.09))

            VStack(alignment: .leading, spacing: 11) {
                Text("iumrah Care")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text(L10n.text("hotel_care_card_body", language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.text("hotel_care_contact", language), action: onOpen)
                    .buttonStyle(IumrahPrimaryButtonStyle())
            }
            .padding(20)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

struct HotelCareContactSheet: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("iumrah Care")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(L10n.text("hotel_care_prebook_body", settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Link(destination: URL(string: "https://t.me/saudiclub966")!) {
                    contactRow(icon: "paperplane.fill", title: "Telegram", value: "@saudiclub966")
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "tel:+998508898845")!) {
                    contactRow(icon: "phone.fill", title: L10n.text("hotel_care_call", settings.language), value: "+998 50 889 88 45")
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
            }
            .padding(IumrahDesign.pagePadding)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("settings_done", settings.language)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func contactRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            IumrahIconBadge(systemName: icon, role: .care, size: 46, symbolSize: 18, cornerRadius: 15)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(value).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .iumrahCard()
    }
}

private func parseStorefrontISO(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
}

private func clock(_ value: String) -> String {
    guard let date = parseStorefrontISO(value) else { return "—" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private func day(_ value: String) -> String {
    guard let date = parseStorefrontISO(value) else { return String(value.prefix(10)) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "d MMM"
    return formatter.string(from: date)
}
