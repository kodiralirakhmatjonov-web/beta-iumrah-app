import SwiftUI

struct SystemNotificationCard: View {
    let notification: ClientSystemNotification
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 9) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.15), in: Circle())

                    Text("iumrah Signal")
                        .font(.caption.weight(.bold))
                        .tracking(0.75)

                    Spacer()

                    if !notification.isRead {
                        Text("NEW")
                            .font(.caption2.weight(.black))
                            .tracking(0.65)
                            .padding(.horizontal, 9)
                            .frame(height: 25)
                            .background(Color.white, in: Capsule())
                            .foregroundStyle(Color.iumrahCareDark)
                    }
                }

                Text(notification.title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Image(systemName: destinationIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.10), in: Circle())
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
            }
            .foregroundStyle(.white)
            .padding(19)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Color.iumrahCareDark, Color(red: 0.12, green: 0.44, blue: 0.25), Color.iumrahCareLight.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(Color.white.opacity(0.11))
                        .frame(width: 180, height: 180)
                        .offset(x: 150, y: -95)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
            }
            .shadow(color: Color.iumrahCareDark.opacity(0.23), radius: 25, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("iumrah Signal. \(notification.title). \(notification.body)")
    }

    private var destinationIcon: String {
        switch notification.destination {
        case "hotels": return "building.2.fill"
        case "bookings", "booking": return "suitcase.fill"
        case "care": return "heart.fill"
        case "account": return "person.crop.circle.fill"
        default: return "house.fill"
        }
    }
}
