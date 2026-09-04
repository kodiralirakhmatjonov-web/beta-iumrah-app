import SwiftUI

struct TawafView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService
    let showsModeBar: Bool

    @State private var showsSunnahDua = false

    var body: some View {
        VStack(spacing: 0) {
            if showsModeBar {
                UmrahRitualModeBar(mode: $flow.tawafMode) {
                    audio.stop()
                }
                .transition(.opacity)
            }

            Group {
                switch flow.tawafMode {
                case .listening:
                    listeningView
                case .reading:
                    TawafReadingPage(flow: flow, store: store)
                }
            }
            .id(flow.tawafMode)
            .transition(.opacity)
            .animation(.smooth(duration: 0.36, extraBounce: 0), value: flow.tawafMode)
        }
        .sheet(isPresented: $showsSunnahDua) {
            SunnahDuaSheet(store: store)
        }
    }

    private var listeningView: some View {
        UmrahVoiceStepScreen(
            store: store,
            audio: audio,
            audioKey: "tawaf_\(flow.tawafRound)",
            kicker: store.text("tawaf_title", fallback: "Tawaf"),
            title: "",
            text: activeText,
            counterText: "\(flow.tawafRound) / 7",
            isArabic: flow.tawafTextMode == 2,
            alignment: flow.tawafTextMode == 2 ? .center : .center,
            allowsTextCycling: true,
            onTextTap: {
                withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                    flow.tawafTextMode = (flow.tawafTextMode + 1) % 3
                }
            },
            showsPrevious: true,
            showsNext: true,
            nextIsDone: flow.tawafRound == 7,
            onPrevious: previousStep,
            onNext: completeRound,
            secondaryActionTitle: store.text("sunna_dua_btn", fallback: "Sunnah Dua"),
            secondaryActionSymbol: "hands.sparkles",
            onSecondaryAction: {
                showsSunnahDua = true
            }
        )
        .id("tawaf-listening-\(flow.tawafRound)")
    }

    private var activeText: String {
        let round = flow.tawafRound
        switch flow.tawafTextMode {
        case 0:
            return store.text("tawaf\(round)_text1", fallback: "Continue Tawaf calmly and keep your attention on worship.")
        case 1:
            return store.text(
                "tawaf\(round)_text2",
                fallback: store.text("tawaf\(round)_text1", fallback: "Make dua while continuing this round.")
            )
        default:
            return store.text(
                "tawaf\(round)_tarab1",
                fallback: store.text("tawaf\(round)_text2", fallback: "Make dua while continuing this round.")
            )
        }
    }

    private func previousStep() {
        audio.stop()
        flow.tawafTextMode = 0
        flow.resetTawafReading()

        if flow.tawafRound > 1 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.tawafRound -= 1
            }
        } else {
            flow.startPhase = 3
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .start
            }
        }
    }

    private func completeRound() {
        audio.stop()
        flow.tawafTextMode = 0
        flow.resetTawafReading()

        if flow.tawafRound < 7 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.tawafRound += 1
            }
        } else {
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .postTawaf
            }
        }
    }
}
