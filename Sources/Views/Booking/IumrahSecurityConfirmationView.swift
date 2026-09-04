import SwiftUI
import AVFoundation
import UIKit

struct IumrahSecurityConfirmationView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var bookings: BookingStore
    @Environment(\.dismiss) private var dismiss

    let bookingID: String

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var passportNumber = ""
    @State private var holderConfirmed = false
    @State private var existing: IumrahSecurityConfirmation?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private let service = BookingService()

    private enum Field: Hashable {
        case firstName, lastName, passport
    }

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    private var normalizedPassport: String {
        passportNumber
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private var canSubmit: Bool {
        validName(firstName) && validName(lastName) && normalizedPassport.count >= 5 && normalizedPassport.count <= 20 && holderConfirmed && !isSubmitting
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                securityHero

                if isLoading {
                    loadingCard
                } else if let existing, existing.isSubmitted {
                    submittedCard(existing)
                } else {
                    warningCard
                    passportForm
                    privacyCard
                    submitButton
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 52)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.iumrahPageBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .task { await load() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                IumrahHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .iumrahGlass(in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("iumrah Security")
                    .font(.headline)
                Text(tr("Security Confirmation · KYC", "Security Confirmation · KYC", "Security Confirmation · KYC", "Security Confirmation · KYC"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var securityHero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)

            LoopingVideoView(resource: "iumrah-security-identity", gravity: .resizeAspect)
                .allowsHitTesting(false)
                .opacity(0.96)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.12), Color.black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Label("iumrah Security", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7))

                Text(tr(
                    "Confirm the booking holder",
                    "Подтверждение владельца бронирования",
                    "Bron egasini tasdiqlash",
                    "Брон эгасини тасдиқлаш"
                ))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

                Text(tr(
                    "Your passport profile is linked to this trip and helps protect booking benefits from duplicate use.",
                    "Паспортный профиль привязывается к этой поездке и помогает защитить преимущества бронирования от повторного использования.",
                    "Pasport profilingiz ushbu safarga bog‘lanadi va bron imtiyozlarini takroriy foydalanishdan himoya qilishga yordam beradi.",
                    "Паспорт профилингиз ушбу сафарга боғланади ва брон имтиёзларини такрорий фойдаланишдан ҳимоя қилишга ёрдам беради."
                ))
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(height: 286)
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 42, height: 42)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(tr("Important", "Важно", "Muhim", "Муҳим"))
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(tr(
                    "These passport details are used for your booking. Enter your first name, last name and passport number exactly as they appear in the passport. Incorrect details can prevent travel services from being issued correctly.",
                    "Эти паспортные данные используются именно в Вашем бронировании. Введите имя, фамилию и номер паспорта точно так, как они указаны в паспорте. Ошибка может помешать корректному оформлению услуг поездки.",
                    "Bu pasport ma’lumotlari aynan broningizda ishlatiladi. Ism, familiya va pasport raqamini pasportdagidek aniq kiriting. Xato ma’lumot safar xizmatlarini to‘g‘ri rasmiylashtirishga xalaqit berishi mumkin.",
                    "Бу паспорт маълумотлари айнан бронда ишлатилади. Исм, фамилия ва паспорт рақамини паспортдагидек аниқ киритинг. Хато маълумот сафар хизматларини тўғри расмийлаштиришга халақит бериши мумкин."
                ))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.075), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.red.opacity(0.20), lineWidth: 1)
        }
    }

    private var passportForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Passport profile", "Паспортный профиль", "Pasport profili", "Паспорт профили"))
                        .font(.headline)
                    Text(tr("Booking holder", "Владелец бронирования", "Bron egasi", "Брон эгаси"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            securityField(
                title: tr("First name", "Имя", "Ism", "Исм"),
                placeholder: tr("Exactly as in passport", "Как в паспорте", "Pasportdagidek", "Паспортдагидек"),
                text: $firstName,
                field: .firstName,
                contentType: .givenName
            )

            securityField(
                title: tr("Last name", "Фамилия", "Familiya", "Фамилия"),
                placeholder: tr("Exactly as in passport", "Как в паспорте", "Pasportdagidek", "Паспортдагидек"),
                text: $lastName,
                field: .lastName,
                contentType: .familyName
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: "passport.fill")
                        .foregroundStyle(.secondary)
                    TextField(tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"), text: $passportNumber)
                        .focused($focusedField, equals: .passport)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .privacySensitive()
                        .onChange(of: passportNumber) { _, newValue in
                            let cleaned = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                            if cleaned != newValue { passportNumber = String(cleaned.prefix(20)) }
                            else if newValue.count > 20 { passportNumber = String(newValue.prefix(20)) }
                        }
                }
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(focusedField == .passport ? Color.primary.opacity(0.18) : Color.primary.opacity(0.05), lineWidth: 1)
                }
            }

            Button {
                holderConfirmed.toggle()
                IumrahHaptics.selection()
            } label: {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: holderConfirmed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(holderConfirmed ? Color.iumrahCareLight : Color.secondary)
                        .padding(.top, 1)
                    Text(tr(
                        "I confirm that these details belong to the passport holder of this booking and are accurate.",
                        "Я подтверждаю, что эти данные принадлежат владельцу паспорта этого бронирования и указаны точно.",
                        "Ushbu ma’lumotlar bron egasining pasportiga tegishli va aniq kiritilganini tasdiqlayman.",
                        "Ушбу маълумотлар брон эгасининг паспортига тегишли ва аниқ киритилганини тасдиқлайман."
                    ))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .iumrahCard()
    }

    private func securityField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .padding(.horizontal, 15)
                .frame(height: 56)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(focusedField == field ? Color.primary.opacity(0.18) : Color.primary.opacity(0.05), lineWidth: 1)
                }
        }
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 17, weight: .semibold))
            Text(tr(
                "iumrah Security does not display your full passport number after submission. A protected identity fingerprint is used to detect duplicate benefit use; travel-document processing remains part of your booking flow.",
                "После отправки iumrah Security не показывает полный номер паспорта. Защищённый fingerprint личности используется для выявления повторного использования преимуществ; оформление документов поездки остаётся частью Вашего бронирования.",
                "Yuborilgandan keyin iumrah Security pasport raqamingizni to‘liq ko‘rsatmaydi. Himoyalangan identity fingerprint imtiyozlardan takroriy foydalanishni aniqlashga yordam beradi; safar hujjatlarini rasmiylashtirish bron jarayonida davom etadi.",
                "Юборилгандан кейин iumrah Security паспорт рақамингизни тўлиқ кўрсатмайди. Ҳимояланган identity fingerprint имтиёзлардан такрорий фойдаланишни аниқлашга ёрдам беради; сафар ҳужжатларини расмийлаштириш брон жараёнида давом этади."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting { ProgressView().tint(.white) }
                Image(systemName: "checkmark.shield.fill")
                Text(tr("Submit securely", "Подтвердить безопасно", "Xavfsiz tasdiqlash", "Хавфсиз тасдиқлаш"))
                Spacer()
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.48)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(tr("Checking security status…", "Проверяем статус безопасности…", "Xavfsizlik holati tekshirilmoqda…", "Хавфсизлик ҳолати текширилмоқда…"))
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private func submittedCard(_ value: IumrahSecurityConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Color.iumrahCareLight)
                    .frame(width: 50, height: 50)
                    .background(Color.iumrahCareLight.opacity(0.13), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Profile submitted for confirmation", "Профиль отправлен на подтверждение", "Profil tasdiqlash uchun yuborildi", "Профиль тасдиқлаш учун юборилди"))
                        .font(.title3.weight(.bold))
                    Text(tr(
                        "Your booking holder details are secured. Final document verification can be completed during travel-document processing.",
                        "Данные владельца бронирования защищены. Финальная проверка документа может быть завершена во время оформления документов поездки.",
                        "Bron egasi ma’lumotlari himoyalangan. Hujjatning yakuniy tekshiruvi safar hujjatlarini rasmiylashtirish vaqtida yakunlanishi mumkin.",
                        "Брон эгаси маълумотлари ҳимояланган. Ҳужжатнинг якуний текшируви сафар ҳужжатларини расмийлаштириш вақтида якунланиши мумкин."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            summaryRow(title: tr("Name", "Имя", "Ism", "Исм"), value: [value.firstName, value.lastName].joined(separator: " "))
            summaryRow(title: tr("Passport", "Паспорт", "Pasport", "Паспорт"), value: "•••• \(value.passportLast4)")
            summaryRow(title: tr("Status", "Статус", "Holat", "Ҳолат"), value: tr("Submitted", "Отправлено", "Yuborildi", "Юборилди"))

            if value.reusedIdentity {
                Label(
                    tr(
                        "This identity has appeared in an earlier iumrah booking. Benefits that require a new customer are checked separately.",
                        "Эта личность уже встречалась в предыдущем бронировании iumrah. Преимущества, доступные только новым клиентам, проверяются отдельно.",
                        "Bu shaxs avvalgi iumrah bronida uchragan. Faqat yangi mijozlarga tegishli imtiyozlar alohida tekshiriladi.",
                        "Бу шахс аввалги iumrah бронида учраган. Фақат янги мижозларга тегишли имтиёзлар алоҳида текширилади."
                    ),
                    systemImage: "person.2.badge.gearshape.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .iumrahCard()
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let session else {
            errorMessage = tr("Booking not found.", "Бронирование не найдено.", "Bron topilmadi.", "Брон топилмади.")
            return
        }

        if firstName.isEmpty { firstName = session.booking.pilgrimProfile?.firstName ?? "" }
        if lastName.isEmpty { lastName = session.booking.pilgrimProfile?.lastName ?? "" }

        do {
            let response = try await service.securityConfirmation(id: bookingID, accessToken: session.accessToken)
            existing = response.confirmation
        } catch APIError.status(let code) where code == 404 {
            existing = nil
        } catch {
            // The entry screen remains usable if an older backend has not been deployed yet.
            existing = nil
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit, let session else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await service.submitSecurityConfirmation(
                id: bookingID,
                accessToken: session.accessToken,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                passportNumber: normalizedPassport
            )
            guard let confirmation = response.confirmation else {
                throw APIError.invalidResponse
            }
            existing = confirmation
            passportNumber = ""
            holderConfirmed = false
            IumrahHaptics.success()
        } catch APIError.server(_, let message) where message == "IDENTITY_CONFIRMATION_NOT_AVAILABLE" {
            errorMessage = tr(
                "Security Confirmation becomes available only after availability is confirmed and the booking moves to payment and pilgrim details.",
                "Security Confirmation доступен только после подтверждения наличия, когда бронирование перейдёт к оплате и данным паломников.",
                "Security Confirmation faqat mavjudlik tasdiqlanib, bron to‘lov va ziyoratchi ma’lumotlari bosqichiga o‘tgandan keyin ochiladi.",
                "Security Confirmation фақат мавжудлик тасдиқланиб, брон тўлов ва зиёратчи маълумотлари босқичига ўтгандан кейин очилади."
            )
            IumrahHaptics.error()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    private func validName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 80 else { return false }
        return trimmed.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar)
                || CharacterSet.whitespaces.contains(scalar)
                || scalar == "-" || scalar == "'" || scalar == "’"
        }
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ uzCyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCyrl
        }
    }
}
