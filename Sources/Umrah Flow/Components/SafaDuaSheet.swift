import SwiftUI

struct SafaDuaSheet: View {
    @ObservedObject var store: UmrahFlowStore
    @Environment(\.dismiss) private var dismiss

    private let arabic = """
اللّٰهُ أَكْبَرُ، اللّٰهُ أَكْبَرُ، اللّٰهُ أَكْبَرُ
لَا إِلٰهَ إِلَّا اللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ
لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ
لَا إِلٰهَ إِلَّا اللّٰهُ وَحْدَهُ
أَنْجَزَ وَعْدَهُ، وَنَصَرَ عَبْدَهُ، وَهَزَمَ الْأَحْزَابَ وَحْدَهُ
"""

    private let transliteration = """
Allāhu akbar, Allāhu akbar, Allāhu akbar. Lā ilāha illallāhu waḥdahu lā sharīka lah, lahul-mulku wa lahul-ḥamd, wa huwa ‘alā kulli shay’in qadīr. Lā ilāha illallāhu waḥdah, anjaza wa‘dah, wa naṣara ‘abdah, wa hazamal-aḥzāba waḥdah.
"""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Text(store.text("overlay_safa_title", fallback: "Dua at Safa and Marwa"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    UmrahGlassIconButton(systemName: "xmark", foreground: .primary, accessibilityLabel: "Close") {
                        dismiss()
                    }
                }

                Text(arabic)
                    .font(.system(size: 27, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .environment(\.layoutDirection, .rightToLeft)

                Text(transliteration)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)

                Text(store.text("overlay_safa_text1", fallback: "Repeat this remembrance, then make your own dua."))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button { dismiss() } label: {
                    Text(store.text("complete_btn", fallback: "Done"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.70), in: Capsule())
                        .iumrahGlass(in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(22)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(40)
        .presentationBackground(.thinMaterial)
    }
}
