import SwiftUI

struct TripBuilderView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                intro
                routeCard
                datesCard
                travelersCard
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
        .iumrahCard()
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text("trip_dates_title", settings.language), systemImage: "calendar")
                .font(.headline)

            DatePicker(L10n.text("departure", settings.language), selection: $journey.trip.departureDate, in: Date()..., displayedComponents: .date)
            DatePicker(L10n.text("return", settings.language), selection: $journey.trip.returnDate, in: journey.trip.departureDate..., displayedComponents: .date)

            Text(L10n.text("trip_flexible_hint", settings.language))
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFlexibility.allCases) { option in
                        Button {
                            journey.trip.flexibility = option
                            IumrahHaptics.selection()
                        } label: {
                            let selected = journey.trip.flexibility == option
                            Text(option.title(settings.language))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(selected ? Color.primary : Color.iumrahRaisedBackground)
                                .foregroundColor(selected ? Color(uiColor: .systemBackground) : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .iumrahCard()
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

            CounterRow(title: L10n.text("adults", settings.language), subtitle: nil, value: $journey.trip.adults, minimum: 1, maximum: 10)
            Divider()
            CounterRow(title: L10n.text("children", settings.language), subtitle: L10n.text("children_age", settings.language), value: $journey.trip.children, minimum: 0, maximum: 8)
            Divider()
            CounterRow(title: L10n.text("infants", settings.language), subtitle: L10n.text("infants_age", settings.language), value: $journey.trip.infants, minimum: 0, maximum: 4)
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
