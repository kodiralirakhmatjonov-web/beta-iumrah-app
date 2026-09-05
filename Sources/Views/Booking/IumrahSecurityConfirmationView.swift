import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
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
    @State private var passportPhotoItem: PhotosPickerItem?
    @State private var passportPhotoData: Data?
    @State private var passportPreview: UIImage?
    @State private var passportContentType = "image/jpeg"
    @State private var existing: IumrahSecurityConfirmation?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var isPreparingPhoto = false
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

    private var hasPassportPhoto: Bool {
        passportPhotoData != nil || existing?.hasPassportPhoto == true
    }

    private var canSubmit: Bool {
        validName(firstName)
            && validName(lastName)
            && normalizedPassport.count >= 5
            && normalizedPassport.count <= 20
            && holderConfirmed
            && hasPassportPhoto
            && !isSubmitting
            && !isPreparingPhoto
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                securityHero
                introCopy

                if isLoading {
                    loadingCard
                } else if let existing, existing.isConfirmed {
                    confirmedCard(existing)
                } else if let existing, existing.isPendingReview {
                    pendingReviewCard(existing)
                } else {
                    if let existing, existing.needsResubmission {
                        correctionCard(existing)
                    }
                    warningCard
                    passportForm
                    passportPhotoCard
                    holderConfirmation
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
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("iumrah Security")
                        .font(.headline)
                    Text("Security Confirmation · KYC")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .iumrahInternalNavigation()
        .task { await load() }
        .onChange(of: passportPhotoItem) { _, item in
            guard let item else { return }
            Task { await preparePassportPhoto(item) }
        }
    }


    private var securityHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black)

            LoopingVideoView(resource: "iumrah-security-identity", gravity: .resizeAspect)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .frame(height: 292)
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .accessibilityHidden(true)
    }

    private var introCopy: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("iumrah Security", systemImage: "lock.shield.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(tr(
                "Confirm the booking holder",
                "Подтверждение владельца бронирования",
                "Bron egasini tasdiqlash",
                "Брон эгасини тасдиқлаш"
            ))
            .font(.system(size: 29, weight: .bold, design: .rounded))
            .tracking(-0.5)

            Text(tr(
                "Send the passport profile for manual review by iumrah Business. Gift Card protection is activated only after the document is checked and confirmed.",
                "Отправьте паспортный профиль на ручную проверку в iumrah Business. Защита Gift Card активируется только после сверки и подтверждения документа.",
                "Pasport profilini iumrah Business orqali qo‘lda tekshirish uchun yuboring. Gift Card himoyasi hujjat tekshirilgandan va tasdiqlangandan keyingina faollashadi.",
                "Паспорт профилини iumrah Business орқали қўлда текшириш учун юборинг. Gift Card ҳимояси ҳужжат текширилгандан ва тасдиқлангандан кейингина фаоллашади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 42, height: 42)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), tint: Color.red.opacity(0.10))

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
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                TextField(tr("Passport number", "Номер паспорта", "Pasport raqami", "Паспорт рақами"), text: $passportNumber)
                    .textContentType(.none)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .passport)
                    .padding(.horizontal, 15)
                    .frame(height: 56)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
                    .onChange(of: passportNumber) { _, value in
                        let normalized = value.uppercased().filter { $0.isLetter || $0.isNumber }
                        if normalized != value { passportNumber = normalized }
                    }
            }
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
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .padding(.horizontal, 15)
                .frame(height: 56)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
        }
    }

    private var passportPhotoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Passport photo", "Фото паспорта", "Pasport rasmi", "Паспорт расми"))
                        .font(.headline)
                    Text(tr(
                        "Attach the passport page with the holder photo and data.",
                        "Прикрепите страницу паспорта с фотографией и данными владельца.",
                        "Egasi rasmi va ma’lumotlari ko‘rsatilgan pasport sahifasini biriktiring.",
                        "Эгаси расми ва маълумотлари кўрсатилган паспорт саҳифасини бириктиринг."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: hasPassportPhoto ? "checkmark.circle.fill" : "photo.badge.plus")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(hasPassportPhoto ? .green : .secondary)
            }

            if let passportPreview {
                Image(uiImage: passportPreview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    }
            } else if existing?.hasPassportPhoto == true {
                Label(
                    tr("Passport photo attached", "Фото паспорта прикреплено", "Pasport rasmi biriktirilgan", "Паспорт расми бириктирилган"),
                    systemImage: "checkmark.shield.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            PhotosPicker(selection: $passportPhotoItem, matching: .images) {
                HStack {
                    if isPreparingPhoto { ProgressView().controlSize(.small) }
                    else { Image(systemName: "photo.on.rectangle.angled") }
                    Text(hasPassportPhoto
                         ? tr("Replace passport photo", "Заменить фото паспорта", "Pasport rasmini almashtirish", "Паспорт расмини алмаштириш")
                         : tr("Attach passport photo", "Прикрепить фото паспорта", "Pasport rasmini biriktirish", "Паспорт расмини бириктириш"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
            }
            .buttonStyle(.plain)
            .disabled(isPreparingPhoto || isSubmitting)
        }
        .iumrahCard()
    }

    private var holderConfirmation: some View {
        Toggle(isOn: $holderConfirmed) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tr("I confirm these are my booking-holder details", "Подтверждаю данные владельца бронирования", "Bron egasi ma’lumotlarini tasdiqlayman", "Брон эгаси маълумотларини тасдиқлайман"))
                    .font(.subheadline.weight(.semibold))
                Text(tr(
                    "iumrah Business will manually compare the entered data with the attached passport photo.",
                    "iumrah Business вручную сверит введённые данные с прикреплённой фотографией паспорта.",
                    "iumrah Business kiritilgan ma’lumotlarni pasport rasmi bilan qo‘lda solishtiradi.",
                    "iumrah Business киритилган маълумотларни паспорт расми билан қўлда солиштиради."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 17, weight: .semibold))
            Text(tr(
                "Your submission stays in the protected manual-review queue. Gift Card anti-fraud uses the confirmed passport identity fingerprint only after iumrah Business approves the document.",
                "Заявка хранится в защищённой очереди ручной проверки. Антифрод Gift Card использует подтверждённый fingerprint паспортной личности только после одобрения документа в iumrah Business.",
                "Ariza himoyalangan qo‘lda tekshirish navbatida saqlanadi. Gift Card antifraud pasport identity fingerprintidan faqat iumrah Business hujjatni tasdiqlagandan keyin foydalanadi.",
                "Ариза ҳимояланган қўлда текшириш навбатида сақланади. Gift Card antifraud паспорт identity fingerprintидан фақат iumrah Business ҳужжатни тасдиқлагандан кейин фойдаланади."
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
                if isSubmitting { ProgressView().controlSize(.small) }
                else { Image(systemName: "paperplane.fill") }
                Text(tr(
                    "Send for manual review",
                    "Отправить на ручную проверку",
                    "Qo‘lda tekshirishga yuborish",
                    "Қўлда текширишга юбориш"
                ))
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.45)
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

    private func pendingReviewCard(_ value: IumrahSecurityConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "hourglass.circle.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 50, height: 50)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous), tint: Color.blue.opacity(0.10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Waiting for manual verification", "Ожидает ручной проверки", "Qo‘lda tekshirish kutilmoqda", "Қўлда текшириш кутилмоқда"))
                        .font(.title3.weight(.bold))
                    Text(tr(
                        "Your passport profile and photo have been sent securely to iumrah Business. Gift Card identity protection remains pending until a staff member confirms the document.",
                        "Паспортный профиль и фотография безопасно отправлены в iumrah Business. Защита личности Gift Card остаётся в ожидании, пока сотрудник вручную не подтвердит документ.",
                        "Pasport profilingiz va rasmingiz iumrah Business ga xavfsiz yuborildi. Xodim hujjatni qo‘lda tasdiqlamaguncha Gift Card himoyasi kutilmoqda.",
                        "Паспорт профилингиз ва расмингиз iumrah Business га хавфсиз юборилди. Ходим ҳужжатни қўлда тасдиқламагунича Gift Card ҳимояси кутилмоқда."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
            summaryRow(title: tr("Name", "Имя", "Ism", "Исм"), value: [value.firstName, value.lastName].joined(separator: " "))
            summaryRow(title: tr("Passport", "Паспорт", "Pasport", "Паспорт"), value: value.passportLast4.isEmpty ? "—" : "•••• \(value.passportLast4)")
            summaryRow(title: tr("Status", "Статус", "Holat", "Ҳолат"), value: tr("Manual review", "Ручная проверка", "Qo‘lda tekshirish", "Қўлда текшириш"))
        }
        .iumrahCard()
    }

    private func confirmedCard(_ value: IumrahSecurityConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 50, height: 50)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous), tint: Color.green.opacity(0.10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Identity confirmed", "Личность подтверждена", "Shaxs tasdiqlandi", "Шахс тасдиқланди"))
                        .font(.title3.weight(.bold))
                    Text(tr(
                        "iumrah Business manually checked the passport profile. This confirmed identity can now protect Gift Card eligibility from duplicate use.",
                        "iumrah Business вручную сверил паспортный профиль. Теперь подтверждённая личность используется для защиты Gift Card от повторного применения.",
                        "iumrah Business pasport profilini qo‘lda tekshirdi. Tasdiqlangan shaxs endi Gift Card dan takroriy foydalanishni himoya qiladi.",
                        "iumrah Business паспорт профилини қўлда текширди. Тасдиқланган шахс энди Gift Card дан такрорий фойдаланишни ҳимоя қилади."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
            summaryRow(title: tr("Name", "Имя", "Ism", "Исм"), value: [value.firstName, value.lastName].joined(separator: " "))
            summaryRow(title: tr("Passport", "Паспорт", "Pasport", "Паспорт"), value: value.passportLast4.isEmpty ? "—" : "•••• \(value.passportLast4)")
            summaryRow(title: tr("Status", "Статус", "Holat", "Ҳолат"), value: tr("Confirmed", "Подтверждено", "Tasdiqlandi", "Тасдиқланди"))
        }
        .iumrahCard()
    }

    private func correctionCard(_ value: IumrahSecurityConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                value.normalizedStatus == "rejected"
                    ? tr("Verification rejected", "Подтверждение отклонено", "Tasdiqlash rad etildi", "Тасдиқлаш рад этилди")
                    : tr("Please correct the profile", "Исправьте данные профиля", "Profilni tuzating", "Профилни тузатинг"),
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.headline)
            .foregroundStyle(.orange)

            if !value.reviewNote.isEmpty {
                Text(value.reviewNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            if let value = response.confirmation, value.canEdit {
                if firstName.isEmpty { firstName = value.firstName }
                if lastName.isEmpty { lastName = value.lastName }
            }
        } catch APIError.status(let code) where code == 404 {
            existing = nil
        } catch {
            errorMessage = L10n.error(error, settings.language)
        }
    }

    @MainActor
    private func preparePassportPhoto(_ item: PhotosPickerItem) async {
        isPreparingPhoto = true
        errorMessage = nil
        defer { isPreparingPhoto = false }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self), !raw.isEmpty else {
                throw APIError.invalidResponse
            }
            let optimized = optimizedPassportImage(raw)
            passportPhotoData = optimized.data
            passportContentType = optimized.contentType
            passportPreview = UIImage(data: optimized.data)
        } catch {
            passportPhotoData = nil
            passportPreview = nil
            errorMessage = tr(
                "Could not prepare the passport photo.",
                "Не удалось подготовить фото паспорта.",
                "Pasport rasmini tayyorlab bo‘lmadi.",
                "Паспорт расмини тайёрлаб бўлмади."
            )
        }
    }

    @MainActor
    private func submit() async {
        guard canSubmit, let session else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            if let passportPhotoData {
                let upload = try await service.uploadSecurityPassport(
                    id: bookingID,
                    accessToken: session.accessToken,
                    data: passportPhotoData,
                    contentType: passportContentType
                )
                existing = upload.confirmation
            }

            let response = try await service.submitSecurityConfirmation(
                id: bookingID,
                accessToken: session.accessToken,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                passportNumber: normalizedPassport
            )
            guard let confirmation = response.confirmation else { throw APIError.invalidResponse }
            existing = confirmation
            passportNumber = ""
            holderConfirmed = false
            passportPhotoData = nil
            passportPreview = nil
            passportPhotoItem = nil
            IumrahHaptics.success()
        } catch APIError.server(_, let message) where message == "IDENTITY_CONFIRMATION_NOT_AVAILABLE" {
            errorMessage = tr(
                "Security Confirmation becomes available only after availability is confirmed and the booking moves to payment and pilgrim details.",
                "Security Confirmation доступен только после подтверждения наличия, когда бронирование перейдёт к оплате и данным паломников.",
                "Security Confirmation faqat mavjudlik tasdiqlanib, bron to‘lov va ziyoratchi ma’lumotlari bosqichiga o‘tgandan keyin ochiladi.",
                "Security Confirmation фақат мавжудлик тасдиқланиб, брон тўлов ва зиёратчи маълумотлари босқичига ўтгандан кейин очилади."
            )
            IumrahHaptics.error()
        } catch APIError.server(_, let message) where message == "IDENTITY_PASSPORT_PHOTO_REQUIRED" {
            errorMessage = tr(
                "Attach a passport photo before sending the profile.",
                "Прикрепите фото паспорта перед отправкой профиля.",
                "Profilni yuborishdan oldin pasport rasmini biriktiring.",
                "Профилни юборишдан олдин паспорт расмини бириктиринг."
            )
            IumrahHaptics.error()
        } catch {
            errorMessage = L10n.error(error, settings.language)
            IumrahHaptics.error()
        }
    }

    private func optimizedPassportImage(_ data: Data) -> (data: Data, contentType: String) {
        guard let image = UIImage(data: data) else { return (data, "image/jpeg") }
        let maxDimension: CGFloat = 2200
        let largest = max(image.size.width, image.size.height)
        let scale = largest > maxDimension ? maxDimension / largest : 1
        let target = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))

        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return (rendered.jpegData(compressionQuality: 0.86) ?? data, "image/jpeg")
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
