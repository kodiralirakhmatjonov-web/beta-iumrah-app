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
        .safeAreaInset(edge: .top, spacing: 8) {
            progressHeader
                .padding(.horizontal, IumrahDesign.pagePadding)
        }
        .background(Color.iumrahPageBackground)
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

    private var progressHeader: some View {
        HStack(spacing: 8) {
            step("1", L10n.text("step_trip", settings.language), active: true)
            divider
            step("2", L10n.text("step_hotel", settings.language), active: false)
            divider
            step("3", L10n.text("step_flight", settings.language), active: false)
            divider
            step("4", L10n.text("step_ready", settings.language), active: false)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.primary.opacity(0.05), lineWidth: 1) }
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 18, height: 1)
    }

    private func step(_ number: String, _ title: String, active: Bool) -> some View {
        HStack(spacing: 9) {
            Text(number)
                .font(.caption2.weight(.bold))
                .frame(width: 26, height: 26)
                .foregroundColor(active ? Color.iumrahPrimaryButtonText : Color.secondary)
                .background(active ? Color.iumrahPrimaryButtonBackground : Color.iumrahRaisedBackground)
                .clipShape(Circle())
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(active ? Color.primary : Color.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(settings.language == .english ? "Where your trip starts" : settings.language == .uzbek ? "Safar qayerdan boshlanadi" : settings.language == .uzbekCyrillic ? "Сафар қаердан бошланади" : "Откуда начинается поездка", systemImage: "airplane.departure")
                .font(.headline)

            AirportSelectorButton(airport: $journey.trip.originAirport, fallbackCode: $journey.trip.origin)

            Text(settings.language == .english ? "Where do you want to go" : settings.language == .uzbek ? "Qayerga yo‘l olmoqchisiz" : settings.language == .uzbekCyrillic ? "Қаерга йўл олмоқчисиз" : "Куда хотите отправиться")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Route", selection: $journey.trip.scope) {
                ForEach(JourneyScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if journey.trip.scope == .makkahAndMadinah {
                VStack(alignment: .leading, spacing: 10) {
                    Text(settings.language == .english ? "Which airport first" : settings.language == .uzbek ? "Avval qaysi aeroport" : settings.language == .uzbekCyrillic ? "Аввал қайси аэропорт" : "Куда прилететь сначала")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Arrival airport", selection: $journey.trip.arrivalAirport) {
                        ForEach(SaudiArrivalAirport.allCases) { airport in
                            Text(airport.shortTitle).tag(airport)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(journey.trip.arrivalAirport == .madinah
                         ? (settings.language == .english ? "Start with Madinah. Return flights will be searched from Jeddah." : settings.language == .uzbek ? "Avval Madina. Qaytish reysi Jiddadan qidiriladi." : settings.language == .uzbekCyrillic ? "Аввал Мадина. Қайтиш рейси Жиддадан қидирилади." : "Сначала Медина. Обратный перелёт будем искать из Джидды.")
                         : (settings.language == .english ? "Start with Makkah via Jeddah. Return flights will be searched from Madinah." : settings.language == .uzbek ? "Avval Makka Jidda orqali. Qaytish reysi Madinadan qidiriladi." : settings.language == .uzbekCyrillic ? "Аввал Макка Жидда орқали. Қайтиш рейси Мадинадан қидирилади." : "Сначала Мекка через Джидду. Обратный перелёт будем искать из Медины."))
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
            Label(settings.language == .english ? "When do you want to travel" : settings.language == .uzbek ? "Qachon yo‘lga chiqmoqchisiz" : settings.language == .uzbekCyrillic ? "Қачон йўлга чиқмоқчисиз" : "Когда хотите отправиться", systemImage: "calendar")
                .font(.headline)

            DatePicker(settings.language == .english ? "Departure" : settings.language == .uzbek ? "Jo‘nash" : settings.language == .uzbekCyrillic ? "Жўнаш" : "Вылет", selection: $journey.trip.departureDate, in: Date()..., displayedComponents: .date)
            DatePicker(settings.language == .english ? "Return" : settings.language == .uzbek ? "Qaytish" : settings.language == .uzbekCyrillic ? "Қайтиш" : "Обратно", selection: $journey.trip.returnDate, in: journey.trip.departureDate..., displayedComponents: .date)

            Text(settings.language == .english ? "Flexible dates help find more suitable flights." : settings.language == .uzbek ? "Moslashuvchan sanalar ko‘proq parvoz variantlarini topishga yordam beradi." : settings.language == .uzbekCyrillic ? "Мослашувчан саналар кўпроқ парвоз вариантларини топишга ёрдам беради." : "Гибкие даты помогают найти больше подходящих перелётов.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFlexibility.allCases) { option in
                        Button {
                            journey.trip.flexibility = option
                            IumrahHaptics.selection()
                        } label: {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(journey.trip.flexibility == option ? Color.primary : Color.iumrahRaisedBackground)
                                .foregroundStyle(journey.trip.flexibility == option ? Color(uiColor: .systemBackground) : .primary)
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
            Label(settings.language == .english ? "Who travels with you" : settings.language == .uzbek ? "Siz bilan kim safar qiladi" : settings.language == .uzbekCyrillic ? "Сиз билан ким сафар қилади" : "Кто отправляется с вами", systemImage: "person.2")
                .font(.headline)
                .padding(.bottom, 4)

            Text(settings.language == .english ? "Rooming and flights will be calculated for your family or group." : settings.language == .uzbek ? "Joylashuv va parvozlar oilangiz yoki guruhingiz uchun hisoblanadi." : settings.language == .uzbekCyrillic ? "Жойлашув ва парвозлар оилангиз ёки гуруҳингиз учун ҳисобланади." : "Размещение и перелёт будут рассчитаны под вашу семью или компанию.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            CounterRow(title: settings.language == .english ? "Adults" : settings.language == .uzbek ? "Kattalar" : settings.language == .uzbekCyrillic ? "Катталар" : "Взрослые", subtitle: nil, value: $journey.trip.adults, minimum: 1, maximum: 10)
            Divider()
            CounterRow(title: settings.language == .english ? "Children" : settings.language == .uzbek ? "Bolalar" : settings.language == .uzbekCyrillic ? "Болалар" : "Дети", subtitle: settings.language == .english ? "2–11 years" : settings.language == .uzbek ? "2–11 yosh" : settings.language == .uzbekCyrillic ? "2–11 ёш" : "2–11 лет", value: $journey.trip.children, minimum: 0, maximum: 8)
            Divider()
            CounterRow(title: settings.language == .english ? "Infants" : settings.language == .uzbek ? "Go‘daklar" : settings.language == .uzbekCyrillic ? "Гўдаклар" : "Младенцы", subtitle: settings.language == .english ? "under 2" : settings.language == .uzbek ? "2 yoshgacha" : settings.language == .uzbekCyrillic ? "2 ёшгача" : "до 2 лет", value: $journey.trip.infants, minimum: 0, maximum: 4)
            Divider()
            CounterRow(title: settings.language == .english ? "Rooms" : settings.language == .uzbek ? "Xonalar" : settings.language == .uzbekCyrillic ? "Хоналар" : "Комнаты", subtitle: nil, value: $journey.trip.rooms, minimum: 1, maximum: 6)
        }
        .iumrahCard()
    }

    private var hotelClassCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(settings.language == .english ? "Hotel level" : settings.language == .uzbek ? "Mehmonxona darajasi" : settings.language == .uzbekCyrillic ? "Меҳмонхона даражаси" : "Уровень отеля", systemImage: "building.2")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { stars in
                    Button {
                        journey.trip.hotelStars = stars
                        IumrahHaptics.selection()
                    } label: {
                        Text("\(stars)★")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(journey.trip.hotelStars == stars ? Color.primary : Color.iumrahRaisedBackground)
                            .foregroundStyle(journey.trip.hotelStars == stars ? Color(uiColor: .systemBackground) : .primary)
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
            Label(settings.language == .english ? "What trip format fits you" : settings.language == .uzbek ? "Qaysi safar formati sizga mos" : settings.language == .uzbekCyrillic ? "Қайси сафар формати сизга мос" : "Какой формат поездки вам ближе", systemImage: "square.grid.2x2")
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
                                Text(tier.title).font(.body.weight(.semibold))
                                if tier == .standard {
                                    Text(settings.language == .english ? "POPULAR" : settings.language == .uzbek ? "KO‘P TANLANADI" : settings.language == .uzbekCyrillic ? "КЎП ТАНЛАНАДИ" : "ЧАЩЕ ВЫБИРАЮТ")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 7)
                                        .frame(height: 20)
                                        .background(Color.iumrahRaisedBackground)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(tier.subtitle).font(.caption).foregroundStyle(.secondary)
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
