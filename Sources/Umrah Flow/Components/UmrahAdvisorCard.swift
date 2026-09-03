import SwiftUI

struct UmrahAdvisorCard: View {
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    let audioKey: String
    var subtitle: String? = nil
    var progress: Double = 0

    @State private var expanded = false

    private var isCurrentPlaying: Bool {
        audio.currentKey == audioKey && audio.isPlaying
    }

    var body: some View {
        Button {
            IumrahHaptics.soft()
            withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                if isCurrentPlaying {
                    audio.stop()
                    expanded = false
                } else {
                    expanded = true
                    audio.toggle(key: audioKey, url: store.audioURL(for: audioKey))
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                progressBar
                    .padding(.bottom, 18)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iumrah Advisor")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(subtitle ?? "Voice Guide")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.035))
                            .frame(width: 46, height: 46)
                            .iumrahGlass(in: Circle())

                        if audio.isLoading, audio.currentKey == audioKey {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        } else {
                            Image(systemName: isCurrentPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: isCurrentPlaying ? 0 : 1)
                        }
                    }
                }

                UmrahAdvisorWave(isActive: isCurrentPlaying)
                    .frame(height: expanded ? 118 : 70)
                    .padding(.top, expanded ? 12 : 2)
                    .animation(.spring(response: 0.62, dampingFraction: 0.86), value: expanded)

                if expanded {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(store.audioURL(for: audioKey) == nil ? Color.white.opacity(0.28) : Color.green.opacity(0.92))
                            .frame(width: 6, height: 6)
                        Text(store.audioURL(for: audioKey) == nil ? "Preparing voice guide…" : (isCurrentPlaying ? "Advisor is speaking" : "Tap to listen"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.48))
                        Spacer()
                        Text("VOICE GUIDE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(.white.opacity(0.30))
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.94),
                                Color(red: 0.075, green: 0.050, blue: 0.030).opacity(0.97)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .strokeBorder(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.62), lineWidth: 1.05)
            }
            .shadow(color: Color(red: 0.96, green: 0.38, blue: 0.04).opacity(expanded ? 0.16 : 0.07), radius: expanded ? 34 : 22, y: 14)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.62, dampingFraction: 0.86), value: expanded)
        .onChange(of: audio.currentKey) { _, key in
            if key != audioKey && expanded {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) { expanded = false }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let normalized = max(0, min(progress, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.13))
                Capsule()
                    .fill(Color(red: 0.96, green: 0.38, blue: 0.04))
                    .frame(width: max(normalized > 0 ? 26 : 0, proxy.size.width * CGFloat(normalized)))
            }
        }
        .frame(height: 14)
    }
}
