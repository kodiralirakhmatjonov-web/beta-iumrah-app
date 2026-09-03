import SwiftUI

struct SunnahDuaSheet: View {
    @ObservedObject var store: UmrahFlowStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sunnah Dua")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Tawaf")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    UmrahGlassIconButton(systemName: "xmark", foreground: .primary, accessibilityLabel: "Close") {
                        dismiss()
                    }
                }

                Text(store.text("tawaf_common_text3", fallback: "Between the Yemeni Corner and the Black Stone"))
                    .font(.caption.weight(.bold))
                    .tracking(0.35)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.03), in: Capsule())
                    .iumrahGlass(in: Capsule())

                Text("رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً، وَفِي الآخِرَةِ حَسَنَةً، وَقِنَا عَذَابَ النَّارِ")
                    .font(.system(size: 29, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .lineSpacing(12)

                Text("Rabbana atina fid-dunya hasanatan, wa fil-akhirati hasanatan, wa qina adhaban-nar")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)

                Text(store.text("tawaf_common_text2", fallback: "You may also make any permissible dua."))
                    .font(.caption.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text(store.text("tawaf_common_text4", fallback: "Ask Allah in your own words."))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(store.text("tawaf_common_text1", fallback: "Keep your heart present and continue Tawaf calmly."))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(22)
            .padding(.bottom, 24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(40)
        .presentationBackground(.thinMaterial)
    }
}
