import SwiftUI

struct UmrahStartView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    private let phaseKeys = ["start_text", "start_text1", "start_text2", "start_text3"]

    var body: some View {
        UmrahVoiceStepScreen(
            store: store,
            audio: audio,
            audioKey: "tawaf_start",
            kicker: store.text("umrah_start_title", fallback: "Start Umrah"),
            title: "",
            text: store.text(phaseKeys[flow.startPhase], fallback: fallbackText),
            counterText: "\(flow.startPhase + 1) / \(phaseKeys.count)",
            showsPrevious: flow.startPhase > 0,
            showsNext: true,
            nextIsDone: flow.startPhase == phaseKeys.count - 1,
            onPrevious: {
                audio.stop()
                guard flow.startPhase > 0 else { return }
                withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                    flow.startPhase -= 1
                }
            },
            onNext: {
                audio.stop()
                if flow.startPhase < phaseKeys.count - 1 {
                    withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                        flow.startPhase += 1
                    }
                } else {
                    withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                        flow.stage = .tawaf
                    }
                }
            }
        )
    }

    private var fallbackText: String {
        switch flow.startPhase {
        case 0: return "Prepare your intention and begin Umrah calmly. Advisor will guide you step by step."
        case 1: return "Enter the Masjid al-Haram with attention, keeping your intention clear."
        case 2: return "Move toward the beginning of Tawaf and follow the guidance for the first round."
        default: return "When you are ready, continue to Tawaf."
        }
    }
}
