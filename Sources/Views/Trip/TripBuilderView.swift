import SwiftUI

struct TripBuilderView: View {
    @EnvironmentObject private var journey: JourneyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SectionHeader(
                    "Соберите свою Умру",
                    eyebrow: "iumrah beta",
                    subtitle: "Выберите основные параметры поездки. Отдельные цены отеля и перелёта не показываются — только стоимость всего пакета."
                )

                routeCard
                datesCard
                travelersCard
                hotelClassCard
                packageCard

                NavigationLink {
                    PrimaryHotelView()
                } label: {
                    Text("Продолжить")
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(!journey.trip.canContinue)
                .opacity(journey.trip.canContinue ? 1 : 0.45)
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Маршрут", systemImage: "airplane.departure")
                .font(.headline)

            TextField("Город или аэропорт вылета", text: $journey.trip.origin)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Picker("Маршрут", selection: $journey.trip.scope) {
                ForEach(JourneyScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
        }
        .iumrahCard()
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Даты", systemImage: "calendar")
                .font(.headline)

            DatePicker("Вылет", selection: $journey.trip.departureDate, in: Date()..., displayedComponents: .date)
            DatePicker("Обратно", selection: $journey.trip.returnDate, in: journey.trip.departureDate..., displayedComponents: .date)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFlexibility.allCases) { option in
                        Button {
                            journey.trip.flexibility = option
                        } label: {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(journey.trip.flexibility == option ? Color.primary : Color.primary.opacity(0.06))
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
            Label("Путешественники", systemImage: "person.2")
                .font(.headline)
                .padding(.bottom, 4)

            CounterRow(title: "Взрослые", subtitle: nil, value: $journey.trip.adults, minimum: 1, maximum: 12)
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
            Label("Класс отеля", systemImage: "building.2")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { stars in
                    Button {
                        journey.trip.hotelStars = stars
                    } label: {
                        Text("\(stars)★")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(journey.trip.hotelStars == stars ? Color.primary : Color.primary.opacity(0.06))
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
            Label("Пакет", systemImage: "square.grid.2x2")
                .font(.headline)

            ForEach(PackageTier.allCases) { tier in
                Button {
                    journey.trip.packageTier = tier
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: journey.trip.packageTier == tier ? "checkmark.circle.fill" : "circle")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.title).font(.body.weight(.semibold))
                            Text(tier.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .iumrahCard()
    }
}
