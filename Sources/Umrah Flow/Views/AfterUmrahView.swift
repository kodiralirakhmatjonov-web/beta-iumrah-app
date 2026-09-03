import SwiftUI

struct AfterUmrahView: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareLight)

                    Text(store.text("home2_3title", fallback: "Umrah completed"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(store.text("home2_3_subtitle", fallback: "May Allah accept your Umrah and your duas."))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 18)

                afterCard(
                    icon: "scissors",
                    title: store.text("home_3_btn", fallback: "After Umrah"),
                    body: store.text("home_3_btn_sub", fallback: "Review the final practical steps after completing Umrah.")
                )

                afterCard(
                    icon: "doc.text.fill",
                    title: store.text("home_3_btn2", fallback: "Your Umrah"),
                    body: store.text("home_3_btn2_sub", fallback: "Keep this journey with you as a completed Umrah."))

                UmrahFlowPrimaryButton(title: "Done", systemImage: "checkmark") {
                    IumrahHaptics.success()
                    onFinish()
                }

                Button {
                    IumrahHaptics.selection()
                    withAnimation(.easeInOut(duration: 0.28)) { flow.reset() }
                } label: {
                    Text(store.text("home_3_btn3", fallback: "Start another Umrah"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.56))
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func afterCard(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7)
        }
    }
}
