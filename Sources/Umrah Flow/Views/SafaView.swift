import SwiftUI

struct SafaView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService
    let showsModeBar: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showsModeBar {
                UmrahRitualModeBar(mode: $flow.safaMode) {
                    audio.stop()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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
            .transition(.opacity.combined(with: .scale(scale: 0.992)))
            .animation(.spring(response: 0.42, dampingFraction: 0.90), value: flow.safaMode)
        }
    }

    private var listeningView: some View {
        ScrollView {
            VStack(spacing: 20) {
                UmrahAdvisorCard(
                    store: store,
                    audio: audio,
                    audioKey: "safa_\(flow.safaRound)",
                    subtitle: "Safa & Marwa · Round \(flow.safaRound)",
                    progress: flow.topProgress
                )

                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Safa & Marwa")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(store.text("safa\(flow.safaRound)_title1", fallback: "Round \(flow.safaRound)"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()

                        ZStack {
                            Circle().stroke(Color.white.opacity(0.10), lineWidth: 7)
                            Circle()
                                .trim(from: 0, to: Double(flow.safaRound) / 7.0)
                                .stroke(
                                    Color(red: 0.96, green: 0.38, blue: 0.04),
                                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            Text("\(flow.safaRound)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 58, height: 58)
                    }

                    TabView(selection: $flow.safaTextMode) {
                        safaTextPage(
                            label: "Guidance",
                            text: store.text(
                                "safa\(flow.safaRound)_text1",
                                fallback: "Continue Sa'i calmly and remember Allah."
                            ),
                            arabic: nil
                        )
                        .tag(0)

                        safaTextPage(
                            label: "Dua",
                            text: store.text(
                                "safa\(flow.safaRound)_text2",
                                fallback: "Make dua in your own words while continuing this passage."
                            ),
                            arabic: store.text("safa\(flow.safaRound)_sarab1", fallback: "")
                        )
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(minHeight: 270)

                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { index in
                            Capsule()
                                .fill(index == flow.safaTextMode ? Color.white : Color.white.opacity(0.18))
                                .frame(width: index == flow.safaTextMode ? 26 : 8, height: 8)
                        }
                    }
                }

                UmrahRoundSwipeControl(
                    round: flow.safaRound,
                    total: 7,
                    label: store.text("tap_btn", fallback: "complete passage")
                ) {
                    completeRound()
                }
                .id("safa-\(flow.safaRound)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func safaTextPage(label: String, text: String, arabic: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.34))

                UmrahAnimatedText(
                    text: text,
                    font: .system(size: text.count > 220 ? 20 : 23, weight: .semibold, design: .rounded),
                    foreground: .white,
                    alignment: .leading,
                    lineSpacing: 5
                )

                if let arabic, !arabic.isEmpty {
                    Divider().overlay(Color.white.opacity(0.10))
                    UmrahAnimatedText(
                        text: arabic,
                        font: .system(size: 24, weight: .medium, design: .rounded),
                        foreground: .white.opacity(0.78),
                        alignment: .center,
                        lineSpacing: 8,
                        isArabic: true
                    )
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 38, style: .continuous))
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 38, style: .continuous))
    }

    private func completeRound() {
        audio.stop()
        flow.safaTextMode = 0
        flow.resetSafaReading()
        if flow.safaRound < 7 {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) { flow.safaRound += 1 }
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) { flow.stage = .end }
        }
    }
}
