import SwiftUI

struct InUmrahView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    UmrahAnimatedText(
                        text: store.text("home1_title", fallback: "Your Umrah"),
                        font: .system(size: 36, weight: .bold, design: .rounded),
                        foreground: .white,
                        alignment: .leading
                    )
                    UmrahAnimatedText(
                        text: store.text("home1_sub", fallback: "A step-by-step Umrah with iumrah Advisor."),
                        font: .title3.weight(.medium),
                        foreground: .white.opacity(0.58),
                        alignment: .leading
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color(red: 0.98, green: 0.47, blue: 0.08))
                    Text("iumrah Advisor")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(store.text("home1_btn3_sub", fallback: "Voice guidance stays with you through Tawaf, Sa'i and the final steps."))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.022), in: RoundedRectangle(cornerRadius: 42, style: .continuous))
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 42, style: .continuous))

                UmrahFlowPrimaryButton(
                    title: store.text("home1_btn", fallback: "Start Umrah"),
                    systemImage: "play.fill"
                ) {
                    IumrahHaptics.success()
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) { flow.stage = .start }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
}
