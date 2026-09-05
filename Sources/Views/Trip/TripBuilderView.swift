import SwiftUI

struct TripBuilderView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var showsDateCalendar = false
    @State private var curatedFlights: [CuratedFlightRecommendation] = []
    @State private var isLoadingCuratedFlights = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahFlowProgress(stage: .trip)
                intro
                routeCard
                datesCard
                curatedFlightsSection
                travelersCard
                FlightSearchFiltersCard(filters: flightFiltersBinding, infantCount: journey.trip.infants)
                hotelClassCard
                packageCard

                NavigationLink {
                    PrimaryHotelView()
                } label: {
                    Text(L10n.text("trip_continue_hotel", settings.language))
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(!journey.trip.canContinue)
                .opacity(journey.trip.canContinue ? 1 : 0.45)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .trip)
        .task(id: curatedFlightsQueryKey) {
            await loadCuratedFlights()
        }
        .onAppear {
            // Production flow is always a complete Umrah journey: the pilgrim
            // chooses the outbound first and the compatible return afterwards.
            // Do not expose an internal ticket-type switch in the customer flow.
            if journey.trip.resolvedFlightTripType != .roundTrip {
                journey.resetAfterTripChange()
                journey.trip.flightTripType = .roundTrip
            } else if journey.trip.flightTripType == nil {
                journey.trip.flightTripType = .roundTrip
            }
            // The former week-wide discovery mode is retired from the customer flow.
            // Date discovery now happens in the cached OTA calendar without buying
            // seven provider searches at once.
            if journey.trip.flexibility.isFlexibleDayRange {
                journey.trip.flexibility = .exact
            }
            if journey.trip.isWeekendUmrah {
                journey.trip.applyWeekendWindow(around: journey.trip.departureDate)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("trip_intro_kicker", settings.language))
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(L10n.text("trip_intro_title", settings.language))
                .font(.system(size: 33, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text(L10n.text("trip_intro_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text("trip_origin_title", settings.language), systemImage: "airplane.departure")
                .font(.headline)

            AirportSelectorButton(airport: $journey.trip.originAirport, fallbackCode: $journey.trip.origin)

            if journey.trip.isWeekendUmrah {
                weekendRouteSummary
            } else {
                Text(L10n.text("trip_destination_title", settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker(L10n.text("trip_route_picker", settings.language), selection: $journey.trip.scope) {
                    ForEach(JourneyScope.allCases) { scope in
                        Text(scope.title(settings.language)).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                if journey.trip.scope == .makkahAndMadinah {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.text("trip_arrival_title", settings.language))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker(L10n.text("trip_arrival_picker", settings.language), selection: $journey.trip.arrivalAirport) {
                            ForEach(SaudiArrivalAirport.allCases) { airport in
                                Text(airport.shortTitle(settings.language)).tag(airport)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(L10n.text(
                            journey.trip.arrivalAirport == .madinah ? "trip_arrival_madinah_hint" : "trip_arrival_jeddah_hint",
                            settings.language
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .iumrahCard()
    }

    private var weekendRouteSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                routeCode(journey.trip.originCode)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                routeCode("JED")
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                routeCode(journey.trip.originCode)
            }

            Text(L10n.format(
                "weekend_route_note",
                settings.language,
                journey.trip.originCode,
                journey.trip.originCode
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahRaisedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
    }

    private func routeCode(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .monospaced()
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.text("trip_dates_title", settings.language), systemImage: "calendar")
                .font(.headline)

            dateModePicker

            if journey.trip.isWeekendUmrah {
                weekendDatesContent
            } else {
                Button {
                    showsDateCalendar = true
                    IumrahHaptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        dateSummaryColumn(title: L10n.text("departure", settings.language), date: journey.trip.departureDate)
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        dateSummaryColumn(title: L10n.text("return", settings.language), date: journey.trip.returnDate)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 76)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                }
                .buttonStyle(.plain)

                HStack(alignment: .top, spacing: 10) {
                    IumrahInlineIcon(
                        systemName: "chart.line.downtrend.xyaxis",
                        role: .payment,
                        size: 12
                    )
                    Text(dateCalendarHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .iumrahCard()
        .sheet(isPresented: $showsDateCalendar) {
            FlightDateCalendarView(
                trip: journey.trip,
                initialDeparture: journey.trip.departureDate,
                initialReturn: journey.trip.returnDate
            ) { outbound, inbound in
                journey.resetAfterTripChange()
                journey.trip.flexibility = .exact
                journey.trip.departureDate = outbound
                journey.trip.returnDate = inbound
            }
            .environmentObject(settings)
        }
    }

    private var dateModePicker: some View {
        HStack(spacing: 8) {
            Button {
                if journey.trip.isWeekendUmrah {
                    journey.resetAfterTripChange()
                    journey.trip.flexibility = .exact
                }
                IumrahHaptics.selection()
            } label: {
                dateModeChip(dateExactTitle, selected: !journey.trip.isWeekendUmrah)
            }
            .buttonStyle(.plain)

            Button {
                if journey.trip.isWeekendUmrah {
                    journey.resetAfterTripChange()
                    journey.trip.flexibility = .exact
                }
                showsDateCalendar = true
                IumrahHaptics.selection()
            } label: {
                dateModeChip(dateCalendarTitle, selected: false, systemImage: "calendar.badge.clock")
            }
            .buttonStyle(.plain)

            Button {
                guard !journey.trip.isWeekendUmrah else { return }
                journey.resetAfterTripChange()
                journey.trip.selectFlexibility(.weekend)
                journey.trip.flightTripType = .roundTrip
                IumrahHaptics.selection()
            } label: {
                dateModeChip(dateWeekendTitle, selected: journey.trip.isWeekendUmrah)
            }
            .buttonStyle(.plain)
        }
    }

    private func dateModeChip(_ title: String, selected: Bool, systemImage: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.caption.weight(.bold)) }
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .foregroundStyle(selected ? Color.iumrahCardBackground : Color.primary)
        .iumrahGlass(in: Capsule(), interactive: true, tint: selected ? Color.primary : nil)
    }

    private func dateSummaryColumn(title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(dateSummary(date))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(minWidth: 88, alignment: .leading)
    }

    private func dateSummary(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return formatter.string(from: date)
    }

    private var dateExactTitle: String {
        switch settings.language {
        case .russian: return "Точно"
        case .english: return "Exact"
        case .uzbek: return "Aniq"
        case .uzbekCyrillic: return "Аниқ"
        }
    }

    private var dateCalendarTitle: String {
        switch settings.language {
        case .russian: return "Даты"
        case .english: return "Dates"
        case .uzbek: return "Sanalar"
        case .uzbekCyrillic: return "Саналар"
        }
    }

    private var dateWeekendTitle: String {
        switch settings.language {
        case .russian: return "Выходные"
        case .english: return "Weekend"
        case .uzbek: return "Dam olish"
        case .uzbekCyrillic: return "Дам олиш"
        }
    }

    private var dateCalendarHint: String {
        switch settings.language {
        case .russian: return "Откройте календарь актуальных дат: он заполняется реальными поисками и помогает выбрать подходящее окно поездки до запуска нового поиска."
        case .english: return "Open the current-date calendar: it grows from real searches and helps choose a suitable travel window before a new flight search starts."
        case .uzbek: return "Dolzarb sanalar kalendarini oching: u haqiqiy qidiruvlar bilan to‘lib boradi va yangi qidiruvdan oldin mos safar oynasini tanlashga yordam beradi."
        case .uzbekCyrillic: return "Долзарб саналар календарини очинг: у ҳақиқий қидирувлар билан тўлиб боради ва янги қидирувдан олдин мос сафар оралиғини танлашга ёрдам беради."
        }
    }

    private var weekendDatesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            DatePicker(
                L10n.text("weekend_picker_title", settings.language),
                selection: weekendAnchorBinding,
                in: Date()...,
                displayedComponents: .date
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("weekend_window_title", settings.language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(weekendDates, id: \.self) { date in
                        VStack(spacing: 4) {
                            Text(shortWeekday(date))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(dayNumber(date))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text(shortMonth(date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                        .background(Color.iumrahRaisedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }

            HStack(alignment: .top, spacing: 13) {
                IumrahIconBadge(
                    systemName: "moon.stars.fill",
                    role: .umrah,
                    size: 42,
                    symbolSize: 18,
                    shape: .circle
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("weekend_umrah_title", settings.language))
                        .font(.headline)
                    Text(L10n.text("weekend_umrah_body", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(15)
            .background(
                LinearGradient(
                    colors: [Color.iumrahCareLight.opacity(0.18), Color.iumrahCardBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.iumrahCareLight.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var weekendDates: [Date] {
        (0...3).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: journey.trip.departureDate) }
    }

    private var departureBinding: Binding<Date> {
        Binding(
            get: { journey.trip.departureDate },
            set: { newValue in
                if Calendar.current.startOfDay(for: newValue) != Calendar.current.startOfDay(for: journey.trip.departureDate) {
                    journey.resetAfterTripChange()
                    journey.trip.departureDate = newValue
                    if journey.trip.returnDate <= newValue {
                        journey.trip.returnDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue.addingTimeInterval(86_400)
                    }
                }
            }
        )
    }

    private var returnBinding: Binding<Date> {
        Binding(
            get: { journey.trip.returnDate },
            set: { newValue in
                if Calendar.current.startOfDay(for: newValue) != Calendar.current.startOfDay(for: journey.trip.returnDate) {
                    journey.resetAfterTripChange()
                    journey.trip.returnDate = newValue
                }
            }
        )
    }

    private var weekendAnchorBinding: Binding<Date> {
        Binding(
            get: { journey.trip.departureDate },
            set: { newValue in
                journey.resetAfterTripChange()
                journey.trip.applyWeekendWindow(around: newValue)
            }
        )
    }

    private func shortWeekday(_ date: Date) -> String {
        dateString(date, format: "EEE").uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        dateString(date, format: "d")
    }

    private func shortMonth(_ date: Date) -> String {
        dateString(date, format: "MMM")
    }

    private func dateString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private var locale: Locale {
        switch settings.language {
        case .english: return Locale(identifier: "en_US")
        case .russian: return Locale(identifier: "ru_RU")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private var flightFiltersBinding: Binding<FlightSearchFilters> {
        Binding(
            get: { journey.trip.effectiveFlightFilters },
            set: { journey.updateFlightFilters($0) }
        )
    }

    private var tripEndDateTitle: String {
        switch settings.language {
        case .russian: return "Завершение поездки"
        case .english: return "Trip end date"
        case .uzbek: return "Safar tugash sanasi"
        case .uzbekCyrillic: return "Сафар тугаш санаси"
        }
    }

    @ViewBuilder
    private var curatedFlightsSection: some View {
        if !curatedFlights.isEmpty {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(curatedFlightsTitle)
                            .font(.headline)
                        Text(curatedFlightsSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "airplane.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 11) {
                        ForEach(curatedFlights) { recommendation in
                            curatedFlightCard(recommendation)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 1, for: .scrollContent)
            }
            .iumrahCard()
        }
    }

    private func curatedFlightCard(_ recommendation: CuratedFlightRecommendation) -> some View {
        Button {
            selectCuratedFlight(recommendation)
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    AirlineLogoView(airlineCode: recommendation.primaryAirlineCode, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.primaryAirlineName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(recommendation.flightNumbers.joined(separator: " · "))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(curatedDirectLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .frame(height: 25)
                        .background(Color.green.opacity(0.09), in: Capsule())
                }

                HStack(spacing: 8) {
                    curatedRouteCode(recommendation.outbound.origin)
                    Image(systemName: "arrow.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    curatedRouteCode(recommendation.outbound.destination)
                    if let inbound = recommendation.inbound {
                        Image(systemName: "arrow.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        curatedRouteCode(inbound.destination)
                    }
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(curatedDatesLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(curatedDateRange(recommendation))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: curatedFlightIsSelected(recommendation) ? "checkmark.circle.fill" : "arrow.up.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(curatedFlightIsSelected(recommendation) ? Color.green : Color.primary)
                }
            }
            .padding(15)
            .frame(width: 286, minHeight: 168, alignment: .leading)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(curatedFlightIsSelected(recommendation) ? Color.green.opacity(0.26) : Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func curatedRouteCode(_ code: String) -> some View {
        Text(code)
            .font(.caption.weight(.bold))
            .monospaced()
            .foregroundStyle(.primary)
    }

    private func curatedDateRange(_ recommendation: CuratedFlightRecommendation) -> String {
        let outbound = CuratedFlightRecommendationService.date(recommendation.outboundDate)
        let inbound = CuratedFlightRecommendationService.date(recommendation.inboundDate)
        let outboundText = outbound.map { shortCuratedDate($0) } ?? recommendation.outboundDate
        let inboundText = inbound.map { shortCuratedDate($0) } ?? recommendation.inboundDate ?? ""
        return inboundText.isEmpty ? outboundText : "\(outboundText) — \(inboundText)"
    }

    private func shortCuratedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func curatedFlightIsSelected(_ recommendation: CuratedFlightRecommendation) -> Bool {
        guard let outbound = CuratedFlightRecommendationService.date(recommendation.outboundDate),
              let inbound = CuratedFlightRecommendationService.date(recommendation.inboundDate) else { return false }
        return Calendar.current.isDate(outbound, inSameDayAs: journey.trip.departureDate)
            && Calendar.current.isDate(inbound, inSameDayAs: journey.trip.returnDate)
    }

    private func selectCuratedFlight(_ recommendation: CuratedFlightRecommendation) {
        guard let outbound = CuratedFlightRecommendationService.date(recommendation.outboundDate),
              let inbound = CuratedFlightRecommendationService.date(recommendation.inboundDate),
              inbound >= outbound else { return }
        journey.resetAfterTripChange()
        journey.trip.flexibility = .exact
        journey.trip.flightTripType = .roundTrip
        journey.trip.departureDate = outbound
        journey.trip.returnDate = inbound
        IumrahHaptics.selection()
    }

    @MainActor
    private func loadCuratedFlights() async {
        isLoadingCuratedFlights = true
        defer { isLoadingCuratedFlights = false }
        do {
            curatedFlights = try await CuratedFlightRecommendationService.shared.load(trip: journey.trip)
        } catch {
            // Recommendations are an enhancement. The normal date picker and live
            // flight search remain fully functional when this cache is unavailable.
            curatedFlights = []
        }
    }

    private var curatedFlightsQueryKey: String {
        [journey.trip.originCode, journey.trip.outboundDestinationCode, journey.trip.returnOriginCode, journey.trip.originCode]
            .map { $0.uppercased() }
            .joined(separator: "|")
    }

    private var curatedFlightsTitle: String {
        switch settings.language {
        case .russian: return "Актуальные прямые рейсы"
        case .english: return "Current direct flights"
        case .uzbek: return "Dolzarb to‘g‘ridan-to‘g‘ri reyslar"
        case .uzbekCyrillic: return "Долзарб тўғридан-тўғри рейслар"
        }
    }

    private var curatedFlightsSubtitle: String {
        switch settings.language {
        case .russian: return "Без пересадок · iumrah рекомендует"
        case .english: return "Nonstop · recommended by iumrah"
        case .uzbek: return "To‘xtovsiz · iumrah tavsiya qiladi"
        case .uzbekCyrillic: return "Тўхтовсиз · iumrah тавсия қилади"
        }
    }

    private var curatedDirectLabel: String {
        switch settings.language {
        case .russian: return "ПРЯМОЙ"
        case .english: return "DIRECT"
        case .uzbek: return "TO‘G‘RI"
        case .uzbekCyrillic: return "ТЎҒРИ"
        }
    }

    private var curatedDatesLabel: String {
        switch settings.language {
        case .russian: return "Даты рейса"
        case .english: return "Flight dates"
        case .uzbek: return "Reys sanalari"
        case .uzbekCyrillic: return "Рейс саналари"
        }
    }

    private var travelersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text("trip_travelers_title", settings.language), systemImage: "person.2")
                .font(.headline)
                .padding(.bottom, 4)

            Text(L10n.text("trip_travelers_body", settings.language))
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
            CounterRow(title: L10n.text("rooms", settings.language), subtitle: nil, value: $journey.trip.rooms, minimum: 1, maximum: 6)
        }
        .iumrahCard()
    }

    private var hotelClassCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text("hotel_level", settings.language), systemImage: "building.2")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { stars in
                    Button {
                        journey.trip.hotelStars = stars
                        IumrahHaptics.selection()
                    } label: {
                        let selected = journey.trip.hotelStars == stars
                        Text("\(stars)★")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .foregroundColor(selected ? Color(uiColor: .systemBackground) : Color.primary)
                            .iumrahGlass(
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                                interactive: true,
                                tint: selected ? Color.primary : nil
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .iumrahCard()
    }

    private var packageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.text("trip_format_title", settings.language), systemImage: "square.grid.2x2")
                .font(.headline)

            ForEach(PackageTier.allCases) { tier in
                Button {
                    journey.trip.packageTier = tier
                    IumrahHaptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: journey.trip.packageTier == tier ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                Text(tier.title(settings.language))
                                    .font(.body.weight(.semibold))
                                if tier == .standard {
                                    Text(L10n.text("popular", settings.language))
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .frame(height: 20)
                                        .background(Color.iumrahRaisedBackground)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(tier.subtitle(settings.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .frame(minHeight: 54)
                    .iumrahGlass(
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                        interactive: true,
                        tint: journey.trip.packageTier == tier ? Color.primary.opacity(0.10) : nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .iumrahCard()
    }
}
