import SwiftUI

struct IumrahAccountView: View {
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var iumrahID = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    identityHero
                    if let profile = account.account { signedInCard(profile) } else { loginCard }
                }
                .padding(.horizontal, IumrahDesign.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 36)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle("iumrah ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(doneTitle) { dismiss() } } }
        }
    }

    private var identityHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 27, weight: .semibold))
                .frame(width: 54, height: 54)
                .background(Color.iumrahCareLight.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(titleText).font(.system(size: 28, weight: .bold, design: .rounded))
            Text(bodyText).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func signedInCard(_ profile: IumrahAccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iumrah ID").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(profile.iumrahID).font(.system(size: 38, weight: .bold, design: .monospaced)).tracking(3).textSelection(.enabled)
            if !profile.displayName.isEmpty { Text(profile.displayName).font(.headline) }
            HStack(spacing: 8) {
                Label("\(bookings.sessions.count) \(tripsWord)", systemImage: "suitcase.fill")
                Spacer()
                Label(accountState, systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            }
            .font(.caption.weight(.semibold))
            Divider()
            Button(role: .destructive) {
                Task {
                    await account.logout(); bookings.setAccountToken(nil); dismiss()
                }
            } label: { Label(logoutTitle, systemImage: "rectangle.portrait.and.arrow.right") }
        }
        .iumrahCard()
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(loginTitle).font(.headline)
            HStack(spacing: 10) {
                Image(systemName: "number").foregroundStyle(.secondary)
                TextField("000016", text: $iumrahID)
                    .keyboardType(.numberPad)
                    .font(.body.monospaced())
                    .onChange(of: iumrahID) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(6))
                        if digits != value { iumrahID = digits }
                    }
            }
            .padding(.horizontal, 14).frame(height: 52)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            HStack(spacing: 10) {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
                SecureField(passwordTitle, text: $password).textContentType(.password)
            }
            .padding(.horizontal, 14).frame(height: 52)
            .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            Button { Task { await login() } } label: {
                HStack { if isLoading { ProgressView().tint(.white) }; Text(loginAction); Spacer(); Image(systemName: "arrow.right") }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .disabled(iumrahID.filter(\.isNumber).count != 6 || password.count < 8 || isLoading)
            Text(activationNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .iumrahCard()
    }

    @MainActor private func login() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do {
            _ = try await account.login(iumrahID: iumrahID, password: password)
            if let token = account.bearerToken { await bookings.restoreAccountTrips(token: token) }
            IumrahHaptics.success()
        } catch { errorMessage = L10n.error(error, settings.language); IumrahHaptics.error() }
    }

    private func t(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String { switch settings.language { case .russian:return ru; case .english:return en; case .uzbek:return uz; case .uzbekCyrillic:return cyrl } }
    private var doneTitle: String { t("Done","Готово","Tayyor","Тайёр") }
    private var titleText: String { t("One ID. Every Umrah.","Один ID. Все Ваши поездки.","Bitta ID. Barcha Umra safarlari.","Битта ID. Барча Умра сафарлари.") }
    private var bodyText: String { t("Your six-digit iumrah ID is your permanent login and connects every trip to one account.","Шестизначный iumrah ID — Ваш постоянный логин. Он объединяет все поездки в одном аккаунте.","Olti xonali iumrah ID — doimiy loginingiz va barcha safarlarni bir akkauntga birlashtiradi.","Олти хонали iumrah ID — доимий логинингиз ва барча сафарларни бир аккаунтга бирлаштиради.") }
    private var loginTitle: String { t("Sign in","Войти в аккаунт","Akkauntga kirish","Аккаунтга кириш") }
    private var passwordTitle: String { t("Password","Пароль","Parol","Парол") }
    private var loginAction: String { t("Sign in to iumrah","Войти в iumrah","iumrah ga kirish","iumrah га кириш") }
    private var logoutTitle: String { t("Sign out","Выйти из аккаунта","Chiqish","Чиқиш") }
    private var accountState: String { t("Account active","Аккаунт активен","Akkaunt faol","Аккаунт фаол") }
    private var activationNote: String { t("A password is created when availability is confirmed and your booking moves to payment & pilgrim details.","Пароль создаётся после подтверждения наличия, когда поездка переходит к оплате и данным паломников.","Parol mavjudlik tasdiqlanib, bron to‘lov va ziyoratchi ma’lumotlari bosqichiga o‘tganda yaratiladi.","Парол мавжудлик тасдиқланиб, брон тўлов ва зиёратчи маълумотлари босқичига ўтганда яратилади.") }
    private var tripsWord: String { t("trips","поездок","safar","сафар") }
}
