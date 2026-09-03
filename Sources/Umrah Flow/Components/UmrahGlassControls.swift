import SwiftUI

struct UmrahGlassIconButton: View {
    let systemName: String
    var foreground: Color = .white
    var accent: Color? = nil
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 46, height: 46)
                .background((accent ?? Color.white).opacity(accent == nil ? 0.045 : 0.30), in: Circle())
                .iumrahGlass(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct UmrahRitualModeBar: View {
    @Binding var mode: UmrahFlowState.RitualMode
    let onModeChanged: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            modeButton(.listening, title: "Listening", icon: "waveform")
            modeButton(.reading, title: "Reading", icon: "text.book.closed.fill")
        }
        .padding(7)
        .background(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.10), in: Capsule())
        .iumrahGlass(in: Capsule())
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func modeButton(_ candidate: UmrahFlowState.RitualMode, title: String, icon: String) -> some View {
        let selected = mode == candidate
        return Button {
            guard mode != candidate else { return }
            IumrahHaptics.selection()
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                mode = candidate
            }
            onModeChanged()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(selected ? 1 : 0.64))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                selected
                    ? Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.72)
                    : Color.white.opacity(0.025),
                in: Capsule()
            )
            .iumrahGlass(in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
