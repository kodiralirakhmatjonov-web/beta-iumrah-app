import SwiftUI

struct UmrahGlassIconButton: View {
    let systemName: String
    var foreground: Color? = nil
    var accent: Color? = nil
    var accessibilityLabel: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(foreground ?? palette.textPrimary)
                .frame(width: 46, height: 46)
                .background(
                    (accent ?? palette.glassTint).opacity(accent == nil ? 1 : 0.48),
                    in: Circle()
                )
                .iumrahGlass(in: Circle())
                .overlay {
                    Circle().stroke(palette.glassStroke, lineWidth: 0.65)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.07), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct UmrahRitualModeBar: View {
    @Binding var mode: UmrahFlowState.RitualMode
    let onModeChanged: () -> Void

    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        HStack(spacing: 6) {
            modeButton(.listening, title: UmrahFlowCopy.listening(settings.language), icon: "waveform")
            modeButton(.reading, title: UmrahFlowCopy.reading(settings.language), icon: "text.book.closed")
        }
        .padding(5)
        .background(palette.glassTint, in: Capsule())
        .iumrahGlass(in: Capsule())
        .overlay { Capsule().stroke(palette.glassStroke, lineWidth: 0.65) }
        .padding(.horizontal, 74)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func modeButton(_ candidate: UmrahFlowState.RitualMode, title: String, icon: String) -> some View {
        let selected = mode == candidate

        return Button {
            guard mode != candidate else { return }
            IumrahHaptics.selection()
            withAnimation(.smooth(duration: 0.30, extraBounce: 0)) {
                mode = candidate
            }
            onModeChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.white : palette.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(selected ? palette.accent.opacity(0.78) : Color.clear, in: Capsule())
            .animation(.smooth(duration: 0.28, extraBounce: 0), value: selected)
        }
        .buttonStyle(.plain)
    }
}
