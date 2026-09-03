import SwiftUI

struct UmrahFlowPrimaryButton: View {
    let title: String
    var systemImage: String? = "arrow.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct UmrahFlowSecondaryButton: View {
    let title: String
    var systemImage: String? = "chevron.left"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct UmrahRoundSwipeControl: View {
    let round: Int
    let total: Int
    let label: String
    let onComplete: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var completed = false

    var body: some View {
        GeometryReader { proxy in
            let height: CGFloat = 76
            let knob: CGFloat = 60
            let maxDrag = max(0, proxy.size.width - knob - 16)
            let progress = maxDrag > 0 ? min(max(dragX / maxDrag, 0), 1) : 0

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 0.96, green: 0.38, blue: 0.04))
                    .frame(width: max(knob + 16, 16 + knob + dragX))

                HStack {
                    Spacer()
                    VStack(spacing: 1) {
                        Text("\(round) / \(total)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .padding(.trailing, 18)
                }

                Circle()
                    .fill(Color(red: 0.96, green: 0.38, blue: 0.04))
                    .overlay {
                        Image(systemName: completed ? "checkmark" : "chevron.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
                    .offset(x: 8 + dragX)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                guard !completed else { return }
                                dragX = min(max(value.translation.width, 0), maxDrag)
                            }
                            .onEnded { _ in
                                guard !completed else { return }
                                if progress >= 0.90 {
                                    completed = true
                                    dragX = maxDrag
                                    IumrahHaptics.success()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        onComplete()
                                        completed = false
                                        dragX = 0
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                        dragX = 0
                                    }
                                }
                            }
                    )
            }
            .frame(height: height)
        }
        .frame(height: 76)
    }
}
