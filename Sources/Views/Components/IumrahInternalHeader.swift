import SwiftUI

enum TripProgressStage: Int, CaseIterable {
    case trip = 1
    case hotel = 2
    case flight = 3
    case ready = 4

    var localizationKey: String {
        switch self {
        case .trip: return "step_trip"
        case .hotel: return "step_hotel"
        case .flight: return "step_flight"
        case .ready: return "step_ready"
        }
    }
}

struct IumrahInternalHeader: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore

    let progressStage: TripProgressStage?

    var body: some View {
        VStack(spacing: progressStage == nil ? 0 : 12) {
            HStack(spacing: 10) {
                Button {
                    IumrahHaptics.soft()
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                        Text(L10n.text("back", settings.language))
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(minWidth: 76, minHeight: 40, alignment: .leading)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                IumrahHeaderLogo(width: 112)

                Spacer(minLength: 0)

                Color.clear
                    .frame(width: 76, height: 40)
            }

            if let progressStage {
                IumrahTripProgressChain(activeStage: progressStage)
            }
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, progressStage == nil ? 14 : 16)
        .background {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.iumrahPageBackground.opacity(0.94), Color.iumrahPageBackground.opacity(0.72), Color.iumrahPageBackground.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: progressStage == nil ? 76 : 122)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

private struct IumrahTripProgressChain: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let activeStage: TripProgressStage

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(TripProgressStage.allCases.enumerated()), id: \.element.rawValue) { index, stage in
                step(stage)
                if index < TripProgressStage.allCases.count - 1 {
                    Capsule()
                        .fill(connectorColor(after: stage))
                        .frame(height: 2)
                        .frame(maxWidth: 18)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.iumrahCardBackground.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }

    private func step(_ stage: TripProgressStage) -> some View {
        let isActive = stage == activeStage
        let isComplete = stage.rawValue < activeStage.rawValue
        let foreground: Color = isActive || isComplete ? Color.iumrahPrimaryButtonText : Color.secondary
        let background: Color = isActive || isComplete ? Color.iumrahPrimaryButtonBackground : Color.iumrahRaisedBackground
        let titleColor: Color = isActive ? Color.primary : Color.secondary

        return VStack(spacing: 4) {
            Group {
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                } else {
                    Text("\(stage.rawValue)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(foreground)
            .frame(width: 24, height: 24)
            .background(background)
            .clipShape(Circle())

            Text(L10n.text(stage.localizationKey, settings.language))
                .font(.system(size: 9, weight: isActive ? .semibold : .medium))
                .foregroundColor(titleColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func connectorColor(after stage: TripProgressStage) -> Color {
        stage.rawValue < activeStage.rawValue ? Color.primary.opacity(0.55) : Color.primary.opacity(0.10)
    }
}

private struct IumrahInternalNavigationModifier: ViewModifier {
    @EnvironmentObject private var chrome: AppChromeStore
    let progressStage: TripProgressStage?
    @State private var registered = false

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                IumrahInternalHeader(progressStage: progressStage)
            }
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
