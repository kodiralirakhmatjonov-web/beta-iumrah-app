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
                    colors: [Color.iumrahPageBackground.opacity(0.95), Color.iumrahPageBackground.opacity(0.76), Color.iumrahPageBackground.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: progressStage == nil ? 76 : 132)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

private struct IumrahTripProgressChain: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let activeStage: TripProgressStage

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Array(TripProgressStage.allCases.enumerated()), id: \.element.rawValue) { index, stage in
                    stageNode(stage)

                    if index < TripProgressStage.allCases.count - 1 {
                        Capsule()
                            .fill(connectorColor(after: stage))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 5)
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(TripProgressStage.allCases, id: \.rawValue) { stage in
                    Text(L10n.text(stage.localizationKey, settings.language))
                        .font(.system(size: 10, weight: stage == activeStage ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(stageLabelColor(stage))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 13)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.iumrahGraphite)
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func stageNode(_ stage: TripProgressStage) -> some View {
        let isComplete = stage.rawValue < activeStage.rawValue
        let isActive = stage == activeStage

        ZStack {
            Circle()
                .fill(nodeBackground(isComplete: isComplete, isActive: isActive))
                .overlay {
                    Circle()
                        .strokeBorder(nodeBorder(isComplete: isComplete, isActive: isActive), lineWidth: isActive ? 2 : 1)
                }

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.iumrahCareDark)
            } else {
                Text("\(stage.rawValue)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? Color.black : Color.white.opacity(0.64))
            }
        }
        .frame(width: 31, height: 31)
        .shadow(color: isActive ? Color.white.opacity(0.14) : Color.clear, radius: 8)
    }

    private func nodeBackground(isComplete: Bool, isActive: Bool) -> Color {
        if isComplete { return Color.iumrahCareLight }
        if isActive { return Color.white }
        return Color.white.opacity(0.06)
    }

    private func nodeBorder(isComplete: Bool, isActive: Bool) -> Color {
        if isComplete { return Color.iumrahCareLight.opacity(0.72) }
        if isActive { return Color.white }
        return Color.white.opacity(0.18)
    }

    private func connectorColor(after stage: TripProgressStage) -> Color {
        stage.rawValue < activeStage.rawValue ? Color.iumrahCareLight : Color.white.opacity(0.14)
    }

    private func stageLabelColor(_ stage: TripProgressStage) -> Color {
        if stage == activeStage { return Color.white }
        if stage.rawValue < activeStage.rawValue { return Color.white.opacity(0.78) }
        return Color.white.opacity(0.42)
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
