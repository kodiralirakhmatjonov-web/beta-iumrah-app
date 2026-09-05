import SwiftUI

struct IumrahPasswordRecoveryView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var challengeID = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var restoredID = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    IumrahIconBadge(
                        systemName: restoredID.isEmpty ? "key.viewfinder" : "checkmark.shield.fill",
                        role: restoredID.isEmpty ? .security : .success,
                        size: 64,
                        symbolSize: 28,
                        cornerRadius: 20
                    )

                    if !restoredID.isEmpty {
                        successContent
                    } else if challengeID.isEmpty {
                        emailContent
                    } else {
                        codeContent
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(IumrahDesign.pagePadding)
                .padding(.bottom, 30)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle(tr("Password recovery", "Восстановление пароля", "Parolni tiklash", "Паролни тиклаш"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var emailContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Reset with email", "Восстановление по почте", "Email orqali tiklash", "Email орқали тиклаш"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(tr(
                "Enter the verified email connected to your iumrah account. We will send a six-digit code.",
                "Введите подтверждённую почту, подключённую к аккаунту iumrah. Мы отправим шестизначный код.",
                "iumrah akkauntingizga ulangan tasdiqlangan emailni kiriting. Olti xonali kod yuboramiz.",
                "iumrah аккаунтингизга уланган тасдиқланган emailни киритинг. Олти хонали код юборамиз."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            field(icon: "envelope.fill") {
                TextField("name@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Button { Task { await sendCode() } } label: {
                HStack {
                    if isWorking { ProgressView().tint(.white) }
                    Text(tr("Send recovery code", "Отправить код", "Tiklash kodini yuborish", "Тиклаш кодини юбориш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(!email.contains("@") || isWorking)
        }
    }

    private var codeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Check your email", "Проверьте почту", "Emailni tekshiring", "Emailни текширинг"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(tr(
                "If this email belongs to an iumrah account, the code is already on its way. It expires in 10 minutes.",
                "Если эта почта подключена к аккаунту iumrah, код уже отправлен. Он действует 10 минут.",
                "Agar bu email iumrah akkauntiga ulangan bo‘lsa, kod yuborildi. U 10 daqiqa amal qiladi.",
                "Агар бу email iumrah аккаунтига уланган бўлса, код юборилди. У 10 дақиқа амал қилади."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            field(icon: "number.square.fill") {
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.body.monospaced())
                    .onChange(of: code) { _, value in
                        code = String(value.filter(\.isNumber).prefix(6))
                    }
            }
            field(icon: "lock.fill") {
                SecureField(tr("New password", "Новый пароль", "Yangi parol", "Янги парол"), text: $newPassword)
                    .textContentType(.newPassword)
            }
            field(icon: "lock.rotation") {
                SecureField(tr("Confirm password", "Повторите пароль", "Parolni takrorlang", "Паролни такрорланг"), text: $confirmPassword)
                    .textContentType(.newPassword)
            }

            Button { Task { await resetPassword() } } label: {
                HStack {
                    if isWorking { ProgressView().tint(.white) }
                    Text(tr("Set new password", "Установить новый пароль", "Yangi parol o‘rnatish", "Янги парол ўрнатиш"))
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(code.count != 6 || newPassword.count < 8 || newPassword != confirmPassword || isWorking)

            Button {
                challengeID = ""
                code = ""
                errorMessage = nil
            } label: {
                Text(tr("Use another email", "Указать другую почту", "Boshqa emaildan foydalanish", "Бошқа emailдан фойдаланиш"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private var successContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Password updated", "Пароль изменён", "Parol yangilandi", "Парол янгиланди"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(tr(
                "All previous sessions were securely ended. Sign in again with your email or iumrah ID \(restoredID).",
                "Все предыдущие сеансы безопасно завершены. Войдите снова по почте или iumrah ID \(restoredID).",
                "Barcha oldingi seanslar xavfsiz tugatildi. Email yoki \(restoredID) iumrah ID bilan qayta kiring.",
                "Барча олдинги сеанслар хавфсиз тугатилди. Email ёки \(restoredID) iumrah ID билан қайта киринг."
            ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(tr("Return to sign in", "Вернуться ко входу", "Kirishga qaytish", "Киришга қайтиш")) { dismiss() }
                .buttonStyle(IumrahPrimaryButtonStyle())
        }
    }

    private func field<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
    }

    @MainActor
    private func sendCode() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await account.startPasswordRecovery(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                locale: settings.language.rawValue
            )
            challengeID = response.challengeID
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
    }

    @MainActor
    private func resetPassword() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await account.confirmPasswordRecovery(
                challengeID: challengeID,
                code: code,
                newPassword: newPassword
            )
            restoredID = response.iumrahID
            IumrahHaptics.success()
        } catch {
            errorMessage = IumrahAccountSecurityCopy.message(for: error, language: settings.language)
            IumrahHaptics.error()
        }
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
