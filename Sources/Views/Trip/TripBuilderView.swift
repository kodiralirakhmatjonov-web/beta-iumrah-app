import SwiftUI

struct TripBuilderView: View {
    @EnvironmentObject private var journey: JourneyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                intro
                progressLine
                routeCard
                datesCard
                travelersCard
                hotelClassCard
                packageCard

                NavigationLink {
                    PrimaryHotelView()
                } label: {
                    Text("Продолжить к отелю")
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(!journey.trip.canContinue)
                .opacity(journey.trip.canContinue ? 1 : 0.45)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("Сборка поездки")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("СОБЕРИТЕ СВОЮ УМРУ")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Text("Начнём с вашей поездки")
                .font(.system(size: 33, weight: .bold, design: .rounded))
                .tracking(-0.7)
            Text("Выберите маршрут, даты и людей. iumrah использует эти параметры, чтобы подобрать отель и найти подходящие перелёты.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressLine: some View {
        HStack(spacing: 8) {
            step("1", "Поездка", active: true)
            step("2", "Отель", active: false)
            step("3", "Перелёт", active: false)
            step("4", "Готово", active: false)
        }
    }

    private func step(_ number: String, _ title: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(number)
                .font(.caption2.weight(.bold))
                .frame(width: 26, height: 26)
                .foregroundColor(active ? Color.iumrahPrimaryButtonText : Color.secondary)
                .background(active ? Color.iumrahPrimaryButtonBackground : Color.iumrahRaisedBackground)
                .clipShape(Circle())
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(active ? Color.primary : Color.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Откуда начинается поездка", systemImage: "airplane.departure")
                .font(.headline)

            AirportSelectorButton(airport: $journey.trip.originAirport, fallbackCode: $journey.trip.origin)

            Text("Куда хотите отправиться")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Маршрут", selection: $journey.trip.scope) {
                ForEach(JourneyScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if journey.trip.scope == .makkahAndMadinah {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Куда прилететь сначала")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Аэропорт прилёта", selection: $journey.trip.arrivalAirport) {
                        ForEach(SaudiArrivalAirport.allCases) { airport in
                            Text(airport.shortTitle).tag(airport)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(journey.trip.arrivalAirport == .madinah
                         ? "Сначала Медина. Обратный перелёт будем искать из Джидды."
                         : "Сначала Мекка через Джидду. Обратный перелёт будем искать из Медины.")
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
            Label("Когда хотите отправиться", systemImage: "calendar")
                .font(.headline)

            DatePicker("Вылет", selection: $journey.trip.departureDate, in: Date()..., displayedComponents: .date)
            DatePicker("Обратно", selection: $journey.trip.returnDate, in: journey.trip.departureDate..., displayedComponents: .date)

            Text("Гибкие даты помогают найти больше подходящих перелётов.")
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
            Label("Кто отправляется с вами", systemImage: "person.2")
                .font(.headline)
                .padding(.bottom, 4)

            Text("Размещение и перелёт будут рассчитаны под вашу семью или компанию.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            CounterRow(title: "Взрослые", subtitle: nil, value: $journey.trip.adults, minimum: 1, maximum: 10)
            Divider()
            CounterRow(title: "Дети", subtitle: "2–11 лет", value: $journey.trip.children, minimum: 0, maximum: 8)
            Divider()
            CounterRow(title: "Младенцы", subtitle: "до 2 лет", value: $journey.trip.infants, minimum: 0, maximum: 4)
            Divider()
            CounterRow(title: "Комнаты", subtitle: nil, value: $journey.trip.rooms, minimum: 1, maximum: 6)
        }
        .iumrahCard()
    }

    private var hotelClassCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Уровень отеля", systemImage: "building.2")
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
            Label("Какой формат поездки вам ближе", systemImage: "square.grid.2x2")
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
                                    Text("ЧАЩЕ ВЫБИРАЮТ")
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
