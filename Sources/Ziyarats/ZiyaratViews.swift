import SwiftUI
import MapKit
import UIKit

// MARK: - iumrah Ziyarats
//
// Map-first experience inspired by Apple Maps / Find My. The map is the permanent
// spatial scene and the Ziyarats chrome lives in one floating bottom surface. The
// surface has three physical states and follows the finger continuously; only the
// final snap is spring-animated. This avoids the rectangular host surface and the
// sheet hand-off visible in the previous implementation.

struct ZiyaratJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore

    @State private var route = ZiyaratSeedData.medina
    @State private var selectedPlace: ZiyaratPlace?
    @State private var activeTab: ZiyaratPanelTab = .journey

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

    @State private var panelVisible = false
    @State private var panelLevel: ZiyaratPanelLevel = .compact
    @GestureState private var panelDrag: CGFloat = 0
    @State private var closing = false
    @Namespace private var glassNamespace

    private var orderedPlaces: [ZiyaratPlace] {
        route.places.sorted { $0.routeOrder < $1.routeOrder }
    }

    private var isCompactPanel: Bool { panelLevel == .compact }
    private var isExpandedPanel: Bool { panelLevel == .full }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                mapScene
                    .ignoresSafeArea()

                mapChrome

                if orderedPlaces.isEmpty && !loadingCatalog {
                    emptyOverlay
                        .padding(.horizontal, 24)
                        .zIndex(5)
                }

                if panelVisible && !welcomeVisible {
                    panelDrawer(in: proxy)
                        .zIndex(15)

                    ziyaratsSystemTabBar(in: proxy)
                        .zIndex(18)
                }

                if welcomeVisible {
                    ZiyaratWelcomeOverlay(
                        pretitle: welcomePretitle,
                        title: "iumrah Ziyarats",
                        city: cityTitle,
                        copyVisible: welcomeCopyVisible
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            chrome.setImmersive(true)
        }
        .onDisappear {
            if !closing { chrome.setImmersive(false) }
        }
        .task {
            await loadJourney()
            await playWelcomeSequence()
        }
        .onChange(of: panelLevel) { _, _ in
            guard let selectedPlace else { return }
            focus(on: selectedPlace, animated: true)
        }
    }

    // MARK: Map

    @ViewBuilder
    private var mapScene: some View {
        switch mapMode {
        case .standard:
            mapContent
                .mapStyle(.standard(
                    elevation: .realistic,
                    emphasis: .muted,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                ))
        case .satellite:
            mapContent
                .mapStyle(.imagery(elevation: .realistic))
        }
    }

    private var mapContent: some View {
        Map(position: $camera) {
            if showRouteLine {
                ForEach(Array(polylines.enumerated()), id: \.offset) { _, polyline in
                    MapPolyline(polyline)
                        .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
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
                            .scaleEffect(!welcomeVisible || index < revealedStopCount ? 1 : 0.76)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(place.localizedContent(locale: settings.language.rawValue).title)
                    }
                }
            }
        }
    }

    private var mapChrome: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                ZiyaratNativeGlassIconButton(
                    systemName: "xmark",
                    accessibilityLabel: closeLabel,
                    action: closeZiyarats
                )

                Spacer()

                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) {
                            ZiyaratNativeGlassIconButton(
                                systemName: mapMode == .standard ? "map.fill" : "globe.americas.fill",
                                foreground: activeTab == .map ? Color(uiColor: .systemBlue) : nil,
                                accessibilityLabel: mapModeLabel
                            ) {
                                selectedPlace = nil
                                activeTab = .map
                                setPanel(.card)
                            }

                            ZiyaratNativeGlassIconButton(
                                systemName: "scope",
                                accessibilityLabel: fitRouteLabel
                            ) {
                                fitEntireRoute(animated: true)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        ZiyaratNativeGlassIconButton(
                            systemName: mapMode == .standard ? "map.fill" : "globe.americas.fill",
                            foreground: activeTab == .map ? Color(uiColor: .systemBlue) : nil,
                            accessibilityLabel: mapModeLabel
                        ) {
                            selectedPlace = nil
                            activeTab = .map
                            setPanel(.card)
                        }

                        ZiyaratNativeGlassIconButton(
                            systemName: "scope",
                            accessibilityLabel: fitRouteLabel
                        ) {
                            fitEntireRoute(animated: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isExpandedPanel ? 0 : 1)
        .allowsHitTesting(!isExpandedPanel && !welcomeVisible)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isExpandedPanel)
        .zIndex(10)
    }

    // MARK: Native Ziyarats chrome

    /// The panel keeps one fixed layout size and moves vertically, like a UIKit sheet.
    /// We do not resize/re-layout the image-heavy body on every drag frame.
    private func panelDrawer(in proxy: GeometryProxy) -> some View {
        let tabBarClearance = ZiyaratSystemTabBar.preferredHeight - 2
        let metrics = ZiyaratPanelMetrics(containerHeight: max(420, proxy.size.height - tabBarClearance + 8))
        let targetVisibleHeight = metrics.height(for: panelLevel)
        let liveVisibleHeight = metrics.rubberBandedHeight(targetVisibleHeight - panelDrag)
        let yOffset = metrics.fullHeight - liveVisibleHeight
        let bodyProgress = metrics.bodyProgress(for: liveVisibleHeight)

        let panel = VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 28)

                Capsule()
                    .fill(Color.secondary.opacity(0.40))
                    .frame(width: 36, height: 5)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isCompactPanel { setPanel(.card) }
                else if isExpandedPanel { setPanel(.card) }
                else { setPanel(.full) }
            }
            .gesture(panelGesture(metrics: metrics))

            panelBody
                .id(panelContentID)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .opacity(bodyProgress)
                .allowsHitTesting(panelLevel != .compact && bodyProgress > 0.88)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.fullHeight)
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

        return Group {
            if #available(iOS 26.0, *) {
                panel
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .glassEffectID("ziyarats-panel", in: glassNamespace)
                    .glassEffectTransition(.materialize)
            } else {
                // Older iOS gets a solid adaptive surface, never a fake blur/material.
                panel
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
                    }
            }
        }
        .padding(.horizontal, 7)
        .padding(.bottom, tabBarClearance)
        .offset(y: yOffset)
        .transaction { transaction in
            if panelDrag != 0 { transaction.animation = nil }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: activeTab)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: selectedPlace?.id)
        .accessibilityElement(children: .contain)
    }

    private func ziyaratsSystemTabBar(in proxy: GeometryProxy) -> some View {
        let safeBottom = proxy.safeAreaInsets.bottom
        return ZiyaratSystemTabBar(
            selection: activeTab,
            items: ZiyaratPanelTab.allCases.map { tab in
                .init(tab: tab, title: tabTitle(tab), systemImage: tab.icon)
            },
            onSelection: { tab, reselected in
                if reselected {
                    selectTab(tab)
                } else {
                    selectTab(tab)
                }
            }
        )
        .frame(height: ZiyaratSystemTabBar.preferredHeight + safeBottom)
        .padding(.horizontal, 5)
        .padding(.bottom, -safeBottom)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(!welcomeVisible)
    }

    private var panelContentID: String {
        if let selectedPlace { return "place-\(selectedPlace.id)" }
        return "tab-\(activeTab.rawValue)"
    }

    private func panelGesture(metrics: ZiyaratPanelMetrics) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .updating($panelDrag) { value, state, _ in
                guard abs(value.translation.height) >= abs(value.translation.width) * 0.62 else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard abs(value.translation.height) >= abs(value.translation.width) * 0.62 else { return }
                let currentVisibleHeight = metrics.height(for: panelLevel)
                let projectedVisibleHeight = currentVisibleHeight - value.predictedEndTranslation.height
                let target = metrics.level(forProjectedHeight: projectedVisibleHeight, current: panelLevel)
                if target != panelLevel { IumrahHaptics.selection() }
                setPanel(target)
            }
    }

    private var panelBody: some View {
        Group {
            if let selectedPlace {
                ZiyaratPlacePanelContent(
                    place: selectedPlace,
                    totalStops: orderedPlaces.count,
                    expanded: isExpandedPanel,
                    language: settings.language,
                    onClose: {
                        IumrahHaptics.selection()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            self.selectedPlace = nil
                        }
                        fitEntireRoute(animated: true)
                    },
                    onExpand: { setPanel(.full) },
                    onOpenMaps: { openInMaps(selectedPlace) }
                )
            } else {
                switch activeTab {
                case .journey: journeyPanel
                case .places: placesPanel
                case .route: routePanel
                case .map: mapPanel
                }
            }
        }
    }

    // MARK: Panel pages

    private var journeyPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iumrah Ziyarats")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(routeTitle)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(-0.6)
                        Text(routeSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                }

                HStack(spacing: 0) {
                    journeyMetric(icon: "mappin.and.ellipse", value: "\(orderedPlaces.count)", label: stopsLabel)
                    Divider().frame(height: 38)
                    journeyMetric(icon: "clock", value: timeText(route.estimatedMinutes), label: totalTimeLabel)
                    Divider().frame(height: 38)
                    journeyMetric(icon: "car.fill", value: transportLabel, label: routeLabel)
                }

                if let first = orderedPlaces.first {
                    Button { select(first) } label: {
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
                    fitEntireRoute(animated: true)
                    setPanel(.card)
                } label: {
                    Label(showRouteLabel, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 18)
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
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
    }

    private var routePanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    panelSectionHeader(title: itineraryTitle, subtitle: routeSubtitle)
                    Spacer(minLength: 8)
                    if loadingRoute { ProgressView().controlSize(.small) }
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
                    setPanel(.compact)
                } label: {
                    Label(showOnMapLabel, systemImage: "map.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
    }

    private var mapPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
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
                    setPanel(.compact)
                } label: {
                    Label(fitRouteLabel, systemImage: "scope")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .modifier(ZiyaratNativeCapsuleButtonModifier(prominent: false))
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
    }

    private func mapModeChoice(_ mode: ZiyaratMapMode, title: String, icon: String) -> some View {
        Button {
            IumrahHaptics.selection()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { mapMode = mode }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
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
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(mapMode == mode ? Color(uiColor: .systemBlue) : Color.primary.opacity(0.07), lineWidth: mapMode == mode ? 1.7 : 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private func panelSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title2.bold()).tracking(-0.25)
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
                Text(value).lineLimit(1).minimumScaleFactor(0.72)
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
        setPanel(.card)
        focus(on: place, animated: true)
    }

    private func selectTab(_ tab: ZiyaratPanelTab) {
        IumrahHaptics.selection()
        let wasActive = activeTab == tab && selectedPlace == nil
        selectedPlace = nil
        activeTab = tab

        if tab == .map {
            // The map tab is the "map first" state: selecting it gives the map
            // back almost the whole screen. A second tap opens map controls.
            setPanel(wasActive && isCompactPanel ? .card : .compact)
        } else if wasActive && !isCompactPanel {
            setPanel(.compact)
        } else {
            setPanel(.card)
        }

        if tab == .route { fitEntireRoute(animated: true) }
    }

    private func setPanel(_ level: ZiyaratPanelLevel) {
        guard panelLevel != level else { return }
        if reduceMotion {
            panelLevel = level
        } else {
            withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12)) {
                panelLevel = level
            }
        }
    }

    private func focus(on place: ZiyaratPlace, animated: Bool) {
        let shift: Double
        let span: Double
        if isExpandedPanel {
            shift = 0.0068
            span = 0.021
        } else if isCompactPanel {
            shift = 0.0008
            span = 0.0135
        } else {
            shift = 0.0038
            span = 0.0155
        }

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude - shift, longitude: place.longitude),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )

        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.56)) { camera = .region(region) }
        } else {
            camera = .region(region)
        }
    }

    private func fitEntireRoute(animated: Bool) {
        guard !orderedPlaces.isEmpty else { return }
        let target = Self.region(for: orderedPlaces)
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.56)) { camera = .region(target) }
        } else {
            camera = .region(target)
        }
    }

    private func openInMaps(_ place: ZiyaratPlace) {
        IumrahHaptics.selection()
        let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        item.name = place.localizedContent(locale: settings.language.rawValue).title
        item.openInMaps()
    }

    private func closeZiyarats() {
        guard !closing else { return }
        closing = true
        IumrahHaptics.selection()
        chrome.setImmersive(false)
        if reduceMotion {
            panelVisible = false
            dismiss()
        } else {
            withAnimation(.easeInOut(duration: 0.16)) { panelVisible = false }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(110))
                dismiss()
            }
        }
    }

    // MARK: Loading / intro

    @MainActor
    private func loadJourney() async {
        loadingCatalog = true
        let live = await ZiyaratService.shared.route(city: "Madinah")
        route = live
        camera = .region(Self.region(for: live.places))
        loadingCatalog = false

        if !welcomeVisible { revealedStopCount = live.places.count }

        loadingRoute = true
        Task { @MainActor in
            let lines = await ZiyaratRouteService.shared.roadPolylines(for: live.places)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.28)) { polylines = lines }
            loadingRoute = false
        }
    }

    @MainActor
    private func playWelcomeSequence() async {
        if reduceMotion {
            welcomeCopyVisible = true
            revealedStopCount = orderedPlaces.count
            try? await Task.sleep(for: .milliseconds(450))
            welcomeVisible = false
            panelVisible = true
            panelLevel = .card
            return
        }

        withAnimation(.easeOut(duration: 0.34)) { welcomeCopyVisible = true }
        try? await Task.sleep(for: .milliseconds(260))

        let count = max(orderedPlaces.count, 1)
        for index in 1...count {
            try? await Task.sleep(for: .milliseconds(92))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                revealedStopCount = index
            }
        }

        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.easeInOut(duration: 0.38)) { welcomeVisible = false }
        try? await Task.sleep(for: .milliseconds(90))
        panelLevel = .compact
        withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) { panelVisible = true }
        try? await Task.sleep(for: .milliseconds(190))
        setPanel(.card)
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
                latitude: (minLat + maxLat) / 2 - 0.002,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.033, (maxLat - minLat) * 1.7),
                longitudeDelta: max(0.033, (maxLon - minLon) * 1.7)
            )
        )
    }

    @ViewBuilder
    private var emptyOverlay: some View {
        let content = VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.title2)
            Text(noPlacesTitle).font(.headline)
            Text(noPlacesSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)

        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
                }
        }
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

