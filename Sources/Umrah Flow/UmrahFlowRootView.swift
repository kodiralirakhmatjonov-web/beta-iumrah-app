import SwiftUI

struct UmrahFlowRootView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var flow: UmrahFlowState
    @StateObject private var store = UmrahFlowStore()
    @StateObject private var audio = UmrahFlowAudioService()
    @State private var showsNavigator = false
    @State private var showsRitualModeBar = true

    init(initialStage: UmrahFlowState.Stage = .start) {
        _flow = StateObject(wrappedValue: UmrahFlowState(initialStage: initialStage))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.94, green: 0.32, blue: 0.03).opacity(0.23),
                    Color.black.opacity(0)
                ],
                center: .bottom,
                startRadius: 20,
                endRadius: 470
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                UmrahFlowHeader(
                    title: stageTitle,
                    progress: flow.topProgress,
                    showsModeToggle: supportsRitualModeBar,
                    isModeBarVisible: showsRitualModeBar,
                    onToggleModeBar: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.90)) {
                            showsRitualModeBar.toggle()
                        }
                    },
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
                        TawafView(flow: flow, store: store, audio: audio, showsModeBar: showsRitualModeBar)
                    case .postTawaf:
                        UmrahView(flow: flow, store: store, audio: audio)
                    case .safa:
                        SafaView(flow: flow, store: store, audio: audio, showsModeBar: showsRitualModeBar)
                    case .end:
                        UmrahEndView(flow: flow, store: store, audio: audio)
                    case .afterUmrah:
                        AfterUmrahView(flow: flow, store: store, onFinish: close)
                    }
                }
                .id(flow.stage)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .animation(.spring(response: 0.48, dampingFraction: 0.90), value: flow.stage)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .task(id: settings.language.rawValue) {
            await store.load(language: settings.language)
        }
        .onChange(of: flow.stage) { _, _ in
            audio.stop()
            showsRitualModeBar = true
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

    private var supportsRitualModeBar: Bool {
        flow.stage == .tawaf || flow.stage == .safa
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
        case .uzbek, .uzbekCyrillic:
            switch flow.stage {
            case .inUmrah: return "Umra"
            case .start: return "Umrani boshlash"
            case .tawaf: return "Tavof"
            case .postTawaf: return "Tavofdan keyin"
            case .safa: return "Safo va Marva"
            case .end: return "Umrani yakunlash"
            case .afterUmrah: return "Umradan keyin"
            }
        }
    }
}
