import SwiftUI

struct UmrahView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    private let audioKeys = ["pray", "zam_zam", "safa_go", "safa_dua"]

    var body: some View {
        UmrahVoiceStepScreen(
            store: store,
            audio: audio,
            audioKey: audioKeys[flow.postTawafStep],
            kicker: content.kicker,
            title: content.title,
            text: content.body,
            counterText: "\(flow.postTawafStep + 1) / 4",
            symbol: content.icon,
            showsPrevious: true,
            showsNext: true,
            nextIsDone: flow.postTawafStep == 3,
            onPrevious: previousStep,
            onNext: nextStep
        )
        .id("post-tawaf-\(flow.postTawafStep)")
    }

    private func previousStep() {
        audio.stop()
        if flow.postTawafStep > 0 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.postTawafStep -= 1
            }
        } else {
            flow.tawafRound = 7
            flow.tawafMode = .listening
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .tawaf
            }
        }
    }

    private func nextStep() {
        audio.stop()
        if flow.postTawafStep < 3 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.postTawafStep += 1
            }
        } else {
            flow.safaRound = 1
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .safa
            }
        }
    }

    private var content: (icon: String, kicker: String, title: String, body: String) {
        switch flow.postTawafStep {
        case 0:
            return (
                "hands.sparkles.fill",
                store.text("tawaf_break_title", fallback: "After Tawaf"),
                store.text("tawafpray_title1", fallback: "Prayer after Tawaf"),
                store.text("tawafpray_text1", fallback: "Pray two rak'ahs when it is appropriate and safe to do so.")
            )
        case 1:
            return (
                "drop.fill",
                store.text("zamzam_title", fallback: "Zamzam"),
                store.text("zamzam_title1", fallback: "Drink Zamzam"),
                store.text("zamzam_text", fallback: "Drink Zamzam and make dua for what is good in this life and the next.")
            )
        case 2:
            return (
                "figure.walk",
                store.text("safago_title", fallback: "Go to Safa"),
                store.text("safago_title1", fallback: "Proceed to Safa"),
                store.text("safago_text", fallback: "Proceed to Safa to begin Sa'i.")
            )
        default:
            return (
                "hands.sparkles.fill",
                store.text("safadua_title", fallback: "Dua at Safa"),
                store.text("safadua_title", fallback: "Dua at Safa"),
                store.text("start_text3", fallback: "Stand facing the qiblah if possible, remember Allah and make dua before beginning Sa'i.")
            )
        }
    }
}
