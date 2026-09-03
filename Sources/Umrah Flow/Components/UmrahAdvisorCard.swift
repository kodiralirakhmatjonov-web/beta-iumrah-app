import SwiftUI

struct UmrahAdvisorCard: View {
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    let audioKey: String
    var subtitle: String? = nil

    private var isCurrentPlaying: Bool {
        audio.currentKey == audioKey && audio.isPlaying
    }

    var body: some View {
        Button {
            IumrahHaptics.soft()
            audio.toggle(key: audioKey, url: store.audioURL(for: audioKey))
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iumrah Advisor")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(subtitle ?? "Voice Guide")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer(minLength: 8)

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 42, height: 42)
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
                    .frame(height: isCurrentPlaying ? 76 : 54)
                    .animation(.spring(response: 0.46, dampingFraction: 0.84), value: isCurrentPlaying)

                HStack(spacing: 7) {
                    Circle()
                        .fill(store.audioURL(for: audioKey) == nil ? Color.white.opacity(0.28) : Color.green.opacity(0.92))
                        .frame(width: 6, height: 6)
                    Text(store.audioURL(for: audioKey) == nil ? "Preparing voice guide…" : (isCurrentPlaying ? "Advisor is speaking" : "Tap to listen"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                    Spacer()
                    Text("SUPABASE AUDIO")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.30))
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.black, Color(red: 0.085, green: 0.075, blue: 0.065)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color(red: 0.97, green: 0.42, blue: 0.06).opacity(0.46), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.30), radius: 28, y: 16)
        }
        .buttonStyle(.plain)
    }
}
