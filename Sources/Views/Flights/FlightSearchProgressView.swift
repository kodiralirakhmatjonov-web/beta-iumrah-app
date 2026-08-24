import SwiftUI

struct FlightSearchProgressView: View {
    @State private var step = 0

    private let labels = [
        "Запускаем поиск",
        "Сравниваем варианты",
        "Убираем дубликаты",
        "Готовим лучшие рейсы"
    ]

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text(labels[min(step, labels.count - 1)])
                .font(.headline)
            Text("Flight Engine")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation { step = min(step + 1, labels.count - 1) }
            }
        }
    }
}
