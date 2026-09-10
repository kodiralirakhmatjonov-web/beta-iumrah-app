import SwiftUI

enum TripProgressStage: Int, CaseIterable {
    case trip = 1
    case hotel = 2
    case flight = 3
    case transfer = 4
    case ready = 5

    var localizationKey: String {
        switch self {
        case .trip: return "step_trip"
        case .hotel: return "step_hotel"
        case .flight: return "step_flight"
        case .transfer: return "step_transfer"
        case .ready: return "step_ready"
        }
    }
}

/// Compact, scrollable progress element for the Umrah builder.
/// It belongs inside page content instead of being pinned to the safe area.
struct IumrahFlowProgress: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let stage: TripProgressStage
    var labelKey: String? = nil
    var currentPriceText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(FlowCopy.text(.stepOfFour, settings.language)) \(stage.rawValue) / 5")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                if let currentPriceText {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(currentPriceLabel)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(.secondary)
                        Text(currentPriceText)
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .contentTransition(.numericText())
                    }
                } else {
                    Text(L10n.text(labelKey ?? stage.localizationKey, settings.language))
                        .font(.subheadline.weight(.semibold))
                }
            }

            HStack(spacing: 7) {
                ForEach(TripProgressStage.allCases, id: \.rawValue) { item in
                    Capsule(style: .continuous)
                        .fill(segmentColor(item))
                        .frame(maxWidth: .infinity)
                        .frame(height: item == stage ? 6 : 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var currentPriceLabel: String {
        switch settings.language {
        case .russian: return "ТЕКУЩАЯ ЦЕНА"
        case .english: return "CURRENT TOTAL"
        case .uzbek: return "JORIY NARX"
        case .uzbekCyrillic: return "ЖОРИЙ НАРХ"
        }
    }

    private func segmentColor(_ item: TripProgressStage) -> Color {
        if item.rawValue < stage.rawValue { return Color.iumrahCareLight }
        if item == stage { return Color.primary }
        return Color.secondary.opacity(0.18)
    }
}

// MARK: - Generator ambient rail

/// A large, tactile carousel that lives in the otherwise empty generator
/// navigation-title area. It is intentionally independent from the progress
/// card below: the progress card communicates completion, while this rail gives
/// the active generator context a calm, living identity.
private struct GeneratorAmbientRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stage: TripProgressStage

    @State private var activeIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var glowBreath = false
    @State private var resetGeneration = 0

    private let itemSpacing: CGFloat = 82
    private let railWidth: CGFloat = 312
    private let railHeight: CGFloat = 100

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let role: IumrahIconRole
        let isResting: Bool

        init(
            id: String,
            symbol: String,
            role: IumrahIconRole,
            isResting: Bool = false
        ) {
            self.id = id
            self.symbol = symbol
            self.role = role
            self.isResting = isResting
        }
    }

    var body: some View {
        ZStack {
            containerSurface
            ambientGlow
            iconStrip
        }
        .frame(width: railWidth, height: railHeight)
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        // Keep the whole ambient rail inside the navigation bar's own bounds.
        // The toolbar remains pinned while the generator content scrolls, and
        // the rail no longer relies on an offset that can be clipped by UIKit.
        .padding(.vertical, 2)
        .gesture(carouselGesture)
        .accessibilityHidden(true)
        .task(id: stage.rawValue) {
            let target = restingIndex
            activeIndex = target
            dragTranslation = 0
            resetGeneration = 0
            glowBreath = false

            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowBreath = true
            }

            // One calm presentation lap on entry, then park on the icon that
            // represents the current generator context. There is no perpetual
            // auto-scrolling after this sequence.
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }

            for step in 1...items.count {
                try? await Task.sleep(nanoseconds: 205_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.50, dampingFraction: 0.86, blendDuration: 0.08)) {
                    activeIndex = wrapped(target + step)
                }
            }
        }
        .task(id: resetGeneration) {
            guard resetGeneration > 0 else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.62, dampingFraction: 0.86, blendDuration: 0.10)) {
                activeIndex = restingIndex
                dragTranslation = 0
            }
        }
    }

    private var containerSurface: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.iumrahCardBackground.opacity(0.20))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.045), lineWidth: 0.75)
            }
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 7)
            .allowsHitTesting(false)
    }

    private var iconStrip: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let phase = continuousDistance(for: index)
                let magnitude = abs(phase)

                if magnitude <= 2.25 {
                    iconTile(item, magnitude: magnitude)
                        .scaleEffect(scale(for: magnitude))
                        .opacity(opacity(for: magnitude))
                        .blur(radius: blur(for: magnitude))
                        .offset(
                            x: phase * itemSpacing,
                            y: verticalOffset(for: magnitude)
                        )
                        .zIndex(Double(4) - Double(magnitude))
                }
            }
        }
        .frame(width: railWidth - 8, height: railHeight - 6)
        // Fade the outer icons gradually instead of hard-clipping them at the
        // rail bounds. This preserves the depth effect during manual swipes.
        .mask(edgeFadeMask)
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .black.opacity(0.45), location: 0.055),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.86),
                .init(color: .black.opacity(0.45), location: 0.945),
                .init(color: .clear, location: 1.00)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var carouselGesture: some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .local)
            .onChanged { value in
                // Keep vertical page gestures natural. The rail only claims a
                // gesture once the movement is clearly horizontal.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.06)) {
                        dragTranslation = 0
                    }
                    resetGeneration &+= 1
                    return
                }

                let projected = value.predictedEndTranslation.width
                let rawSteps = Int((-projected / itemSpacing).rounded())
                let steps = min(max(rawSteps, -2), 2)

                if steps != 0 {
                    IumrahHaptics.selection()
                }

                withAnimation(.spring(response: 0.46, dampingFraction: 0.84, blendDuration: 0.08)) {
                    activeIndex = wrapped(activeIndex + steps)
                    dragTranslation = 0
                }

                // Every manual play session is temporary: one second after the
                // finger leaves the rail, return to the generator's real context.
                resetGeneration &+= 1
            }
    }

    private var ambientGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        activeItem.role.color.opacity(0.30),
                        activeItem.role.color.opacity(0.12),
                        activeItem.role.color.opacity(0.035),
                        .clear
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 118
                )
            )
            .frame(width: glowBreath ? 236 : 208, height: glowBreath ? 62 : 52)
            .blur(radius: 18)
            .opacity(glowBreath ? 0.88 : 0.68)
            .offset(y: 24)
            .animation(.easeInOut(duration: 0.58), value: activeIndex)
            .allowsHitTesting(false)
    }

    private func iconTile(_ item: Item, magnitude: CGFloat) -> some View {
        let emphasis = max(0, 1 - min(magnitude, 1))

        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.iumrahCardBackground.opacity(0.72 + (0.26 * Double(emphasis))))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(0.025 + (0.03 * Double(emphasis))),
                            lineWidth: 0.75
                        )
                }
                .shadow(
                    color: item.role.color.opacity(0.12 * Double(emphasis)),
                    radius: 14 * emphasis,
                    x: 0,
                    y: 7 * emphasis
                )

            Image(systemName: item.symbol)
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.role.color)
        }
        .frame(width: 72, height: 72)
    }

    private var restingIndex: Int {
        items.firstIndex(where: \.isResting) ?? 0
    }

    private var activeItem: Item {
        items[wrapped(activeIndex)]
    }

    private var items: [Item] {
        switch stage {
        case .trip:
            return [
                Item(id: "trip-flight", symbol: "airplane.departure", role: .travel),
                Item(id: "trip-location", symbol: "mappin.and.ellipse", role: .location),
                // The trip screen contains the date choice, so the carousel
                // settles on the calendar after its one-time presentation lap.
                Item(id: "trip-calendar", symbol: "calendar", role: .calendar, isResting: true),
                Item(id: "trip-guests", symbol: "person.2.fill", role: .profile),
                Item(id: "trip-bag", symbol: "suitcase.fill", role: .booking)
            ]
        case .hotel:
            return [
                Item(id: "hotel-building", symbol: "building.2.fill", role: .hotel, isResting: true),
                Item(id: "hotel-bed", symbol: "bed.double.fill", role: .hotel),
                Item(id: "hotel-location", symbol: "mappin.and.ellipse", role: .location),
                Item(id: "hotel-rating", symbol: "star.fill", role: .rating),
                Item(id: "hotel-meal", symbol: "fork.knife", role: .booking)
            ]
        case .flight:
            return [
                Item(id: "flight-departure", symbol: "airplane.departure", role: .travel, isResting: true),
                Item(id: "flight-time", symbol: "clock.fill", role: .waiting),
                Item(id: "flight-bag", symbol: "suitcase.fill", role: .booking),
                Item(id: "flight-route", symbol: "arrow.left.arrow.right", role: .accent),
                Item(id: "flight-arrival", symbol: "airplane.arrival", role: .travel)
            ]
        case .transfer:
            return [
                Item(id: "transfer-car", symbol: "car.side.fill", role: .transfer, isResting: true),
                Item(id: "transfer-map", symbol: "map.fill", role: .location),
                Item(id: "transfer-guests", symbol: "person.2.fill", role: .profile),
                Item(id: "transfer-bag", symbol: "suitcase.fill", role: .booking),
                Item(id: "transfer-pin", symbol: "location.fill", role: .location)
            ]
        case .ready:
            return [
                Item(id: "ready-seal", symbol: "checkmark.seal.fill", role: .success, isResting: true),
                Item(id: "ready-document", symbol: "doc.text.fill", role: .document),
                Item(id: "ready-payment", symbol: "creditcard.fill", role: .payment),
                Item(id: "ready-care", symbol: "heart.fill", role: .care),
                Item(id: "ready-sparkles", symbol: "sparkles", role: .umrah)
            ]
        }
    }

    private func continuousDistance(for index: Int) -> CGFloat {
        let base = CGFloat(signedDistance(for: index))
        return base + (dragTranslation / itemSpacing)
    }

    private func signedDistance(for index: Int) -> Int {
        let count = items.count
        let normalizedActive = wrapped(activeIndex)
        let direct = index - normalizedActive
        let forwardWrap = direct + count
        let backwardWrap = direct - count
        return [direct, forwardWrap, backwardWrap].min { abs($0) < abs($1) } ?? direct
    }

    private func wrapped(_ index: Int) -> Int {
        let count = max(items.count, 1)
        return ((index % count) + count) % count
    }

    private func scale(for magnitude: CGFloat) -> CGFloat {
        if magnitude <= 1 {
            return 1.06 - (0.25 * magnitude)
        }
        return max(0.60, 0.81 - (0.18 * (magnitude - 1)))
    }

    private func opacity(for magnitude: CGFloat) -> Double {
        if magnitude <= 1 {
            return 1.0 - (0.44 * Double(magnitude))
        }
        return max(0.12, 0.56 - (0.34 * Double(magnitude - 1)))
    }

    private func blur(for magnitude: CGFloat) -> CGFloat {
        if magnitude <= 0.35 { return 0 }
        if magnitude <= 1 { return 2.2 * magnitude }
        return min(6.4, 2.2 + ((magnitude - 1) * 3.2))
    }

    private func verticalOffset(for magnitude: CGFloat) -> CGFloat {
        min(4.5, magnitude * 2.4)
    }
}

