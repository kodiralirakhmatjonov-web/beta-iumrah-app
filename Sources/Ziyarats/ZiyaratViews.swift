import SwiftUI
import MapKit

// MARK: - iumrah Ziyarats
//
// This module intentionally behaves like a map-first Apple system experience:
// the MapKit scene never navigates away, one persistent lower surface changes
// state, and place details expand inside the same spatial context.

struct ZiyaratJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var route = ZiyaratSeedData.medina
    @State private var selectedPlace: ZiyaratPlace?
    @State private var activeTab: ZiyaratPanelTab = .journey
    @State private var panelDetent: ZiyaratPanelDetent = .medium
    @GestureState private var panelDragTranslation: CGFloat = 0

    @State private var camera: MapCameraPosition = .region(Self.region(for: ZiyaratSeedData.medina.places))
    @State private var polylines: [MKPolyline] = []
    @State private var loadingCatalog = true
    @State private var loadingRoute = false

    @State private var mapMode: ZiyaratMapMode = .standard
    @State private var showRouteLine = true
    @State private var showPlacePins = true

    @State private var welcomeVisible = true
    @State private var welcomeCopyVisible = false
    @State private var revealedStopCount = 0

    private let panelAnimation = Animation.spring(response: 0.46, dampingFraction: 0.88, blendDuration: 0.12)
    private let cameraAnimation = Animation.easeInOut(duration: 0.62)

    private var orderedPlaces: [ZiyaratPlace] {
        route.places.sorted { $0.routeOrder < $1.routeOrder }
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let heights = panelHeights(totalHeight: proxy.size.height, safeTop: safeTop, safeBottom: safeBottom)
            let panelHeight = livePanelHeight(heights: heights)

            ZStack(alignment: .bottom) {
                mapScene
                    .ignoresSafeArea()

                mapChrome(safeTop: safeTop)
                    .opacity(panelDetent == .expanded ? 0 : 1)
                    .allowsHitTesting(panelDetent != .expanded)
                    .animation(panelAnimation, value: panelDetent)

                if welcomeVisible {
                    ZiyaratWelcomeOverlay(
                        pretitle: welcomePretitle,
                        title: "iumrah Ziyarats",
                        city: cityTitle,
                        copyVisible: welcomeCopyVisible
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(4)
                }

                if orderedPlaces.isEmpty && !loadingCatalog {
                    emptyOverlay
                        .padding(.horizontal, 24)
                        .padding(.bottom, heights.collapsed + 22)
                        .zIndex(3)
                }

                lowerPanel(height: panelHeight, safeBottom: safeBottom, heights: heights)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                    .zIndex(5)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarBackButtonHidden(true)
        .task { await loadJourney() }
        .onChange(of: panelDetent) { _, _ in
            guard let selectedPlace else { return }
            focus(on: selectedPlace, animated: true)
        }
    }

    // MARK: Map scene

    @ViewBuilder
    private var mapScene: some View {
        switch mapMode {
        case .standard:
            mapContent
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        case .satellite:
            mapContent
                .mapStyle(.imagery(elevation: .realistic))
        }
    }

    private var mapContent: some View {
        Map(position: $camera) {
            if showRouteLine {
                ForEach(Array(polylines.enumerated()), id: \.offset) { _, polyline in
                    // A light casing keeps the route legible over both Standard and Satellite.
                    MapPolyline(polyline)
                        .stroke(.white.opacity(0.88), style: StrokeStyle(lineWidth: 7.5, lineCap: .round, lineJoin: .round))
                    MapPolyline(polyline)
                        .stroke(Color(uiColor: .systemBlue), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                }
            }

            if showPlacePins {
                ForEach(Array(orderedPlaces.enumerated()), id: \.offset) { index, place in
                    Annotation(
                        place.localizedContent(locale: settings.language.rawValue).title,
                        coordinate: place.coordinate,
                        anchor: .bottom
                    ) {
                        Button {
                            select(place)
                        } label: {
                            ZiyaratMapPin(
                                number: place.routeOrder,
                                title: place.localizedContent(locale: settings.language.rawValue).title,
                                isSelected: selectedPlace?.id == place.id
                            )
                            .opacity(!welcomeVisible || index < revealedStopCount ? 1 : 0)
                            .scaleEffect(!welcomeVisible || index < revealedStopCount ? 1 : 0.72)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(place.localizedContent(locale: settings.language.rawValue).title)
                    }
                }
            }
        }
    }

    private func mapChrome(safeTop: CGFloat) -> some View {
        VStack {
            HStack(alignment: .top) {
                IumrahGlassIconButton(
                    systemName: "xmark",
                    size: 46,
                    fontSize: 16,
                    accessibilityLabel: closeLabel
                ) {
                    dismiss()
                }

                Spacer()

                IumrahGlassGroup(spacing: 8) {
                    VStack(spacing: 8) {
                        IumrahGlassIconButton(
                            systemName: mapMode == .standard ? "map.fill" : "globe.americas.fill",
                            size: 46,
                            fontSize: 16,
                            foreground: activeTab == .map ? Color(uiColor: .systemBlue) : nil,
                            accessibilityLabel: mapModeLabel
                        ) {
                            selectedPlace = nil
                            activeTab = .map
                            withAnimation(panelAnimation) { panelDetent = .medium }
                        }

                        IumrahGlassIconButton(
                            systemName: "scope",
                            size: 46,
                            fontSize: 16,
                            accessibilityLabel: fitRouteLabel
                        ) {
                            fitEntireRoute(animated: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, safeTop + 6)

            Spacer()
        }
        .zIndex(2)
    }

    // MARK: Persistent lower panel

    private func lowerPanel(
        height: CGFloat,
        safeBottom: CGFloat,
        heights: ZiyaratPanelHeights
    ) -> some View {
        VStack(spacing: 0) {
            panelHandle(heights: heights)

            if panelDetent != .collapsed || panelDragTranslation < -18 {
                panelBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Spacer(minLength: 0)
            }

            Divider()
                .opacity(panelDetent == .collapsed ? 0 : 0.55)

            panelTabBar(safeBottom: safeBottom)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .iumrahGlass(
            in: RoundedRectangle(cornerRadius: 34, style: .continuous),
            allowsStaticGlass: true,
            chrome: true
        )
        .shadow(color: .black.opacity(0.17), radius: 24, y: 10)
        .animation(panelAnimation, value: panelDetent)
        .animation(panelAnimation, value: activeTab)
        .animation(panelAnimation, value: selectedPlace?.id)
    }

    private func panelHandle(heights: ZiyaratPanelHeights) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.42))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(panelDragGesture(heights: heights))
        .accessibilityLabel(panelResizeLabel)
    }

    private var panelBody: some View {
        ZStack(alignment: .topLeading) {
            if let selectedPlace {
                ZiyaratPlacePanelContent(
                    place: selectedPlace,
                    totalStops: orderedPlaces.count,
                    expanded: panelDetent == .expanded,
                    language: settings.language,
                    onClose: {
                        withAnimation(panelAnimation) { self.selectedPlace = nil }
                        fitEntireRoute(animated: true)
                    },
                    onExpand: {
                        withAnimation(panelAnimation) { panelDetent = .expanded }
                    },
                    onOpenMaps: { openInMaps(selectedPlace) }
                )
                .id("place-\(selectedPlace.id)-\(panelDetent == .expanded)")
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                switch activeTab {
                case .journey:
                    journeyPanel
                        .id("journey")
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                case .places:
                    placesPanel
                        .id("places")
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                case .route:
                    routePanel
                        .id("route")
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                case .map:
                    mapPanel
                        .id("map")
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
        }
        .animation(panelAnimation, value: activeTab)
        .animation(panelAnimation, value: selectedPlace?.id)
    }

    private var journeyPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iumrah Ziyarats")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(routeTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(-0.7)
                    Text(routeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 0) {
                    journeyMetric(icon: "mappin.and.ellipse", value: "\(orderedPlaces.count)", label: stopsLabel)
                    Divider().frame(height: 40)
                    journeyMetric(icon: "clock", value: timeText(route.estimatedMinutes), label: totalTimeLabel)
                    Divider().frame(height: 40)
                    journeyMetric(icon: "car.fill", value: transportLabel, label: routeLabel)
                }

                if let first = orderedPlaces.first {
                    Button {
                        select(first)
                    } label: {
                        ZiyaratJourneyNextStopRow(
                            place: first,
                            title: first.localizedContent(locale: settings.language.rawValue).title,
                            eyebrow: firstStopLabel,
                            durationText: durationText(first.durationMinutes)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    selectedPlace = nil
                    activeTab = .route
                    withAnimation(panelAnimation) { panelDetent = .medium }
                    fitEntireRoute(animated: true)
                } label: {
                    Label(showRouteLabel, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    private var placesPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                panelSectionHeader(title: placesTitle, subtitle: "\(orderedPlaces.count) \(stopsLabel)")
                    .padding(.bottom, 8)

                ForEach(Array(orderedPlaces.enumerated()), id: \.offset) { index, place in
                    Button { select(place) } label: {
                        ZiyaratPlaceListRow(
                            place: place,
                            content: place.localizedContent(locale: settings.language.rawValue),
                            visitText: visitType(place.visitType),
                            durationText: durationText(place.durationMinutes)
                        )
                    }
                    .buttonStyle(.plain)

                    if index < orderedPlaces.count - 1 {
                        Divider().padding(.leading, 90)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    private var routePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    panelSectionHeader(title: itineraryTitle, subtitle: routeSubtitle)
                    Spacer(minLength: 8)
                    if loadingRoute {
                        ProgressView().controlSize(.small)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(orderedPlaces.enumerated()), id: \.offset) { index, place in
                        Button { select(place) } label: {
                            ZiyaratRouteStepRow(
                                place: place,
                                title: place.localizedContent(locale: settings.language.rawValue).title,
                                subtitle: place.localizedContent(locale: settings.language.rawValue).shortDescription,
                                duration: durationText(place.durationMinutes),
                                isLast: index == orderedPlaces.count - 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    fitEntireRoute(animated: true)
                    withAnimation(panelAnimation) { panelDetent = .collapsed }
                } label: {
                    Label(showOnMapLabel, systemImage: "map.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    private var mapPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                panelSectionHeader(title: mapModesTitle, subtitle: mapModesSubtitle)

                HStack(spacing: 12) {
                    mapModeChoice(.standard, title: standardMapTitle, icon: "map.fill")
                    mapModeChoice(.satellite, title: satelliteMapTitle, icon: "globe.americas.fill")
                }

                VStack(spacing: 0) {
                    Toggle(isOn: $showRouteLine) {
                        Label(routeLineTitle, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .tint(Color(uiColor: .systemBlue))
                    .padding(.vertical, 12)

                    Divider()

                    Toggle(isOn: $showPlacePins) {
                        Label(placePinsTitle, systemImage: "mappin.circle.fill")
                    }
                    .tint(Color(uiColor: .systemBlue))
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 14)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    fitEntireRoute(animated: true)
                    withAnimation(panelAnimation) { panelDetent = .collapsed }
                } label: {
                    Label(fitRouteLabel, systemImage: "scope")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: false))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    private func mapModeChoice(_ mode: ZiyaratMapMode, title: String, icon: String) -> some View {
        Button {
            IumrahHaptics.selection()
            withAnimation(.easeInOut(duration: 0.28)) { mapMode = mode }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer()
                    if mapMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(uiColor: .systemBlue))
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(mapMode == mode ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.07), lineWidth: mapMode == mode ? 2 : 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private func panelTabBar(safeBottom: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(ZiyaratPanelTab.allCases) { tab in
                Button {
                    selectTab(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: activeTab == tab ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)
                        Text(tabTitle(tab))
                            .font(.system(size: 10.5, weight: activeTab == tab ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .foregroundStyle(activeTab == tab ? Color(uiColor: .systemBlue) : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, max(2, safeBottom - 2))
        .frame(minHeight: 70 + max(0, safeBottom - 2))
    }

    private func panelSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title2.bold())
                .tracking(-0.25)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func journeyMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(value).lineLimit(1).minimumScaleFactor(0.75)
            }
            .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Interaction

    private func select(_ place: ZiyaratPlace) {
        IumrahHaptics.selection()
        selectedPlace = place
        activeTab = .places
        withAnimation(panelAnimation) { panelDetent = .medium }
        focus(on: place, animated: true)
    }

    private func selectTab(_ tab: ZiyaratPanelTab) {
        IumrahHaptics.selection()
        let sameTab = activeTab == tab && selectedPlace == nil
        selectedPlace = nil
        activeTab = tab

        withAnimation(panelAnimation) {
            if sameTab && panelDetent == .medium {
                panelDetent = .collapsed
            } else {
                panelDetent = .medium
            }
        }

        if tab == .route {
            fitEntireRoute(animated: true)
        }
    }

    private func panelDragGesture(heights: ZiyaratPanelHeights) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .updating($panelDragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let current = targetPanelHeight(heights: heights)
                let projected = current - value.predictedEndTranslation.height
                let targets: [(ZiyaratPanelDetent, CGFloat)] = [
                    (.collapsed, heights.collapsed),
                    (.medium, heights.medium),
                    (.expanded, heights.expanded)
                ]
                let nearest = targets.min { abs($0.1 - projected) < abs($1.1 - projected) }?.0 ?? .medium
                IumrahHaptics.selection()
                withAnimation(panelAnimation) { panelDetent = nearest }
            }
    }

    private func panelHeights(totalHeight: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) -> ZiyaratPanelHeights {
        let collapsed = 92 + max(0, safeBottom - 2)
        let maximumMedium = max(collapsed + 170, totalHeight - safeTop - 126)
        let desiredMedium = max(collapsed + 230, totalHeight * 0.52)
        let medium = min(desiredMedium, maximumMedium)
        let expanded = min(totalHeight - 4, max(medium + 90, totalHeight - safeTop - 8))
        return ZiyaratPanelHeights(collapsed: collapsed, medium: medium, expanded: expanded)
    }

    private func targetPanelHeight(heights: ZiyaratPanelHeights) -> CGFloat {
        switch panelDetent {
        case .collapsed: return heights.collapsed
        case .medium: return heights.medium
        case .expanded: return heights.expanded
        }
    }

    private func livePanelHeight(heights: ZiyaratPanelHeights) -> CGFloat {
        let target = targetPanelHeight(heights: heights)
        return min(heights.expanded, max(heights.collapsed, target - panelDragTranslation))
    }

    private func focus(on place: ZiyaratPlace, animated: Bool) {
        // Shift the map center slightly south so the exact coordinate remains
        // visible above the persistent lower panel instead of being hidden by it.
        let shift: Double
        switch panelDetent {
        case .collapsed: shift = 0.0010
        case .medium: shift = 0.0042
        case .expanded: shift = 0.0075
        }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude - shift, longitude: place.longitude),
            span: MKCoordinateSpan(latitudeDelta: panelDetent == .expanded ? 0.022 : 0.015, longitudeDelta: panelDetent == .expanded ? 0.022 : 0.015)
        )
        if animated {
            withAnimation(cameraAnimation) { camera = .region(region) }
        } else {
            camera = .region(region)
        }
    }

    private func fitEntireRoute(animated: Bool) {
        guard !orderedPlaces.isEmpty else { return }
        let target = Self.region(for: orderedPlaces)
        if animated {
            withAnimation(cameraAnimation) { camera = .region(target) }
        } else {
            camera = .region(target)
        }
    }

    private func openInMaps(_ place: ZiyaratPlace) {
        let content = place.localizedContent(locale: settings.language.rawValue)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = content.title
        item.openInMaps()
    }

    // MARK: Loading / welcome

    @MainActor
    private func loadJourney() async {
        loadingCatalog = true
        let live = await ZiyaratService.shared.route(city: "Madinah")
        route = live
        camera = .region(Self.region(for: live.places))
        loadingCatalog = false

        loadingRoute = true
        polylines = await ZiyaratRouteService.shared.roadPolylines(for: live.places)
        loadingRoute = false

        await playWelcomeSequence(stopCount: live.places.count)
    }

    @MainActor
    private func playWelcomeSequence(stopCount: Int) async {
        if reduceMotion {
            welcomeCopyVisible = true
            revealedStopCount = stopCount
            try? await Task.sleep(for: .milliseconds(650))
            welcomeVisible = false
            return
        }

        withAnimation(.easeOut(duration: 0.38)) { welcomeCopyVisible = true }
        try? await Task.sleep(for: .milliseconds(240))

        if stopCount > 0 {
            for index in 1...stopCount {
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    revealedStopCount = index
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(820))
        withAnimation(.easeInOut(duration: 0.48)) { welcomeVisible = false }
    }

    private static func region(for places: [ZiyaratPlace]) -> MKCoordinateRegion {
        guard !places.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 24.4672, longitude: 39.6111),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        }

        let lats = places.map(\.latitude)
        let lons = places.map(\.longitude)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2 - 0.003,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.035, (maxLat - minLat) * 1.65),
                longitudeDelta: max(0.035, (maxLon - minLon) * 1.65)
            )
        )
    }

    private var emptyOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.title2)
            Text(noPlacesTitle).font(.headline)
            Text(noPlacesSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .iumrahGlass(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            allowsStaticGlass: true,
            chrome: true
        )
    }

    // MARK: Localized UI copy

    private var routeTitle: String { localized("Зиярат Медины", "Medina Ziyarat", "Madina ziyorati", "Мадина зиёрати") }
    private var cityTitle: String { localized("Медина", "Madinah", "Madina", "Мадина") }
    private var routeSubtitle: String { localized("Священные и исторические места в одной поездке", "Sacred and historic places in one journey", "Muqaddas va tarixiy joylar bitta yo‘nalishda", "Муқаддас ва тарихий жойлар битта йўналишда") }
    private var welcomePretitle: String { localized("Добро пожаловать в", "Welcome to", "Xush kelibsiz", "Хуш келибсиз") }
    private var stopsLabel: String { localized("мест", "stops", "joy", "жой") }
    private var totalTimeLabel: String { localized("всего", "total", "jami", "жами") }
    private var transportLabel: String { localized("Авто", "Car", "Avto", "Авто") }
    private var routeLabel: String { localized("поездка", "journey", "sayohat", "саёҳат") }
    private var firstStopLabel: String { localized("Первая остановка", "First stop", "Birinchi bekat", "Биринчи бекат") }
    private var showRouteLabel: String { localized("Показать маршрут", "Show route", "Yo‘nalishni ko‘rsatish", "Йўналишни кўрсатиш") }
    private var showOnMapLabel: String { localized("Показать на карте", "Show on map", "Xaritada ko‘rsatish", "Харитада кўрсатиш") }
    private var placesTitle: String { localized("Все места", "All places", "Barcha joylar", "Барча жойлар") }
    private var itineraryTitle: String { localized("Маршрут зиярата", "Ziyarat route", "Ziyorat yo‘nalishi", "Зиёрат йўналиши") }
    private var mapModesTitle: String { localized("Режим карты", "Map mode", "Xarita rejimi", "Харита режими") }
    private var mapModesSubtitle: String { localized("Выберите вид карты и то, что показывать", "Choose the map view and what to display", "Xarita ko‘rinishi va ko‘rsatiladigan ma’lumotlarni tanlang", "Харита кўриниши ва кўрсатиладиган маълумотларни танланг") }
    private var standardMapTitle: String { localized("Стандарт", "Standard", "Standart", "Стандарт") }
    private var satelliteMapTitle: String { localized("Спутник", "Satellite", "Sun’iy yo‘ldosh", "Сунъий йўлдош") }
    private var routeLineTitle: String { localized("Линия маршрута", "Route line", "Yo‘nalish chizig‘i", "Йўналиш чизиғи") }
    private var placePinsTitle: String { localized("Метки мест", "Place markers", "Joy belgilari", "Жой белгилари") }
    private var fitRouteLabel: String { localized("Показать весь маршрут", "Fit entire route", "Butun yo‘nalishni ko‘rsatish", "Бутун йўналишни кўрсатиш") }
    private var mapModeLabel: String { localized("Режим карты", "Map mode", "Xarita rejimi", "Харита режими") }
    private var closeLabel: String { localized("Закрыть", "Close", "Yopish", "Ёпиш") }
    private var panelResizeLabel: String { localized("Изменить размер панели", "Resize panel", "Panel o‘lchamini o‘zgartirish", "Панель ўлчамини ўзгартириш") }
    private var noPlacesTitle: String { localized("Пока нет мест", "No places yet", "Hozircha joylar yo‘q", "Ҳозирча жойлар йўқ") }
    private var noPlacesSubtitle: String { localized("Опубликованные в iumrah Business точки появятся здесь автоматически.", "Places published in iumrah Business will appear here automatically.", "iumrah Business’da chop etilgan joylar bu yerda avtomatik paydo bo‘ladi.", "iumrah Business’да чоп этилган жойлар бу ерда автоматик пайдо бўлади.") }

    private func tabTitle(_ tab: ZiyaratPanelTab) -> String {
        switch tab {
        case .journey: return localized("Поездка", "Journey", "Sayohat", "Саёҳат")
        case .places: return localized("Места", "Places", "Joylar", "Жойлар")
        case .route: return localized("Маршрут", "Route", "Yo‘nalish", "Йўналиш")
        case .map: return localized("Карта", "Map", "Xarita", "Харита")
        }
    }

    private func timeText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        if minutes >= 60 {
            let hours = max(1, minutes / 60)
            let remainder = minutes % 60
            if remainder >= 15 {
                return localized("~\(hours) ч \(remainder) мин", "~\(hours)h \(remainder)m", "~\(hours) soat \(remainder) daq", "~\(hours) соат \(remainder) дақ")
            }
            return localized("~\(hours) ч", "~\(hours)h", "~\(hours) soat", "~\(hours) соат")
        }
        return durationText(minutes)
    }

    private func durationText(_ minutes: Int) -> String {
        localized("\(minutes) мин", "\(minutes) min", "\(minutes) daq", "\(minutes) дақ")
    }

    private func visitType(_ raw: String) -> String {
        switch raw {
        case "enter": return localized("Заходим", "Enter", "Kiramiz", "Кирамиз")
        case "view": return localized("Осмотр", "View", "Ko‘ramiz", "Кўрамиз")
        case "pass": return localized("Проездом", "Pass by", "Yo‘lda", "Йўлда")
        default: return localized("Остановка", "Stop", "To‘xtash", "Тўхташ")
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

// MARK: - Panel state

private enum ZiyaratPanelDetent: Equatable {
    case collapsed
    case medium
    case expanded
}

private struct ZiyaratPanelHeights {
    let collapsed: CGFloat
    let medium: CGFloat
    let expanded: CGFloat
}

private enum ZiyaratPanelTab: String, CaseIterable, Identifiable {
    case journey
    case places
    case route
    case map

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .journey: return "figure.walk"
        case .places: return "square.grid.2x2.fill"
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .map: return "map.fill"
        }
    }
}

private enum ZiyaratMapMode: Equatable {
    case standard
    case satellite
}

// MARK: - Welcome

private struct ZiyaratWelcomeOverlay: View {
    let pretitle: String
    let title: String
    let city: String
    let copyVisible: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Text(pretitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                Text(title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1.1)
                    .foregroundStyle(.white)
                Text(city)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 2)
            }
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.32), radius: 18, y: 8)
            .opacity(copyVisible ? 1 : 0)
            .scaleEffect(copyVisible ? 1 : 0.97)
        }
    }
}

// MARK: - Map pin

private struct ZiyaratMapPin: View {
    let number: Int
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            if isSelected {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 31)
                    .iumrahGlass(in: Capsule(), allowsStaticGlass: true, chrome: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            VStack(spacing: -2) {
                Text("\(number)")
                    .font(.system(size: isSelected ? 15 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: isSelected ? 40 : 33, height: isSelected ? 40 : 33)
                    .background(isSelected ? Color(uiColor: .systemBlue) : Color.black.opacity(0.84), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.96), lineWidth: isSelected ? 3 : 2.5))
                    .shadow(color: .black.opacity(0.27), radius: 8, y: 4)

                Image(systemName: "triangle.fill")
                    .font(.system(size: isSelected ? 8 : 7))
                    .rotationEffect(.degrees(180))
                    .foregroundStyle(isSelected ? Color(uiColor: .systemBlue) : Color.black.opacity(0.84))
            }
        }
        .animation(.spring(response: 0.33, dampingFraction: 0.78), value: isSelected)
    }
}

// MARK: - Journey content

private struct ZiyaratJourneyNextStopRow: View {
    let place: ZiyaratPlace
    let title: String
    let eyebrow: String
    let durationText: String

    var body: some View {
        HStack(spacing: 13) {
            ZiyaratImageView(image: place.images.first)
                .frame(width: 78, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("\(place.routeOrder)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 23, height: 23)
                        .background(Color.black.opacity(0.78), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                        .padding(6)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Label(durationText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ZiyaratPlaceListRow: View {
    let place: ZiyaratPlace
    let content: ZiyaratPlaceTranslation
    let visitText: String
    let durationText: String

    var body: some View {
        HStack(spacing: 13) {
            ZiyaratImageView(image: place.images.first)
                .frame(width: 70, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("\(place.routeOrder)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.80), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.4))
                        .padding(5)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(content.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !place.titleArabic.isEmpty {
                    Text(place.titleArabic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(content.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label(visitText, systemImage: visitIcon(place.visitType))
                    Label(durationText, systemImage: "clock")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func visitIcon(_ raw: String) -> String {
        raw == "pass" ? "car.fill" : raw == "view" ? "eye.fill" : "figure.walk"
    }
}

private struct ZiyaratRouteStepRow: View {
    let place: ZiyaratPlace
    let title: String
    let subtitle: String
    let duration: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Text("\(place.routeOrder)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.86), in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.30))
                        .frame(width: 2, height: 54)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(duration)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !place.titleArabic.isEmpty {
                    Text(place.titleArabic)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 3)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Place details inside the persistent panel

private struct ZiyaratPlacePanelContent: View {
    let place: ZiyaratPlace
    let totalStops: Int
    let expanded: Bool
    let language: AppSettingsStore.Language
    let onClose: () -> Void
    let onExpand: () -> Void
    let onOpenMaps: () -> Void

    @State private var selectedImage = 0

    private var content: ZiyaratPlaceTranslation {
        place.localizedContent(locale: language.rawValue)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                placeToolbar
                gallery
                placeHeader
                metadata

                Text(content.shortDescription)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                if expanded {
                    Divider().padding(.vertical, 2)
                    infoSection(title: localized("Подробнее", "Details", "Batafsil", "Батафсил"), body: content.longDescription)

                    if !content.interestingFacts.isEmpty {
                        factsSection
                    }

                    if !content.visitNotes.isEmpty {
                        infoSection(title: localized("Посещение", "Visit", "Tashrif", "Ташриф"), body: content.visitNotes)
                    }

                    exactPointSection
                } else {
                    Button(action: onExpand) {
                        Label(localized("Подробнее", "More details", "Batafsil", "Батафсил"), systemImage: "chevron.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: false))
                }

                Button(action: onOpenMaps) {
                    Label(localized("Открыть точную точку", "Open exact point", "Aniq nuqtani ochish", "Аниқ нуқтани очиш"), systemImage: "location.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var placeToolbar: some View {
        HStack {
            Text(localized("Остановка \(place.routeOrder) из \(max(totalStops, 1))", "Stop \(place.routeOrder) of \(max(totalStops, 1))", "\(place.routeOrder) / \(max(totalStops, 1)) bekat", "\(place.routeOrder) / \(max(totalStops, 1)) бекат"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color.iumrahRaisedBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("Закрыть место", "Close place", "Joy ma’lumotini yopish", "Жой маълумотини ёпиш"))
        }
    }

    private var gallery: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                if place.images.isEmpty {
                    ZiyaratImageView(image: nil)
                        .frame(height: expanded ? 260 : 190)
                } else {
                    TabView(selection: $selectedImage) {
                        ForEach(Array(place.images.prefix(5).enumerated()), id: \.offset) { index, image in
                            ZiyaratImageView(image: image)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: expanded ? 260 : 190)
                }

                if !place.images.isEmpty {
                    Text("\(min(selectedImage + 1, place.images.count)) / \(min(place.images.count, 5))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 27)
                        .background(Color.black.opacity(0.52), in: Capsule())
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            if place.images.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(place.images.prefix(5).enumerated()), id: \.offset) { index, image in
                            Button {
                                withAnimation(.easeInOut(duration: 0.24)) { selectedImage = index }
                            } label: {
                                ZiyaratImageView(image: image)
                                    .frame(width: 62, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selectedImage == index ? Color(uiColor: .systemBlue) : Color.clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: expanded)
    }

    private var placeHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(content.title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.65)
            if !place.titleArabic.isEmpty {
                Text(place.titleArabic)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metadata: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                metaCapsule(icon: visitIcon(place.visitType), text: visitType(place.visitType))
                metaCapsule(icon: "clock", text: localized("\(place.durationMinutes) мин", "\(place.durationMinutes) min", "\(place.durationMinutes) daq", "\(place.durationMinutes) дақ"))
                metaCapsule(icon: categoryIcon(place.category), text: categoryTitle(place.category))
            }
        }
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Что интересно здесь", "What’s interesting here", "Bu yerda nimalar qiziq", "Бу ерда нималар қизиқ"))
                .font(.title3.bold())

            VStack(spacing: 0) {
                ForEach(Array(content.interestingFacts.enumerated()), id: \.offset) { index, fact in
                    HStack(alignment: .top, spacing: 11) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.iumrahRaisedBackground, in: Circle())
                        Text(fact)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)

                    if index < content.interestingFacts.count - 1 {
                        Divider().padding(.leading, 35)
                    }
                }
            }
        }
    }

    private var exactPointSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("Точная точка", "Exact point", "Aniq nuqta", "Аниқ нуқта"))
                        .font(.title3.bold())
                    Text(place.mapLabel.isEmpty ? place.address : place.mapLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Image(systemName: "scope")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color(uiColor: .systemBlue))
                Text(localized("Координаты", "Coordinates", "Koordinatalar", "Координаталар"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(13)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func infoSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.title3.bold())
            Text(body)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaCapsule(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.iumrahRaisedBackground, in: Capsule())
            .lineLimit(1)
    }

    private func visitType(_ raw: String) -> String {
        switch raw {
        case "enter": return localized("Заходим", "Enter", "Kiramiz", "Кирамиз")
        case "view": return localized("Осмотр", "View", "Ko‘ramiz", "Кўрамиз")
        case "pass": return localized("Проездом", "Pass by", "Yo‘lda", "Йўлда")
        default: return localized("Остановка", "Stop", "To‘xtash", "Тўхташ")
        }
    }

    private func visitIcon(_ raw: String) -> String {
        raw == "pass" ? "car.fill" : raw == "view" ? "eye.fill" : "figure.walk"
    }

    private func categoryTitle(_ raw: String) -> String {
        switch raw {
        case "mosque": return localized("Мечеть", "Mosque", "Masjid", "Масжид")
        case "mountain": return localized("Гора", "Mountain", "Tog‘", "Тоғ")
        case "garden": return localized("Сад", "Garden", "Bog‘", "Боғ")
        case "cemetery": return localized("Кладбище", "Cemetery", "Qabriston", "Қабристон")
        case "restaurant": return localized("Ресторан", "Restaurant", "Restoran", "Ресторан")
        case "beach": return localized("Море", "Sea", "Dengiz", "Денгиз")
        case "picnic": return localized("Пикник", "Picnic", "Piknik", "Пикник")
        case "museum": return localized("Музей", "Museum", "Muzey", "Музей")
        default: return localized("Место", "Place", "Joy", "Жой")
        }
    }

    private func categoryIcon(_ raw: String) -> String {
        switch raw {
        case "mosque": return "building.columns.fill"
        case "mountain": return "mountain.2.fill"
        case "garden": return "tree.fill"
        case "cemetery": return "leaf.fill"
        case "restaurant": return "fork.knife"
        case "beach": return "water.waves"
        case "picnic": return "basket.fill"
        case "museum": return "building.2.fill"
        default: return "mappin.and.ellipse"
        }
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}

// MARK: - Native capsule buttons

private struct ZiyaratNativeCapsuleButtonModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            } else {
                content
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            }
        } else {
            if prominent {
                content
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            } else {
                content
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Color(uiColor: .systemBlue))
            }
        }
    }
}

// MARK: - Shared image renderer

struct ZiyaratImageView: View {
    let image: ZiyaratImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.iumrahRaisedBackground)

            if let image, let asset = image.bundledAssetName {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else if let image, let url = AppConfig.absoluteURL(image.url) {
                AsyncImage(url: url) { phase in
                    if let loaded = phase.image {
                        loaded.resizable().scaledToFill()
                    } else if phase.error != nil, let fallback = fallbackAsset(for: image.id) {
                        Image(fallback).resizable().scaledToFill()
                    } else {
                        ProgressView()
                    }
                }
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
    }

    private func fallbackAsset(for id: String) -> String? {
        guard id.hasPrefix("quba-") else { return nil }
        let number = id.replacingOccurrences(of: "quba-", with: "")
        return "ZiyaratQuba\(number)"
    }
}
