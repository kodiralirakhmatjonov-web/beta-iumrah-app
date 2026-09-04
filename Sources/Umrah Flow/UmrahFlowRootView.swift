import SwiftUI

struct UmrahFlowRootView: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss

    let guideLanguage: UmrahGuideLanguage

    @StateObject private var flow: UmrahFlowState
    @StateObject private var store: UmrahFlowStore
    @StateObject private var audio = UmrahFlowAudioService()
    @State private var showsNavigator = false

    init(
        initialStage: UmrahFlowState.Stage = .start,
        guideLanguage: UmrahGuideLanguage = .english
    ) {
        self.guideLanguage = guideLanguage
        _flow = StateObject(wrappedValue: UmrahFlowState(initialStage: initialStage))
        _store = StateObject(wrappedValue: UmrahFlowStore(language: guideLanguage))
    }

    var body: some View {
        ZStack {
            UmrahFlowBackground()

            VStack(spacing: 0) {
                UmrahFlowHeader(
                    title: stageTitle,
                    progress: flow.topProgress,
                    advisorTitle: UmrahFlowCopy.advisorTitle(guideLanguage),
                    advisorSubtitle: UmrahFlowCopy.advisorSubtitle(guideLanguage),
                    advisorStatus: advisorStatus,
                    onOpenNavigator: {
                        audio.stop()
                        showsNavigator = true
                    }
                )

                Group {
                    switch flow.stage {
                    case .inUmrah:
                        InUmrahView(flow: flow, store: store)
                    case .start:
                        UmrahStartView(flow: flow, store: store, audio: audio)
                    case .tawaf:
                        TawafView(flow: flow, store: store, audio: audio, showsModeBar: true)
                    case .postTawaf:
                        UmrahView(flow: flow, store: store, audio: audio)
                    case .safa:
                        SafaView(flow: flow, store: store, audio: audio, showsModeBar: true)
                    case .end:
                        UmrahEndView(flow: flow, store: store, audio: audio)
                    case .afterUmrah:
                        AfterUmrahView(flow: flow, store: store, onFinish: close)
                    }
                }
                .id(flow.stage)
                .transition(.opacity)
                .animation(.smooth(duration: 0.44, extraBounce: 0), value: flow.stage)
            }
        }
        // Keep interactive content inside the system safe area. The background and
        // AdvisorVoiceGradient independently extend under the bottom inset, so the
        // aura still reaches the physical screen edge without dragging controls under
        // the Home indicator.
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: guideLanguage.rawValue) {
            await store.load(language: guideLanguage)
        }
        .onChange(of: flow.stage) { _, _ in
            audio.stop()
        }
        .onAppear { chrome.setImmersive(true) }
        .onDisappear {
            audio.stop()
            chrome.setImmersive(false)
        }
        .sheet(isPresented: $showsNavigator) {
            UmrahFlowNavigatorSheet(flow: flow, store: store, onExit: close)
        }
    }

    private func close() {
        audio.stop()
        IumrahHaptics.selection()
        dismiss()
    }

    private var advisorStatus: String? {
        if flow.stage == .inUmrah || flow.stage == .afterUmrah { return nil }
        if flow.stage == .tawaf && flow.tawafMode == .reading { return nil }
        if flow.stage == .safa && flow.safaMode == .reading { return nil }

        if audio.isLoading {
            return UmrahFlowCopy.loadingVoice(guideLanguage)
        }
        if audio.isPlaying {
            return UmrahFlowCopy.advisorSpeaking(guideLanguage)
        }
        return UmrahFlowCopy.tapToListen(guideLanguage)
    }

    private var stageTitle: String {
        UmrahFlowCopy.stageTitle(flow.stage, language: guideLanguage)
    }
}
