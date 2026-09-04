import SwiftUI

struct UmrahFlowNavigatorSheet: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    let onExit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedStage: UmrahFlowState.Stage

    init(flow: UmrahFlowState, store: UmrahFlowStore, onExit: @escaping () -> Void) {
        self.flow = flow
        self.store = store
        self.onExit = onExit
        _selectedStage = State(initialValue: flow.stage)
    }

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(palette.textSecondary.opacity(0.28))
                .frame(width: 38, height: 5)
                .padding(.top, 8)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(UmrahFlowCopy.chooseStage(store.guideLanguage))
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                    Text(stageTitle(flow.stage))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer()
                UmrahGlassIconButton(
                    systemName: "xmark",
                    foreground: palette.textPrimary,
                    accessibilityLabel: store.text("close_button", fallback: "Close")
                ) {
                    dismiss()
                }
            }
            .padding(.horizontal, 20)

            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(navigableStages, id: \.self) { stage in
                        stageButton(stage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                Button {
                    IumrahHaptics.selection()
                    withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                        flow.stage = selectedStage
                    }
                    dismiss()
                } label: {
                    Text(store.text("navigate_button", fallback: "Go"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .iumrahGlass(in: Capsule(), interactive: true, tint: palette.accent.opacity(0.56))
                }
                .buttonStyle(.plain)

                Button {
                    IumrahHaptics.soft()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        onExit()
                    }
                } label: {
                    Text(UmrahFlowCopy.leaveUmrah(store.guideLanguage))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .iumrahGlass(in: Capsule(), interactive: true, tint: palette.danger.opacity(0.08))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
    }

    private func stageButton(_ stage: UmrahFlowState.Stage) -> some View {
        let selected = selectedStage == stage

        return Button {
            IumrahHaptics.selection()
            withAnimation(.smooth(duration: 0.26, extraBounce: 0)) {
                selectedStage = stage
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: stageSymbol(stage))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : palette.textSecondary)
                    .frame(width: 38, height: 38)
                    .iumrahGlass(in: Circle(), interactive: true, tint: selected ? palette.accent.opacity(0.56) : nil)

                Text(stageTitle(stage))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 58)
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: 22, style: .continuous),
                interactive: true,
                tint: selected ? palette.accent.opacity(0.14) : nil
            )
        }
        .buttonStyle(.plain)
    }

    private var navigableStages: [UmrahFlowState.Stage] {
        [.start, .tawaf, .postTawaf, .safa, .end]
    }

    private func stageSymbol(_ stage: UmrahFlowState.Stage) -> String {
        switch stage {
        case .start: return "play.fill"
        case .tawaf: return "circle.dashed"
        case .postTawaf: return "hands.sparkles.fill"
        case .safa: return "figure.walk"
        case .end: return "checkmark"
        default: return "circle"
        }
    }

    private func stageTitle(_ stage: UmrahFlowState.Stage) -> String {
        switch stage {
        case .inUmrah:
            return store.text("home1_title", fallback: "Umrah")
        case .start:
            return store.text("umrah_start_title", fallback: "Start Umrah")
        case .tawaf:
            return store.text("tawaf_title", fallback: "Tawaf")
        case .postTawaf:
            return store.text("tawaf_break_title", fallback: "Prayer & Zamzam")
        case .safa:
            return store.text("sai_title", fallback: "Safa & Marwa")
        case .end:
            return store.text("tahallul_title", fallback: "Complete Umrah")
        case .afterUmrah:
            return store.text("home2_3title", fallback: "After Umrah")
        }
    }
}
