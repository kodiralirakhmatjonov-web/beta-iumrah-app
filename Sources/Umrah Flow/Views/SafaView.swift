import SwiftUI

struct SafaView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                UmrahAdvisorCard(
                    store: store,
                    audio: audio,
                    audioKey: "safa_\(flow.safaRound)",
                    subtitle: "Safa & Marwa · Round \(flow.safaRound)"
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
            .padding(.vertical, 16)
        }
    }

    private func safaTextPage(label: String, text: String, arabic: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.34))

                Text(text)
                    .font(.system(size: text.count > 220 ? 20 : 23, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let arabic, !arabic.isEmpty {
                    Divider().overlay(Color.white.opacity(0.10))
                    Text(arabic)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
        }
    }

    private func completeRound() {
        audio.stop()
        flow.safaTextMode = 0
        if flow.safaRound < 7 {
            withAnimation(.easeInOut(duration: 0.28)) { flow.safaRound += 1 }
        } else {
            withAnimation(.easeInOut(duration: 0.28)) { flow.stage = .end }
        }
    }
}
