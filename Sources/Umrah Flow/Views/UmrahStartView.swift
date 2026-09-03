import SwiftUI

struct UmrahStartView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    private let phaseKeys = ["start_text", "start_text1", "start_text2", "start_text3"]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                UmrahAdvisorCard(
                    store: store,
                    audio: audio,
                    audioKey: "tawaf_start",
                    subtitle: "Umrah Voice Guide",
                    progress: flow.topProgress
                )

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("START")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.42))
                        Spacer()
                        Text("\(flow.startPhase + 1) / \(phaseKeys.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.40))
                    }

                    UmrahAnimatedText(
                        text: store.text(phaseKeys[flow.startPhase], fallback: fallbackText),
                        font: .system(size: instructionFontSize, weight: .bold, design: .rounded),
                        foreground: .white,
                        alignment: .leading,
                        lineSpacing: 5
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 245, alignment: .bottomLeading)
                .padding(22)
                .background(Color.white.opacity(0.022), in: RoundedRectangle(cornerRadius: 42, style: .continuous))
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 42, style: .continuous))

                HStack(spacing: 12) {
                    if flow.startPhase > 0 {
                        UmrahFlowSecondaryButton(title: backLabel) {
                            audio.stop()
                            IumrahHaptics.selection()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) { flow.startPhase -= 1 }
                        }
                    }

                    UmrahFlowPrimaryButton(title: continueLabel) {
                        audio.stop()
                        IumrahHaptics.selection()
                        if flow.startPhase < phaseKeys.count - 1 {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) { flow.startPhase += 1 }
                        } else {
                            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) { flow.stage = .tawaf }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var instructionFontSize: CGFloat {
        let text = store.text(phaseKeys[flow.startPhase], fallback: fallbackText)
        if text.count > 210 { return 25 }
        if text.count > 150 { return 28 }
        if text.count > 100 { return 31 }
        return 35
    }

    private var continueLabel: String {
        store.text("complete_btn", fallback: store.text("continue_btn", fallback: "Continue"))
    }

    private var backLabel: String { "Back" }

    private var fallbackText: String {
        switch flow.startPhase {
        case 0: return "Prepare your intention and begin Umrah calmly. Advisor will guide you step by step."
        case 1: return "Enter the Masjid al-Haram with attention, keeping your intention clear."
        case 2: return "Move toward the beginning of Tawaf and follow the guidance for the first round."
        default: return "When you are ready, continue to Tawaf."
        }
    }
}
