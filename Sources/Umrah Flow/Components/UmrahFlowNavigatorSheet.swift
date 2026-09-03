import SwiftUI

struct UmrahFlowNavigatorSheet: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    let onExit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStage: UmrahFlowState.Stage

    init(flow: UmrahFlowState, store: UmrahFlowStore, onExit: @escaping () -> Void) {
        self.flow = flow
        self.store = store
        self.onExit = onExit
        _selectedStage = State(initialValue: flow.stage)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Umrah Flow")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Choose a stage or leave Umrah")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                UmrahGlassIconButton(
                    systemName: "xmark",
                    foreground: .primary,
                    accessibilityLabel: store.text("close_button", fallback: "Close")
                ) { dismiss() }
            }

            Picker("Umrah stage", selection: $selectedStage) {
                ForEach(navigableStages, id: \.self) { stage in
                    Text(stageTitle(stage)).tag(stage)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity, minHeight: 170)
            .clipped()
            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))

            Button {
                IumrahHaptics.selection()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    flow.stage = selectedStage
                }
                dismiss()
            } label: {
                Text(store.text("navigate_button", fallback: "Go"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.70), in: Capsule())
                    .iumrahGlass(in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                IumrahHaptics.selection()
                dismiss()
            } label: {
                Text(store.text("close_button", fallback: "Close"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.primary.opacity(0.025), in: Capsule())
                    .iumrahGlass(in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                IumrahHaptics.soft()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    onExit()
                }
            } label: {
                Text(store.text("cancel_omra", fallback: "Exit Umrah"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color.red.opacity(0.72), in: Capsule())
                    .iumrahGlass(in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .presentationDetents([.fraction(0.64), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(.thinMaterial)
    }

    private var navigableStages: [UmrahFlowState.Stage] {
        [.start, .tawaf, .postTawaf, .safa, .end]
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
