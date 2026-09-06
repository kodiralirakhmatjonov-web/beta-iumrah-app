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

                Picker(copy("Раздел", "Section"), selection: $board) {
                    Text(copy("Отели", "Hotels")).tag(HotelsShowcaseBoard.hotels)
                    Text(copy("Авиабилеты", "Flights")).tag(HotelsShowcaseBoard.flights)
                    Text("Weekend").tag(HotelsShowcaseBoard.sundayClub)
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

                HotelCareShowcaseCard(language: settings.language) {
                    carePresented = true
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
        case .hotels: return copy("Отели", "Hotels")
        case .flights: return copy("Авиабилеты", "Flights")
        case .sundayClub: return "Sunday Umrah Club"
        }
    }

    // MARK: - Hotels

    private var hotelsBoard: some View {
        VStack(alignment: .leading, spacing: 24) {
            ShowcaseHero(
                asset: "IumrahHotelsShowcaseHero",
                title: "iumrah Hotel Space",
                body: copy(
                    "Отели, которые iumrah отбирает для более спокойной Умры: удобная локация, проверенный сервис и готовая стоимость поездки.",
                    "Hotels curated by iumrah for a calmer Umrah: convenient location, trusted service and a ready trip price."
                ),
                note: copy(
                    "В каждой карточке уже рассчитан Standard пакет: опубликованный прямой перелёт Ташкент → Медина + Джидда → Ташкент, этот отель и сервисы iumrah.",
                    "Every card already includes a Standard package: published direct Tashkent → Madinah + Jeddah → Tashkent flights, this hotel and iumrah services."
                )
            )

            hotelCitySection(
                title: L10n.text("hotels_makkah", settings.language),
                hotels: storefront.makkahHotels
            )
            hotelCitySection(
                title: L10n.text("hotels_madinah", settings.language),
                hotels: storefront.madinahHotels
            )

            if storefront.isLoading && storefront.standardQuotes.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(copy("Готовим актуальные цены пакетов…", "Preparing current package prices…"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 92)
            }

            if let error = storefront.errorMessage, storefront.standardQuotes.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .iumrahCard()
            }
        }
    }

    private func hotelCitySection(title: String, hotels: [HotelSummary]) -> some View {
        let readyHotels = hotels.filter { storefront.quote(for: $0, tier: .standard) != nil }
        return VStack(alignment: .leading, spacing: 14) {
            if !readyHotels.isEmpty {
                SectionHeader(title, eyebrow: L10n.text("hotels_selected_badge", settings.language), subtitle: nil)
                ForEach(readyHotels) { hotel in
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
                body: copy(
                    "Актуальные прямые рейсы, опубликованные iumrah Business для более лёгкого пути на Умру — без лишних пересадок и сложных маршрутов.",
                    "Current direct flights published by iumrah Business for an easier Umrah journey — without unnecessary connections or complicated routing."
                ),
                note: copy(
                    "Для готовой цены пакета iumrah использует пару Ташкент → Медина и Джидда → Ташкент.",
                    "For the ready package price, iumrah uses Tashkent → Madinah and Jeddah → Tashkent."
                )
            )

            if let baseline = storefront.baseline {
                SectionHeader(copy("Рейс для расчёта пакета", "Package flight baseline"), eyebrow: "IUMRAH RECOMMENDS", subtitle: nil)
                StorefrontBaselineFlightCard(baseline: baseline, language: settings.language)
            }

            if let options = storefront.flightBoard?.options, !options.isEmpty {
                SectionHeader(copy("Опубликованные рейсы", "Published flights"), eyebrow: copy("АКТУАЛЬНО", "CURRENT"), subtitle: nil)
                VStack(spacing: 12) {
                    ForEach(Array(options.prefix(12))) { option in
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
                body: copy(
                    "Умра, которая помещается в ваши выходные. Отдельная подборка коротких поездок для тех, кто хочет улететь на Умру без длинного отпуска.",
                    "Umrah that fits into your weekend. A separate collection of short journeys for pilgrims who want to travel without a long holiday."
                ),
                note: copy(
                    "Weekend-пакеты появятся здесь отдельными готовыми вылетами. Сейчас раздел подготовлен без тестовых или вымышленных предложений.",
                    "Weekend packages will appear here as ready departures. The section is prepared without placeholder or fictional offers."
                ),
                imageBackground: .white
            )
        }
    }

    private func openRequestedHotel(_ hotelID: String?) {
        guard let hotelID, let hotel = storefront.hotel(id: hotelID) else { return }
        selectedHotel = hotel
        chrome.requestedHotelID = nil
    }

    private func copy(_ russian: String, _ english: String) -> String {
        settings.language == .russian ? russian : english
    }
}

// MARK: - Storefront components

private struct ShowcaseHero: View {
    let asset: String
    let title: String
    let body: String
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
                Text(body)
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

    var body: some View {
        HStack(spacing: 0) {
            HotelStorefrontCollage(images: images, fallback: hotel.coverImageURL)
                .frame(width: 138, height: 246)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 5) {
                    Text(hotel.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 2)

                    HStack(spacing: 8) {
                        Button(action: onFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isFavorite ? Color.iumrahCareLight : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language == .russian
                                            ? (isFavorite ? "Убрать из избранного" : "Добавить в избранное")
                                            : (isFavorite ? "Remove from favorites" : "Add to favorites"))

                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language == .russian ? "Поделиться отелем" : "Share hotel")
                    }
                }

                if let stars = hotel.stars {
                    HStack(spacing: 5) {
                        Text(String(repeating: "★", count: max(1, min(5, stars))))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(IumrahIconRole.warning.color)
                        if let rating = hotel.rating {
                            Text(String(format: "%.1f", rating))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Label(L10n.city(hotel.city, language), systemImage: "mappin.and.ellipse")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if let quote {
                    Text("Standard")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(money(quote.packageQuote.pricePerPerson))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                    Text(language == .russian ? "на паломника" : "per pilgrim")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(language == .russian
                         ? "\(money(quote.packageQuote.totalPackagePrice)) за пакет"
                         : "\(money(quote.packageQuote.totalPackagePrice)) package total")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Text(language == .russian ? "Перелёт + отель + iumrah" : "Flight + stay + iumrah")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(15)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.045), radius: 16, y: 7)
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
        VStack(spacing: 3) {
            HotelCachedImage(rawURL: resolved[0])
                .frame(height: 153)
                .clipped()
            HStack(spacing: 3) {
                HotelCachedImage(rawURL: resolved[1])
                    .clipped()
                HotelCachedImage(rawURL: resolved[2])
                    .clipped()
            }
        }
        .clipped()
    }
}

private struct StorefrontBaselineFlightCard: View {
    let baseline: StorefrontFlightBaseline
    let language: AppSettingsStore.Language

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            routeRow(leg: baseline.outbound, direction: language == .russian ? "Туда" : "Outbound")
            Divider()
            routeRow(leg: baseline.inbound, direction: language == .russian ? "Обратно" : "Return")
            Divider()
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language == .russian ? "Для расчёта пакета" : "Package baseline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.0f", baseline.perTravelerFareUsd))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                Text(language == .russian ? "на паломника\nтуда-обратно" : "per pilgrim\nround trip")
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
                Text(language == .russian ? "Прямой" : "Direct")
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
                    Text(language == .russian ? "на паломника" : "per pilgrim")
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

            Label(language == .russian ? "Опубликован iumrah Business · прямой" : "Published by iumrah Business · direct", systemImage: "checkmark.seal.fill")
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
                Text(language == .russian
                     ? "Остались вопросы об отеле или его расположении? Получите совет команды iumrah до бронирования."
                     : "Questions about a hotel or its location? Ask the iumrah team before booking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(language == .russian ? "Связаться с iumrah Care" : "Contact iumrah Care", action: onOpen)
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
                    Text(settings.language == .russian
                         ? "Для вопросов до бронирования напишите нам в Telegram или позвоните. Внутренний чат iumrah Care становится доступен для забронированных поездок."
                         : "For questions before booking, contact us on Telegram or call. The in-app iumrah Care chat becomes available for booked trips.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Link(destination: URL(string: "https://t.me/saudiclub966")!) {
                    contactRow(icon: "paperplane.fill", title: "Telegram", value: "@saudiclub966")
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "tel:+998508898845")!) {
                    contactRow(icon: "phone.fill", title: settings.language == .russian ? "Позвонить" : "Call", value: "+998 50 889 88 45")
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)
            }
            .padding(IumrahDesign.pagePadding)
            .background(Color.iumrahPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.language == .russian ? "Готово" : "Done") { dismiss() }
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
