import SwiftUI

struct BookingsHomeView: View {
    @EnvironmentObject private var journey: JourneyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SectionHeader(
                    "Booking",
                    eyebrow: "Ваши поездки",
                    subtitle: "Подтверждённые Umrah-пакеты и будущие бронирования будут собраны здесь."
                )

                if journey.quote != nil || journey.selectedHotel != nil {
                    currentDraftCard
                } else {
                    emptyCard
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentDraftCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Текущая поездка", systemImage: "suitcase.rolling")
                .font(.headline)
            if let hotel = journey.selectedHotel {
                Text(hotel.name)
                    .font(.title3.weight(.semibold))
            }
            Text("После подключения финального Booking API здесь появится номер бронирования, статус и документы поездки.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "suitcase")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Бронирований пока нет")
                .font(.title3.weight(.bold))
            Text("Когда Вы соберёте и подтвердите Umrah-пакет, поездка появится в этой вкладке.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .iumrahCard()
    }
}
