import SwiftUI

struct UmrahView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    private let audioKeys = ["pray", "zam_zam", "safa_go", "safa_dua"]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                UmrahAdvisorCard(
                    store: store,
                    audio: audio,
                    audioKey: audioKeys[flow.postTawafStep],
                    subtitle: "Voice Guide · \(flow.postTawafStep + 1) / 4"
                )

                VStack(spacing: 18) {
                    Image(systemName: content.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color(red: 0.96, green: 0.38, blue: 0.04))
                        .frame(width: 64, height: 64)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text(content.title)
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let secondary = content.secondary, !secondary.isEmpty {
                        Text(secondary)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                    }

                    Text(content.body)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 310)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
                }

                HStack(spacing: 12) {
                    if flow.postTawafStep > 0 {
                        UmrahFlowSecondaryButton(title: "Back") {
                            audio.stop()
                            IumrahHaptics.selection()
                            withAnimation(.easeInOut(duration: 0.24)) { flow.postTawafStep -= 1 }
                        }
                    }
                    UmrahFlowPrimaryButton(title: continueLabel) {
                        audio.stop()
                        IumrahHaptics.selection()
                        if flow.postTawafStep < 3 {
                            withAnimation(.easeInOut(duration: 0.24)) { flow.postTawafStep += 1 }
                        } else {
                            withAnimation(.easeInOut(duration: 0.28)) { flow.stage = .safa }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var continueLabel: String {
        store.text("continue_btn", fallback: "Continue")
    }

    private var content: (icon: String, title: String, secondary: String?, body: String) {
        switch flow.postTawafStep {
        case 0:
            return (
                "figure.mind.and.body",
                store.text("tawafpray_title1", fallback: "Prayer after Tawaf"),
                nil,
                store.text("tawafpray_text1", fallback: "Pray two rak'ahs when it is appropriate and safe to do so.")
            )
        case 1:
            return (
                "drop.fill",
                store.text("zamzam_title1", fallback: "Zamzam"),
                store.text("zamzam_title", fallback: "Drink Zamzam"),
                store.text("zamzam_text", fallback: "Drink Zamzam and make dua for what is good in this life and the next.")
            )
        case 2:
            return (
                "figure.walk",
                store.text("safago_title", fallback: "Go to Safa"),
                store.text("safago_title1", fallback: nil),
                store.text("safago_text", fallback: "Proceed to Safa to begin Sa'i.")
            )
        default:
            return (
                "hands.sparkles.fill",
                store.text("safadua_title", fallback: "Dua at Safa"),
                nil,
                store.text("start_text3", fallback: "Stand facing the qiblah if possible, remember Allah and make dua before beginning Sa'i.")
            )
        }
    }
}
