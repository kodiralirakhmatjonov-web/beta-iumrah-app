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
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)
            .background(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(0.70), in: Capsule())
            .iumrahGlass(in: Capsule())
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
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(Color.white.opacity(0.025), in: Capsule())
            .iumrahGlass(in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct UmrahRoundSwipeControl: View {
    let round: Int
    let total: Int
    let label: String
    var isEnabled: Bool = true
    let onComplete: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var completed = false
    @State private var lastHapticBucket = -1

    var body: some View {
        GeometryReader { proxy in
            let height: CGFloat = 82
            let knob: CGFloat = 64
            let maxDrag = max(0, proxy.size.width - knob - 18)
            let progress = maxDrag > 0 ? min(max(dragX / maxDrag, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.035))
                    .iumrahGlass(in: Capsule())

                Capsule()
                    .fill(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(isEnabled ? 0.60 : 0.18))
                    .frame(width: max(knob + 18, 18 + knob + dragX))

                HStack {
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.13), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: Double(round) / Double(max(total, 1)))
                            .stroke(
                                Color(red: 1.00, green: 0.54, blue: 0.10),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        Text("\(round)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 58, height: 58)
                    .padding(.trailing, 11)
                }

                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.52 : 0.30))
                    .lineLimit(2)
                    .padding(.leading, 92)
                    .padding(.trailing, 78)

                Circle()
                    .fill(Color(red: 0.96, green: 0.38, blue: 0.04).opacity(isEnabled ? 0.90 : 0.36))
                    .overlay {
                        Image(systemName: completed ? "checkmark" : "chevron.right")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.48))
                    }
                    .frame(width: knob, height: knob)
                    .iumrahGlass(in: Circle())
                    .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
                    .offset(x: 9 + dragX)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                guard isEnabled, !completed else { return }
                                dragX = min(max(value.translation.width, 0), maxDrag)
                                let bucket = Int((progress * 8).rounded(.down))
                                if bucket != lastHapticBucket, bucket > 0, bucket < 8 {
                                    lastHapticBucket = bucket
                                    IumrahHaptics.selection()
                                }
                            }
                            .onEnded { _ in
                                guard isEnabled, !completed else { return }
                                if progress >= 0.90 {
                                    completed = true
                                    dragX = maxDrag
                                    IumrahHaptics.success()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        onComplete()
                                        completed = false
                                        dragX = 0
                                        lastHapticBucket = -1
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                        dragX = 0
                                        lastHapticBucket = -1
                                    }
                                }
                            }
                    )
            }
            .frame(height: height)
            .opacity(isEnabled ? 1 : 0.68)
        }
        .frame(height: 82)
    }
}
