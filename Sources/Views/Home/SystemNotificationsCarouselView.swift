import SwiftUI

struct SystemNotificationsCarouselView: View {
    let notifications: [ClientSystemNotification]
    let onOpen: (ClientSystemNotification) -> Void
    let onDismiss: (ClientSystemNotification) -> Void

    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                TabView(selection: $selectedIndex) {
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                        SystemNotificationCard(
                            notification: notification,
                            onOpen: { onOpen(notification) },
                            onDismiss: { onDismiss(notification) }
                        )
                        .frame(width: proxy.size.width)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(height: 192)

            if notifications.count > 1 {
                HStack(spacing: 7) {
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { index, _ in
                        Capsule(style: .continuous)
                            .fill(index == selectedIndex ? Color.primary.opacity(0.88) : Color.secondary.opacity(0.22))
                            .frame(width: index == selectedIndex ? 18 : 7, height: 7)
                            .animation(.spring(response: 0.26, dampingFraction: 0.88), value: selectedIndex)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
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
