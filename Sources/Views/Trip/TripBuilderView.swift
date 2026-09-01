import SwiftUI

struct TripBuilderView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahFlowProgress(stage: .trip)
                intro
                routeCard
                datesCard
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
        .onAppear {
            if journey.trip.flexibility == .plusMinusOne {
                journey.trip.flexibility = .plusMinusTwo
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

            flexibilityPicker

            if journey.trip.isWeekendUmrah {
                weekendDatesContent
            } else {
                DatePicker(
                    L10n.text("departure", settings.language),
                    selection: departureBinding,
                    in: Date()...,
                    displayedComponents: .date
                )
                DatePicker(
                    L10n.text("return", settings.language),
                    selection: returnBinding,
                    in: journey.trip.departureDate...,
                    displayedComponents: .date
                )

                Text(L10n.text("trip_flexible_hint", settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .iumrahCard()
    }

    private var flexibilityPicker: some View {
        HStack(spacing: 8) {
            ForEach(DateFlexibility.allCases) { option in
                Button {
                    guard journey.trip.flexibility != option else { return }
                    journey.resetAfterTripChange()
                    journey.trip.selectFlexibility(option)
                    IumrahHaptics.selection()
                } label: {
                    let selected = normalizedFlexibility == option
                    Text(option.title(settings.language))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(selected ? Color.primary : Color.iumrahRaisedBackground)
                        .foregroundColor(selected ? Color(uiColor: .systemBackground) : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var normalizedFlexibility: DateFlexibility {
        journey.trip.flexibility == .plusMinusOne ? .plusMinusTwo : journey.trip.flexibility
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
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareDark)
                    .frame(width: 42, height: 42)
                    .background(Color.iumrahCareLight.opacity(0.22), in: Circle())

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
                            .background(selected ? Color.primary : Color.iumrahRaisedBackground)
                            .foregroundColor(selected ? Color(uiColor: .systemBackground) : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }
        }
        .iumrahCard()
    }
}
