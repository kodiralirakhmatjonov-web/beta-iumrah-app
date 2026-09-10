import SwiftUI

struct HotelsHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var storefront: HotelStorefrontStore

    @State private var board: HotelsShowcaseBoard = .hotels
    @State private var selectedHotel: HotelSummary?
    @State private var carePresented = false

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

    private var flightsBoard: some View {
        VStack(alignment: .leading, spacing: 24) {
            ShowcaseHero(
                asset: "IumrahFlightsShowcaseHero",
                title: "iumrah Flights",
                description: L10n.text("hotel_storefront_flights_hero_body", settings.language),
                note: L10n.text("hotel_storefront_flights_hero_note", settings.language)
            )

            if let baseline = storefront.baseline {
                SectionHeader(L10n.text("hotel_storefront_package_baseline", settings.language), eyebrow: L10n.text("hotel_storefront_recommends", settings.language), subtitle: nil)
                StorefrontBaselineFlightCard(baseline: baseline, language: settings.language)
            }

            if let options = storefront.flightBoard?.options, !options.isEmpty {
                SectionHeader(L10n.text("hotel_storefront_published_flights", settings.language), eyebrow: L10n.text("hotel_storefront_current", settings.language), subtitle: nil)
                LazyVStack(spacing: 12) {
                    ForEach(options) { option in
                        StorefrontFlightOptionCard(option: option, language: settings.language)
                    }
                }
            } else if storefront.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
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

private struct StorefrontBaselineFlightCard: View {
    let baseline: StorefrontFlightBaseline
    let language: AppSettingsStore.Language

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            routeRow(leg: baseline.outbound, direction: L10n.text("hotel_storefront_outbound", language))
            Divider()
            routeRow(leg: baseline.inbound, direction: L10n.text("hotel_storefront_return", language))
            Divider()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("hotel_storefront_package_baseline", language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.0f", baseline.perTravelerFareUsd))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                Text(L10n.text("hotel_storefront_round_trip", language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .iumrahCard()
    }

    private func routeRow(leg: StorefrontFlightLeg, direction: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            IumrahIconBadge(systemName: "airplane", role: .travel, size: 42, symbolSize: 18, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text(direction.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(leg.origin) → \(leg.destination)")
                    .font(.headline)
                Text("\(leg.airline) · \(leg.flightNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(clock(leg.departureAt))
                    .font(.headline.monospacedDigit())
                Text(day(leg.departureAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(L10n.text("hotel_storefront_direct", language))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(IumrahIconRole.success.color)
            }
        }
    }
}

private struct StorefrontFlightOptionCard: View {
    let option: StorefrontFlightOption
    let language: AppSettingsStore.Language

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(routeTitle)
                        .font(.headline)
                    Text(airlineTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "$%.0f", option.perTravelerFare))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(L10n.text("hotel_storefront_per_pilgrim", language))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                flightTime(option.outbound)
                if let inbound = option.inbound {
                    Divider().frame(height: 34)
                    flightTime(inbound)
                }
            }

            Label(L10n.text("hotel_storefront_published_direct", language), systemImage: "checkmark.seal.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .iumrahCard()
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
