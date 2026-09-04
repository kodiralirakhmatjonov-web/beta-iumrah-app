import SwiftUI

struct SunnahDuaSheet: View {
    @ObservedObject var store: UmrahFlowStore

    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ZStack {
            sheetBackground

            ScrollView {
                VStack(spacing: 24) {
                    header

                    Text(store.text("tawaf_common_text3", fallback: "Between the Yemeni Corner and the Black Stone"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.3)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(palette.glassTint, in: Capsule())
                        .iumrahGlass(in: Capsule())

                    UmrahAnimatedText(
                        text: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً، وَفِي الآخِرَةِ حَسَنَةً، وَقِنَا عَذَابَ النَّارِ",
                        font: .system(size: 28, weight: .medium, design: .rounded),
                        foreground: palette.textPrimary,
                        alignment: .center,
                        lineSpacing: 11,
                        isArabic: true
                    )

                    Text("Rabbana atina fid-dunya hasanatan, wa fil-akhirati hasanatan, wa qina adhaban-nar")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)

                    Text(store.text("tawaf_common_text2", fallback: "You may also make any permissible dua."))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(palette.glassTint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Text(store.text("tawaf_common_text4", fallback: "Ask Allah in your own words."))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)

                    Text(store.text("tawaf_common_text1", fallback: "Keep your heart present and continue Tawaf calmly."))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 34)
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
            VStack(alignment: .leading, spacing: 3) {
                Text(store.text("sunnah_dua_title", fallback: "Sunnah Dua"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                Text(store.text("tawaf_title", fallback: "Tawaf"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
            }

            Spacer()

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
                colors: [
                    palette.progressStart.opacity(colorScheme == .dark ? 0.10 : 0.07),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [
                    palette.progressEnd.opacity(colorScheme == .dark ? 0.08 : 0.06),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 340
            )
        }
        .ignoresSafeArea()
    }
}
