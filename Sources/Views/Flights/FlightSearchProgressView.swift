import SwiftUI

struct FlightSearchProgressView: View {
    @State private var step = 0

    private let labels = [
        "Проверяем авиакомпании",
        "Сравниваем актуальные даты",
        "Считаем весь Umrah-пакет",
        "Лучшие билеты почти готовы"
    ]

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottom) {
                LoopingVideoView(resource: "flight-search")
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Image("HeaderWordmarkDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 118)
                    .padding(.bottom, 22)
            }

            VStack(spacing: 6) {
                Text("Лучшие билеты почти готовы")
                    .font(.title3.weight(.bold))
                Text(labels[min(step, labels.count - 1)])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(750))
                withAnimation(.easeInOut(duration: 0.25)) {
                    step = min(step + 1, labels.count - 1)
                }
            }
        }
    }
}
