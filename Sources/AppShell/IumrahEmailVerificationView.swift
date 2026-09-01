import SwiftUI

struct IumrahEmailVerificationView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    let existingEmail: String?

    @State private var email = ""
    @State private var challengeID = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 64, height: 64)
                        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text(challengeID.isEmpty
                         ? tr("Sign-in email", "Почта для входа", "Kirish emaili", "Кириш emailи")
                         : tr("Enter verification code", "Введите код подтверждения", "Tasdiqlash kodini kiriting", "Тасдиқлаш кодини киритинг"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text(challengeID.isEmpty
                         ? tr(
                            "This verified address will work together with your iumrah ID and password. It does not create another account.",
                            "Подтверждённая почта будет работать вместе с Вашим iumrah ID и паролем. Второй аккаунт не создаётся.",
                            "Tasdiqlangan email iumrah ID va parolingiz bilan birga ishlaydi. Ikkinchi akkaunt yaratilmaydi.",
                            "Тасдиқланган email iumrah ID ва паролингиз билан бирга ишлайди. Иккинчи аккаунт яратилмайди."
                         )
                         : tr(
                            "We sent a six-digit code to \(email). It expires in 10 minutes.",
                            "Мы отправили шестизначный код на \(email). Он действует 10 минут.",
                            "\(email) manziliga olti xonali kod yubordik. U 10 daqiqa amal qiladi.",
                            "\(email) манзилига олти хонали код юбордик. У 10 дақиқа амал қилади."
                         ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if challengeID.isEmpty {
                        input(icon: "envelope.fill") {
                            TextField("name@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Button { Task { await sendCode() } } label: {
                            HStack {
                                if isWorking { ProgressView().tint(.white) }
                                Text(tr("Send verification code", "Отправить код", "Tasdiqlash kodini yuborish", "Тасдиқлаш кодини юбориш"))
                                Spacer()
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .buttonStyle(IumrahPrimaryButtonStyle())
                        .disabled(!email.contains("@") || isWorking)
                    } else {
                        input(icon: "number.square.fill") {
                            TextField("000000", text: $code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .font(.body.monospaced())
                                .onChange(of: code) { _, value in
                                    code = String(value.filter(\.isNumber).prefix(6))
                                }
                        }
                        Button { Task { await confirmCode() } } label: {
                            HStack {
                                if isWorking { ProgressView().tint(.white) }
                                Text(tr("Confirm email", "Подтвердить почту", "Emailni tasdiqlash", "Emailни тасдиқлаш"))
                                Spacer()
                                Image(systemName: "checkmark.shield.fill")
                            }
                        }
                        .buttonStyle(IumrahPrimaryButtonStyle())
                        .disabled(code.count != 6 || isWorking)

                        Button {
                            challengeID = ""
                            code = ""
                            errorMessage = nil
                        } label: {
                            Text(tr("Change email", "Изменить почту", "Emailni o‘zgartirish", "Emailни ўзгартириш"))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
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
            .navigationTitle(tr("Email security", "Безопасность почты", "Email xavfsizligi", "Email хавфсизлиги"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close", "Закрыть", "Yopish", "Ёпиш")) { dismiss() }
                }
            }
        }
        .onAppear { if email.isEmpty { email = existingEmail ?? "" } }
        .presentationDetents([.large])
    }

    private func input<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @MainActor
    private func sendCode() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let response = try await account.startEmailVerification(
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
    private func confirmCode() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await account.confirmEmailVerification(challengeID: challengeID, code: code)
            IumrahHaptics.success()
            dismiss()
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
