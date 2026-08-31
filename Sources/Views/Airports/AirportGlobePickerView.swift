import SwiftUI
import MapKit
import CoreLocation

struct AirportGlobePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @Binding var selection: Airport?
    @Binding var fallbackCode: String
    private let onSelectionCommitted: () -> Void

    @State private var position: MapCameraPosition
    @State private var selectedFeature: MapFeature?
    @State private var resolvedAirport: Airport?
    @State private var isResolving = false
    @State private var resolveFailed = false
    @State private var visibleRegion = Self.worldRegion

    private let airportService = AirportSearchService()

    init(
        selection: Binding<Airport?>,
        fallbackCode: Binding<String>,
        onSelectionCommitted: @escaping () -> Void = {}
    ) {
        _selection = selection
        _fallbackCode = fallbackCode
        self.onSelectionCommitted = onSelectionCommitted

        let center: CLLocationCoordinate2D
        if let airport = selection.wrappedValue {
            center = CLLocationCoordinate2D(latitude: airport.lat, longitude: airport.lon)
        } else {
            // Start with the Middle East / Central Asia facing the user. At this
            // distance MapKit presents its native globe instead of a flat map.
            center = CLLocationCoordinate2D(latitude: 28.0, longitude: 52.0)
        }

        _position = State(initialValue: .camera(Self.globeCamera(centeredAt: center)))
    }

    var body: some View {
        ZStack {
            Map(
                position: $position,
                interactionModes: .all,
                selection: $selectedFeature
            ) {
                if let current = selection {
                    Annotation(
                        current.iata,
                        coordinate: CLLocationCoordinate2D(latitude: current.lat, longitude: current.lon),
                        anchor: .bottom
                    ) {
                        currentAirportMarker(current)
                    }
                }
            }
            .mapStyle(
                .hybrid(
                    elevation: .realistic,
                    pointsOfInterest: .including([.airport]),
                    showsTraffic: false
                )
            )
            .mapFeatureSelectionDisabled { feature in
                feature.pointOfInterestCategory != .airport
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .onChange(of: selectedFeature) { _, feature in
                guard let feature, feature.pointOfInterestCategory == .airport else {
                    if selectedFeature == nil {
                        resolvedAirport = nil
                        resolveFailed = false
                        isResolving = false
                    }
                    return
                }
                resolve(feature)
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                topBar

                Spacer(minLength: 12)

                bottomPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                resetToGlobe()
            } label: {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("airport_map_reset", settings.language))

            Text(L10n.text("airport_map_title", settings.language))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Button {
                dismiss()
            } label: {
                Text(L10n.text("close", settings.language))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 13)
                    .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .foregroundStyle(.primary)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 25, style: .continuous))
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if let feature = selectedFeature, feature.pointOfInterestCategory == .airport {
            selectedAirportPanel(feature)
        } else {
            instructionPanel
        }
    }

    private var instructionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("airport_map_hint_title", settings.language))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(mapHintText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 27, style: .continuous))
    }

    private func selectedAirportPanel(_ feature: MapFeature) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.primary.opacity(0.10))
                        .frame(width: 50, height: 50)

                    if let resolvedAirport {
                        Text(resolvedAirport.iata)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospaced()
                    } else {
                        Image(systemName: "airplane")
                            .font(.system(size: 20, weight: .semibold))
                            .rotationEffect(.degrees(-35))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedAirport?.city ?? feature.title ?? L10n.text("airport_map_airport", settings.language))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .lineLimit(2)

                    if let resolvedAirport {
                        Text(resolvedAirport.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else if let title = feature.title {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    selectedFeature = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                        .background(.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if isResolving {
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.text("airport_map_resolving", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if resolveFailed {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    Text(L10n.text("airport_map_resolve_failed", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let resolvedAirport {
                Button {
                    choose(resolvedAirport)
                } label: {
                    Text(L10n.format("airport_map_choose", settings.language, resolvedAirport.iata))
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 29, style: .continuous))
    }

    private var mapHintText: String {
        let span = max(visibleRegion.span.latitudeDelta, visibleRegion.span.longitudeDelta)
        return L10n.text(span > 55 ? "airport_map_zoom_hint" : "airport_map_tap_hint", settings.language)
    }

    private func currentAirportMarker(_ airport: Airport) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "airplane")
                .font(.system(size: 18, weight: .bold))
                .rotationEffect(.degrees(-35))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .shadow(color: .black.opacity(0.30), radius: 8, y: 4)

            Text(airport.iata)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.68), in: Capsule())
        }
        .accessibilityLabel(airport.compactTitle)
    }

    private func resetToGlobe() {
        selectedFeature = nil
        resolvedAirport = nil
        resolveFailed = false
        isResolving = false

        let center: CLLocationCoordinate2D
        if let current = selection {
            center = CLLocationCoordinate2D(latitude: current.lat, longitude: current.lon)
        } else {
            center = CLLocationCoordinate2D(latitude: 28.0, longitude: 52.0)
        }

        withAnimation(.easeInOut(duration: 0.65)) {
            position = .camera(Self.globeCamera(centeredAt: center))
        }
        IumrahHaptics.soft()
    }

    private func resolve(_ feature: MapFeature) {
        resolvedAirport = nil
        resolveFailed = false
        isResolving = true
        IumrahHaptics.selection()

        let featureSnapshot = AirportFeatureSnapshot(feature: feature)

        Task {
            let airport = await resolveAirport(for: featureSnapshot)
            guard selectedFeature?.coordinate.latitude == featureSnapshot.coordinate.latitude,
                  selectedFeature?.coordinate.longitude == featureSnapshot.coordinate.longitude else {
                return
            }

            resolvedAirport = airport
            resolveFailed = airport == nil
            isResolving = false

            if airport == nil {
                IumrahHaptics.error()
            }
        }
    }

    private func resolveAirport(for feature: AirportFeatureSnapshot) async -> Airport? {
        let location = CLLocation(latitude: feature.coordinate.latitude, longitude: feature.coordinate.longitude)
        var queries: [String] = []

        if let title = feature.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            queries.append(title)
        }

        // Reverse geocoding is only used to obtain an English city spelling for
        // the existing iumrah airport API. It does not request the user's location
        // and therefore does not add a location permission requirement.
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(
            location,
            preferredLocale: Locale(identifier: "en_US")
        ).first {
            if let locality = placemark.locality, !locality.isEmpty {
                queries.append(locality)
            }
            if let subAdministrativeArea = placemark.subAdministrativeArea, !subAdministrativeArea.isEmpty {
                queries.append(subAdministrativeArea)
            }
        }

        var seen = Set<String>()
        let uniqueQueries = queries.filter { query in
            let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        for query in uniqueQueries {
            guard !Task.isCancelled else { return nil }
            guard let airports = try? await airportService.search(query, limit: 12), !airports.isEmpty else {
                continue
            }

            if let nearest = nearestAirport(to: location, from: airports), nearest.distance <= 50_000 {
                return nearest.airport
            }
        }

        return nil
    }

    private func nearestAirport(to location: CLLocation, from airports: [Airport]) -> (airport: Airport, distance: CLLocationDistance)? {
        airports
            .map { airport in
                let airportLocation = CLLocation(latitude: airport.lat, longitude: airport.lon)
                return (airport: airport, distance: location.distance(from: airportLocation))
            }
            .min { $0.distance < $1.distance }
    }

    private func choose(_ airport: Airport) {
        selection = airport
        fallbackCode = airport.iata
        IumrahHaptics.success()
        onSelectionCommitted()
        dismiss()
    }

    private static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.0, longitude: 52.0),
        span: MKCoordinateSpan(latitudeDelta: 140.0, longitudeDelta: 220.0)
    )

    private static func globeCamera(centeredAt coordinate: CLLocationCoordinate2D) -> MapCamera {
        MapCamera(
            centerCoordinate: coordinate,
            distance: 32_000_000,
            heading: 0,
            pitch: 0
        )
    }
}

private struct AirportFeatureSnapshot {
    let title: String?
    let coordinate: CLLocationCoordinate2D

    init(feature: MapFeature) {
        title = feature.title
        coordinate = feature.coordinate
    }
}
