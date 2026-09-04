import SwiftUI

struct SafaView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService
    let showsModeBar: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showsModeBar {
                UmrahRitualModeBar(mode: $flow.safaMode, language: store.guideLanguage) {
                    audio.stop()
                }
                .transition(.opacity)
            }

            Group {
                switch flow.safaMode {
                case .listening:
                    listeningView
                case .reading:
                    SafaReadingPage(flow: flow, store: store)
                }
            }
            .id(flow.safaMode)
            .transition(.opacity)
            .animation(.smooth(duration: 0.36, extraBounce: 0), value: flow.safaMode)
        }
    }

    private var listeningView: some View {
        UmrahVoiceStepScreen(
            store: store,
            audio: audio,
            audioKey: "safa_\(flow.safaRound)",
            kicker: store.text("sai_title", fallback: "Safa & Marwa"),
            title: store.text("safa\(flow.safaRound)_title1", fallback: ""),
            text: activeText,
            counterText: "\(flow.safaRound) / 7",
            allowsTextCycling: true,
            onTextTap: {
                withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                    flow.safaTextMode = (flow.safaTextMode + 1) % 2
                }
            },
            showsPrevious: true,
            showsNext: true,
            nextIsDone: flow.safaRound == 7,
            onPrevious: previousStep,
            onNext: completeRound
        )
        .id("safa-listening-\(flow.safaRound)")
    }

    private var activeText: String {
        if flow.safaTextMode == 0 {
            return store.text(
                "safa\(flow.safaRound)_text1",
                fallback: "Continue Sa'i calmly and remember Allah."
            )
        }

        return store.text(
            "safa\(flow.safaRound)_text2",
            fallback: "Make dua in your own words while continuing this passage."
        )
    }

    private func previousStep() {
        audio.stop()
        flow.safaTextMode = 0
        flow.resetSafaReading()

        if flow.safaRound > 1 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.safaRound -= 1
            }
        } else {
            flow.postTawafStep = 3
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .postTawaf
            }
        }
    }

    private func completeRound() {
        audio.stop()
        flow.safaTextMode = 0
        flow.resetSafaReading()

        if flow.safaRound < 7 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.safaRound += 1
            }
        } else {
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .end
            }
        }
    }
}
