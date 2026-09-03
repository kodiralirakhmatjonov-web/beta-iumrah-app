import SwiftUI

struct UmrahEndView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    private let keys = ["end_text", "end_text1", "end_text3"]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                UmrahAdvisorCard(
                    store: store,
                    audio: audio,
                    audioKey: "safa_end",
                    subtitle: "Final Umrah Guidance"
                )

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 78, height: 78)
                        Image(systemName: flow.endPhase == keys.count - 1 ? "checkmark.seal.fill" : "moon.stars.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Color(red: 1.00, green: 0.63, blue: 0.17))
                    }

                    Text(store.text(keys[flow.endPhase], fallback: fallbackText))
                        .font(.system(size: textFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        ForEach(0..<keys.count, id: \.self) { index in
                            Capsule()
                                .fill(index == flow.endPhase ? Color.white : Color.white.opacity(0.18))
                                .frame(width: index == flow.endPhase ? 28 : 8, height: 8)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 330)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
                }

                HStack(spacing: 12) {
                    if flow.endPhase > 0 {
                        UmrahFlowSecondaryButton(title: "Back") {
                            audio.stop()
                            IumrahHaptics.selection()
                            withAnimation(.easeInOut(duration: 0.24)) { flow.endPhase -= 1 }
                        }
                    }

                    UmrahFlowPrimaryButton(
                        title: flow.endPhase == keys.count - 1 ? "Complete Umrah" : store.text("continue_btn", fallback: "Continue"),
                        systemImage: flow.endPhase == keys.count - 1 ? "checkmark" : "arrow.right"
                    ) {
                        audio.stop()
                        IumrahHaptics.selection()
                        if flow.endPhase < keys.count - 1 {
                            withAnimation(.easeInOut(duration: 0.24)) { flow.endPhase += 1 }
                        } else {
                            IumrahHaptics.success()
                            withAnimation(.easeInOut(duration: 0.30)) { flow.stage = .afterUmrah }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var textFontSize: CGFloat {
        let text = store.text(keys[flow.endPhase], fallback: fallbackText)
        return text.count > 190 ? 24 : (text.count > 120 ? 27 : 30)
    }

    private var fallbackText: String {
        switch flow.endPhase {
        case 0: return "You have completed Sa'i. Follow the final guidance carefully."
        case 1: return "Complete the final requirement of Umrah and keep your worship calm and deliberate."
        default: return "Your Umrah is complete. May Allah accept it from you."
        }
    }
}
