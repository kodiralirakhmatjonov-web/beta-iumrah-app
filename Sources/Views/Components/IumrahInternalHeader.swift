import SwiftUI
import UIKit

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

    fileprivate var carouselSymbol: String {
        switch self {
        case .trip: return "calendar"
        case .hotel: return "building.2.fill"
        case .flight: return "airplane.departure"
        case .transfer: return "car.side.fill"
        case .ready: return "checkmark.seal.fill"
        }
    }

    fileprivate var carouselRole: IumrahIconRole {
        switch self {
        case .trip: return .calendar
        case .hotel: return .hotel
        case .flight: return .travel
        case .transfer: return .transfer
        case .ready: return .success
        }
    }
}

/// Compatibility progress view retained for non-generator call sites. The five
/// generator destinations now render the same progress information inside the
/// pinned generator header instead of duplicating a card in scroll content.
struct IumrahFlowProgress: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let stage: TripProgressStage
    var labelKey: String? = nil
    var currentPriceText: String? = nil

    var body: some View {
        GeneratorProgressStrip(
            stage: stage,
            labelKey: labelKey,
            currentPriceText: currentPriceText
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Generator pinned header

/// The progress strip is deliberately surface-free here because it lives inside
/// the single pinned generator container with the carousel and back control.
private struct GeneratorProgressStrip: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let stage: TripProgressStage
    var labelKey: String? = nil
    var currentPriceText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
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
                        .lineLimit(1)
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

/// Native SwiftUI circular carousel for the five real generator stages.
/// Every stage remains in the hierarchy at all times. Items that leave one
/// side travel around the back of the ring and return from the other side, so
/// there is no edge clipping or visual "teleporting" from a fade mask.
private struct GeneratorStageCarousel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stage: TripProgressStage

    @State private var carouselPosition: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var glowBreath = false
    @State private var resetGeneration = 0

    private let itemSpacing: CGFloat = 78
    private let carouselHeight: CGFloat = 90

    var body: some View {
        GeometryReader { proxy in
            let radiusX = min(102, max(58, proxy.size.width * 0.39))

            ZStack {
                ambientGlow

                ForEach(Array(TripProgressStage.allCases.enumerated()), id: \.element.rawValue) { index, item in
                    let angle = angle(for: index)
                    let depth = cos(angle)
                    let frontness = (depth + 1) / 2
                    let x = sin(angle) * radiusX

                    stageTile(item, frontness: frontness)
                        .scaleEffect(scale(for: frontness))
                        .opacity(opacity(for: frontness))
                        .blur(radius: blur(for: frontness))
                        .rotation3DEffect(
                            .degrees(Double(-sin(angle) * 18)),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.46
                        )
                        .offset(
                            x: x,
                            y: verticalOffset(for: frontness)
                        )
                        .zIndex(Double(depth * 10))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(carouselGesture)
        }
        .frame(height: carouselHeight)
        .accessibilityHidden(true)
        .task(id: stage.rawValue) {
            let target = restingIndex
            carouselPosition = CGFloat(target)
            dragTranslation = 0
            resetGeneration = 0
            glowBreath = false

            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowBreath = true
            }

            // One continuous 360° presentation lap on entry. The state itself
            // is unbounded; sin/cos provide the wrap, so an item physically
            // travels around the back of the ring rather than being removed
            // and recreated at the opposite edge.
            try? await Task.sleep(nanoseconds: 260_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 1.55)) {
                carouselPosition = CGFloat(target + TripProgressStage.allCases.count)
            }
        }
        .task(id: resetGeneration) {
            guard resetGeneration > 0 else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }

            let target = nearestEquivalentPosition(for: restingIndex, around: carouselPosition)
            withAnimation(.spring(response: 0.62, dampingFraction: 0.87, blendDuration: 0.10)) {
                carouselPosition = target
                dragTranslation = 0
            }
        }
    }

    private var carouselGesture: some Gesture {
        DragGesture(minimumDistance: 7, coordinateSpace: .local)
            .onChanged { value in
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
                    carouselPosition += CGFloat(steps)
                    dragTranslation = 0
                }

                // Manual play is temporary. One second after the finger leaves,
                // the carousel returns to the actual generator stage.
                resetGeneration &+= 1
            }
    }

    private var ambientGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        activeStage.carouselRole.color.opacity(0.27),
                        activeStage.carouselRole.color.opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 96
                )
            )
            .frame(width: glowBreath ? 188 : 166, height: glowBreath ? 54 : 46)
            .blur(radius: 17)
            .opacity(glowBreath ? 0.88 : 0.68)
            .offset(y: 18)
            .animation(.easeInOut(duration: 0.58), value: activeStage.rawValue)
            .allowsHitTesting(false)
    }

    private func stageTile(_ item: TripProgressStage, frontness: CGFloat) -> some View {
        let emphasis = pow(frontness, 4.5)
        let tileOpacity = 0.06 + (0.90 * Double(emphasis))

        return ZStack {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(Color.iumrahCardBackground.opacity(tileOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(0.018 + (0.045 * Double(emphasis))),
                            lineWidth: 0.75
                        )
                }
                .shadow(
                    color: item.carouselRole.color.opacity(0.13 * Double(emphasis)),
                    radius: 14 * emphasis,
                    x: 0,
                    y: 7 * emphasis
                )

            Image(systemName: item.carouselSymbol)
                .font(.system(size: 29 + (6 * frontness), weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.carouselRole.color)
        }
        .frame(width: 74, height: 74)
    }

    private var restingIndex: Int {
        max(0, stage.rawValue - 1)
    }

    private var displayedPosition: CGFloat {
        carouselPosition - (dragTranslation / itemSpacing)
    }

    private var activeStage: TripProgressStage {
        let index = wrapped(Int(displayedPosition.rounded()))
        return TripProgressStage.allCases[index]
    }

    private func angle(for index: Int) -> CGFloat {
        let step = (2 * CGFloat.pi) / CGFloat(TripProgressStage.allCases.count)
        return (CGFloat(index) - displayedPosition) * step
    }

    private func nearestEquivalentPosition(for index: Int, around current: CGFloat) -> CGFloat {
        let count = CGFloat(TripProgressStage.allCases.count)
        let base = CGFloat(index)
        let revolutions = ((current - base) / count).rounded()
        return base + (revolutions * count)
    }

    private func wrapped(_ index: Int) -> Int {
        let count = max(TripProgressStage.allCases.count, 1)
        return ((index % count) + count) % count
    }

    private func scale(for frontness: CGFloat) -> CGFloat {
        0.52 + (0.52 * frontness)
    }

    private func opacity(for frontness: CGFloat) -> Double {
        0.14 + (0.86 * Double(pow(frontness, 0.9)))
    }

    private func blur(for frontness: CGFloat) -> CGFloat {
        6.0 * (1 - frontness)
    }

    private func verticalOffset(for frontness: CGFloat) -> CGFloat {
        8.0 * (1 - frontness)
    }
}

