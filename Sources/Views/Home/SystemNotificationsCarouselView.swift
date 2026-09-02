import SwiftUI

struct SystemNotificationsCarouselView: View {
    let notifications: [ClientSystemNotification]
    let onOpen: (ClientSystemNotification) -> Void
    let onDismiss: (ClientSystemNotification) -> Void

    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("iumrah Signal", systemImage: "bell.badge.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                if notifications.count > 1 {
                    Text("\(selectedIndex + 1)/\(notifications.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
            }

            GeometryReader { proxy in
                TabView(selection: $selectedIndex) {
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                        SystemNotificationCard(
                            notification: notification,
                            onOpen: { onOpen(notification) },
                            onDismiss: { onDismiss(notification) }
                        )
                        .frame(width: max(0, proxy.size.width - 2), height: proxy.size.height)
                        .padding(.vertical, 2)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
            }
            .frame(height: 176)

            if notifications.count > 1 {
                HStack(spacing: 7) {
                    Spacer(minLength: 0)
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { index, _ in
                        Capsule(style: .continuous)
                            .fill(index == selectedIndex ? Color.primary.opacity(0.88) : Color.secondary.opacity(0.22))
                            .frame(width: index == selectedIndex ? 18 : 7, height: 7)
                            .animation(.spring(response: 0.26, dampingFraction: 0.88), value: selectedIndex)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 22, y: 10)
        .onAppear {
            selectedIndex = boundedSelection(selectedIndex)
        }
        .onChange(of: notifications.map(\.id)) { _, _ in
            selectedIndex = boundedSelection(selectedIndex)
        }
    }

    private func boundedSelection(_ value: Int) -> Int {
        guard !notifications.isEmpty else { return 0 }
        return min(max(0, value), notifications.count - 1)
    }
}
