import SwiftUI

struct UmrahFlowRootView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var flow: UmrahFlowState
    @StateObject private var store = UmrahFlowStore()
    @StateObject private var audio = UmrahFlowAudioService()
    @State private var showsNavigator = false

    init(initialStage: UmrahFlowState.Stage = .start) {
        _flow = StateObject(wrappedValue: UmrahFlowState(initialStage: initialStage))
    }

    var body: some View {
        ZStack {
            UmrahFlowBackground()

            VStack(spacing: 0) {
                UmrahFlowHeader(
                    title: stageTitle,
                    progress: flow.topProgress,
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
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: settings.language.rawValue) {
            await store.load(language: settings.language)
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
                .environmentObject(settings)
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
            return UmrahFlowCopy.loadingVoice(settings.language)
        }
        if audio.isPlaying {
            return UmrahFlowCopy.advisorSpeaking(settings.language)
        }
        return UmrahFlowCopy.tapToListen(settings.language)
    }

    private var stageTitle: String {
        switch settings.language {
        case .russian:
            switch flow.stage {
            case .inUmrah: return "Умра"
            case .start: return "Начало Умры"
            case .tawaf: return "Таваф"
            case .postTawaf: return "После Тавафа"
            case .safa: return "Сафа и Марва"
            case .end: return "Завершение"
            case .afterUmrah: return "После Умры"
            }
        case .english:
            switch flow.stage {
            case .inUmrah: return "Umrah"
            case .start: return "Start Umrah"
            case .tawaf: return "Tawaf"
            case .postTawaf: return "After Tawaf"
            case .safa: return "Safa & Marwa"
            case .end: return "Complete Umrah"
            case .afterUmrah: return "After Umrah"
            }
        case .uzbek:
            switch flow.stage {
            case .inUmrah: return "Umra"
            case .start: return "Umrani boshlash"
            case .tawaf: return "Tavof"
            case .postTawaf: return "Tavofdan keyin"
            case .safa: return "Safo va Marva"
            case .end: return "Umrani yakunlash"
            case .afterUmrah: return "Umradan keyin"
            }
        case .uzbekCyrillic:
            switch flow.stage {
            case .inUmrah: return "Умра"
            case .start: return "Умрани бошлаш"
            case .tawaf: return "Тавоф"
            case .postTawaf: return "Тавофдан кейин"
            case .safa: return "Сафо ва Марва"
            case .end: return "Умрани якунлаш"
            case .afterUmrah: return "Умрадан кейин"
            }
        }
    }
}
