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

private struct IumrahInternalNavigationModifier: ViewModifier {
    @EnvironmentObject private var chrome: AppChromeStore
    let progressStage: TripProgressStage?
    @State private var registered = false

    func body(content: Content) -> some View {
        content
            // Internal destinations use Apple's real navigation bar and real back
            // affordance. This preserves UINavigationController's edge-swipe pop
            // gesture instead of recreating a back button with dismiss().
            .toolbar(.visible, for: .navigationBar)
            .navigationBarBackButtonHidden(false)
            .navigationBarTitleDisplayMode(.inline)
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
    func iumrahInternalNavigation(progress: TripProgressStage? = nil) -> some View {
        modifier(IumrahInternalNavigationModifier(progressStage: progress))
    }
}
