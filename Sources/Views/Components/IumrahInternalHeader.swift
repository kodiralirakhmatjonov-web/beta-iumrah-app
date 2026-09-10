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

/// Decorative generator motion that lives in the otherwise empty navigation-title
/// area. The progress card below remains the authoritative step indicator; this
/// rail only gives the five-step package builder a calm, living system identity.
private struct GeneratorAmbientRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let stage: TripProgressStage

    @State private var activeIndex = 0
    @State private var glowBreath = false

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let role: IumrahIconRole
    }

    var body: some View {
        ZStack {
            ambientGlow

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let distance = signedDistance(for: index)
                let magnitude = abs(distance)

                if magnitude <= 2 {
                    iconTile(item, magnitude: magnitude)
                        .scaleEffect(scale(for: magnitude))
                        .opacity(opacity(for: magnitude))
                        .blur(radius: blur(for: magnitude))
                        .offset(x: CGFloat(distance) * 54, y: magnitude == 0 ? -1 : 1)
                        .zIndex(Double(3 - magnitude))
                }
            }
        }
        .frame(width: 194, height: 50)
        .clipped()
        .contentShape(Rectangle())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: stage.rawValue) {
            activeIndex = 0
            glowBreath = false

            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                glowBreath = true
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_850_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(.spring(response: 0.72, dampingFraction: 0.88, blendDuration: 0.12)) {
                    activeIndex = (activeIndex + 1) % items.count
                }
            }
        }
    }

    private var ambientGlow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        activeItem.role.color.opacity(0.30),
                        activeItem.role.color.opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 54
                )
            )
            .frame(width: glowBreath ? 116 : 94, height: glowBreath ? 28 : 22)
            .blur(radius: 9)
            .opacity(glowBreath ? 0.92 : 0.66)
            .offset(y: 16)
            .animation(.easeInOut(duration: 0.65), value: activeIndex)
    }

    private func iconTile(_ item: Item, magnitude: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.iumrahCardBackground)

            Image(systemName: item.symbol)
                .font(.system(size: magnitude == 0 ? 18 : 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.role.color)
        }
        .frame(width: 40, height: 40)
    }

    private var activeItem: Item {
        items[min(max(activeIndex, 0), items.count - 1)]
    }

    private var items: [Item] {
        switch stage {
        case .trip:
            return [
                Item(id: "trip-flight", symbol: "airplane.departure", role: .travel),
                Item(id: "trip-location", symbol: "mappin.and.ellipse", role: .location),
                Item(id: "trip-calendar", symbol: "calendar", role: .calendar),
                Item(id: "trip-guests", symbol: "person.2.fill", role: .profile),
                Item(id: "trip-bag", symbol: "suitcase.fill", role: .booking)
            ]
        case .hotel:
            return [
                Item(id: "hotel-building", symbol: "building.2.fill", role: .hotel),
                Item(id: "hotel-bed", symbol: "bed.double.fill", role: .hotel),
                Item(id: "hotel-location", symbol: "mappin.and.ellipse", role: .location),
                Item(id: "hotel-rating", symbol: "star.fill", role: .rating),
                Item(id: "hotel-meal", symbol: "fork.knife", role: .booking)
            ]
        case .flight:
            return [
                Item(id: "flight-departure", symbol: "airplane.departure", role: .travel),
                Item(id: "flight-time", symbol: "clock.fill", role: .waiting),
                Item(id: "flight-bag", symbol: "suitcase.fill", role: .booking),
                Item(id: "flight-route", symbol: "arrow.left.arrow.right", role: .accent),
                Item(id: "flight-arrival", symbol: "airplane.arrival", role: .travel)
            ]
        case .transfer:
            return [
                Item(id: "transfer-car", symbol: "car.side.fill", role: .transfer),
                Item(id: "transfer-map", symbol: "map.fill", role: .location),
                Item(id: "transfer-guests", symbol: "person.2.fill", role: .profile),
                Item(id: "transfer-bag", symbol: "suitcase.fill", role: .booking),
                Item(id: "transfer-pin", symbol: "location.fill", role: .location)
            ]
        case .ready:
            return [
                Item(id: "ready-seal", symbol: "checkmark.seal.fill", role: .success),
                Item(id: "ready-document", symbol: "doc.text.fill", role: .document),
                Item(id: "ready-payment", symbol: "creditcard.fill", role: .payment),
                Item(id: "ready-care", symbol: "heart.fill", role: .care),
                Item(id: "ready-sparkles", symbol: "sparkles", role: .umrah)
            ]
        }
    }

    private func signedDistance(for index: Int) -> Int {
        let count = items.count
        let direct = index - activeIndex
        let forwardWrap = direct + count
        let backwardWrap = direct - count
        return [direct, forwardWrap, backwardWrap].min { abs($0) < abs($1) } ?? direct
    }

    private func scale(for magnitude: Int) -> CGFloat {
        switch magnitude {
        case 0: return 1.08
        case 1: return 0.82
        default: return 0.66
        }
    }

    private func opacity(for magnitude: Int) -> Double {
        switch magnitude {
        case 0: return 1
        case 1: return 0.42
        default: return 0.08
        }
    }

    private func blur(for magnitude: Int) -> CGFloat {
        switch magnitude {
        case 0: return 0
        case 1: return 1.35
        default: return 3.6
        }
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