private enum ZiyaratPanelLevel {
    case compact
    case card
    case full
}

private struct ZiyaratPanelMetrics {
    let compactHeight: CGFloat
    let cardHeight: CGFloat
    let fullHeight: CGFloat

    init(containerHeight: CGFloat) {
        compactHeight = 0
        cardHeight = min(372, max(316, containerHeight * 0.43))
        fullHeight = max(cardHeight + 170, containerHeight - 6)
    }

    func height(for level: ZiyaratPanelLevel) -> CGFloat {
        switch level {
        case .compact: return compactHeight
        case .card: return cardHeight
        case .full: return fullHeight
        }
    }

    func bodyProgress(for height: CGFloat) -> Double {
        let distance = max(1, cardHeight - compactHeight)
        return Double(min(1, max(0, (height - 18) / min(108, distance))))
    }

    func rubberBandedHeight(_ proposed: CGFloat) -> CGFloat {
        if proposed < compactHeight {
            return compactHeight - rubberBand(compactHeight - proposed)
        }
        if proposed > fullHeight {
            return fullHeight + rubberBand(proposed - fullHeight)
        }
        return proposed
    }

    func level(forProjectedHeight projected: CGFloat, current: ZiyaratPanelLevel) -> ZiyaratPanelLevel {
        let lowerMid = (compactHeight + cardHeight) / 2
        let upperMid = (cardHeight + fullHeight) / 2

        // A small directional bias makes quick flicks feel like the system sheet
        // without making slow positioning unpredictable.
        switch current {
        case .compact:
            if projected > upperMid { return .full }
            return projected > lowerMid - 18 ? .card : .compact
        case .card:
            if projected < lowerMid + 12 { return .compact }
            if projected > upperMid - 12 { return .full }
            return .card
        case .full:
            if projected < lowerMid { return .compact }
            return projected < upperMid + 18 ? .card : .full
        }
    }

    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        // Diminishing resistance close to UIScrollView/UISheet overscroll.
        let c: CGFloat = 0.36
        return (1 - (1 / ((distance * c / 120) + 1))) * 120
    }
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


