import SwiftUI
import UserNotifications
import UIKit

struct IumrahAccountView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var loginID = ""
    @State private var loginPassword = ""
    @State private var isLoggingIn = false
    @State private var loginError: String?

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
    }

    private var accountHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Account")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .tracking(-1)
                Text(account.isAuthenticated ? tr("Your iumrah profile and trips", "Ваш профиль и поездки iumrah", "iumrah profilingiz va safarlaringiz", "iumrah профилингиз ва сафарларингиз") : tr("Sign in with your permanent iumrah ID", "Войдите по постоянному iumrah ID", "Doimiy iumrah ID orqali kiring", "Доимий iumrah ID орқали киринг"))
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
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.iumrahCareDark, Color.iumrahGraphite],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 180, height: 180)
                .offset(x: 215, y: -82)

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iumrah")
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        Text("IDENTITY")
                            .font(.caption2.weight(.bold))
                            .tracking(2.1)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Label(tr("Active", "Активен", "Faol", "Фаол"), systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(.white.opacity(0.12), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName(profile))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text("ID  \(normalizedID(profile.iumrahID))")
                        .font(.system(size: 31, weight: .bold, design: .monospaced))
                        .tracking(2.4)
                        .textSelection(.enabled)
                }

                HStack(spacing: 18) {
                    Label("\(bookings.sessions.count) \(tr("trips", "поездок", "safar", "сафар"))", systemImage: "suitcase.fill")
                    Label(tr("One account", "Единый аккаунт", "Yagona akkaunt", "Ягона аккаунт"), systemImage: "person.2.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .frame(minHeight: 238)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1) }
        .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
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
            sectionHeader(icon: "person.text.rectangle.fill", title: tr("Account details", "Данные аккаунта", "Akkaunt ma’lumotlari", "Аккаунт маълумотлари"), subtitle: tr("Used for your profile and future trips", "Используются в профиле и новых поездках", "Profil va yangi safarlarda ishlatiladi", "Профил ва янги сафарларда ишлатилади"))

            accountField(tr("First name", "Имя", "Ism", "Исм"), text: $firstName, contentType: .givenName)
            accountField(tr("Last name", "Фамилия", "Familiya", "Фамилия"), text: $lastName, contentType: .familyName)
            accountField(tr("Phone", "Телефон", "Telefon", "Телефон"), text: $phone, keyboard: .phonePad, contentType: .telephoneNumber)
            accountField("Email", text: $email, keyboard: .emailAddress, contentType: .emailAddress, autocapitalization: .never)
            accountField("Telegram", text: $telegram, autocapitalization: .never)
            accountField("WhatsApp", text: $whatsapp, keyboard: .phonePad, contentType: .telephoneNumber)

            if let profileMessage {
                Text(profileMessage)
                    .font(.caption)
                    .foregroundStyle(profileMessage == savedText ? Color.green : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await saveProfile() }
            } label: {
                HStack(spacing: 10) {
                    if isSavingProfile { ProgressView().tint(.white) }
                    Image(systemName: "checkmark.circle.fill")
                    Text(tr("Save account details", "Сохранить данные аккаунта", "Akkaunt ma’lumotlarini saqlash", "Аккаунт маълумотларини сақлаш"))
                    Spacer(minLength: 10)
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingProfile)
        }
        .iumrahCard()
        .onAppear { loadProfileDraftIfNeeded(force: false, profile: profile) }
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

            settingsRow(icon: "lock.shield.fill", title: tr("Account security", "Безопасность аккаунта", "Akkaunt xavfsizligi", "Аккаунт хавфсизлиги"), value: tr("iumrah ID + password", "iumrah ID + пароль", "iumrah ID + parol", "iumrah ID + парол"), showsChevron: false)
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
            sectionHeader(icon: "key.fill", title: tr("Sign in", "Войти в аккаунт", "Akkauntga kirish", "Аккаунтга кириш"), subtitle: tr("Use your six-digit iumrah ID and password", "Введите шестизначный iumrah ID и пароль", "Olti xonali iumrah ID va parolni kiriting", "Олти хонали iumrah ID ва паролни киритинг"))

            HStack(spacing: 11) {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("000016", text: $loginID)
                    .keyboardType(.numberPad)
                    .font(.body.monospaced())
                    .onChange(of: loginID) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(6))
                        if digits != value { loginID = digits }
                    }
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
            .disabled(loginID.filter(\.isNumber).count != 6 || loginPassword.count < 8 || isLoggingIn)
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
                Text("\(L10n.date(session.booking.input.startDate, settings.language)) · \(L10n.status(session.effectiveStatus, settings.language))")
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
            let profile = try await account.login(iumrahID: loginID, password: loginPassword)
            bookings.setAccountToken(account.bearerToken)
            if let token = account.bearerToken {
                await bookings.restoreAccountTrips(token: token)
                await bookings.refreshAll()
            }
            applyProfileToLocalSettings(profile)
            loadProfileDraftIfNeeded(force: true, profile: profile)
            loginPassword = ""
            IumrahHaptics.success()
        } catch {
            loginError = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func saveProfile() async {
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
