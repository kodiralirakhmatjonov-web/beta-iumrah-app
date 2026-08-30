import SwiftUI

struct CareHomeView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                IumrahRootPageTitle(title: L10n.text("tab_care", settings.language))
                careHero

                if bookings.sessions.isEmpty {
                    lockedChatCard
                } else {
                    SectionHeader(
                        L10n.text("care_chats", settings.language),
                        eyebrow: "iumrah Care",
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
            .padding(.top, 10)
            .padding(.bottom, 42)
        }
        .background {
            ZStack {
                Color.iumrahPageBackground
                RadialGradient(
                    colors: [Color.iumrahCareLight.opacity(0.10), Color.clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await bookings.refreshAll() }
    }

    private var careHero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 74)
                    .padding(7)
                    .background(Color.white.opacity(0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                    Text("24/7")
                        .font(.caption2.weight(.bold))
                        .tracking(0.45)
                }
                .padding(.horizontal, 11)
                .frame(height: 32)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.13))
                .clipShape(Capsule())
                .overlay { Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("iumrah Care")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(.white)

                Text(L10n.text("care_subtitle", settings.language))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.96))

                Text(L10n.text("care_promise_body", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                careMetric(icon: "message.fill", text: L10n.text("care_metric_answers", settings.language))
                careMetric(icon: "bell.fill", text: L10n.text("care_metric_updates", settings.language))
                careMetric(icon: "heart.fill", text: L10n.text("care_metric_care", settings.language))
            }

            Label(L10n.text("care_free_year", settings.language), systemImage: "gift.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.13))
                .clipShape(Capsule())
        }
        .padding(22)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color.iumrahCareDark.opacity(0.98), Color(red: 0.12, green: 0.33, blue: 0.23), Color.iumrahCareLight.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 210, height: 210)
                    .blur(radius: 2)
                    .offset(x: 145, y: -115)

                Circle()
                    .fill(Color.iumrahCareDark.opacity(0.20))
                    .frame(width: 160, height: 160)
                    .offset(x: -150, y: 155)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: Color.iumrahCareDark.opacity(0.25), radius: 30, y: 16)
    }

    private func careMetric(icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.13))
                .clipShape(Circle())
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(11)
        .background(Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func chatCard(_ session: StoredBookingSession) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .padding(4)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.iumrahCareLight.opacity(0.18), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.iumrahCareLight)
                        .frame(width: 7, height: 7)
                    Text("iumrah Care")
                        .font(.headline)
                }
                Text(careTripSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(L10n.status(session.effectiveStatus, settings.language))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.iumrahCareDark.opacity(0.56))
                .frame(width: 34, height: 34)
                .background(Color.iumrahCareLight.opacity(0.13))
                .clipShape(Circle())
        }
        .padding(17)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.iumrahCareLight.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: Color.iumrahCareDark.opacity(0.07), radius: 20, y: 10)
    }

    private var careTripSubtitle: String {
        switch settings.language {
        case .russian: return "Поддержка рядом на всех этапах вашей поездки"
        case .english: return "Support by your side throughout your journey"
        case .uzbek: return "Safaringizning barcha bosqichlarida yoningizdagi yordam"
        case .uzbekCyrillic: return "Сафарингизнинг барча босқичларида ёнингиздаги ёрдам"
        }
    }

    private var lockedChatCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.iumrahCareDark)
                .frame(width: 40, height: 40)
                .background(Color.iumrahCareLight.opacity(0.17))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("care_locked_title", settings.language))
                    .font(.headline)
                Text(L10n.text("care_locked_body", settings.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var supportPromise: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.iumrahCareDark)
                Spacer()
                Text("iumrah Care")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.74))
            }
            Text(L10n.text("care_promise_title", settings.language))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(.white)
            Text(L10n.text("care_promise_body", settings.language))
                .font(.body)
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background {
            LinearGradient(
                colors: [Color.iumrahCareDark.opacity(0.98), Color(red: 0.12, green: 0.33, blue: 0.23), Color.iumrahCareLight.opacity(0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}
