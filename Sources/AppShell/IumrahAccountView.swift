import AuthenticationServices
import SwiftUI
import UserNotifications
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct IumrahAccountView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var loginID = ""
    @State private var loginPassword = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?
    @State private var appleNonce = ""
    @State private var isAppleSigningIn = false
    @State private var showPasswordRecovery = false

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var telegram = ""
    @State private var whatsapp = ""
    @State private var isSavingProfile = false
    @State private var profileMessage: String?
    @State private var profileLoadedForID: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showProfileEditor = false
    @State private var identityCardFlipped = false
    @State private var showIdentityFullscreen = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                accountHeader

                if let profile = account.account {
                    identityCard(profile)
                    if let active = activeTrip {
                        activeTripCard(active)
                    }
                    tripsSection
                    profileSection(profile)
                    settingsSection
                    signOutButton
                } else {
                    guestCard
                    loginCard
                    if let pending = pendingActivationTrip {
                        activationShortcut(pending)
                    }
                    guestSettingsSection
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 46)
        }
        .background(Color.iumrahPageBackground)
        .refreshable {
            await refreshAccountContent()
        }
        .task {
            loadProfileDraftIfNeeded(force: false)
            await refreshNotificationStatus()
            await refreshAccountContent()
        }
        .onChange(of: account.iumrahID) { _, _ in
            loadProfileDraftIfNeeded(force: true)
        }
        .sheet(isPresented: $showProfileEditor) {
            profileEditorSheet
        }
        .sheet(isPresented: $showPasswordRecovery) {
            IumrahPasswordRecoveryView()
                .environmentObject(account)
                .environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showIdentityFullscreen) {
            identityFullscreenView
        }
    }

    private var accountHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Account")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1)
                Text(account.isAuthenticated ? tr("Your iumrah profile and trips", "Ваш профиль и поездки iumrah", "iumrah profilingiz va safarlaringiz", "iumrah профилингиз ва сафарларингиз") : tr("Sign in with email, iumrah ID or Apple", "Войдите по почте, iumrah ID или через Apple", "Email, iumrah ID yoki Apple orqali kiring", "Email, iumrah ID ёки Apple орқали киринг"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 10)
            Image(systemName: account.isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                .font(.system(size: 25, weight: .semibold))
                .frame(width: 50, height: 50)
                .background(Color.iumrahCardBackground, in: Circle())
                .overlay { Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func identityCard(_ profile: IumrahAccountProfile) -> some View {
        VStack(spacing: 10) {
            ZStack {
                identityFront(profile)
                    .opacity(identityCardFlipped ? 0 : 1)

                identityBack(profile)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(identityCardFlipped ? 1 : 0)
            }
            .frame(height: 238)
            .rotation3DEffect(.degrees(identityCardFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
            .animation(.spring(response: 0.52, dampingFraction: 0.82), value: identityCardFlipped)
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .onTapGesture {
                IumrahHaptics.selection()
                identityCardFlipped.toggle()
            }

            HStack(spacing: 8) {
                Label(
                    identityCardFlipped ? tr("Front side", "Лицевая сторона", "Old tomoni", "Олд томони") : tr("Tap to flip", "Нажмите, чтобы перевернуть", "Aylantirish uchun bosing", "Айлантириш учун босинг"),
                    systemImage: identityCardFlipped ? "rectangle.portrait.rotate" : "hand.tap.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Spacer()
                Button {
                    IumrahHaptics.selection()
                    showIdentityFullscreen = true
                } label: {
                    Label(tr("Full screen", "На весь экран", "To‘liq ekran", "Тўлиқ экран"), systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
        }
    }

    private func identityFront(_ profile: IumrahAccountProfile) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)

            LinearGradient(
                colors: [Color.white.opacity(0.09), .clear, Color.iumrahCareLight.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            Circle()
                .fill(Color.white.opacity(0.055))
                .frame(width: 190, height: 190)
                .offset(x: 220, y: -98)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Iumrah ID")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        Text(tr("DIGITAL PILGRIM IDENTITY", "ЦИФРОВАЯ ID-КАРТА ПАЛОМНИКА", "RAQAMLI ZIYORATCHI ID", "РАҚАМЛИ ЗИЁРАТЧИ ID"))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareLight)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(displayName(profile))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(normalizedID(profile.iumrahID))
                        .font(.system(size: 33, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .textSelection(.enabled)
                }

                HStack(spacing: 18) {
                    Label("\(bookings.sessions.count) \(tr("trips", "поездок", "safar", "сафар"))", systemImage: "suitcase.fill")
                    Label(tr("Permanent ID", "Постоянный ID", "Doimiy ID", "Доимий ID"), systemImage: "person.text.rectangle.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1) }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private func identityBack(_ profile: IumrahAccountProfile) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.iumrahCardBackground)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 1)

            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Image("HeaderWordmarkLight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 142, height: 34, alignment: .leading)
                        .accessibilityLabel("Iumrah")
                    Text(tr("Official digital identity", "Цифровая идентификация", "Raqamli identifikatsiya", "Рақамли идентификация"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text("Iumrah ID")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(normalizedID(profile.iumrahID))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(2)
                    Text("aiumra.app")
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                qrCodeView(size: 116)
                    .padding(9)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 1) }
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }

    private var identityFullscreenView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let profile = account.account {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()
                        Button {
                            IumrahHaptics.soft()
                            showIdentityFullscreen = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    ZStack {
                        identityFront(profile).opacity(identityCardFlipped ? 0 : 1)
                        identityBack(profile)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            .opacity(identityCardFlipped ? 1 : 0)
                    }
                    .frame(height: 260)
                    .rotation3DEffect(.degrees(identityCardFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                    .animation(.spring(response: 0.52, dampingFraction: 0.82), value: identityCardFlipped)
                    .onTapGesture {
                        IumrahHaptics.selection()
                        identityCardFlipped.toggle()
                    }

                    Text(tr("Tap the card to flip it", "Нажмите на карту, чтобы перевернуть", "Kartani aylantirish uchun bosing", "Картани айлантириш учун босинг"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private func qrCodeView(size: CGFloat) -> some View {
        if let image = makeQRCode("https://aiumra.app") {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: size * 0.66, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(.black)
        }
    }

    private func makeQRCode(_ value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext(options: nil)
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func activeTripCard(_ session: StoredBookingSession) -> some View {
        NavigationLink {
            BookingDetailView(bookingID: session.id)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.iumrahCareLight.opacity(0.14))
                        Image(systemName: session.effectiveStatus.uppercased() == "IN_TRIP" ? "location.fill" : "airplane.departure")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(Color.iumrahCareDark)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Active trip", "Активная поездка", "Faol safar", "Фаол сафар"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                        Text("Бронь \(session.displayBookingNumber)")
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                }

                HStack(spacing: 8) {
                    statusChip(session.effectiveStatus)
                    tripDateChip(session)
                }

                if !session.booking.hotelNames.makkah.isEmpty {
                    Label(session.booking.hotelNames.makkah, systemImage: "building.2.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .iumrahCard()
        }
        .buttonStyle(.plain)
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("My trips", "Мои поездки", "Safarlarim", "Сафарларим"))
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(tr("Current, completed and cancelled bookings", "Текущие, завершённые и отменённые бронирования", "Joriy, yakunlangan va bekor qilingan bronlar", "Жорий, якунланган ва бекор қилинган бронлар"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "suitcase.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.iumrahRaisedBackground, in: Circle())
            }

            if allTrips.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "suitcase")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text(tr("Your trips will appear here after they are linked to this iumrah ID.", "Все поездки, привязанные к этому iumrah ID, появятся здесь.", "Ushbu iumrah ID ga bog‘langan safarlar shu yerda ko‘rinadi.", "Ушбу iumrah ID га боғланган сафарлар шу ерда кўринади."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color.iumrahRaisedBackground.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allTrips.enumerated()), id: \.element.id) { index, session in
                        NavigationLink {
                            BookingDetailView(bookingID: session.id)
                        } label: {
                            tripRow(session)
                        }
                        .buttonStyle(.plain)
                        if index < allTrips.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .iumrahCard()
    }

    private func profileSection(_ profile: IumrahAccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                sectionHeader(
                    icon: "person.text.rectangle.fill",
                    title: tr("Account details", "Данные аккаунта", "Akkaunt ma’lumotlari", "Аккаунт маълумотлари"),
                    subtitle: tr("Used for your profile and future trips", "Используются в профиле и новых поездках", "Profil va yangi safarlarda ishlatiladi", "Профил ва янги сафарларда ишлатилади")
                )
                Spacer(minLength: 4)
                Button {
                    loadProfileDraftIfNeeded(force: true, profile: profile)
                    profileMessage = nil
                    showProfileEditor = true
                    IumrahHaptics.selection()
                } label: {
                    Label(tr("Edit", "Изменить", "Tahrirlash", "Таҳрирлаш"), systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(Color.iumrahRaisedBackground, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                accountSummaryRow(icon: "person.fill", title: tr("Name", "Имя", "Ism", "Исм"), value: displayName(profile))
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "phone.fill", title: tr("Phone", "Телефон", "Telefon", "Телефон"), value: profile.phone)
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "envelope.fill", title: "Email", value: profile.email)
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "paperplane.fill", title: "Telegram", value: profile.telegram)
                Divider().padding(.leading, 52)
                accountSummaryRow(icon: "message.fill", title: "WhatsApp", value: profile.whatsapp)
            }
            .padding(.horizontal, 4)
        }
        .iumrahCard()
        .onAppear { loadProfileDraftIfNeeded(force: false, profile: profile) }
    }

    private func accountSummaryRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private var profileEditorSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(tr("Account details", "Данные аккаунта", "Akkaunt ma’lumotlari", "Аккаунт маълумотлари"))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(tr("These details are reused for future Iumrah trips.", "Эти данные будут использоваться для Ваших следующих поездок Iumrah.", "Bu ma’lumotlar keyingi Iumrah safarlarida ishlatiladi.", "Бу маълумотлар кейинги Iumrah сафарларида ишлатилади."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        accountField(tr("First name", "Имя", "Ism", "Исм"), text: $firstName, contentType: .givenName)
                        accountField(tr("Last name", "Фамилия", "Familiya", "Фамилия"), text: $lastName, contentType: .familyName)
                        accountField(tr("Phone", "Телефон", "Telefon", "Телефон"), text: $phone, keyboard: .phonePad, contentType: .telephoneNumber)
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.badge.shield.half.filled")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(email.isEmpty ? "Email" : email)
                                    .font(.subheadline.weight(.semibold))
                                Text(tr(
                                    "Manage and verify your sign-in email in Account Security.",
                                    "Добавить или изменить почту для входа можно в разделе «Безопасность аккаунта».",
                                    "Kirish emailini Akkaunt xavfsizligida boshqaring va tasdiqlang.",
                                    "Кириш emailини Аккаунт хавфсизлигида бошқаринг ва тасдиқланг."
                                ))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 4)
                        .frame(minHeight: 58)
                        accountField("Telegram", text: $telegram, autocapitalization: .never)
                        accountField("WhatsApp", text: $whatsapp, keyboard: .phonePad, contentType: .telephoneNumber)
                    }
                    .padding(16)
                    .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    if let profileMessage {
                        Text(profileMessage)
                            .font(.footnote)
                            .foregroundStyle(profileMessage == savedText ? Color.green : Color.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await saveProfile(dismissAfterSave: true) }
                    } label: {
                        HStack(spacing: 10) {
                            if isSavingProfile { ProgressView().tint(.white) }
                            Image(systemName: "checkmark.circle.fill")
                            Text(tr("Save account details", "Сохранить данные аккаунта", "Akkaunt ma’lumotlarini saqlash", "Аккаунт маълумотларини сақлаш"))
                            Spacer(minLength: 8)
                        }
                    }
                    .buttonStyle(IumrahPrimaryButtonStyle())
                    .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingProfile)
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { showProfileEditor = false }
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "gearshape.fill", title: tr("Settings", "Настройки", "Sozlamalar", "Созламалар"), subtitle: tr("App, language, appearance and notifications", "Приложение, язык, оформление и уведомления", "Ilova, til, ko‘rinish va bildirishnomalar", "Илова, тил, кўриниш ва билдиришномалар"))
                .padding(.bottom, 8)

            Menu {
                Picker(tr("Language", "Язык", "Til", "Тил"), selection: $settings.language) {
                    ForEach(AppSettingsStore.Language.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
            } label: {
                settingsRow(icon: "globe", title: tr("Language", "Язык", "Til", "Тил"), value: settings.language.title)
            }

            Divider().padding(.leading, 54)

            Menu {
                Picker(tr("Appearance", "Оформление", "Ko‘rinish", "Кўриниш"), selection: $settings.appearance) {
                    ForEach(AppSettingsStore.Appearance.allCases) { appearance in
                        Text(appearance.title(settings.language)).tag(appearance)
                    }
                }
            } label: {
                settingsRow(icon: "circle.lefthalf.filled", title: tr("Appearance", "Оформление", "Ko‘rinish", "Кўриниш"), value: settings.appearance.title(settings.language))
            }

            Divider().padding(.leading, 54)

            Button {
                openSystemSettings()
            } label: {
                settingsRow(icon: "bell.badge.fill", title: tr("Notifications", "Уведомления", "Bildirishnomalar", "Билдиришномалар"), value: notificationStatusText)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 54)

            NavigationLink {
                IumrahAccountSecurityView()
            } label: {
                settingsRow(
                    icon: "lock.shield.fill",
                    title: tr("Account security", "Безопасность аккаунта", "Akkaunt xavfsizligi", "Аккаунт хавфсизлиги"),
                    value: tr("Apple and active sessions", "Apple и активные сеансы", "Apple va faol seanslar", "Apple ва фаол сеанслар")
                )
            }
            .buttonStyle(.plain)
        }
        .iumrahCard()
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task {
                await account.logout()
                bookings.setAccountToken(nil)
                IumrahHaptics.soft()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(tr("Sign out", "Выйти из аккаунта", "Akkauntdan chiqish", "Аккаунтдан чиқиш"))
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .foregroundStyle(.red)
            .background(Color.red.opacity(0.075), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var guestCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.iumrahCareLight.opacity(0.14))
                Image(systemName: "person.crop.circle.badge.key.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareDark)
            }
            .frame(width: 54, height: 54)

            Text(tr("Your permanent iumrah account", "Ваш постоянный аккаунт iumrah", "Doimiy iumrah akkauntingiz", "Доимий iumrah аккаунтингиз"))
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text(tr("Sign in once to restore all trips after reinstalling the app and automatically link future bookings to the same ID.", "Войдите один раз, чтобы восстанавливать все поездки после переустановки приложения и автоматически привязывать новые брони к одному ID.", "Ilovani qayta o‘rnatgandan keyin barcha safarlarni tiklash va yangi bronlarni bitta ID ga bog‘lash uchun kiring.", "Иловани қайта ўрнатгандан кейин барча сафарларни тиклаш ва янги бронларни битта ID га боғлаш учун киринг."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "key.fill", title: tr("Sign in", "Войти в аккаунт", "Akkauntga kirish", "Аккаунтга кириш"), subtitle: tr("Use your email or six-digit iumrah ID", "Введите почту или шестизначный iumrah ID", "Email yoki olti xonali iumrah ID ni kiriting", "Email ёки олти хонали iumrah ID ни киритинг"))

            HStack(spacing: 11) {
                Image(systemName: loginID.contains("@") ? "envelope.fill" : "person.text.rectangle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField(tr("Email or iumrah ID", "Почта или iumrah ID", "Email yoki iumrah ID", "Email ёки iumrah ID"), text: $loginID)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))

            HStack(spacing: 11) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                SecureField(tr("Password", "Пароль", "Parol", "Парол"), text: $loginPassword)
                    .textContentType(.password)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 19, style: .continuous))

            if let loginError {
                Text(loginError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await login() }
            } label: {
                HStack(spacing: 10) {
                    if isLoggingIn { ProgressView().tint(.white) }
                    Image(systemName: "person.crop.circle.fill")
                    Text(tr("Sign in to iumrah", "Войти в iumrah", "iumrah ga kirish", "iumrah га кириш"))
                    Spacer(minLength: 10)
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(loginID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loginPassword.count < 8 || isLoggingIn)

            Button {
                showPasswordRecovery = true
            } label: {
                Text(tr("Forgot password?", "Забыли пароль?", "Parolni unutdingizmi?", "Паролни унутдингизми?"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            HStack(spacing: 12) {
                Rectangle().fill(Color.secondary.opacity(0.20)).frame(height: 1)
                Text(tr("or", "или", "yoki", "ёки"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Rectangle().fill(Color.secondary.opacity(0.20)).frame(height: 1)
            }

            SignInWithAppleButton(.continue) { request in
                prepareAppleSignIn(request)
            } onCompletion: { result in
                completeAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .disabled(isAppleSigningIn || isLoggingIn)

            Text(tr(
                "Apple securely finds or creates your single iumrah account. Your six-digit iumrah ID remains permanent.",
                "Apple безопасно найдёт или создаст Ваш единый аккаунт. Шестизначный iumrah ID останется постоянным.",
                "Apple yagona iumrah akkauntingizni xavfsiz topadi yoki yaratadi. Olti xonali iumrah ID doimiy qoladi.",
                "Apple ягона iumrah аккаунтингизни хавфсиз топади ёки яратади. Олти хонали iumrah ID доимий қолади."
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .iumrahCard()
    }

    private func activationShortcut(_ session: StoredBookingSession) -> some View {
        NavigationLink {
            PilgrimCheckoutView(bookingID: session.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .background(Color.iumrahCareLight.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .foregroundStyle(Color.iumrahCareDark)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Activate your iumrah ID", "Активировать iumrah ID", "iumrah ID ni faollashtirish", "iumrah ID ни фаоллаштириш"))
                        .font(.subheadline.weight(.bold))
                    if let id = session.displayPilgrimID {
                        Text("ID \(id) · \(tr("booking ready for details", "бронь готова к заполнению", "bron ma’lumotlarga tayyor", "брон маълумотларга тайёр"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 10)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.055), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private var guestSettingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "slider.horizontal.3", title: tr("App settings", "Настройки приложения", "Ilova sozlamalari", "Илова созламалари"), subtitle: nil)
                .padding(.bottom, 8)
            Menu {
                Picker(tr("Language", "Язык", "Til", "Тил"), selection: $settings.language) {
                    ForEach(AppSettingsStore.Language.allCases) { language in Text(language.title).tag(language) }
                }
            } label: {
                settingsRow(icon: "globe", title: tr("Language", "Язык", "Til", "Тил"), value: settings.language.title)
            }
            Divider().padding(.leading, 54)
            Menu {
                Picker(tr("Appearance", "Оформление", "Ko‘rinish", "Кўриниш"), selection: $settings.appearance) {
                    ForEach(AppSettingsStore.Appearance.allCases) { appearance in Text(appearance.title(settings.language)).tag(appearance) }
                }
            } label: {
                settingsRow(icon: "circle.lefthalf.filled", title: tr("Appearance", "Оформление", "Ko‘rinish", "Кўриниш"), value: settings.appearance.title(settings.language))
            }
        }
        .iumrahCard()
    }

    private func tripRow(_ session: StoredBookingSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.iumrahRaisedBackground)
                Image(systemName: tripIcon(session.effectiveStatus))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusColor(session.effectiveStatus))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)")
                    .font(.subheadline.weight(.bold))
                Text("Бронь \(session.displayBookingNumber) · \(L10n.date(session.booking.input.startDate, settings.language))")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(L10n.status(session.effectiveStatus, settings.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func sectionHeader(icon: String, title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func accountField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .words
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func settingsRow(icon: String, title: String, value: String, showsChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    private func statusChip(_ status: String) -> some View {
        Text(L10n.status(status, settings.language))
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(statusColor(status).opacity(0.10), in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func tripDateChip(_ session: StoredBookingSession) -> some View {
        Label(L10n.date(session.booking.input.startDate, settings.language), systemImage: "calendar")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    private var activeTrip: StoredBookingSession? {
        allTrips
            .filter { !["COMPLETED", "CANCELLED"].contains($0.effectiveStatus.uppercased()) }
            .sorted { tripPriority($0) < tripPriority($1) }
            .first
    }

    private var allTrips: [StoredBookingSession] {
        bookings.sessions.sorted { lhs, rhs in
            let l = lhs.booking.input.startDate
            let r = rhs.booking.input.startDate
            if l == r { return lhs.booking.createdAt > rhs.booking.createdAt }
            return l > r
        }
    }

    private var pendingActivationTrip: StoredBookingSession? {
        bookings.sessions.first { $0.effectiveStatus.uppercased() == "PAYMENT_PENDING" && $0.displayPilgrimID != nil }
    }

    private func tripPriority(_ session: StoredBookingSession) -> String {
        let status = session.effectiveStatus.uppercased()
        let rank: Int
        switch status {
        case "IN_TRIP": rank = 0
        case "READY_TO_TRAVEL": rank = 1
        case "BOOKING_CONFIRMED": rank = 2
        case "PAYMENT_PENDING": rank = 3
        case "AVAILABILITY_CHECK": rank = 4
        default: rank = 9
        }
        return "\(rank)-\(session.booking.input.startDate)"
    }

    private func tripIcon(_ status: String) -> String {
        switch status.uppercased() {
        case "IN_TRIP": return "location.fill"
        case "READY_TO_TRAVEL": return "checkmark.seal.fill"
        case "BOOKING_CONFIRMED": return "checkmark.circle.fill"
        case "PAYMENT_PENDING": return "creditcard.fill"
        case "CANCELLED": return "xmark.circle.fill"
        case "COMPLETED": return "flag.checkered"
        default: return "clock.fill"
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "CANCELLED": return .red
        case "PAYMENT_PENDING": return .orange
        case "IN_TRIP", "READY_TO_TRAVEL", "BOOKING_CONFIRMED", "COMPLETED": return Color.iumrahCareLight
        default: return .secondary
        }
    }

    @MainActor
    private func login() async {
        isLoggingIn = true
        loginError = nil
        defer { isLoggingIn = false }
        do {
            let profile = try await account.login(
                identifier: loginID.trimmingCharacters(in: .whitespacesAndNewlines),
                password: loginPassword,
                locale: settings.language.rawValue
            )
            await completeAuthenticatedLogin(profile)
            loginPassword = ""
            IumrahHaptics.success()
        } catch {
            loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    private func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        do {
            appleNonce = try IumrahAppleSignInSupport.prepare(request)
            isAppleSigningIn = true
            loginError = nil
        } catch {
            loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
        }
    }

    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task { @MainActor in
            defer { isAppleSigningIn = false }
            do {
                let authorization = try result.get()
                let credential = try IumrahAppleSignInSupport.credential(from: authorization, nonce: appleNonce)
                let profile = try await account.signInWithApple(credential, locale: settings.language.rawValue)
                await completeAuthenticatedLogin(profile)
                IumrahHaptics.success()
            } catch let error as ASAuthorizationError where error.code == .canceled {
                loginError = nil
            } catch {
                loginError = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                IumrahHaptics.error()
            }
        }
    }

    @MainActor
    private func completeAuthenticatedLogin(_ profile: IumrahAccountProfile) async {
        bookings.setAccountToken(account.bearerToken)
        if let token = account.bearerToken {
            await bookings.restoreAccountTrips(token: token)
            await bookings.refreshAll()
        }
        applyProfileToLocalSettings(profile)
        loadProfileDraftIfNeeded(force: true, profile: profile)
    }

    @MainActor
    private func saveProfile(dismissAfterSave: Bool = false) async {
        isSavingProfile = true
        profileMessage = nil
        defer { isSavingProfile = false }
        do {
            let profile = try await account.updateProfile(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                telegram: telegram.trimmingCharacters(in: .whitespacesAndNewlines),
                whatsapp: whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            applyProfileToLocalSettings(profile)
            profileMessage = savedText
            IumrahHaptics.success()
            if dismissAfterSave { showProfileEditor = false }
        } catch {
            profileMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func refreshAccountContent() async {
        guard let token = account.bearerToken else { return }
        await bookings.restoreAccountTrips(token: token)
        await bookings.refreshAll()
    }

    @MainActor
    private func loadProfileDraftIfNeeded(force: Bool, profile explicit: IumrahAccountProfile? = nil) {
        guard let profile = explicit ?? account.account else { return }
        if !force, profileLoadedForID == profile.iumrahID { return }
        profileLoadedForID = profile.iumrahID
        firstName = profile.firstName
        lastName = profile.lastName
        phone = profile.phone
        email = profile.email
        telegram = profile.telegram
        whatsapp = profile.whatsapp
    }

    @MainActor
    private func applyProfileToLocalSettings(_ profile: IumrahAccountProfile) {
        settings.firstName = profile.firstName
        settings.lastName = profile.lastName
        settings.telegram = profile.telegram
        settings.whatsapp = profile.whatsapp.isEmpty ? profile.phone : profile.whatsapp
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let value = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = value.authorizationStatus
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return tr("Enabled", "Включены", "Yoqilgan", "Ёқилган")
        case .denied:
            return tr("Disabled in iOS Settings", "Выключены в настройках iOS", "iOS sozlamalarida o‘chirilgan", "iOS созламаларида ўчирилган")
        default:
            return tr("Not configured", "Не настроены", "Sozlanmagan", "Созланмаган")
        }
    }

    private var savedText: String { tr("Saved", "Сохранено", "Saqlandi", "Сақланди") }

    private func displayName(_ profile: IumrahAccountProfile) -> String {
        let value = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty { return value }
        let fallback = [profile.firstName, profile.lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return fallback.isEmpty ? tr("Pilgrim", "Паломник", "Ziyoratchi", "Зиёратчи") : fallback
    }

    private func normalizedID(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return value }
        return String(repeating: "0", count: max(0, 6 - digits.count)) + String(digits.suffix(6))
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
