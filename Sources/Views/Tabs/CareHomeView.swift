import SwiftUI

struct CareHomeView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                careHero

                if bookings.sessions.isEmpty {
                    lockedChatCard
                } else {
                    SectionHeader(
                        L10n.text("care_chats", settings.language),
                        eyebrow: L10n.text("care_title", settings.language),
                        subtitle: L10n.text("care_chats_subtitle", settings.language)
                    )
                    ForEach(bookings.sessions) { session in
                        NavigationLink {
                            BookingChatView(bookingID: session.id)
                        } label: {
                            chatCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                }

                supportPromise
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await bookings.refreshAll() }
    }

    private var careHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 74)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Spacer()
                Text("24/7")
                    .font(.caption2.weight(.bold))
                    .tracking(0.45)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("care_title", settings.language))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(L10n.text("care_subtitle", settings.language))
                    .font(.title3.weight(.semibold))
                Text(L10n.text("care_promise_body", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 18) {
                careMetric(icon: "message.fill", text: settings.language == .english ? "Answers" : settings.language == .uzbek ? "Javoblar" : settings.language == .uzbekCyrillic ? "Жавоблар" : "Ответы")
                careMetric(icon: "bell.fill", text: settings.language == .english ? "Updates" : settings.language == .uzbek ? "Holat" : settings.language == .uzbekCyrillic ? "Ҳолат" : "Статус")
                careMetric(icon: "heart.fill", text: settings.language == .english ? "Care" : settings.language == .uzbek ? "G‘amxo‘rlik" : settings.language == .uzbekCyrillic ? "Ғамхўрлик" : "Забота")
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard(dark: true)
    }

    private func careMetric(icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.headline)
            Text(text).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chatCard(_ session: StoredBookingSession) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(Color.iumrahCareLight).frame(width: 7, height: 7)
                    Text("Aiomra Care")
                        .font(.headline)
                }
                Text(session.travelerName ?? session.id)
                    .font(.subheadline.weight(.semibold))
                Text(session.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(L10n.status(session.booking.status, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var lockedChatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.text("care_locked_title", settings.language), systemImage: "lock.fill")
                .font(.headline)
            Text(L10n.text("care_locked_body", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var supportPromise: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("care_promise_title", settings.language))
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text(L10n.text("care_promise_body", settings.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahMarketingCard()
    }
}
