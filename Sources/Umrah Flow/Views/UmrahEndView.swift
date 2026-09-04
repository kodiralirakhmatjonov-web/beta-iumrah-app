import SwiftUI

struct UmrahEndView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    private let keys = ["end_text", "end_text1", "end_text3"]

    var body: some View {
        UmrahVoiceStepScreen(
            store: store,
            audio: audio,
            audioKey: "safa_end",
            kicker: store.text("tahallul_title", fallback: "Complete Umrah"),
            title: "",
            text: store.text(keys[flow.endPhase], fallback: fallbackText),
            counterText: "\(flow.endPhase + 1) / \(keys.count)",
            symbol: flow.endPhase == keys.count - 1 ? "checkmark.seal.fill" : "scissors",
            showsPrevious: true,
            showsNext: true,
            nextIsDone: flow.endPhase == keys.count - 1,
            onPrevious: previousStep,
            onNext: nextStep
        )
        .id("umrah-end-\(flow.endPhase)")
    }

    private func previousStep() {
        audio.stop()
        if flow.endPhase > 0 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.endPhase -= 1
            }
        } else {
            flow.safaRound = 7
            flow.safaMode = .listening
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .safa
            }
        }
    }

    private func nextStep() {
        audio.stop()
        if flow.endPhase < keys.count - 1 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.endPhase += 1
            }
        } else {
            IumrahHaptics.success()
            withAnimation(.smooth(duration: 0.44, extraBounce: 0)) {
                flow.stage = .afterUmrah
            }
        }
    }

    private var fallbackText: String {
        switch flow.endPhase {
        case 0: return "You have completed Sa'i. Follow the final guidance carefully."
        case 1: return "Complete the final requirement of Umrah and keep your worship calm and deliberate."
        default: return "Your Umrah is complete. May Allah accept it from you."
        }
    }
}
