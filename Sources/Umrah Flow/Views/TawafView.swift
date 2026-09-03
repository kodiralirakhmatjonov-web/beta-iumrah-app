import SwiftUI

struct TawafView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService
    @State private var showsSunnahDua = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                UmrahAdvisorCard(
                    store: store,
                    audio: audio,
                    audioKey: "tawaf_\(flow.tawafRound)",
                    subtitle: "Tawaf · Round \(flow.tawafRound)"
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
                        withAnimation(.easeInOut(duration: 0.22)) {
                            flow.tawafTextMode = (flow.tawafTextMode + 1) % 3
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(activeText)
                                .font(.system(size: activeFontSize, weight: flow.tawafTextMode == 2 ? .medium : .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(flow.tawafTextMode == 2 ? .center : .leading)
                                .frame(maxWidth: .infinity, alignment: flow.tawafTextMode == 2 ? .center : .leading)
                                .environment(\.layoutDirection, flow.tawafTextMode == 2 ? .rightToLeft : .leftToRight)
                                .fixedSize(horizontal: false, vertical: true)

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
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
                        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
                        }
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
                                .foregroundStyle(.secondary)
                        }
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showsSunnahDua) {
            SunnahDuaSheet(store: store)
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
        if flow.tawafRound < 7 {
            withAnimation(.easeInOut(duration: 0.28)) { flow.tawafRound += 1 }
        } else {
            withAnimation(.easeInOut(duration: 0.28)) { flow.stage = .postTawaf }
        }
    }
}
