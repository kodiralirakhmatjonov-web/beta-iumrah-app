import SwiftUI
import MapKit

struct ZiyaratJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var route = ZiyaratSeedData.medina
    @State private var selectedPlace: ZiyaratPlace?
    @State private var showItinerary = false
    @State private var camera: MapCameraPosition = .region(Self.region(for: ZiyaratSeedData.medina.places))
    @State private var polylines: [MKPolyline] = []
    @State private var loading = true

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                ForEach(Array(polylines.enumerated()), id: \.offset) { _, polyline in
                    MapPolyline(polyline)
                        .stroke(Color(red: 0.03, green: 0.28, blue: 0.18), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                ForEach(route.places.sorted(by: { $0.routeOrder < $1.routeOrder })) { place in
                    Annotation(place.title, coordinate: place.coordinate, anchor: .bottom) {
                        Button {
                            selectedPlace = place
                            withAnimation(.snappy(duration: 0.35)) {
                                camera = .region(MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)))
                            }
                        } label: {
                            ZiyaratMapPin(number: place.routeOrder, isSelected: selectedPlace?.id == place.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                Spacer()
                routeCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 10)
            .allowsHitTesting(true)
        }
        .navigationBarBackButtonHidden(true)
        .task {
            loading = true
            let live = await ZiyaratService.shared.route(city: "Madinah")
            route = live
            camera = .region(Self.region(for: live.places))
            polylines = await ZiyaratRouteService.shared.roadPolylines(for: live.places)
            loading = false
        }
        .sheet(item: $selectedPlace) { place in
            ZiyaratPlaceDetailView(place: place)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showItinerary) {
            NavigationStack { ZiyaratItineraryView(route: route, onSelect: { place in showItinerary = false; selectedPlace = place }) }
                .presentationDetents([.large])
        }
    }

    private var topChrome: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.primary)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true, chrome: true)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("iumrah Ziyarats").font(.caption.weight(.bold)).foregroundStyle(Color(red: 0.03, green: 0.30, blue: 0.19))
                Text(cityTitle).font(.headline)
            }
            .padding(.horizontal, 16).frame(height: 48).iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), chrome: true)
            Spacer()
            Button {
                camera = .region(Self.region(for: route.places))
            } label: {
                Image(systemName: "location.fill").font(.system(size: 16, weight: .bold)).frame(width: 44, height: 44).foregroundStyle(.primary).iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true, chrome: true)
            }
        }
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iumrah Ziyarats").font(.caption.weight(.bold)).foregroundStyle(Color(red: 0.03, green: 0.30, blue: 0.19))
                    Text(routeTitle).font(.system(size: 27, weight: .bold, design: .rounded)).tracking(-0.6)
                    Text(routeSubtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if loading { ProgressView().controlSize(.small) }
            }

            HStack(spacing: 10) {
                metric(icon: "mappin.and.ellipse", value: "\(route.stopCount)", label: stopsLabel)
                metric(icon: "clock", value: timeText(route.estimatedMinutes), label: totalTimeLabel)
                metric(icon: "car.fill", value: transportLabel, label: shortWalksLabel)
            }

            Button { showItinerary = true } label: {
                HStack {
                    Image(systemName: "map.fill")
                    Text(viewRouteLabel)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Color(red: 0.02, green: 0.30, blue: 0.19), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous), allowsStaticGlass: true, chrome: true)
        .shadow(color: .black.opacity(0.16), radius: 26, y: 12)
    }

    private func metric(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) { Image(systemName: icon); Text(value).lineLimit(1).minimumScaleFactor(0.75) }.font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private static func region(for places: [ZiyaratPlace]) -> MKCoordinateRegion {
        guard !places.isEmpty else { return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 24.4672, longitude: 39.6111), span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)) }
        let lats = places.map(\.latitude), lons = places.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!, minLon = lons.min()!, maxLon = lons.max()!
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.035, (maxLat - minLat) * 1.55), longitudeDelta: max(0.035, (maxLon - minLon) * 1.55))
        )
    }

    private var routeTitle: String { localized("Зиярат Медины", "Medina Ziyarat", "Madina ziyorati", "Мадина зиёрати") }
    private var cityTitle: String { localized("Медина", "Madinah", "Madina", "Мадина") }
    private var routeSubtitle: String { localized("Священные и исторические места в одной поездке", "Sacred and historic places in one journey", "Muqaddas va tarixiy joylar bitta yo‘nalishda", "Муқаддас ва тарихий жойлар битта йўналишда") }
    private var stopsLabel: String { localized("мест", "stops", "joy", "жой") }
    private var totalTimeLabel: String { localized("всего", "total", "jami", "жами") }
    private var shortWalksLabel: String { localized("короткие прогулки", "short walks", "qisqa yurish", "қисқа юриш") }
    private var transportLabel: String { localized("Авто", "Car", "Avto", "Авто") }
    private var viewRouteLabel: String { localized("Посмотреть маршрут", "View itinerary", "Yo‘nalishni ko‘rish", "Йўналишни кўриш") }
    private func timeText(_ minutes: Int) -> String { minutes >= 60 ? "~\(max(1, minutes / 60)) ч" : "~\(minutes) мин" }
    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language { case .russian: return ru; case .english: return en; case .uzbek: return uz; case .uzbekCyrillic: return uzCy }
    }
}