private struct ZiyaratNativeGlassIconButton: View {
    let systemName: String
    var foreground: Color? = nil
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button {
                    IumrahHaptics.selection()
                    action()
                } label: {
                    Image(systemName: systemName)
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(foreground ?? Color.primary)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            } else {
                Button {
                    IumrahHaptics.selection()
                    action()
                } label: {
                    Image(systemName: systemName)
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(foreground ?? Color.primary)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A real UIKit tab bar. On iOS 26 the system owns the Liquid Glass compositor,
/// selection lens, touch response, haptics, and accessibility. No custom blur,
/// material, opacity or painted tab background is applied here.
private struct ZiyaratSystemTabBar: UIViewRepresentable {
    static let preferredHeight: CGFloat = 62

    struct Item: Equatable {
        let tab: ZiyaratPanelTab
        let title: String
        let systemImage: String
    }

    let selection: ZiyaratPanelTab
    let items: [Item]
    let onSelection: (ZiyaratPanelTab, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITabBar {
        let tabBar = UITabBar(frame: .zero)
        tabBar.delegate = context.coordinator
        tabBar.isTranslucent = true
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .secondaryLabel
        tabBar.itemPositioning = .fill
        configure(tabBar)
        return tabBar
    }

    func updateUIView(_ tabBar: UITabBar, context: Context) {
        context.coordinator.parent = self
        configure(tabBar)
    }

    private func configure(_ tabBar: UITabBar) {
        if tabBar.items?.count != items.count {
            tabBar.items = items.enumerated().map { index, item in
                let barItem = UITabBarItem(
                    title: item.title,
                    image: UIImage(systemName: item.systemImage),
                    selectedImage: UIImage(systemName: item.systemImage)
                )
                barItem.tag = index
                return barItem
            }
        } else {
            for (index, item) in items.enumerated() {
                guard let barItem = tabBar.items?[safe: index] else { continue }
                barItem.title = item.title
                barItem.image = UIImage(systemName: item.systemImage)
                barItem.selectedImage = UIImage(systemName: item.systemImage)
                barItem.tag = index
            }
        }

        if let index = items.firstIndex(where: { $0.tab == selection }),
           let selected = tabBar.items?[safe: index],
           tabBar.selectedItem !== selected {
            tabBar.selectedItem = selected
        }
    }

    final class Coordinator: NSObject, UITabBarDelegate {
        var parent: ZiyaratSystemTabBar

        init(parent: ZiyaratSystemTabBar) {
            self.parent = parent
        }

        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            guard let model = parent.items[safe: item.tag] else { return }
            let reselected = parent.selection == model.tab
            parent.onSelection(model.tab, reselected)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private enum ZiyaratMapMode: Equatable {
    case standard
    case satellite
}

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
                    .background(Color(uiColor: .systemBackground), in: Capsule())
                    .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.7))
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
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
                ZiyaratRemoteImageView(url: url, fallbackAsset: fallbackAsset(for: image.id))
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

private struct ZiyaratRemoteImageView: View {
    let url: URL
    let fallbackAsset: String?
    @StateObject private var loader = ZiyaratRemoteImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if loader.failed, let fallbackAsset {
                Image(fallbackAsset)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task(id: url) {
            loader.load(url: url)
        }
        .onDisappear { loader.cancel() }
        .animation(.easeOut(duration: 0.16), value: loader.image != nil)
    }
}

@MainActor
private final class ZiyaratRemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false

    private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 48
        cache.totalCostLimit = 72 * 1024 * 1024
        return cache
    }()

    private var task: Task<Void, Never>?
    private var currentURL: URL?

    func load(url: URL) {
        guard currentURL != url || (image == nil && !failed) else { return }
        currentURL = url
        failed = false
        task?.cancel()

        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        image = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
                request.setValue("image/avif,image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard !Task.isCancelled else { return }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    failed = true
                    return
                }
                guard let decoded = UIImage(data: data) else {
                    failed = true
                    return
                }
                Self.cache.setObject(decoded, forKey: url as NSURL, cost: data.count)
                image = decoded
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