/// One chrome block below the device safe area. It contains the native Liquid
/// Glass back control, the circular stage carousel, and the progress strip.
private struct GeneratorPinnedHeader: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    let stage: TripProgressStage
    var currentPriceText: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .leading) {
                GeneratorStageCarousel(stage: stage)
                    .padding(.horizontal, 54)

                IumrahGlassIconButton(
                    systemName: "chevron.left",
                    size: 56,
                    fontSize: 25,
                    accessibilityLabel: backAccessibilityLabel
                ) {
                    dismiss()
                }
                .padding(.leading, 2)
            }
            .frame(height: 92)

            GeneratorProgressStrip(
                stage: stage,
                currentPriceText: currentPriceText
            )
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 13)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    Color.iumrahRaisedBackground
                        .opacity(colorScheme == .dark ? 0.94 : 0.97)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.055), radius: 18, x: 0, y: 8)
        }
        .accessibilityElement(children: .contain)
    }

    private var backAccessibilityLabel: String {
        switch settings.language {
        case .russian: return "Назад"
        case .english: return "Back"
        case .uzbek: return "Orqaga"
        case .uzbekCyrillic: return "Орқага"
        }
    }
}

/// Keeps UINavigationController's native edge-swipe pop gesture available even
/// though generator screens hide the stock navigation bar in favor of the
/// safe-area-aware pinned header above.
private struct GeneratorInteractivePopRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

private struct IumrahInternalNavigationModifier: ViewModifier {
    @EnvironmentObject private var chrome: AppChromeStore

    let progressStage: TripProgressStage?
    let showsGeneratorAmbient: Bool
    let currentPriceText: String?

    @State private var registered = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if showsGeneratorAmbient, let progressStage {
            content
                // The generator owns one pinned header below the hardware safe
                // area. This avoids the Dynamic Island / status bar entirely on
                // every iPhone size and removes the constrained toolbar title box.
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
                .safeAreaInset(edge: .top, spacing: 0) {
                    GeneratorPinnedHeader(
                        stage: progressStage,
                        currentPriceText: currentPriceText
                    )
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
                .background {
                    GeneratorInteractivePopRestorer()
                        .frame(width: 0, height: 0)
                }
                .tint(Color.primary)
                .modifier(InternalChromeRegistrationModifier(
                    chrome: chrome,
                    registered: $registered
                ))
        } else {
            content
                // Non-generator internal destinations keep Apple's stock
                // navigation bar and native back affordance unchanged.
                .toolbar(.visible, for: .navigationBar)
                .navigationBarBackButtonHidden(false)
                .navigationBarTitleDisplayMode(.inline)
                .tint(Color.primary)
                .modifier(InternalChromeRegistrationModifier(
                    chrome: chrome,
                    registered: $registered
                ))
        }
    }
}

/// Isolated lifecycle registration avoids duplicating onAppear/onDisappear
/// bookkeeping across the two navigation presentation branches above.
private struct InternalChromeRegistrationModifier: ViewModifier {
    let chrome: AppChromeStore
    @Binding var registered: Bool

    func body(content: Content) -> some View {
        content
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
        showsGeneratorAmbient: Bool = false,
        currentPriceText: String? = nil
    ) -> some View {
        modifier(
            IumrahInternalNavigationModifier(
                progressStage: progress,
                showsGeneratorAmbient: showsGeneratorAmbient,
                currentPriceText: currentPriceText
            )
        )
    }
}