private struct ZiyaratMapPin: View {
    let number: Int
    let isSelected: Bool
    var body: some View {
        VStack(spacing: -2) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: isSelected ? 39 : 34, height: isSelected ? 39 : 34)
                .background(Color(red: 0.02, green: 0.30, blue: 0.19), in: Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
            Image(systemName: "triangle.fill").font(.system(size: 8)).rotationEffect(.degrees(180)).foregroundStyle(Color(red: 0.02, green: 0.30, blue: 0.19))
        }
        .animation(.snappy(duration: 0.22), value: isSelected)
    }
}

struct ZiyaratItineraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    let route: ZiyaratRoute
    let onSelect: (ZiyaratPlace) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                summary
                ForEach(route.places.sorted(by: { $0.routeOrder < $1.routeOrder })) { place in
                    Button { onSelect(place) } label: { row(place) }.buttonStyle(.plain)
                }
            }.padding(16).padding(.bottom, 24)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(localized("Маршрут зиярата", "Ziyarat itinerary", "Ziyorat yo‘nalishi", "Зиёрат йўналиши"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(localized("Готово", "Done", "Tayyor", "Тайёр")) { dismiss() } } }
    }

    private var summary: some View {
        HStack(spacing: 16) {
            summaryMetric("mappin.and.ellipse", "\(route.stopCount)", localized("мест", "stops", "joy", "жой"))
            summaryMetric("clock", route.estimatedMinutes >= 60 ? "~\(route.estimatedMinutes / 60) ч" : "~\(route.estimatedMinutes) мин", localized("время", "time", "vaqt", "вақт"))
            summaryMetric("car.fill", localized("Авто", "Car", "Avto", "Авто"), localized("маршрут", "route", "yo‘nalish", "йўналиш"))
        }.padding(16).iumrahCard()
    }

    private func row(_ place: ZiyaratPlace) -> some View {
        HStack(spacing: 12) {
            ZiyaratImageView(image: place.images.first)
                .frame(width: 105, height: 88).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topLeading) { Text("\(place.routeOrder)").font(.caption.bold()).foregroundStyle(.white).frame(width: 27, height: 27).background(Color(red: 0.02, green: 0.30, blue: 0.19), in: Circle()).padding(7) }
            VStack(alignment: .leading, spacing: 4) {
                Text(place.title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                if !place.titleArabic.isEmpty { Text(place.titleArabic).font(.caption).foregroundStyle(.secondary) }
                Text(place.shortDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack(spacing: 9) { Label(visitType(place.visitType), systemImage: visitIcon(place.visitType)); Label("\(place.durationMinutes) min", systemImage: "clock") }.font(.caption2.weight(.semibold)).foregroundStyle(Color(red: 0.02, green: 0.30, blue: 0.19))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(10).background(Color.iumrahPhotoCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7))
    }

    private func summaryMetric(_ icon: String, _ value: String, _ label: String) -> some View { VStack(spacing: 4) { Image(systemName: icon).font(.headline); Text(value).font(.subheadline.bold()); Text(label).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) }
    private func visitType(_ raw: String) -> String { switch raw { case "enter": return localized("Заходим", "Enter", "Kiramiz", "Кирамиз"); case "view": return localized("Осмотр", "View", "Ko‘ramiz", "Кўрамиз"); case "pass": return localized("Проездом", "Pass by", "Yo‘lda", "Йўлда"); default: return localized("Остановка", "Stop", "To‘xtash", "Тўхташ") } }
    private func visitIcon(_ raw: String) -> String { raw == "pass" ? "car.fill" : raw == "view" ? "eye.fill" : "figure.walk" }
    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String { switch settings.language { case .russian: return ru; case .english: return en; case .uzbek: return uz; case .uzbekCyrillic: return uzCy } }
}

struct ZiyaratPlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    let place: ZiyaratPlace
    @State private var selectedImage = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                gallery
                header
                metadata
                infoBlock(localized("Коротко", "Short information", "Qisqacha", "Қисқача"), place.shortDescription)
                infoBlock(localized("Подробнее", "Detailed information", "Batafsil", "Батафсил"), place.longDescription)
                if !place.interestingFacts.isEmpty { factsBlock }
                if !place.visitNotes.isEmpty { infoBlock(localized("Как проходит посещение", "Visit notes", "Tashrif", "Ташриф"), place.visitNotes) }
                exactPointCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
        }
        .background(Color.iumrahPageBackground)
    }

    private var gallery: some View {
        VStack(spacing: 9) {
            TabView(selection: $selectedImage) {
                ForEach(Array(place.images.prefix(5).enumerated()), id: \.offset) { index, image in
                    ZiyaratImageView(image: image).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 315)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            if place.images.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(place.images.prefix(5).enumerated()), id: \.offset) { index, image in
                            Button { withAnimation(.snappy) { selectedImage = index } } label: {
                                ZiyaratImageView(image: image).frame(width: 68, height: 54).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selectedImage == index ? Color(red: 0.02, green: 0.30, blue: 0.19) : .clear, lineWidth: 2))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) { VStack(alignment: .leading, spacing: 3) { Text(place.title).font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-0.8); if !place.titleArabic.isEmpty { Text(place.titleArabic).font(.title3).foregroundStyle(.secondary) } }; Spacer(); Text("\(place.routeOrder)").font(.headline.bold()).foregroundStyle(.white).frame(width: 38, height: 38).background(Color(red: 0.02, green: 0.30, blue: 0.19), in: Circle()) }
        }
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            meta("figure.walk", visitType(place.visitType))
            meta("clock", "\(place.durationMinutes) min")
            meta(categoryIcon(place.category), categoryTitle(place.category))
        }
    }

    private var factsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Что интересно здесь", "What’s interesting here", "Bu yerda nimalar qiziq", "Бу ерда нималар қизиқ")).font(.title3.bold())
            ForEach(Array(place.interestingFacts.enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .top, spacing: 11) { Image(systemName: "sparkles").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(red: 0.02, green: 0.30, blue: 0.19)).frame(width: 23, height: 23); Text(fact).font(.subheadline).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 0) }
            }
        }
        .padding(17).iumrahCard()
    }

    private var exactPointCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { VStack(alignment: .leading, spacing: 3) { Text(localized("Точная точка", "Exact point", "Aniq nuqta", "Аниқ нуқта")).font(.title3.bold()); Text(place.mapLabel.isEmpty ? place.address : place.mapLabel).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "scope").foregroundStyle(Color(red: 0.02, green: 0.30, blue: 0.19)) }
            Map(initialPosition: .region(MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)))) {
                Annotation(place.title, coordinate: place.coordinate) { ZiyaratMapPin(number: place.routeOrder, isSelected: true) }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)).allowsHitTesting(false)
            Button { openInMaps() } label: { Label(localized("Открыть точную точку", "Open exact point", "Aniq nuqtani ochish", "Аниқ нуқтани очиш"), systemImage: "location.fill").font(.headline).frame(maxWidth: .infinity).frame(height: 52).foregroundStyle(.white).background(Color(red: 0.02, green: 0.30, blue: 0.19), in: RoundedRectangle(cornerRadius: 17, style: .continuous)) }.buttonStyle(.plain)
        }.padding(17).iumrahCard()
    }

    private func infoBlock(_ title: String, _ body: String) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.title3.bold()); Text(body).font(.body).foregroundStyle(.primary.opacity(0.82)).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading) }
    private func meta(_ icon: String, _ text: String) -> some View { Label(text, systemImage: icon).font(.caption.weight(.semibold)).padding(.horizontal, 10).frame(height: 34).background(Color.iumrahRaisedBackground, in: Capsule()).lineLimit(1).minimumScaleFactor(0.75) }
    private func visitType(_ raw: String) -> String { switch raw { case "enter": return localized("Заходим", "Enter", "Kiramiz", "Кирамиз"); case "view": return localized("Осмотр", "View", "Ko‘ramiz", "Кўрамиз"); case "pass": return localized("Проездом", "Pass by", "Yo‘lda", "Йўлда"); default: return localized("Остановка", "Stop", "To‘xtash", "Тўхташ") } }
    private func categoryTitle(_ raw: String) -> String { switch raw { case "mosque": return localized("Мечеть", "Mosque", "Masjid", "Масжид"); case "mountain": return localized("Гора", "Mountain", "Tog‘", "Тоғ"); case "garden": return localized("Сад", "Garden", "Bog‘", "Боғ"); case "cemetery": return localized("Кладбище", "Cemetery", "Qabriston", "Қабристон"); case "restaurant": return localized("Ресторан", "Restaurant", "Restoran", "Ресторан"); case "beach": return localized("Море", "Sea", "Dengiz", "Денгиз"); default: return localized("Место", "Place", "Joy", "Жой") } }
    private func categoryIcon(_ raw: String) -> String { switch raw { case "mosque": return "building.columns.fill"; case "mountain": return "mountain.2.fill"; case "garden": return "tree.fill"; case "cemetery": return "leaf.fill"; case "restaurant": return "fork.knife"; case "beach": return "water.waves"; default: return "mappin.and.ellipse" } }
    private func openInMaps() { let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)); item.name = place.title; item.openInMaps() }
    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String { switch settings.language { case .russian: return ru; case .english: return en; case .uzbek: return uz; case .uzbekCyrillic: return uzCy } }
}

struct ZiyaratImageView: View {
    let image: ZiyaratImage?
    var body: some View {
        ZStack {
            Rectangle().fill(Color.iumrahRaisedBackground)
            if let image, let asset = image.bundledAssetName {
                Image(asset).resizable().scaledToFill()
            } else if let image, let url = AppConfig.absoluteURL(image.url) {
                AsyncImage(url: url) { phase in
                    if let loaded = phase.image { loaded.resizable().scaledToFill() }
                    else if phase.error != nil, let fallback = fallbackAsset(for: image.id) { Image(fallback).resizable().scaledToFill() }
                    else { ProgressView() }
                }
            } else {
                Image(systemName: "photo").font(.title2).foregroundStyle(.secondary)
            }
        }.clipped()
    }
    private func fallbackAsset(for id: String) -> String? { guard id.hasPrefix("quba-") else { return nil }; let number = id.replacingOccurrences(of: "quba-", with: ""); return "ZiyaratQuba\(number)" }
}
