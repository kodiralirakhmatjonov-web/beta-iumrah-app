import SwiftUI

struct HotelsHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var storefront: HotelStorefrontStore

    @State private var board: HotelsShowcaseBoard = .hotels
    @State private var selectedHotel: HotelSummary?
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
                            StorefrontFlightOptionCard(
                                option: option,
                                packagePreview: storefront.packagePreview(for: option),
                                isCalculating: storefront.isLoading,
                                language: settings.language
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
        case .russian: return "По этому маршруту нет опубликованных рейсов"
        case .english: return "No published flights for this route"
        case .uzbek: return "Bu yo‘nalishda e’lon qilingan reyslar yo‘q"
        case .uzbekCyrillic: return "Бу йўналишда эълон қилинган рейслар йўқ"
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

    var body: some View {
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

            Label(L10n.text("hotel_storefront_published_direct", language), systemImage: "checkmark.seal.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .iumrahCard()
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
        case .russian: return "Пакет: \(route) · \(preview.totalNights) ноч."
        case .english: return "Package: \(route) · \(preview.totalNights) nights"
        case .uzbek: return "Paket: \(route) · \(preview.totalNights) tun"
        case .uzbekCyrillic: return "Пакет: \(route) · \(preview.totalNights) тун"
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
        case .russian: return "нет пары 4–8 дней"
        case .english: return "no 4–8 day pair"
        case .uzbek: return "4–8 kunlik juftlik yo‘q"
        case .uzbekCyrillic: return "4–8 кунлик жуфтлик йўқ"
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
