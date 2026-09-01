import AuthenticationServices
import Foundation
import SwiftUI

struct IumrahAccountSecurityView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var overview: IumrahSecurityOverview?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingPrimarySheet = false
    @State private var primaryPassword = ""
    @State private var isClaimingPrimary = false
    @State private var pendingTermination: IumrahSecuritySession?
    @State private var isTerminating = false
    @State private var appleNonce = ""
    @State private var isLinkingApple = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                securityHero

                if let overview {
                    primaryDeviceCard(overview)
                    appleCard(overview)
                    sessionsCard(overview)
                } else if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 70)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                privacyNote
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle(tr("Security", "Безопасность", "Xavfsizlik", "Хавфсизлик"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $showingPrimarySheet) { primaryDeviceSheet }
        .confirmationDialog(
            tr("End this session?", "Завершить этот сеанс?", "Seans tugatilsinmi?", "Сеанс тугатилсинми?"),
            isPresented: Binding(
                get: { pendingTermination != nil },
                set: { if !$0 { pendingTermination = nil } }
            ),
            presenting: pendingTermination
        ) { session in
            Button(
                session.isCurrent
                    ? tr("Sign out this device", "Выйти на этом устройстве", "Bu qurilmadan chiqish", "Бу қурилмадан чиқиш")
                    : tr("End session", "Завершить сеанс", "Seansni tugatish", "Сеансни тугатиш"),
                role: .destructive
            ) {
                Task { await terminate(session) }
            }
            Button(tr("Cancel", "Отмена", "Bekor qilish", "Бекор қилиш"), role: .cancel) {}
        } message: { session in
            Text(session.isCurrent
                 ? tr("You will need to sign in again.", "Для продолжения потребуется войти снова.", "Qayta kirish kerak bo‘ladi.", "Қайта кириш керак бўлади.")
                 : tr("This device will immediately lose access to your account.", "Это устройство сразу потеряет доступ к Вашему аккаунту.", "Bu qurilma akkauntga kirish huquqini darhol yo‘qotadi.", "Бу қурилма аккаунтга кириш ҳуқуқини дарҳол йўқотади."))
        }
    }

    private var securityHero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(LinearGradient(colors: [.black, Color.iumrahCareDark], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 180, height: 180)
                .offset(x: 220, y: -90)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.iumrahCareLight)
                    Spacer()
                    if let overview {
                        Text("ID \(overview.iumrahID)")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }
                Text(tr("Your account. Your devices.", "Ваш аккаунт. Ваши устройства.", "Akkauntingiz. Qurilmalaringiz.", "Аккаунтингиз. Қурилмаларингиз."))
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(tr(
                    "A new session can end only itself. Only your protected primary device can end other sessions.",
                    "Новый сеанс может завершить только себя. Остальные сеансы может завершать только Ваше защищённое основное устройство.",
                    "Yangi seans faqat o‘zini tugata oladi. Boshqa seanslarni faqat himoyalangan asosiy qurilmangiz tugata oladi.",
                    "Янги сеанс фақат ўзини тугата олади. Бошқа сеансларни фақат ҳимояланган асосий қурилмангиз тугата олади."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private func primaryDeviceCard(_ value: IumrahSecurityOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                icon: value.primaryDeviceProtected ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                title: tr("Primary device", "Основное устройство", "Asosiy qurilma", "Асосий қурилма"),
                tint: value.primaryDeviceProtected ? Color.iumrahCareLight : .orange
            )

            if value.currentDeviceIsPrimary {
                statusRow(
                    icon: "iphone.gen3",
                    title: tr("This is your primary device", "Это Ваше основное устройство", "Bu asosiy qurilmangiz", "Бу асосий қурилмангиз"),
                    detail: tr("It can securely manage the other sessions.", "Оно может безопасно управлять остальными сеансами.", "U boshqa seanslarni xavfsiz boshqara oladi.", "У бошқа сеансларни хавфсиз бошқара олади."),
                    tint: Color.iumrahCareLight
                )
            } else if value.primaryDeviceProtected {
                statusRow(
                    icon: "lock.fill",
                    title: tr("Secondary session", "Дополнительный сеанс", "Qo‘shimcha seans", "Қўшимча сеанс"),
                    detail: tr("This device can end only its own session.", "Это устройство может завершить только свой сеанс.", "Bu qurilma faqat o‘z seansini tugata oladi.", "Бу қурилма фақат ўз сеансини тугата олади."),
                    tint: .secondary
                )
            } else {
                Text(tr(
                    "Confirm your current password once to make this iPhone the protected primary device.",
                    "Один раз подтвердите текущий пароль, чтобы сделать этот iPhone защищённым основным устройством.",
                    "Ushbu iPhone’ni himoyalangan asosiy qurilma qilish uchun joriy parolni bir marta tasdiqlang.",
                    "Ушбу iPhone’ни ҳимояланган асосий қурилма қилиш учун жорий паролни бир марта тасдиқланг."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    primaryPassword = ""
                    errorMessage = nil
                    showingPrimarySheet = true
                } label: {
                    Label(tr("Protect this iPhone", "Защитить этот iPhone", "Bu iPhone’ni himoyalash", "Бу iPhone’ни ҳимоялаш"), systemImage: "lock.shield.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
            }
        }
        .iumrahCard()
    }

    private func appleCard(_ value: IumrahSecurityOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "apple.logo", title: "Sign in with Apple", tint: .primary)

            if value.apple.linked {
                statusRow(
                    icon: "checkmark.circle.fill",
                    title: tr("Apple is connected", "Apple подключён", "Apple ulangan", "Apple уланган"),
                    detail: tr(
                        "Apple signs in to this same iumrah ID — no second account is created.",
                        "Apple выполняет вход в этот же iumrah ID — второй аккаунт не создаётся.",
                        "Apple aynan shu iumrah ID’ga kiradi — ikkinchi akkaunt yaratilmaydi.",
                        "Apple айнан шу iumrah ID’га киради — иккинчи аккаунт яратилмайди."
                    ),
                    tint: Color.iumrahCareLight
                )
            } else {
                Text(tr(
                    "Connect Apple to ID \(value.iumrahID). After that you can sign in without typing the six-digit ID or password.",
                    "Подключите Apple к ID \(value.iumrahID). После этого можно входить без ввода шестизначного ID и пароля.",
                    "Apple’ni \(value.iumrahID) ID’ga ulang. Shundan keyin olti xonali ID va parolsiz kirishingiz mumkin.",
                    "Apple’ни \(value.iumrahID) ID’га уланг. Шундан кейин олти хонали ID ва паролсиз киришингиз мумкин."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SignInWithAppleButton(.continue) { request in
                    prepareApple(request)
                } onCompletion: { result in
                    completeApple(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .disabled(!value.currentDeviceIsPrimary || isLinkingApple)
                .opacity(value.currentDeviceIsPrimary ? 1 : 0.48)

                if !value.currentDeviceIsPrimary {
                    Label(
                        tr("Only the primary device can connect a new sign-in method.", "Новый способ входа может подключить только основное устройство.", "Yangi kirish usulini faqat asosiy qurilma ulashi mumkin.", "Янги кириш усулини фақат асосий қурилма улаши мумкин."),
                        systemImage: "lock.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .iumrahCard()
    }

    private func sessionsCard(_ value: IumrahSecurityOverview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle(icon: "rectangle.stack.badge.person.crop.fill", title: tr("Active sessions", "Активные сеансы", "Faol seanslar", "Фаол сеанслар"), tint: .blue)
                Spacer(minLength: 8)
                Text("\(value.sessions.count)")
                    .font(.caption.monospaced().weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.iumrahRaisedBackground, in: Capsule())
            }

            VStack(spacing: 0) {
                ForEach(Array(value.sessions.enumerated()), id: \.element.id) { index, session in
                    sessionRow(session)
                    if index < value.sessions.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
        }
        .iumrahCard()
    }

    private func sessionRow(_ session: IumrahSecuritySession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: session.platform.lowercased().contains("ios") ? "iphone.gen3" : "desktopcomputer")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(session.isCurrent ? Color.blue : Color.secondary)
                    .frame(width: 44, height: 44)
                    .background((session.isCurrent ? Color.blue : Color.secondary).opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(localizedDeviceName(session))
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                        if session.isCurrent { badge(tr("This device", "Это устройство", "Bu qurilma", "Бу қурилма"), color: .blue) }
                        if session.isPrimary { badge(tr("Primary", "Основное", "Asosiy", "Асосий"), color: Color.iumrahCareLight) }
                    }
                    if !deviceDetails(session).isEmpty {
                        Text(deviceDetails(session))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(sessionLocationAndActivity(session))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            if session.canTerminate {
                Button(role: .destructive) {
                    pendingTermination = session
                } label: {
                    Label(
                        session.isCurrent
                            ? tr("End my session", "Завершить мой сеанс", "Seansimni tugatish", "Сеансимни тугатиш")
                            : tr("End session", "Завершить сеанс", "Seansni tugatish", "Сеансни тугатиш"),
                        systemImage: "hand.raised.fill"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(isTerminating)
                .padding(.leading, 56)
            } else {
                Label(
                    tr("This session cannot manage other devices", "Этот сеанс не может управлять другими устройствами", "Bu seans boshqa qurilmalarni boshqara olmaydi", "Бу сеанс бошқа қурилмаларни бошқара олмайди"),
                    systemImage: "lock.fill"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 56)
            }
        }
        .padding(.vertical, 12)
    }

    private var privacyNote: some View {
        Label(
            tr(
                "iumrah never receives your Apple password. Apple is stored only as a secure key to your existing six-digit iumrah ID.",
                "iumrah никогда не получает Ваш пароль Apple. Apple хранится только как защищённый ключ к существующему шестизначному iumrah ID.",
                "iumrah Apple parolingizni hech qachon olmaydi. Apple faqat mavjud olti xonali iumrah ID uchun xavfsiz kalit sifatida saqlanadi.",
                "iumrah Apple паролингизни ҳеч қачон олмайди. Apple фақат мавжуд олти хонали iumrah ID учун хавфсиз калит сифатида сақланади."
            ),
            systemImage: "hand.raised.fill"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 4)
    }

    private var primaryDeviceSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareLight)
                Text(tr("Protect this iPhone", "Защитить этот iPhone", "Bu iPhone’ni himoyalash", "Бу iPhone’ни ҳимоялаш"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(tr(
                    "Enter the password for ID \(overview?.iumrahID ?? ""). It is checked only on the server and is not saved on this screen.",
                    "Введите пароль от ID \(overview?.iumrahID ?? ""). Он проверяется только на сервере и не сохраняется на этом экране.",
                    "\(overview?.iumrahID ?? "") ID parolini kiriting. U faqat serverda tekshiriladi va bu ekranda saqlanmaydi.",
                    "\(overview?.iumrahID ?? "") ID паролини киритинг. У фақат серверда текширилади ва бу экранда сақланмайди."
                ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField(tr("Current password", "Текущий пароль", "Joriy parol", "Жорий парол"), text: $primaryPassword)
                    .textContentType(.password)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await claimPrimary() }
                } label: {
                    HStack {
                        if isClaimingPrimary { ProgressView().tint(.white) }
                        Label(tr("Confirm and protect", "Подтвердить и защитить", "Tasdiqlash va himoyalash", "Тасдиқлаш ва ҳимоялаш"), systemImage: "checkmark.shield.fill")
                        Spacer()
                    }
                }
                .buttonStyle(IumrahPrimaryButtonStyle())
                .disabled(primaryPassword.count < 8 || isClaimingPrimary)

                Spacer()
            }
            .padding(IumrahDesign.pagePadding)
            .background(Color.iumrahPageBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { showingPrimarySheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func sectionTitle(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title).font(.headline)
        }
    }

    private func statusRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(color.opacity(0.10), in: Capsule())
    }

    @MainActor
    private func load() async {
        isLoading = overview == nil
        defer { isLoading = false }
        do {
            overview = try await account.securityOverview(locale: settings.language.rawValue)
            errorMessage = nil
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
        }
    }

    @MainActor
    private func claimPrimary() async {
        isClaimingPrimary = true
        defer { isClaimingPrimary = false }
        do {
            overview = try await account.claimPrimaryDevice(password: primaryPassword)
            primaryPassword = ""
            showingPrimarySheet = false
            errorMessage = nil
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func terminate(_ session: IumrahSecuritySession) async {
        isTerminating = true
        pendingTermination = nil
        defer { isTerminating = false }
        do {
            let signedOut = try await account.terminateSecuritySession(id: session.id)
            IumrahHaptics.success()
            if signedOut {
                dismiss()
            } else {
                await load()
            }
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    private func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        do {
            appleNonce = try IumrahAppleSignInSupport.prepare(request)
            isLinkingApple = true
            errorMessage = nil
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
        }
    }

    private func completeApple(_ result: Result<ASAuthorization, Error>) {
        Task { @MainActor in
            defer { isLinkingApple = false }
            do {
                let authorization = try result.get()
                let credential = try IumrahAppleSignInSupport.credential(from: authorization, nonce: appleNonce)
                _ = try await account.linkApple(credential)
                await load()
                IumrahHaptics.success()
            } catch let error as ASAuthorizationError where error.code == .canceled {
                errorMessage = nil
            } catch {
                errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
                IumrahHaptics.error()
            }
        }
    }

    private func localizedDeviceName(_ session: IumrahSecuritySession) -> String {
        session.deviceName == "Unknown device"
            ? tr("Unknown device", "Неизвестное устройство", "Noma’lum qurilma", "Номаълум қурилма")
            : session.deviceName
    }

    private func deviceDetails(_ session: IumrahSecuritySession) -> String {
        let platform = [session.platform, session.osVersion].filter { !$0.isEmpty }.joined(separator: " ")
        return [session.model, platform].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func sessionLocationAndActivity(_ session: IumrahSecuritySession) -> String {
        let location = [session.city, session.country].filter { !$0.isEmpty }.joined(separator: ", ")
        let activity = relativeDate(session.lastActiveAt)
        return [location, activity].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func relativeDate(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        if abs(date.timeIntervalSinceNow) < 45 {
            return tr("online", "в сети", "onlayn", "онлайн")
        }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        switch settings.language {
        case .russian: relative.locale = Locale(identifier: "ru")
        case .english: relative.locale = Locale(identifier: "en")
        case .uzbek: relative.locale = Locale(identifier: "uz-Latn")
        case .uzbekCyrillic: relative.locale = Locale(identifier: "uz-Cyrl")
        }
        return relative.localizedString(for: date, relativeTo: Date())
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

enum IumrahAccountSecurityCopy {
    static func message(for error: Error, language: AppSettingsStore.Language) -> String {
        let code: String
        if let apiError = error as? APIError {
            guard case .server(_, let value) = apiError else {
                return L10n.error(error, language)
            }
            code = value
        } else if let localized = error as? LocalizedError,
                  let description = localized.errorDescription,
                  !description.isEmpty {
            return description
        } else {
            return L10n.error(error, language)
        }

        let en: String
        let ru: String
        let uz: String
        let cyrl: String
        switch code {
        case "APPLE_ACCOUNT_NOT_LINKED":
            en = "First sign in with your six-digit iumrah ID and password, then connect Apple in Account Security."
            ru = "Сначала войдите по шестизначному iumrah ID и паролю, затем подключите Apple в разделе «Безопасность аккаунта»."
            uz = "Avval olti xonali iumrah ID va parol bilan kiring, keyin Akkaunt xavfsizligida Apple’ni ulang."
            cyrl = "Аввал олти хонали iumrah ID ва парол билан киринг, кейин Аккаунт хавфсизлигида Apple’ни уланг."
        case "PRIMARY_DEVICE_REQUIRED":
            en = "Only the protected primary device can do this."
            ru = "Это действие доступно только на защищённом основном устройстве."
            uz = "Bu amal faqat himoyalangan asosiy qurilmada mavjud."
            cyrl = "Бу амал фақат ҳимояланган асосий қурилмада мавжуд."
        case "PRIMARY_DEVICE_ALREADY_PROTECTED":
            en = "Another primary device is already protecting this account."
            ru = "Этот аккаунт уже защищён другим основным устройством."
            uz = "Bu akkaunt boshqa asosiy qurilma bilan himoyalangan."
            cyrl = "Бу аккаунт бошқа асосий қурилма билан ҳимояланган."
        case "INVALID_CREDENTIALS":
            en = "The password is incorrect."
            ru = "Неверный пароль."
            uz = "Parol noto‘g‘ri."
            cyrl = "Парол нотўғри."
        case "ACCOUNT_TEMPORARILY_LOCKED":
            en = "Too many attempts. Try again in 15 minutes."
            ru = "Слишком много попыток. Повторите через 15 минут."
            uz = "Urinishlar ko‘p. 15 daqiqadan keyin qayta urinib ko‘ring."
            cyrl = "Уринишлар кўп. 15 дақиқадан кейин қайта уриниб кўринг."
        case "APPLE_ID_CONNECTED_TO_ANOTHER_ACCOUNT":
            en = "This Apple ID is already connected to another iumrah ID."
            ru = "Этот Apple ID уже подключён к другому iumrah ID."
            uz = "Bu Apple ID boshqa iumrah ID’ga ulangan."
            cyrl = "Бу Apple ID бошқа iumrah ID’га уланган."
        case "APPLE_ID_ALREADY_CONNECTED":
            en = "A different Apple ID is already connected to this account."
            ru = "К этому аккаунту уже подключён другой Apple ID."
            uz = "Bu akkauntga boshqa Apple ID ulangan."
            cyrl = "Бу аккаунтга бошқа Apple ID уланган."
        case "APPLE_TOKEN_INVALID", "APPLE_TOKEN_REPLAYED":
            en = "Apple authorization expired. Please try again."
            ru = "Подтверждение Apple устарело. Попробуйте ещё раз."
            uz = "Apple tasdig‘i eskirgan. Qayta urinib ko‘ring."
            cyrl = "Apple тасдиғи эскирган. Қайта уриниб кўринг."
        default:
            en = "Account security is temporarily unavailable."
            ru = "Безопасность аккаунта временно недоступна."
            uz = "Akkaunt xavfsizligi vaqtincha mavjud emas."
            cyrl = "Аккаунт хавфсизлиги вақтинча мавжуд эмас."
        }
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
