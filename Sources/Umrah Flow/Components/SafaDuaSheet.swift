import SwiftUI

struct SafaDuaSheet: View {
    @ObservedObject var store: UmrahFlowStore

    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

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
        ZStack {
            sheetBackground

            ScrollView {
                VStack(spacing: 24) {
                    header

                    UmrahAnimatedText(
                        text: arabic,
                        font: .system(size: 25, weight: .medium, design: .rounded),
                        foreground: palette.textPrimary,
                        alignment: .center,
                        lineSpacing: 10,
                        isArabic: true
                    )

                    Text(transliteration)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)

                    Text(store.text("overlay_safa_text1", fallback: "Repeat this remembrance, then make your own dua."))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(palette.glassTint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Button {
                        IumrahHaptics.selection()
                        dismiss()
                    } label: {
                        Text(store.text("complete_btn", fallback: UmrahFlowCopy.done(settings.language)))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(palette.accent.opacity(0.78), in: Capsule())
                            .iumrahGlass(in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
        .presentationBackground(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(store.text("overlay_safa_title", fallback: "Dua at Safa and Marwa"))
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 12)

            UmrahGlassIconButton(
                systemName: "xmark",
                foreground: palette.textPrimary,
                accessibilityLabel: store.text("close_button", fallback: "Close")
            ) {
                dismiss()
            }
        }
    }

    private var sheetBackground: some View {
        ZStack {
            palette.background.opacity(colorScheme == .dark ? 0.94 : 0.86)
            RadialGradient(
                colors: [palette.progressStart.opacity(colorScheme == .dark ? 0.10 : 0.07), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [palette.progressEnd.opacity(colorScheme == .dark ? 0.08 : 0.06), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }
}
