import SwiftUI

struct UmrahFlowHeader: View {
    let title: String
    let progress: Double
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08), in: Circle())
                        .overlay { Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.7) }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("iumrah")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.46))
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("\(Int((max(0, min(progress, 1)) * 100).rounded()))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            GeometryReader { proxy in
                let width = max(0, min(proxy.size.width, proxy.size.width * CGFloat(progress)))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.66, blue: 0.24),
                                    Color(red: 0.96, green: 0.37, blue: 0.04)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}