private struct IumrahInternalNavigationModifier: ViewModifier {
    @EnvironmentObject private var chrome: AppChromeStore
    let progressStage: TripProgressStage?
    let showsGeneratorAmbient: Bool
    @State private var registered = false

    func body(content: Content) -> some View {
        content
            // Internal destinations use Apple's real navigation bar and real back
            // affordance. This preserves UINavigationController's edge-swipe pop
            // gesture instead of recreating a back button with dismiss().
            .toolbar(.visible, for: .navigationBar)
            .navigationBarBackButtonHidden(false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsGeneratorAmbient, let progressStage {
                    ToolbarItem(placement: .principal) {
                        GeneratorAmbientRail(stage: progressStage)
                    }
                }
            }
            .tint(Color.primary)
            .onAppear {
                guard !registered else { return }
                registered = true
                chrome.beginInternalNavigation()
            }
            .onDisappear {
                guard registered else { return }
                registered = false
                chrome.endInternalNavigation()
            }
    }
}

extension View {
    func iumrahInternalNavigation(
        progress: TripProgressStage? = nil,
        showsGeneratorAmbient: Bool = false
    ) -> some View {
        modifier(
            IumrahInternalNavigationModifier(
                progressStage: progress,
                showsGeneratorAmbient: showsGeneratorAmbient
            )
        )
    }
}
