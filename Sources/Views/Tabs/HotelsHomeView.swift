import SwiftUI

struct HotelsHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var journey: JourneyStore
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

                AirportSelectorButton(airport: $journey.trip.originAirport, fallbackCode: $journey.trip.origin)

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
        .refreshable {
            await storefront.updateDepartureAirport(journey.trip.originCode)
            await storefront.refresh()
        }
        .task(id: journey.trip.originCode.uppercased()) {
            await storefront.prepareIfNeeded()
            await storefront.updateDepartureAirport(journey.trip.originCode)
        }
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
                title: "iumrah Hotels",
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
                        quote: storefront.automaticQuote(for: hotel),
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
        case (.makkahComfortShort, .russian), (.hotelFirstMakkah, .russian): return "Только Мекка"
        case (.makkahComfortShort, .english), (.hotelFirstMakkah, .english): return "Makkah only"
        case (.makkahComfortShort, .uzbek), (.hotelFirstMakkah, .uzbek): return "Faqat Makka"
        case (.makkahComfortShort, .uzbekCyrillic), (.hotelFirstMakkah, .uzbekCyrillic): return "Фақат Макка"
        case (.makkahMadinahStandard, .russian): return "Мекка + Медина"
        case (.makkahMadinahStandard, .english): return "Makkah + Madinah"
        case (.makkahMadinahStandard, .uzbek): return "Makka + Madina"
        case (.makkahMadinahStandard, .uzbekCyrillic): return "Макка + Мадина"
        }
    }

    private var generatedStampText: String {
        switch language {
        case .russian: return packagePreview == nil ? "iumrah Flights Scanner" : "Сгенерировано iumrah Configurator"
        case .english: return packagePreview == nil ? "iumrah Flights Scanner" : "Generated by iumrah Configurator"
        case .uzbek: return packagePreview == nil ? "iumrah Flights Scanner" : "iumrah Configurator yaratdi"
        case .uzbekCyrillic: return packagePreview == nil ? "iumrah Flights Scanner" : "iumrah Configurator яратди"
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

private enum StorefrontPackageInfoSheet: String, Identifiable {
    case visa
    case guide
    case trust

    var id: String { rawValue }
}

private struct PackageHotelSelectionTarget: Identifiable, Hashable {
    let hotel: HotelSummary
    let role: HotelSelectionRole

    var id: String { "\(role.rawValue)::\(hotel.id)" }
}

enum StorefrontConfiguratorEntry: Hashable {
    case flightFirst
    case hotelFirst(hotelID: String)
}

private enum StorefrontFlightPickerSheetKind: String, Identifiable {
    case outbound
    case inbound

    var id: String { rawValue }
    var direction: FlightDirection { self == .outbound ? .outbound : .inbound }
}

struct StorefrontUmrahPackageDetailView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var storefront: HotelStorefrontStore
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var bookings: BookingStore
    @ObservedObject private var push = PushNotificationManager.shared

    let preview: StorefrontFlightPackagePreview
    var entry: StorefrontConfiguratorEntry = .flightFirst

    @State private var heroImageIndex = 0
    @State private var isPrepared = false
    @State private var selectedHotelTarget: PackageHotelSelectionTarget?
    @State private var showTransferSelection = false
    @State private var infoSheet: StorefrontPackageInfoSheet?
    @State private var isProfileSheetPresented = false
    @State private var isSubmitting = false
    @State private var bookingError: String?
    @State private var createdBookingID: String?
    @State private var flightPickerSheet: StorefrontFlightPickerSheetKind?
    @State private var selectedOutboundChoice: StorefrontConfiguratorFlightChoice?
    @State private var selectedInboundChoice: StorefrontConfiguratorFlightChoice?
    @State private var initialOutboundFare: Decimal?
    @State private var initialInboundFare: Decimal?
    @State private var suppressQuoteRefresh = false
    @State private var showMadinahFirstCityPicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                packageHero
                overviewCard

                SectionHeader(flightsTitle, eyebrow: "iumrah Flights Scanner", subtitle: nil)
                PackageFlightLegDetailCard(
                    leg: currentOutboundLeg,
                    direction: outboundTitle,
                    language: settings.language,
                    actionTitle: changeTitle
                ) {
                    flightPickerSheet = .outbound
                }
                PackageFlightLegDetailCard(
                    leg: currentInboundLeg,
                    direction: returnTitle,
                    language: settings.language,
                    actionTitle: changeTitle
                ) {
                    flightPickerSheet = .inbound
                }

                if isHotelFirst {
                    hotelFirstRouteCard
                }

                SectionHeader(hotelsTitle, eyebrow: "iumrah Hotels", subtitle: nil)
                ForEach(displayPackageHotels) { hotel in
                    PackageHotelDetailCard(
                        hotel: hotel,
                        selectedRoomName: selectedRoomName(for: hotel),
                        chooseRoomText: chooseRoomTitle,
                        language: settings.language,
                        onOpen: { openHotel(hotel) }
                    )
                }

                SectionHeader(includedTitle, eyebrow: "iumrah", subtitle: nil)
                servicesCard

                travelersCard

                IumrahRefundPolicyCard(component: .package, compact: true)

                PackagePurchaseTrustCard(language: settings.language) {
                    infoSheet = .trust
                }

                priceCard

                if let bookingError {
                    Text(bookingError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                bookingButton

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
        .task {
            await storefront.prepareIfNeeded()
            prepareBookingJourneyIfNeeded()
        }
        .onChange(of: journey.trip) { _, _ in
            guard isPrepared, !suppressQuoteRefresh else { return }
            refreshQuote()
        }
        .navigationDestination(item: $selectedHotelTarget) { target in
            HotelDetailView(
                hotel: target.hotel,
                selectionFlow: true,
                selectionRole: target.role,
                onSelectionSaved: {
                    refreshQuote()
                }
            )
        }
        .navigationDestination(isPresented: $showTransferSelection) {
            TransferSelectionView(selectionMode: true) {
                refreshQuote()
            }
        }
        .navigationDestination(item: $createdBookingID) { bookingID in
            BookingDetailView(bookingID: bookingID)
        }
        .sheet(item: $infoSheet) { sheet in
            StorefrontPackageInformationSheet(
                kind: sheet,
                language: settings.language,
                preview: preview
            )
        }
        .sheet(isPresented: $isProfileSheetPresented) {
            BookingProfileCaptureSheet {
                Task { await createBooking() }
            }
            .environmentObject(settings)
        }
        .sheet(item: $flightPickerSheet) { sheet in
            PackageFlightPickerSheet(
                direction: sheet.direction,
                currentAirport: journey.trip.originAirport,
                currentOriginCode: journey.trip.originCode,
                referenceFare: sheet.direction == .outbound ? resolvedOutboundFare : resolvedInboundFare,
                selectedOptionID: sheet.direction == .outbound ? selectedOutboundOptionID : selectedInboundOptionID
            ) { choice, airport, originCode in
                applyFlightChoice(choice, direction: sheet.direction, airport: airport, originCode: originCode)
            }
            .environmentObject(settings)
            .environmentObject(storefront)
            .environmentObject(journey)
        }
        .confirmationDialog(
            firstCityQuestionTitle,
            isPresented: $showMadinahFirstCityPicker,
            titleVisibility: .visible
        ) {
            Button(firstMadinahTitle) { addMadinahToHotelPackage(firstCity: .madinah) }
            Button(firstJeddahTitle) { addMadinahToHotelPackage(firstCity: .jeddah) }
            Button(cancelTitle, role: .cancel) {}
        } message: {
            Text(firstCityQuestionBody)
        }
    }

    private var packageHero: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                TabView(selection: $heroImageIndex) {
                    if heroImages.isEmpty {
                        Image("IumrahFlightsShowcaseHero")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .tag(0)
                    } else {
                        ForEach(Array(heroImages.enumerated()), id: \.offset) { index, imageURL in
                            HotelCachedImage(rawURL: imageURL)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 8) {
                    Label("iumrah Configurator", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("\(currentOutboundLeg.origin) → \(currentOutboundLeg.destination) · \(currentInboundLeg.origin) → \(currentInboundLeg.destination)")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(money(currentQuote.pricePerPerson))
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(perPersonShort)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .padding(20)
                .allowsHitTesting(false)

                if heroImages.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(heroImages.indices, id: \.self) { index in
                            Capsule()
                                .fill(Color.white.opacity(index == heroImageIndex ? 0.95 : 0.42))
                                .frame(width: index == heroImageIndex ? 18 : 6, height: 6)
                                .animation(.easeInOut(duration: 0.18), value: heroImageIndex)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .allowsHitTesting(false)
                }
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

    private var heroImages: [String] {
        guard let hotel = primaryHotelSummary else {
            return preview.primaryHotel?.coverImageURL.map { [$0] } ?? []
        }
        let values = storefront.previewImages(for: hotel, limit: 6)
        if !values.isEmpty { return values }
        return hotel.coverImageURL.map { [$0] } ?? []
    }

    private var isHotelFirst: Bool {
        if case .hotelFirst = entry { return true }
        return false
    }

    private var selectedOutboundOptionID: String {
        selectedOutboundChoice?.id ?? preview.outboundOptionID
    }

    private var selectedInboundOptionID: String {
        selectedInboundChoice?.id ?? preview.returnOptionID
    }

    private var resolvedOutboundFare: Decimal {
        selectedOutboundChoice?.farePerTravelerUSD ?? initialOutboundFare ?? (preview.flightFarePerPersonUSD / 2)
    }

    private var resolvedInboundFare: Decimal {
        selectedInboundChoice?.farePerTravelerUSD ?? initialInboundFare ?? (preview.flightFarePerPersonUSD / 2)
    }

    private var currentJourneyFarePerPerson: Decimal {
        let value = resolvedOutboundFare + resolvedInboundFare
        return value > 0 ? value : preview.flightFarePerPersonUSD
    }

    private var currentOutboundLeg: StorefrontFlightLeg {
        selectedOutboundChoice?.leg ?? preview.outbound
    }

    private var currentInboundLeg: StorefrontFlightLeg {
        selectedInboundChoice?.leg ?? preview.inbound
    }

    private var currentDurationDays: Int {
        guard let outbound = parseStorefrontISO(currentOutboundLeg.departureAt),
              let inbound = parseStorefrontISO(currentInboundLeg.departureAt) else { return preview.durationDays }
        let calendar = Calendar(identifier: .gregorian)
        return max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: outbound), to: calendar.startOfDay(for: inbound)).day ?? preview.durationDays)
    }

    private var displayPackageHotels: [StorefrontPackageHotel] {
        guard isPrepared, let makkah = journey.selectedHotel else { return preview.hotels }
        let stay = TripStayPlanner.breakdown(for: journey.trip)
        var result = [packageHotelSummary(makkah, nights: stay.makkahNights)]
        if journey.trip.scope == .makkahAndMadinah,
           let madinah = journey.selectedMadinahHotel,
           stay.madinahNights > 0 {
            result.append(packageHotelSummary(madinah, nights: stay.madinahNights))
        }
        return result
    }

    private func packageHotelSummary(_ hotel: HotelSummary, nights: Int) -> StorefrontPackageHotel {
        StorefrontPackageHotel(
            id: hotel.id,
            name: hotel.name,
            city: hotel.city,
            stars: hotel.stars,
            coverImageURL: storefront.previewImages(for: hotel, limit: 1).first ?? hotel.coverImageURL,
            nights: max(1, nights)
        )
    }

    private var hotelFirstRouteCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "map.fill", role: .location, size: 44, symbolSize: 17, cornerRadius: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(routeConfiguratorTitle)
                        .font(.headline)
                    Text(journey.trip.scope == .makkahAndMadinah ? makkahMadinahRouteSubtitle : makkahOnlyRouteSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if journey.trip.scope == .makkahAndMadinah {
                Divider()
                Text(firstCityTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Picker(firstCityTitle, selection: Binding(
                    get: { journey.trip.arrivalAirport },
                    set: { setFirstSaudiCity($0) }
                )) {
                    Text(firstJeddahTitle).tag(SaudiArrivalAirport.jeddah)
                    Text(firstMadinahTitle).tag(SaudiArrivalAirport.madinah)
                }
                .pickerStyle(.segmented)

                Button(removeMadinahTitle) {
                    removeMadinahFromHotelPackage()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Button {
                    showMadinahFirstCityPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(addMadinahTitle)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            }
        }
        .iumrahCard()
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "airplane.departure", role: .travel, size: 46, symbolSize: 18, cornerRadius: 15)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(currentDurationDays) \(daysWord) · \(scopeTitle)")
                        .font(.headline)
                    Text(preview.tier.title(settings.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if usesTashkentReturnFallback {
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
            serviceButtonRow(
                icon: "doc.text.fill",
                title: visaTitle,
                subtitle: visaSummary,
                role: .document
            ) {
                infoSheet = .visa
            }

            Divider().padding(.leading, 54)

            serviceButtonRow(
                icon: "car.side.fill",
                title: transferTitle,
                subtitle: journey.selectedTransferVehicle?.modelName ?? "Kia Carnival",
                role: .transfer
            ) {
                journey.transferSelectionConfirmed = false
                showTransferSelection = true
            }

            Divider().padding(.leading, 54)

            serviceRow(
                icon: "fork.knife",
                title: mealsTitle,
                subtitle: mealsSummary,
                role: .hotel
            )

            Divider().padding(.leading, 54)

            serviceButtonRow(
                icon: "person.crop.circle.badge.checkmark",
                title: guideTitle,
                subtitle: guideSummary,
                role: .care
            ) {
                infoSheet = .guide
            }

            Divider().padding(.leading, 54)
            serviceRow(icon: "mappin.and.ellipse", title: makkahZiyaratTitle, subtitle: nil, role: .location)
            if journey.trip.scope == .makkahAndMadinah {
                Divider().padding(.leading, 54)
                serviceRow(icon: "mappin.circle.fill", title: madinahZiyaratTitle, subtitle: nil, role: .location)
            }
            Divider().padding(.leading, 54)
            serviceRow(icon: "heart.fill", title: "iumrah Care", subtitle: careSummary, role: .care)
        }
        .iumrahCard()
    }

    private func serviceRow(icon: String, title: String, subtitle: String?, role: IumrahIconRole) -> some View {
        HStack(spacing: 12) {
            IumrahIconBadge(systemName: icon, role: role, size: 40, symbolSize: 15, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(IumrahIconRole.success.color)
        }
        .padding(.vertical, 11)
    }

    private func serviceButtonRow(
        icon: String,
        title: String,
        subtitle: String,
        role: IumrahIconRole,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: icon, role: role, size: 40, symbolSize: 15, cornerRadius: 13)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var travelersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("trip_travelers_title", settings.language), systemImage: "person.2")
                .font(.headline)
                .padding(.bottom, 4)

            Text(travelersBody)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            CounterRow(
                title: L10n.text("adults", settings.language),
                subtitle: nil,
                value: $journey.trip.adults,
                minimum: 1,
                maximum: max(1, 9 - journey.trip.children - journey.trip.infants)
            )
            Divider()
            CounterRow(
                title: L10n.text("children", settings.language),
                subtitle: L10n.text("children_age", settings.language),
                value: $journey.trip.children,
                minimum: 0,
                maximum: max(0, 9 - journey.trip.adults - journey.trip.infants)
            )
            Divider()
            CounterRow(
                title: L10n.text("infants", settings.language),
                subtitle: L10n.text("infants_age", settings.language),
                value: $journey.trip.infants,
                minimum: 0,
                maximum: min(4, max(0, 9 - journey.trip.adults - journey.trip.children))
            )
            Divider()
            CounterRow(
                title: L10n.text("rooms", settings.language),
                subtitle: nil,
                value: $journey.trip.rooms,
                minimum: 1,
                maximum: 6
            )
        }
        .iumrahCard()
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(finalPriceTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .lastTextBaseline) {
                Text(money(currentQuote.totalPackagePrice))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                Spacer()
                Text(totalForTravelersText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Label("\(money(currentQuote.pricePerPerson)) · \(perPersonLong)", systemImage: "person.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .iumrahCard()
    }

    private var bookingButton: some View {
        Button {
            isProfileSheetPresented = true
        } label: {
            HStack(spacing: 12) {
                if isSubmitting {
                    ProgressView().tint(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSubmitting ? bookingInProgressTitle : bookTripTitle)
                        .font(.headline)
                    if !isSubmitting {
                        Text("\(money(currentQuote.totalPackagePrice)) · \(totalForTravelersText)")
                            .font(.caption.weight(.semibold))
                            .opacity(0.76)
                    }
                }
                Spacer(minLength: 8)
                if !isSubmitting {
                    Image(systemName: "arrow.right")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(!canBook || isSubmitting)
        .opacity(canBook && !isSubmitting ? 1 : 0.45)
    }

    private var currentQuote: PackageQuote {
        journey.quote ?? preview.packageQuote
    }

    private var primaryHotelSummary: HotelSummary? {
        guard let id = preview.primaryHotel?.id else { return nil }
        return storefront.hotel(id: id)
    }

    private var canBook: Bool {
        guard isPrepared,
              journey.quote != nil,
              journey.selectedHotel != nil,
              journey.selectedOutbound != nil,
              journey.selectedInbound != nil else { return false }
        if journey.trip.scope == .makkahAndMadinah, journey.selectedMadinahHotel == nil { return false }
        return true
    }

    private func openHotel(_ packageHotel: StorefrontPackageHotel) {
        guard let hotel = storefront.hotel(id: packageHotel.id) else {
            bookingError = hotelUnavailableText
            IumrahHaptics.error()
            return
        }
        let role: HotelSelectionRole = isMadinahCity(packageHotel.city) ? .madinah : .makkah
        selectedHotelTarget = PackageHotelSelectionTarget(hotel: hotel, role: role)
    }

    private func selectedRoomName(for packageHotel: StorefrontPackageHotel) -> String? {
        let role: HotelSelectionRole = isMadinahCity(packageHotel.city) ? .madinah : .makkah
        switch role {
        case .makkah:
            if let room = journey.selectedRoom { return room.name }
            if let category = journey.selectedRoomCategory { return L10n.text(category.category.titleKey, settings.language) }
        case .madinah:
            if let room = journey.selectedMadinahRoom { return room.name }
            if let category = journey.selectedMadinahRoomCategory { return L10n.text(category.category.titleKey, settings.language) }
        }
        return nil
    }

    private func isMadinahCity(_ city: String) -> Bool {
        let value = city.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        return value.contains("madin") || value.contains("medin")
    }

    @MainActor
    private func prepareBookingJourneyIfNeeded() {
        guard !isPrepared else { return }
        guard let makkahPackageHotel = preview.hotels.first(where: { !isMadinahCity($0.city) }),
              let makkahHotel = storefront.hotel(id: makkahPackageHotel.id),
              let outboundDeparture = parseStorefrontISO(preview.outbound.departureAt),
              let outboundArrival = parseStorefrontISO(preview.outbound.arrivalAt),
              let returnDeparture = parseStorefrontISO(preview.inbound.departureAt),
              let offers = storefront.bookingFlightOffers(for: preview) else {
            bookingError = packagePreparationErrorText
            return
        }

        let initialScope: JourneyScope
        if isHotelFirst {
            initialScope = .makkahOnly
        } else {
            initialScope = preview.kind == .makkahComfortShort ? .makkahOnly : .makkahAndMadinah
        }

        let madinahHotel: HotelSummary?
        if initialScope == .makkahAndMadinah {
            guard let packageHotel = preview.hotels.first(where: { isMadinahCity($0.city) }),
                  let resolved = storefront.hotel(id: packageHotel.id) else {
                bookingError = packagePreparationErrorText
                return
            }
            madinahHotel = resolved
        } else {
            madinahHotel = nil
        }

        let preservedAirport = journey.trip.originAirport?.iata.uppercased() == preview.outbound.origin.uppercased()
            ? journey.trip.originAirport
            : nil

        var trip = TripDraft()
        trip.origin = preview.outbound.origin.uppercased()
        trip.originAirport = preservedAirport
        trip.arrivalAirport = preview.outbound.destination.uppercased() == "MED" ? .madinah : .jeddah
        trip.departureDate = Calendar.current.startOfDay(for: outboundDeparture)
        trip.saudiArrivalDate = Calendar.current.startOfDay(for: outboundArrival)
        trip.returnDate = Calendar.current.startOfDay(for: returnDeparture)
        trip.flexibility = .exact
        trip.adults = isHotelFirst ? 2 : 1
        trip.children = 0
        trip.infants = 0
        trip.rooms = 1
        trip.hotelStars = preview.tier.primaryHotelStars
        trip.packageTier = preview.tier
        trip.mealSelection = nil
        trip.scope = initialScope
        trip.flightTripType = .roundTrip

        initialOutboundFare = storefront.publishedFarePerTraveler(optionID: preview.outboundOptionID)
        initialInboundFare = storefront.publishedFarePerTraveler(optionID: preview.returnOptionID)
        if preview.outboundOptionID == preview.returnOptionID {
            initialOutboundFare = preview.flightFarePerPersonUSD / 2
            initialInboundFare = preview.flightFarePerPersonUSD / 2
        } else if let outbound = initialOutboundFare, initialInboundFare == nil {
            initialInboundFare = max(0, preview.flightFarePerPersonUSD - outbound)
        } else if let inbound = initialInboundFare, initialOutboundFare == nil {
            initialOutboundFare = max(0, preview.flightFarePerPersonUSD - inbound)
        }

        suppressQuoteRefresh = true
        journey.resetAfterTripChange()
        journey.trip = trip
        journey.packageFlightPath = .publishedDirect
        journey.selectedPublishedCompleteID = preview.outboundOptionID == preview.returnOptionID ? preview.outboundOptionID : nil
        journey.selectedPublishedOutboundID = preview.outboundOptionID
        journey.selectedPublishedReturnID = preview.returnOptionID
        journey.hotels = storefront.makkahHotels
        journey.madinahHotels = storefront.madinahHotels
        journey.selectedHotel = makkahHotel
        journey.selectedMadinahHotel = madinahHotel
        journey.selectedRoom = nil
        journey.selectedRoomCategory = nil
        journey.selectedMadinahRoom = nil
        journey.selectedMadinahRoomCategory = nil
        journey.selectedOutbound = offers.outbound
        journey.selectedInbound = offers.inbound
        journey.selectedTransferVehicle = .carnival
        journey.haramainTrainSelected = false
        journey.transferSelectionConfirmed = false
        journey.quote = preview.packageQuote
        journey.errorMessage = nil
        heroImageIndex = 0
        isPrepared = true
        suppressQuoteRefresh = false

        // Hotel cards and the hotel detail use the same two-person storefront quote.
        // Preserve that exact number on first open; subsequent edits recalculate live.
        if !isHotelFirst {
            refreshQuote()
        }
    }

    @MainActor
    private func refreshQuote() {
        guard isPrepared,
              let makkahHotel = journey.selectedHotel else { return }

        let quote = storefront.checkoutQuote(
            for: preview,
            trip: journey.trip,
            makkahHotel: makkahHotel,
            madinahHotel: journey.selectedMadinahHotel,
            makkahRoomID: journey.selectedRoom?.id ?? journey.selectedRoomCategory?.id,
            madinahRoomID: journey.selectedMadinahRoom?.id ?? journey.selectedMadinahRoomCategory?.id,
            transferVehicle: journey.selectedTransferVehicle,
            includeHaramainTrain: journey.haramainTrainSelected,
            haramainPublicAddOnUsd: journey.haramainTrainAddOnUsd,
            journeyFarePerPersonUSD: currentJourneyFarePerPerson,
            outboundOffer: journey.selectedOutbound,
            inboundOffer: journey.selectedInbound
        )

        if let quote {
            journey.quote = quote
            bookingError = nil
        } else {
            bookingError = priceRefreshErrorText
        }
    }

    @MainActor
    private func applyFlightChoice(
        _ choice: StorefrontConfiguratorFlightChoice,
        direction: FlightDirection,
        airport: Airport?,
        originCode: String
    ) {
        guard let offer = storefront.bookingFlightOffer(for: choice, direction: direction) else {
            bookingError = priceRefreshErrorText
            IumrahHaptics.error()
            return
        }

        suppressQuoteRefresh = true
        journey.selectedPublishedCompleteID = nil

        switch direction {
        case .outbound:
            let selectedOrigin = choice.leg.origin.uppercased()
            journey.trip.origin = selectedOrigin
            journey.trip.originAirport = airport?.iata.uppercased() == selectedOrigin ? airport : nil
            if choice.leg.destination.uppercased() == "MED" {
                journey.trip.arrivalAirport = .madinah
            } else if choice.leg.destination.uppercased() == "JED" {
                journey.trip.arrivalAirport = .jeddah
            }
            if let departure = parseStorefrontISO(choice.leg.departureAt) {
                journey.trip.departureDate = Calendar.current.startOfDay(for: departure)
            }
            if let arrival = parseStorefrontISO(choice.leg.arrivalAt) {
                journey.trip.saudiArrivalDate = Calendar.current.startOfDay(for: arrival)
            }
            journey.selectedOutbound = offer
            journey.selectedPublishedOutboundID = choice.id
            selectedOutboundChoice = choice

            // Keep the package valid after an outbound change. If the old return no
            // longer matches the selected route/window, choose the nearest published
            // compatible return automatically; the pilgrim can still change it next.
            if !currentReturnStillCompatible() {
                selectBestReturnForCurrentRoute()
            }

        case .inbound:
            if let departure = parseStorefrontISO(choice.leg.departureAt) {
                journey.trip.returnDate = Calendar.current.startOfDay(for: departure)
            }
            journey.selectedInbound = offer
            journey.selectedPublishedReturnID = choice.id
            selectedInboundChoice = choice
        }

        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.selection()
    }

    private func currentReturnStillCompatible() -> Bool {
        let leg = currentInboundLeg
        let origin = journey.trip.originCode.uppercased()
        let expectedSaudi = journey.trip.returnOriginCode.uppercased()
        let destination = leg.destination.uppercased()
        let destinationMatches = destination == origin || (origin != "TAS" && destination == "TAS")
        guard leg.origin.uppercased() == expectedSaudi, destinationMatches else { return false }
        guard let arrival = journey.trip.saudiArrivalDate,
              let returnDate = parseStorefrontISO(leg.departureAt) else { return true }
        let gap = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: arrival),
            to: Calendar.current.startOfDay(for: returnDate)
        ).day ?? 0
        return (2...15).contains(gap)
    }

    @MainActor
    private func selectBestReturnForCurrentRoute() {
        let choices = storefront.configurableFlightChoices(direction: .inbound, trip: journey.trip)
        let candidates = (choices.primary + choices.other).filter(isCompatibleReturnChoice)
        guard let choice = candidates.first,
              let offer = storefront.bookingFlightOffer(for: choice, direction: .inbound) else { return }
        selectedInboundChoice = choice
        journey.selectedInbound = offer
        journey.selectedPublishedReturnID = choice.id
        if let departure = parseStorefrontISO(choice.leg.departureAt) {
            journey.trip.returnDate = Calendar.current.startOfDay(for: departure)
        }
    }

    private func isCompatibleReturnChoice(_ choice: StorefrontConfiguratorFlightChoice) -> Bool {
        guard let arrival = journey.trip.saudiArrivalDate,
              let departure = parseStorefrontISO(choice.leg.departureAt) else { return true }
        let gap = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: arrival),
            to: Calendar.current.startOfDay(for: departure)
        ).day ?? 0
        return (2...15).contains(gap)
    }

    @MainActor
    private func addMadinahToHotelPackage(firstCity: SaudiArrivalAirport) {
        guard let hotel = storefront.defaultMadinahHotel(for: journey.trip.packageTier) else {
            bookingError = madinahUnavailableText
            IumrahHaptics.error()
            return
        }
        suppressQuoteRefresh = true
        journey.trip.scope = .makkahAndMadinah
        journey.trip.arrivalAirport = firstCity
        journey.selectedMadinahHotel = hotel
        journey.selectedMadinahRoom = nil
        journey.selectedMadinahRoomCategory = nil
        selectBestFlightsForCurrentRouteOrder()
        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.success()
    }

    @MainActor
    private func removeMadinahFromHotelPackage() {
        suppressQuoteRefresh = true
        journey.trip.scope = .makkahOnly
        journey.trip.arrivalAirport = .jeddah
        journey.selectedMadinahHotel = nil
        journey.selectedMadinahRoom = nil
        journey.selectedMadinahRoomCategory = nil
        selectBestFlightsForCurrentRouteOrder()
        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.selection()
    }

    @MainActor
    private func setFirstSaudiCity(_ airport: SaudiArrivalAirport) {
        guard journey.trip.scope == .makkahAndMadinah else { return }
        suppressQuoteRefresh = true
        journey.trip.arrivalAirport = airport
        selectBestFlightsForCurrentRouteOrder()
        suppressQuoteRefresh = false
        refreshQuote()
        IumrahHaptics.selection()
    }

    @MainActor
    private func selectBestFlightsForCurrentRouteOrder() {
        let outboundChoices = storefront.configurableFlightChoices(direction: .outbound, trip: journey.trip)
        if let outbound = outboundChoices.primary.first,
           let offer = storefront.bookingFlightOffer(for: outbound, direction: .outbound) {
            selectedOutboundChoice = outbound
            journey.selectedOutbound = offer
            journey.selectedPublishedOutboundID = outbound.id
            journey.selectedPublishedCompleteID = nil
            if let departure = parseStorefrontISO(outbound.leg.departureAt) {
                journey.trip.departureDate = Calendar.current.startOfDay(for: departure)
            }
            if let arrival = parseStorefrontISO(outbound.leg.arrivalAt) {
                journey.trip.saudiArrivalDate = Calendar.current.startOfDay(for: arrival)
            }
        }
        selectBestReturnForCurrentRoute()
    }

    @MainActor
    private func createBooking() async {
        guard !isSubmitting,
              let hotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound,
              let inbound = journey.selectedInbound,
              let quote = journey.quote else { return }

        if journey.trip.scope == .makkahAndMadinah, journey.selectedMadinahHotel == nil { return }

        isSubmitting = true
        bookingError = nil
        defer { isSubmitting = false }

        do {
            let profile = BookingPilgrimProfile(
                firstName: settings.firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: settings.lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                telegram: settings.telegram.trimmingCharacters(in: .whitespacesAndNewlines),
                whatsapp: settings.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            let session = try await bookings.create(
                trip: journey.trip,
                hotel: hotel,
                madinahHotel: journey.selectedMadinahHotel,
                room: journey.selectedRoom,
                roomCategory: journey.selectedRoomCategory,
                madinahRoom: journey.selectedMadinahRoom,
                madinahRoomCategory: journey.selectedMadinahRoomCategory,
                intercityTransport: journey.trip.scope == .makkahAndMadinah
                    ? (journey.haramainTrainSelected ? .haramainTrain : .road)
                    : nil,
                outbound: outbound,
                inbound: inbound,
                quote: quote,
                language: settings.language,
                pilgrimProfile: profile
            )

            if let deviceToken = push.deviceToken {
                await bookings.syncPushSubscriptions(deviceToken: deviceToken, locale: settings.language.rawValue)
            }
            IumrahHaptics.success()
            createdBookingID = session.id
        } catch {
            bookingError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
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
        journey.trip.scope == .makkahOnly
            ? tr("Только Мекка", "Makkah only", "Faqat Makka", "Фақат Макка")
            : tr("Мекка + Медина", "Makkah + Madinah", "Makka + Madina", "Макка + Мадина")
    }
    private var daysWord: String { tr("дней", "days", "kun", "кун") }
    private var usesTashkentReturnFallback: Bool {
        currentOutboundLeg.origin.uppercased() != "TAS" && currentInboundLeg.destination.uppercased() == "TAS"
    }

    private var returnFallbackText: String {
        tr(
            "Для этого пакета обратный рейс приходит в Ташкент, потому что подходящего возврата в \(currentOutboundLeg.origin) в выбранном диапазоне нет.",
            "This package returns to Tashkent because no suitable flight back to \(currentOutboundLeg.origin) is available in the package window.",
            "Bu paket Toshkentga qaytadi, chunki paket oralig‘ida \(currentOutboundLeg.origin) ga mos qaytish reysi topilmadi.",
            "Бу пакет Тошкентга қайтади, чунки пакет оралиғида \(currentOutboundLeg.origin) га мос қайтиш рейси топилмади."
        )
    }
    private var visaTitle: String { tr("Туристическая виза", "Tourist visa", "Turistik viza", "Туристик виза") }
    private var visaSummary: String { tr("eVisa · 1 год · многократный въезд · до 90 дней", "eVisa · 1 year · multiple entry · up to 90 days", "eVisa · 1 yil · ko‘p martalik kirish · 90 kungacha", "eVisa · 1 йил · кўп марталик кириш · 90 кунгача") }
    private var transferTitle: String {
        journey.trip.scope == .makkahOnly
            ? tr("Аэропортовый трансфер", "Airport transfer", "Aeroport transferi", "Аэропорт трансфери")
            : tr("Трансферы и переезд между городами", "Transfers and intercity journey", "Transferlar va shaharlararo yo‘l", "Трансферлар ва шаҳарлараро йўл")
    }
    private var mealsTitle: String { tr("Питание", "Meals", "Ovqatlanish", "Овқатланиш") }
    private var mealsSummary: String {
        journey.trip.scope == .makkahOnly
            ? tr("Мекка · питание включено по категории пакета", "Makkah · meals follow the package category", "Makka · ovqatlanish paket toifasiga muvofiq", "Макка · овқатланиш пакет тоифасига мувофиқ")
            : tr("Мекка + Медина · питание по категории пакета", "Makkah + Madinah · meals follow the package category", "Makka + Madina · ovqatlanish paket toifasiga muvofiq", "Макка + Мадина · овқатланиш пакет тоифасига мувофиқ")
    }
    private var guideTitle: String { tr("iumrah Guide · сопровождение", "iumrah Guide · personal assistance", "iumrah Guide · shaxsiy hamrohlik", "iumrah Guide · шахсий ҳамроҳлик") }
    private var guideSummary: String { tr("От встречи в аэропорту до вашего вылета", "From airport arrival until your departure", "Aeroportda kutib olishdan jo‘nab ketishingizgacha", "Аэропортда кутиб олишдан жўнаб кетишингизгача") }
    private var careSummary: String { tr("Поддержка по вашей поездке", "Support for your trip", "Safaringiz bo‘yicha yordam", "Сафарингиз бўйича ёрдам") }
    private var makkahZiyaratTitle: String { tr("Зияраты в Мекке", "Makkah ziyarat", "Makka ziyoratlari", "Макка зиёратлари") }
    private var madinahZiyaratTitle: String { tr("Зияраты в Медине", "Madinah ziyarat", "Madina ziyoratlari", "Мадина зиёратлари") }
    private var finalPriceTitle: String { tr("Итоговая цена поездки", "Final trip price", "Safarning yakuniy narxi", "Сафарнинг якуний нархи") }
    private var perPersonShort: String { tr("за 1 человека", "for 1 person", "1 kishi uchun", "1 киши учун") }
    private var perPersonLong: String { tr("на 1 человека", "per person", "1 kishi uchun", "1 киши учун") }
    private var totalForTravelersText: String {
        let count = max(1, journey.trip.travelerCount)
        return tr("за \(count) чел.", "for \(count) travelers", "\(count) kishi uchun", "\(count) киши учун")
    }
    private var travelersBody: String { tr("Добавьте тех, кто едет с вами. Итоговая цена пакета пересчитается автоматически.", "Add the people traveling with you. The package total recalculates automatically.", "Siz bilan safar qiladiganlarni qo‘shing. Paketning umumiy narxi avtomatik qayta hisoblanadi.", "Сиз билан сафар қиладиганларни қўшинг. Пакетнинг умумий нархи автоматик қайта ҳисобланади.") }
    private var changeTitle: String { tr("Изменить", "Change", "O‘zgartirish", "Ўзгартириш") }
    private var routeConfiguratorTitle: String { tr("Маршрут поездки", "Trip route", "Safar yo‘nalishi", "Сафар йўналиши") }
    private var makkahOnlyRouteSubtitle: String { tr("Сейчас пакет собран только для Мекки", "The package currently covers Makkah only", "Hozir paket faqat Makka uchun", "Ҳозир пакет фақат Макка учун") }
    private var makkahMadinahRouteSubtitle: String { tr("Мекка и Медина включены в один маршрут", "Makkah and Madinah are included in one route", "Makka va Madina bitta yo‘nalishga qo‘shilgan", "Макка ва Мадина битта йўналишга қўшилган") }
    private var firstCityTitle: String { tr("Первый город", "First city", "Birinchi shahar", "Биринчи шаҳар") }
    private var firstCityQuestionTitle: String { tr("С какого города начать?", "Which city first?", "Qaysi shahardan boshlaysiz?", "Қайси шаҳардан бошлайсиз?") }
    private var firstCityQuestionBody: String { tr("iumrah Configurator перестроит перелёты, ночи и маршрут пакета под выбранный порядок.", "iumrah Configurator will rebuild the flights, nights and package route for the selected order.", "iumrah Configurator tanlangan tartib bo‘yicha reyslar, tunlar va paket yo‘nalishini qayta hisoblaydi.", "iumrah Configurator танланган тартиб бўйича рейслар, тунлар ва пакет йўналишини қайта ҳисоблайди.") }
    private var firstJeddahTitle: String { tr("Джидда · JED", "Jeddah · JED", "Jidda · JED", "Жидда · JED") }
    private var firstMadinahTitle: String { tr("Медина · MED", "Madinah · MED", "Madina · MED", "Мадина · MED") }
    private var addMadinahTitle: String { tr("Добавить Медину", "Add Madinah", "Madinani qo‘shish", "Мадинани қўшиш") }
    private var removeMadinahTitle: String { tr("Убрать Медину из пакета", "Remove Madinah from package", "Madinani paketdan olib tashlash", "Мадинани пакетдан олиб ташлаш") }
    private var cancelTitle: String { tr("Отмена", "Cancel", "Bekor qilish", "Бекор қилиш") }
    private var madinahUnavailableText: String { tr("Сейчас нет подходящего опубликованного отеля в Медине для этой категории.", "No suitable published Madinah hotel is available for this category right now.", "Hozir bu toifa uchun Madinada mos e’lon qilingan mehmonxona yo‘q.", "Ҳозир бу тоифа учун Мадинада мос эълон қилинган меҳмонхона йўқ.") }
    private var chooseRoomTitle: String { tr("Выбрать комнату", "Choose a room", "Xona tanlash", "Хона танлаш") }
    private var bookTripTitle: String { tr("Забронировать поездку", "Book this trip", "Safarni bron qilish", "Сафарни брон қилиш") }
    private var bookingInProgressTitle: String { tr("Создаём бронирование…", "Creating booking…", "Bron yaratilmoqda…", "Брон яратилмоқда…") }
    private var generatedStamp: String { tr("Сгенерировано iumrah Configurator", "Generated by iumrah Configurator", "iumrah Configurator yaratdi", "iumrah Configurator яратди") }
    private var packagePreparationErrorText: String { tr("Не удалось подготовить этот пакет к бронированию. Обновите каталог и попробуйте снова.", "This package could not be prepared for booking. Refresh the catalog and try again.", "Bu paketni bron qilishga tayyorlab bo‘lmadi. Katalogni yangilang va qayta urinib ko‘ring.", "Бу пакетни брон қилишга тайёрлаб бўлмади. Каталогни янгиланг ва қайта уриниб кўринг.") }
    private var priceRefreshErrorText: String { tr("Не удалось пересчитать пакет после изменения выбора.", "The package could not be recalculated after your change.", "Tanlovdan keyin paket narxini qayta hisoblab bo‘lmadi.", "Танловдан кейин пакет нархини қайта ҳисоблаб бўлмади.") }
    private var hotelUnavailableText: String { tr("Карточка этого отеля временно недоступна.", "This hotel page is temporarily unavailable.", "Bu mehmonxona sahifasi vaqtincha mavjud emas.", "Бу меҳмонхона саҳифаси вақтинча мавжуд эмас.") }
}

private struct PackageFlightPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var storefront: HotelStorefrontStore
    @EnvironmentObject private var journey: JourneyStore

    let direction: FlightDirection
    let referenceFare: Decimal
    let selectedOptionID: String
    let onSelect: (StorefrontConfiguratorFlightChoice, Airport?, String) -> Void

    @State private var draftAirport: Airport?
    @State private var draftOriginCode: String

    init(
        direction: FlightDirection,
        currentAirport: Airport?,
        currentOriginCode: String,
        referenceFare: Decimal,
        selectedOptionID: String,
        onSelect: @escaping (StorefrontConfiguratorFlightChoice, Airport?, String) -> Void
    ) {
        self.direction = direction
        self.referenceFare = referenceFare
        self.selectedOptionID = selectedOptionID
        self.onSelect = onSelect
        _draftAirport = State(initialValue: currentAirport)
        _draftOriginCode = State(initialValue: currentOriginCode.uppercased())
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(airportSectionTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        AirportSelectorButton(
                            airport: $draftAirport,
                            fallbackCode: $draftOriginCode
                        )

                        Text(airportHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 6)

                    if !primaryChoices.isEmpty {
                        sectionTitle(primarySectionTitle)
                        ForEach(primaryChoices) { choice in
                            choiceCard(choice)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(noExactFlightsTitle, systemImage: "airplane.circle")
                                .font(.headline)
                            Text(noExactFlightsBody)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .iumrahCard()
                    }

                    if !otherChoices.isEmpty {
                        sectionTitle(otherFlightsTitle)
                            .padding(.top, 6)
                        ForEach(otherChoices) { choice in
                            choiceCard(choice)
                        }
                    }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(doneTitle) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .padding(.top, 2)
    }

    private func choiceCard(_ choice: StorefrontConfiguratorFlightChoice) -> some View {
        PackageFlightChoiceCard(
            choice: choice,
            deltaText: deltaText(for: choice),
            isSelected: choice.id == selectedOptionID,
            language: settings.language
        ) {
            let code = resolvedOriginCode
            onSelect(choice, draftAirport, code)
            dismiss()
        }
    }

    private var configuredTrip: TripDraft {
        var trip = journey.trip
        let code = resolvedOriginCode
        trip.origin = code
        trip.originAirport = draftAirport?.iata.uppercased() == code ? draftAirport : nil
        return trip
    }

    private var availableChoices: (primary: [StorefrontConfiguratorFlightChoice], other: [StorefrontConfiguratorFlightChoice]) {
        let result = storefront.configurableFlightChoices(direction: direction, trip: configuredTrip)
        return (
            result.primary.filter(isDateCompatible),
            result.other.filter(isDateCompatible)
        )
    }

    private var primaryChoices: [StorefrontConfiguratorFlightChoice] { availableChoices.primary }
    private var otherChoices: [StorefrontConfiguratorFlightChoice] { availableChoices.other }

    private var resolvedOriginCode: String {
        let code = (draftAirport?.iata ?? draftOriginCode)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return code.count == 3 ? code : journey.trip.originCode.uppercased()
    }

    private func isDateCompatible(_ choice: StorefrontConfiguratorFlightChoice) -> Bool {
        guard let departure = parseStorefrontISO(choice.leg.departureAt) else { return true }
        let calendar = Calendar.current

        switch direction {
        case .outbound:
            // Published rows can contain multiple future departures. Keep the complete
            // airport-specific list, but never offer a leg that has already departed.
            return departure >= calendar.startOfDay(for: Date())

        case .inbound:
            guard let arrival = journey.trip.saudiArrivalDate else { return true }
            let gap = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: arrival),
                to: calendar.startOfDay(for: departure)
            ).day ?? 0
            return (2...15).contains(gap)
        }
    }

    private func deltaText(for choice: StorefrontConfiguratorFlightChoice) -> String {
        if choice.id == selectedOptionID { return selectedTitle }
        let delta = NSDecimalNumber(decimal: choice.farePerTravelerUSD - referenceFare).doubleValue
        if abs(delta) < 0.5 { return noChangeTitle }
        let amount = Int(abs(delta).rounded())
        return delta > 0 ? "+$\(amount)" : "−$\(amount)"
    }

    private var navigationTitle: String {
        direction == .outbound
            ? tr("Изменить перелёт туда", "Change outbound flight", "Borish reysini o‘zgartirish", "Бориш рейсини ўзгартириш")
            : tr("Изменить обратный рейс", "Change return flight", "Qaytish reysini o‘zgartirish", "Қайтиш рейсини ўзгартириш")
    }

    private var airportSectionTitle: String { tr("Аэропорт вылета", "Departure airport", "Jo‘nash aeroporti", "Жўнаш аэропорти") }
    private var airportHint: String { tr(
        "Сначала показаны опубликованные рейсы для выбранного аэропорта. Цена билета скрыта — iumrah Configurator показывает только изменение итоговой стоимости.",
        "Published flights for the selected airport are shown first. The ticket fare stays hidden — iumrah Configurator shows only the change to the package price.",
        "Avval tanlangan aeroport uchun e’lon qilingan reyslar ko‘rsatiladi. Chipta narxi yashirin — iumrah Configurator faqat paket narxidagi farqni ko‘rsatadi.",
        "Аввал танланган аэропорт учун эълон қилинган рейслар кўрсатилади. Чипта нархи яширин — iumrah Configurator фақат пакет нархидаги фарқни кўрсатади."
    ) }
    private var primarySectionTitle: String { tr("Подходящие рейсы", "Matching flights", "Mos reyslar", "Мос рейслар") }
    private var otherFlightsTitle: String { tr("Другие актуальные билеты", "Other current flights", "Boshqa dolzarb chiptalar", "Бошқа долзарб чипталар") }
    private var noExactFlightsTitle: String { tr("Подходящих рейсов пока нет", "No matching flights yet", "Mos reyslar hozircha yo‘q", "Мос рейслар ҳозирча йўқ") }
    private var noExactFlightsBody: String { tr(
        "Ниже показаны другие актуальные варианты для этого аэропорта, если они доступны.",
        "Other current options for this airport are shown below when available.",
        "Quyida ushbu aeroport uchun boshqa dolzarb variantlar mavjud bo‘lsa ko‘rsatiladi.",
        "Қуйида ушбу аэропорт учун бошқа долзарб вариантлар мавжуд бўлса кўрсатилади."
    ) }
    private var selectedTitle: String { tr("Выбран", "Selected", "Tanlangan", "Танланган") }
    private var noChangeTitle: String { tr("Без доплаты", "No extra cost", "Qo‘shimcha to‘lovsiz", "Қўшимча тўловсиз") }
    private var doneTitle: String { tr("Готово", "Done", "Tayyor", "Тайёр") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private struct PackageFlightChoiceCard: View {
    let choice: StorefrontConfiguratorFlightChoice
    let deltaText: String
    let isSelected: Bool
    let language: AppSettingsStore.Language
    let onSelect: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onSelect()
        } label: {
            HStack(spacing: 14) {
                AirlineLogoView(airlineCode: choice.leg.airlineCode, size: 54)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("\(choice.leg.origin) → \(choice.leg.destination)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if choice.leg.stops == 0 {
                            Text(directTitle)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.iumrahRaisedBackground, in: Capsule())
                        }
                    }

                    Text("\(choice.leg.airline) · \(choice.leg.flightNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("\(localizedDay(choice.leg.departureAt)) · \(clock(choice.leg.departureAt))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 7) {
                    Text(deltaText)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Color.iumrahRaisedBackground, in: Capsule())

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? IumrahIconRole.success.color : Color.secondary.opacity(0.55))
                }
            }
            .padding(16)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isSelected ? 0.13 : 0.055), lineWidth: isSelected ? 1.1 : 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func localizedDay(_ value: String) -> String {
        guard let date = parseStorefrontISO(value) else { return String(value.prefix(10)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private var directTitle: String {
        switch language {
        case .russian: return "прямой"
        case .english: return "direct"
        case .uzbek: return "to‘g‘ri"
        case .uzbekCyrillic: return "тўғри"
        }
    }
}

private struct PackageFlightLegDetailCard: View {
    let leg: StorefrontFlightLeg
    let direction: String
    let language: AppSettingsStore.Language
    let actionTitle: String?
    let onChange: (() -> Void)?
    @State private var expanded = false

    init(
        leg: StorefrontFlightLeg,
        direction: String,
        language: AppSettingsStore.Language,
        actionTitle: String? = nil,
        onChange: (() -> Void)? = nil
    ) {
        self.leg = leg
        self.direction = direction
        self.language = language
        self.actionTitle = actionTitle
        self.onChange = onChange
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                        expanded.toggle()
                    }
                    IumrahHaptics.selection()
                } label: {
                    HStack(spacing: 14) {
                        AirlineLogoView(airlineCode: leg.airlineCode, size: 50)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(direction.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text("\(leg.origin) → \(leg.destination)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(leg.airline) \(leg.flightNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text("\(day(leg.departureAt)) · \(clock(leg.departureAt))")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Spacer(minLength: 4)

                        VStack(alignment: .trailing, spacing: 6) {
                            Image(systemName: "airplane")
                                .font(.headline)
                                .foregroundStyle(IumrahIconRole.travel.color)
                            Text(directText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let actionTitle, let onChange {
                    Button {
                        IumrahHaptics.selection()
                        onChange()
                    } label: {
                        Text(actionTitle)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .frame(height: 34)
                            .background(Color.iumrahRaisedBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if expanded {
                Divider().padding(.vertical, 14)
                VStack(spacing: 11) {
                    flightFact(title: departureAirportTitle, value: airportText(leg.origin))
                    flightFact(title: arrivalAirportTitle, value: airportText(leg.destination))
                    flightFact(title: departureTimeTitle, value: fullDateTime(leg.departureAt))
                    flightFact(title: arrivalTimeTitle, value: fullDateTime(leg.arrivalAt))
                    flightFact(title: durationTitle, value: durationText(leg.durationMinutes))
                    flightFact(title: cabinTitle, value: leg.cabinClass.isEmpty ? "—" : leg.cabinClass.capitalized)
                    flightFact(title: flightNumberTitle, value: leg.flightNumber)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .iumrahCard()
    }

    private func flightFact(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    private func airportText(_ code: String) -> String {
        if let airport = FlightReferenceCatalog.airport(code) {
            return "\(airport.city) · \(airport.name) · \(code.uppercased())"
        }
        return code.uppercased()
    }

    private func fullDateTime(_ value: String) -> String {
        guard let date = parseStorefrontISO(value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy HH:mm")
        return formatter.string(from: date)
    }

    private func durationText(_ minutes: Int) -> String {
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var directText: String {
        switch language {
        case .russian: return leg.stops == 0 ? "прямой" : "\(leg.stops) пересад."
        case .english: return leg.stops == 0 ? "direct" : "\(leg.stops) stops"
        case .uzbek: return leg.stops == 0 ? "to‘g‘ridan-to‘g‘ri" : "\(leg.stops) ulanish"
        case .uzbekCyrillic: return leg.stops == 0 ? "тўғридан-тўғри" : "\(leg.stops) уланиш"
        }
    }

    private var departureAirportTitle: String { tr("Аэропорт вылета", "Departure airport", "Jo‘nash aeroporti", "Жўнаш аэропорти") }
    private var arrivalAirportTitle: String { tr("Аэропорт прилёта", "Arrival airport", "Yetib borish aeroporti", "Етиб бориш аэропорти") }
    private var departureTimeTitle: String { tr("Вылет", "Departure", "Jo‘nash", "Жўнаш") }
    private var arrivalTimeTitle: String { tr("Прилёт", "Arrival", "Yetib kelish", "Етиб келиш") }
    private var durationTitle: String { tr("В пути", "Duration", "Yo‘lda", "Йўлда") }
    private var cabinTitle: String { tr("Класс", "Cabin", "Klass", "Класс") }
    private var flightNumberTitle: String { tr("Рейс", "Flight", "Reys", "Рейс") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

private struct PackageHotelDetailCard: View {
    let hotel: StorefrontPackageHotel
    let selectedRoomName: String?
    let chooseRoomText: String
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onOpen()
        } label: {
            GeometryReader { proxy in
                let mediaWidth = min(max(proxy.size.width * 0.31, 108), 124)
                HStack(spacing: 0) {
                    ZStack {
                        if let imageURL = hotel.coverImageURL, !imageURL.isEmpty {
                            HotelCachedImage(rawURL: imageURL)
                                .frame(width: mediaWidth, height: 150)
                        } else {
                            Color.iumrahRaisedBackground
                                .overlay {
                                    Image(systemName: "building.2.fill")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: mediaWidth, height: 150)
                    .clipped()

                    VStack(alignment: .leading, spacing: 7) {
                        Text(hotel.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
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

                        HStack(spacing: 6) {
                            Image(systemName: "bed.double.fill")
                                .font(.caption)
                            Text(selectedRoomName ?? chooseRoomText)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(selectedRoomName == nil ? .secondary : .primary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: proxy.size.width, height: 150)
            }
            .frame(height: 150)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.6)
            }
        }
        .buttonStyle(.plain)
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

private struct PackagePurchaseTrustCard: View {
    let language: AppSettingsStore.Language
    let onOpen: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            onOpen()
        } label: {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "checkmark.shield.fill", role: .security, size: 42, symbolSize: 17, cornerRadius: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
        }
    }

    private var title: String {
        switch language {
        case .russian: return "Доверие и подтверждение бронирования"
        case .english: return "Booking trust and confirmation"
        case .uzbek: return "Bron ishonchi va tasdig‘i"
        case .uzbekCyrillic: return "Брон ишончи ва тасдиғи"
        }
    }

    private var subtitle: String {
        switch language {
        case .russian: return "Booking ID · инвойс · чек после подтверждения оплаты · поддержка iumrah"
        case .english: return "Booking ID · invoice · receipt after payment confirmation · iumrah support"
        case .uzbek: return "Booking ID · invoice · to‘lov tasdiqlangach chek · iumrah yordami"
        case .uzbekCyrillic: return "Booking ID · invoice · тўлов тасдиқлангач чек · iumrah ёрдами"
        }
    }
}

private struct StorefrontPackageInformationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: StorefrontPackageInfoSheet
    let language: AppSettingsStore.Language
    let preview: StorefrontFlightPackagePreview

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    switch kind {
                    case .visa:
                        visaContent
                    case .guide:
                        guideContent
                    case .trust:
                        trustContent
                    }
                }
                .padding(IumrahDesign.pagePadding)
                .padding(.bottom, 26)
            }
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(doneTitle) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            IumrahIconBadge(systemName: headerIcon, role: headerRole, size: 50, symbolSize: 20, cornerRadius: 16)
            Text(sheetTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text(sheetSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var visaContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoCard {
                infoPoint(icon: "calendar", title: tr("Срок действия", "Validity", "Amal qilish muddati", "Амал қилиш муддати"), body: tr("До 1 года с даты выдачи.", "Up to 1 year from issue.", "Berilgan kundan boshlab 1 yilgacha.", "Берилган кундан бошлаб 1 йилгача."))
                Divider()
                infoPoint(icon: "arrow.left.arrow.right", title: tr("Въезды", "Entries", "Kirishlar", "Киришлар"), body: tr("Многократный въезд, если иное не указано в самой eVisa.", "Multiple entry unless the issued eVisa states otherwise.", "eVisa hujjatida boshqacha ko‘rsatilmagan bo‘lsa, ko‘p martalik kirish.", "eVisa ҳужжатида бошқача кўрсатилмаган бўлса, кўп марталик кириш."))
                Divider()
                infoPoint(icon: "clock", title: tr("Пребывание", "Stay", "Qolish muddati", "Қолиш муддати"), body: tr("Максимальный срок пребывания — до 90 дней.", "Maximum stay is up to 90 days.", "Maksimal qolish muddati — 90 kungacha.", "Максимал қолиш муддати — 90 кунгача."))
                Divider()
                infoPoint(icon: "building.columns.fill", title: tr("Умра", "Umrah", "Umra", "Умра"), body: tr("Туристическая eVisa разрешает совершение Умры, но не Хаджа.", "The tourist eVisa permits Umrah, but not Hajj.", "Turistik eVisa Umra qilishga ruxsat beradi, ammo Haj uchun emas.", "Туристик eVisa Умра қилишга рухсат беради, аммо Ҳаж учун эмас."))
                Divider()
                infoPoint(icon: "person.text.rectangle", title: tr("Паспорт", "Passport", "Pasport", "Паспорт"), body: tr("Для подачи через официальный eVisa-сервис паспорт должен быть действителен не менее 6 месяцев на дату въезда.", "For the official eVisa service, the passport must have at least 6 months validity at entry.", "Rasmiy eVisa xizmati uchun pasport kirish sanasida kamida 6 oy amal qilishi kerak.", "Расмий eVisa хизмати учун паспорт кириш санасида камида 6 ой амал қилиши керак."))
            }

            Text(visaAuthorityNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: URL(string: "https://visa.visitsaudi.com/")!) {
                HStack {
                    Label(officialVisaSourceTitle, systemImage: "safari.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
    }

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoCard {
                guidePoint("airplane.arrival", tr("Встреча в аэропорту", "Airport welcome", "Aeroportda kutib olish", "Аэропортда кутиб олиш"), tr("iumrah Guide встречает вас по маршруту поездки и помогает начать поездку без лишних вопросов после прилёта.", "Your iumrah Guide meets you for the trip and helps you start the journey smoothly after arrival.", "iumrah Guide safar yo‘nalishingiz bo‘yicha kutib oladi va kelganingizdan keyin safarni oson boshlashga yordam beradi.", "iumrah Guide сафар йўналишингиз бўйича кутиб олади ва келганингиздан кейин сафарни осон бошлашга ёрдам беради."))
                Divider()
                guidePoint("text.bubble.fill", tr("Арабский язык и заселение", "Arabic and hotel check-in", "Arab tili va mehmonxonaga joylashish", "Араб тили ва меҳмонхонага жойлашиш"), tr("Помогает с общением на арабском и сопровождает заселение в выбранный отель.", "Helps with Arabic communication and supports hotel check-in.", "Arab tilida muloqot qilish va tanlangan mehmonxonaga joylashishda yordam beradi.", "Араб тилида мулоқот қилиш ва танланган меҳмонхонага жойлашишда ёрдам беради."))
                Divider()
                guidePoint("car.fill", tr("Маршрут и трансферы", "Route and transfers", "Yo‘nalish va transferlar", "Йўналиш ва трансферлар"), tr("Сопровождает ключевые переезды по программе, включая переход между Меккой и Мединой, когда он есть в пакете.", "Supports the key transfers in your itinerary, including the Makkah–Madinah journey when included.", "Dasturdagi asosiy transferlarda, jumladan paketda bo‘lsa Makka–Madina yo‘lida hamroh bo‘ladi.", "Дастурдаги асосий трансферларда, жумладан пакетда бўлса Макка–Мадина йўлида ҳамроҳ бўлади."))
                Divider()
                guidePoint("mappin.and.ellipse", tr("Зияраты", "Ziyarat", "Ziyoratlar", "Зиёратлар"), tr("Сопровождает включённые зияраты и помогает ориентироваться по программе поездки.", "Accompanies the included ziyarat program and helps you follow the itinerary.", "Paketga kiritilgan ziyoratlarda hamroh bo‘ladi va safar dasturi bo‘yicha yo‘l ko‘rsatadi.", "Пакетга киритилган зиёратларда ҳамроҳ бўлади ва сафар дастури бўйича йўл кўрсатади."))
                Divider()
                guidePoint("hands.sparkles.fill", tr("Сопровождение Умры", "Umrah support", "Umra hamrohligi", "Умра ҳамроҳлиги"), tr("Помогает пройти организационную часть Умры и остаётся вашим контактным лицом по поездке.", "Helps with the organizational side of Umrah and remains your trip contact.", "Umraning tashkiliy qismida yordam beradi va safar davomida sizning aloqa shaxsingiz bo‘lib qoladi.", "Умранинг ташкилий қисмида ёрдам беради ва сафар давомида сизнинг алоқа шахсингиз бўлиб қолади."))
                Divider()
                guidePoint("airplane.departure", tr("До вылета домой", "Until departure home", "Uyga jo‘nashgacha", "Уйга жўнашгача"), tr("Сопровождение привязано к вашей поездке до её завершения и трансфера в аэропорт на обратный вылет.", "The assistance stays tied to your trip through its completion and the airport transfer for your return flight.", "Hamrohlik safaringiz yakunigacha va qaytish reysi uchun aeroport transferigacha davom etadi.", "Ҳамроҳлик сафарингиз якунигача ва қайтиш рейси учун аэропорт трансферигача давом этади."))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(founderContactTitle)
                    .font(.headline)
                Text(founderContactBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Link(destination: URL(string: "tel:+998508898845")!) {
                        Label(callTitle, systemImage: "phone.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())

                    Link(destination: URL(string: "https://t.me/saudiclub966")!) {
                        Label("Telegram", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IumrahSecondaryButtonStyle())
                }
            }
            .iumrahCard()
        }
    }

    private var trustContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(trustIntro)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            infoCard {
                infoPoint(icon: "number.square.fill", title: "iumrah Booking ID", body: trustBookingIDBody)
                Divider()
                infoPoint(icon: "doc.text.fill", title: tr("Инвойс", "Invoice", "Invoice", "Invoice"), body: trustInvoiceBody)
                Divider()
                infoPoint(icon: "checkmark.seal.fill", title: tr("Чек", "Receipt", "Chek", "Чек"), body: trustReceiptBody)
                Divider()
                infoPoint(icon: "arrow.uturn.backward.circle.fill", title: tr("Возврат", "Refund", "Qaytarish", "Қайтариш"), body: trustRefundBody)
                Divider()
                infoPoint(icon: "heart.fill", title: "iumrah Care", body: trustCareBody)
            }

            Text(trustIndividualNote)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .iumrahCard()
    }

    private func infoPoint(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, role: .security, size: 38, symbolSize: 14, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func guidePoint(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IumrahIconBadge(systemName: icon, role: .care, size: 38, symbolSize: 14, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerIcon: String {
        switch kind {
        case .visa: return "doc.text.fill"
        case .guide: return "person.crop.circle.badge.checkmark"
        case .trust: return "checkmark.shield.fill"
        }
    }

    private var headerRole: IumrahIconRole {
        switch kind {
        case .visa: return .document
        case .guide: return .care
        case .trust: return .security
        }
    }

    private var sheetTitle: String {
        switch kind {
        case .visa: return tr("Туристическая eVisa Саудовской Аравии", "Saudi tourist eVisa", "Saudiya turistik eVisa", "Саудия туристик eVisa")
        case .guide: return "iumrah Guide"
        case .trust: return tr("Доверие к бронированию", "Booking confidence", "Bronga ishonch", "Бронга ишонч")
        }
    }

    private var sheetSubtitle: String {
        switch kind {
        case .visa:
            return tr("Официальные условия туристической eVisa, применимые к поездке на Умру.", "Official tourist eVisa terms relevant to an Umrah trip.", "Umra safariga tegishli rasmiy turistik eVisa shartlari.", "Умра сафарига тегишли расмий туристик eVisa шартлари.")
        case .guide:
            return tr("Индивидуальное сопровождение, привязанное к вашей поездке — от прилёта до обратного вылета.", "Personal assistance tied to your trip, from arrival until your return departure.", "Safaringizga biriktirilgan shaxsiy hamrohlik — kelishdan qaytish reysigacha.", "Сафарингизга бириктирилган шахсий ҳамроҳлик — келишдан қайтиш рейсигача.")
        case .trust:
            return tr("Что фиксирует iumrah после того, как вы создаёте бронирование этого пакета.", "What iumrah records after you create a booking for this package.", "Bu paket uchun bron yaratganingizdan keyin iumrah nimalarni qayd etadi.", "Бу пакет учун брон яратганингиздан кейин iumrah нималарни қайд этади.")
        }
    }

    private var visaAuthorityNote: String { tr("Узбекистан указан в официальном списке стран, граждане которых могут подавать на Saudi eVisa. Решение о выдаче визы и разрешении на въезд всегда остаётся за компетентными органами Саудовской Аравии.", "Uzbekistan is listed among the countries whose citizens can apply for the Saudi eVisa. Visa approval and admission to Saudi Arabia remain subject to the competent Saudi authorities.", "O‘zbekiston Saudi eVisa uchun ariza berishi mumkin bo‘lgan davlatlar rasmiy ro‘yxatida bor. Vizani berish va mamlakatga kiritish bo‘yicha yakuniy qaror Saudiya vakolatli organlariga tegishli.", "Ўзбекистон Saudi eVisa учун ариза бериши мумкин бўлган давлатлар расмий рўйхатида бор. Визани бериш ва мамлакатга киритиш бўйича якуний қарор Саудия ваколатли органларига тегишли.") }
    private var officialVisaSourceTitle: String { tr("Официальный Saudi eVisa портал", "Official Saudi eVisa portal", "Rasmiy Saudi eVisa portali", "Расмий Saudi eVisa портали") }
    private var founderContactTitle: String { tr("Поговорите с основателем iumrah до бронирования", "Talk to the iumrah founder before booking", "Bron qilishdan oldin iumrah asoschisi bilan gaplashing", "Брон қилишдан олдин iumrah асосчиси билан гаплашинг") }
    private var founderContactBody: String { tr("Можно прямо сейчас обсудить именно этот пакет или другой вариант с Абдулазизом. Звонок и Telegram доступны напрямую — без передачи запроса через общий чат.", "You can discuss this exact package or another option directly with Abdulaziz now. Call or Telegram him directly without routing the question through a general chat.", "Aynan shu paket yoki boshqa variantni hozir Abdulaziz bilan bevosita muhokama qilishingiz mumkin. Qo‘ng‘iroq va Telegram to‘g‘ridan-to‘g‘ri mavjud.", "Айнан шу пакет ёки бошқа вариантни ҳозир Абдулазиз билан бевосита муҳокама қилишингиз мумкин. Қўнғироқ ва Telegram тўғридан-тўғри мавжуд.") }
    private var callTitle: String { tr("Позвонить", "Call", "Qo‘ng‘iroq", "Қўнғироқ") }
    private var trustIntro: String { tr("Бронирование создаётся внутри вашей учётной записи iumrah и получает собственный идентификатор. Маршрут, выбранные отели, комнаты, трансфер и сервисы сохраняются вместе с поездкой.", "The booking is created inside your iumrah account with its own identifier. Route, hotels, rooms, transfer and services are saved with the trip.", "Bron iumrah hisobingiz ichida alohida identifikator bilan yaratiladi. Yo‘nalish, mehmonxonalar, xonalar, transfer va xizmatlar safar bilan birga saqlanadi.", "Брон iumrah ҳисобингиз ичида алоҳида идентификатор билан яратилади. Йўналиш, меҳмонхоналар, хоналар, трансфер ва хизматлар сафар билан бирга сақланади.") }
    private var trustBookingIDBody: String { tr("После создания поездка получает уникальный ID бронирования и появляется в разделе «Бронирование».", "After creation, the trip receives a unique booking ID and appears in Bookings.", "Yaratilgach, safar noyob bron ID oladi va Bron bo‘limida paydo bo‘ladi.", "Яратилгач, сафар ноёб брон ID олади ва Брон бўлимида пайдо бўлади.") }
    private var trustInvoiceBody: String { tr("Данные заказа и сумма пакета фиксируются в бронировании; инвойс доступен как документ покупки/оплаты по процессу бронирования.", "Order details and the package amount are recorded in the booking; the invoice is available as part of the purchase/payment process.", "Buyurtma ma’lumotlari va paket summasi bronda qayd etiladi; invoice xarid/to‘lov jarayonining bir qismi sifatida mavjud bo‘ladi.", "Буюртма маълумотлари ва пакет суммаси бронда қайд этилади; invoice харид/тўлов жараёнининг бир қисми сифатида мавжуд бўлади.") }
    private var trustReceiptBody: String { tr("После подтверждения оплаты чек сохраняется внутри бронирования вместе с платёжными документами.", "After payment is confirmed, the receipt is stored inside the booking with the payment documents.", "To‘lov tasdiqlangach, chek to‘lov hujjatlari bilan birga bron ichida saqlanadi.", "Тўлов тасдиқлангач, чек тўлов ҳужжатлари билан бирга брон ичида сақланади.") }
    private var trustRefundBody: String { tr("Условия возврата доступны до бронирования и остаются привязаны к соответствующим компонентам поездки.", "Refund terms are available before booking and remain tied to the relevant trip components.", "Qaytarish shartlari bron qilishdan oldin ko‘rinadi va safarning tegishli qismlariga bog‘lanadi.", "Қайтариш шартлари брон қилишдан олдин кўринади ва сафарнинг тегишли қисмларига боғланади.") }
    private var trustCareBody: String { tr("После создания бронирования iumrah Care остаётся точкой связи по вашей поездке и её обслуживанию.", "After the booking is created, iumrah Care remains your support point for the trip and its services.", "Bron yaratilgach, iumrah Care safaringiz va xizmatlar bo‘yicha aloqa nuqtasi bo‘lib qoladi.", "Брон яратилгач, iumrah Care сафарингиз ва хизматлар бўйича алоқа нуқтаси бўлиб қолади.") }
    private var trustIndividualNote: String { tr("Этот пакет оформляется как индивидуальная поездка: выбранные сервисы iumrah привязываются к вашему бронированию и вашей программе.", "This package is arranged as an individual trip: the selected iumrah services are tied to your booking and itinerary.", "Bu paket individual safar sifatida rasmiylashtiriladi: tanlangan iumrah xizmatlari broningiz va dasturingizga biriktiriladi.", "Бу пакет индивидуал сафар сифатида расмийлаштирилади: танланган iumrah хизматлари брон ва дастурингизга бириктирилади.") }
    private var doneTitle: String { tr("Готово", "Done", "Tayyor", "Тайёр") }

    private func tr(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
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
