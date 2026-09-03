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
                .transition(.opacity.combined(with: .move(edge: .top)))
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
            .transition(.opacity.combined(with: .scale(scale: 0.992)))
            .animation(.spring(response: 0.42, dampingFraction: 0.90), value: flow.tawafMode)
        }
        .sheet(isPresented: $showsSunnahDua) {
            SunnahDuaSheet(store: store)
        }
    }

    private var listeningView: some View {
        ScrollView {
            VStack(spacing: 20) {
                UmrahAdvisorCard(
                    store: store,
                    audio: audio,
                    audioKey: "tawaf_\(flow.tawafRound)",
                    subtitle: "Tawaf · Round \(flow.tawafRound)",
                    progress: flow.topProgress
                )

                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.text("tawaf_title", fallback: "Tawaf"))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Round \(flow.tawafRound) of 7")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.44))
                        }
                        Spacer()

                        ZStack {
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 7)
                            Circle()
                                .trim(from: 0, to: Double(flow.tawafRound) / 7.0)
                                .stroke(
                                    Color(red: 0.96, green: 0.38, blue: 0.04),
                                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            Text("\(flow.tawafRound)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 58, height: 58)
                    }

                    Button {
                        IumrahHaptics.selection()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) {
                            flow.tawafTextMode = (flow.tawafTextMode + 1) % 3
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            UmrahAnimatedText(
                                text: activeText,
                                font: .system(size: activeFontSize, weight: flow.tawafTextMode == 2 ? .medium : .semibold, design: .rounded),
                                foreground: .white,
                                alignment: flow.tawafTextMode == 2 ? .center : .leading,
                                lineSpacing: 5,
                                isArabic: flow.tawafTextMode == 2
                            )

                            HStack {
                                HStack(spacing: 7) {
                                    ForEach(0..<3, id: \.self) { index in
                                        Capsule()
                                            .fill(index == flow.tawafTextMode ? Color.white : Color.white.opacity(0.18))
                                            .frame(width: index == flow.tawafTextMode ? 22 : 7, height: 7)
                                    }
                                }
                                Spacer()
                                Label("Tap to change", systemImage: "hand.tap.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.34))
                            }
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, minHeight: 238, alignment: .topLeading)
                        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 38, style: .continuous))
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 38, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        IumrahHaptics.soft()
                        showsSunnahDua = true
                    } label: {
                        HStack {
                            Image(systemName: "hands.sparkles.fill")
                            Text(store.text("sunna_dua_btn", fallback: "Sunnah Dua"))
                            Spacer()
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.bold))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.025), in: Capsule())
                        .iumrahGlass(in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                UmrahRoundSwipeControl(
                    round: flow.tawafRound,
                    total: 7,
                    label: store.text("tap_btn", fallback: "complete round")
                ) {
                    completeRound()
                }
                .id("tawaf-\(flow.tawafRound)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var activeText: String {
        let r = flow.tawafRound
        switch flow.tawafTextMode {
        case 0:
            return store.text("tawaf\(r)_text1", fallback: "Continue Tawaf calmly and keep your attention on worship.")
        case 1:
            return store.text("tawaf\(r)_text2", fallback: store.text("tawaf\(r)_text1", fallback: "Make dua while continuing this round."))
        default:
            return store.text("tawaf\(r)_tarab1", fallback: store.text("tawaf\(r)_text2", fallback: "Make dua while continuing this round."))
        }
    }

    private var activeFontSize: CGFloat {
        if flow.tawafTextMode == 2 { return 25 }
        if activeText.count > 250 { return 20 }
        if activeText.count > 160 { return 22 }
        return 25
    }

    private func completeRound() {
        audio.stop()
        flow.tawafTextMode = 0
        flow.resetTawafReading()
        if flow.tawafRound < 7 {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) { flow.tawafRound += 1 }
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) { flow.stage = .postTawaf }
        }
    }
}
