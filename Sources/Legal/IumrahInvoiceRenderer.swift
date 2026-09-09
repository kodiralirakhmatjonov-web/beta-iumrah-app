import SwiftUI
import UIKit

struct IumrahInvoiceShareCard: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let session: StoredBookingSession
    var compact: Bool = false

    @State private var shareURL: URL?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IumrahIconBadge(systemName: "doc.text.fill", role: .document, size: compact ? 40 : 44, symbolSize: 17, cornerRadius: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedTitle)
                        .font(compact ? .subheadline.weight(.semibold) : .headline)
                    Text(localizedBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            Button {
                do {
                    shareURL = try IumrahInvoiceRenderer.makeInvoice(session: session, language: settings.language)
                    IumrahHaptics.soft()
                } catch {
                    errorText = localizedError
                    IumrahHaptics.error()
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text(localizedAction)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                IumrahFileShareSheet(url: shareURL)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var localizedTitle: String {
        switch settings.language {
        case .russian: return "Инвойс бронирования"
        case .english: return "Booking invoice"
        case .uzbek: return "Bron invoice"
        case .uzbekCyrillic: return "Брон invoice"
        }
    }

    private var localizedBody: String {
        switch settings.language {
        case .russian: return "Формируется из сохранённых данных этой поездки и доступен для сохранения в PDF."
        case .english: return "Generated from the saved booking snapshot and available to save as a PDF."
        case .uzbek: return "Saqlangan bron ma’lumotlaridan yaratiladi va PDF sifatida saqlanishi mumkin."
        case .uzbekCyrillic: return "Сақланган брон маълумотларидан яратилади ва PDF сифатида сақланиши мумкин."
        }
    }

    private var localizedAction: String {
        switch settings.language {
        case .russian: return "Сохранить инвойс PDF"
        case .english: return "Save invoice PDF"
        case .uzbek: return "Invoice PDF saqlash"
        case .uzbekCyrillic: return "Invoice PDF сақлаш"
        }
    }

    private var localizedError: String {
        switch settings.language {
        case .russian: return "Не удалось сформировать PDF. Попробуйте ещё раз."
        case .english: return "Could not create the PDF. Please try again."
        case .uzbek: return "PDF yaratilmadi. Qayta urinib ko‘ring."
        case .uzbekCyrillic: return "PDF яратилмади. Қайта уриниб кўринг."
        }
    }
}

struct IumrahFileShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum IumrahInvoiceRenderer {
    static func makeInvoice(session: StoredBookingSession, language: AppSettingsStore.Language) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        let metadata: [String: Any] = [
            kCGPDFContextTitle as String: invoiceTitle(language),
            kCGPDFContextCreator as String: "iumrah"
        ]
        format.documentInfo = metadata
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)

        let safeNumber = session.displayBookingNumber.replacingOccurrences(of: "#", with: "")
        let filename = "iumrah-invoice-\(safeNumber.isEmpty ? session.id : safeNumber).pdf"
        let documentsRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let invoiceDirectory = documentsRoot
            .appendingPathComponent("iumrah", isDirectory: true)
            .appendingPathComponent("Invoices", isDirectory: true)
        try FileManager.default.createDirectory(at: invoiceDirectory, withIntermediateDirectories: true)
        let url = invoiceDirectory.appendingPathComponent(filename)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            var y: CGFloat = 48
            let left: CGFloat = 44
            let width: CGFloat = page.width - 88

            draw("iumrah", at: CGRect(x: left, y: y, width: width, height: 36), font: .systemFont(ofSize: 28, weight: .bold), color: .label)
            y += 42
            draw(invoiceTitle(language), at: CGRect(x: left, y: y, width: width, height: 28), font: .systemFont(ofSize: 20, weight: .bold), color: .label)
            y += 40

            drawKeyValue(key: bookingLabel(language), value: session.displayBookingNumber, x: left, y: &y, width: width)
            drawKeyValue(key: dateLabel(language), value: invoiceDate(language), x: left, y: &y, width: width)
            drawKeyValue(key: routeLabel(language), value: "\(session.booking.route.originCode) → \(session.booking.route.outboundDestination)", x: left, y: &y, width: width)
            drawKeyValue(key: travelDatesLabel(language), value: "\(session.booking.input.startDate) — \(session.booking.input.endDate)", x: left, y: &y, width: width)
            drawKeyValue(key: travelersLabel(language), value: "\(session.booking.input.travelers.totalPeople)", x: left, y: &y, width: width)
            drawKeyValue(key: packageLabel(language), value: session.booking.planId.capitalized, x: left, y: &y, width: width)

            y += 12
            drawDivider(x: left, y: y, width: width)
            y += 22

            draw(totalLabel(language), at: CGRect(x: left, y: y, width: width * 0.55, height: 30), font: .systemFont(ofSize: 16, weight: .semibold), color: .secondaryLabel)
            let total = String(format: "$%.2f", session.booking.totalUsd)
            draw(total, at: CGRect(x: left + width * 0.55, y: y - 3, width: width * 0.45, height: 36), font: .monospacedDigitSystemFont(ofSize: 24, weight: .bold), color: .label, alignment: .right)
            y += 54

            draw(sectionTitle(language), at: CGRect(x: left, y: y, width: width, height: 24), font: .systemFont(ofSize: 15, weight: .bold), color: .label)
            y += 30
            let terms = termsText(language)
            let termHeight = (terms as NSString).boundingRect(with: CGSize(width: width, height: 220), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: UIFont.systemFont(ofSize: 11)], context: nil).height + 8
            draw(terms, at: CGRect(x: left, y: y, width: width, height: termHeight), font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += termHeight + 18

            drawDivider(x: left, y: y, width: width)
            y += 18
            draw(footer(language), at: CGRect(x: left, y: y, width: width, height: 60), font: .systemFont(ofSize: 9), color: .tertiaryLabel)
        }

        return url
    }

    private static func drawKeyValue(key: String, value: String, x: CGFloat, y: inout CGFloat, width: CGFloat) {
        draw(key, at: CGRect(x: x, y: y, width: width * 0.42, height: 22), font: .systemFont(ofSize: 11, weight: .semibold), color: .secondaryLabel)
        draw(value, at: CGRect(x: x + width * 0.42, y: y, width: width * 0.58, height: 22), font: .systemFont(ofSize: 11, weight: .medium), color: .label, alignment: .right)
        y += 26
    }

    private static func drawDivider(x: CGFloat, y: CGFloat, width: CGFloat) {
        UIColor.separator.setFill()
        UIRectFill(CGRect(x: x, y: y, width: width, height: 0.6))
    }

    private static func draw(_ text: String, at rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]).draw(in: rect)
    }

    private static func invoiceTitle(_ language: AppSettingsStore.Language) -> String {
        switch language {
        case .russian: return "Инвойс бронирования"
        case .english: return "Booking Invoice"
        case .uzbek: return "Bron Invoice"
        case .uzbekCyrillic: return "Брон Invoice"
        }
    }

    private static func bookingLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Бронирование", "Booking", "Bron", "Брон") }
    private static func dateLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Дата инвойса", "Invoice date", "Invoice sanasi", "Invoice санаси") }
    private static func routeLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Маршрут", "Route", "Yo‘nalish", "Йўналиш") }
    private static func travelDatesLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Даты поездки", "Travel dates", "Safar sanalari", "Сафар саналари") }
    private static func travelersLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Паломники", "Pilgrims", "Ziyoratchilar", "Зиёратчилар") }
    private static func packageLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Пакет", "Package", "Paket", "Пакет") }
    private static func totalLabel(_ language: AppSettingsStore.Language) -> String { label(language, "Сумма бронирования", "Booking total", "Bron summasi", "Брон суммаси") }
    private static func sectionTitle(_ language: AppSettingsStore.Language) -> String { label(language, "Оплата и возврат", "Payment & refunds", "To‘lov va qaytarish", "Тўлов ва қайтариш") }

    private static func invoiceDate(_ language: AppSettingsStore.Language) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    private static func termsText(_ language: AppSettingsStore.Language) -> String {
        label(language,
              "В первой версии оплата временно выполняется вручную по реквизитам внутри бронирования. После оплаты необходимо прикрепить банковский чек. Возврат рассчитывается отдельно: авиабилеты и отели по умолчанию невозвратные, если конкретный тариф не говорит иначе; трансфер — полный возврат до 120 часов, затем удержание $100; неиспользованные сервисы iumrah возвращаются до начала услуги.",
              "In the first release, payment is temporarily made manually using the details inside the booking. After payment, upload the bank receipt. Refunds are calculated separately: flights and hotels are non-refundable by default unless the selected fare/rate says otherwise; transfer is fully refundable until 120 hours before service, then a $100 fee applies; unused iumrah services are refundable before they begin.",
              "Birinchi versiyada to‘lov vaqtincha bron ichidagi rekvizitlar bo‘yicha qo‘lda amalga oshiriladi. To‘lovdan keyin bank chekini yuklang. Qaytarish alohida hisoblanadi: aviachiptalar va mehmonxonalar aniq tarif boshqacha demasa, odatda qaytarilmaydi; transfer 120 soatgacha to‘liq qaytariladi, keyin $100 ushlab qolinadi; foydalanilmagan iumrah xizmatlari boshlanishidan oldin qaytariladi.",
              "Биринчи версияда тўлов вақтинча брон ичидаги реквизитлар бўйича қўлда амалга оширилади. Тўловдан кейин банк чекни юкланг. Қайтариш алоҳида ҳисобланади: авиачипталар ва меҳмонхоналар аниқ тариф бошқача демаса, одатда қайтарилмайди; трансфер 120 соатгача тўлиқ қайтарилади, кейин $100 ушлаб қолинади; фойдаланилмаган iumrah хизматлари бошланишидан олдин қайтарилади.")
    }

    private static func footer(_ language: AppSettingsStore.Language) -> String {
        label(language,
              "Этот PDF сформирован из сохранённого снимка бронирования iumrah. Он не является банковской квитанцией. Подтверждением ручной оплаты служит загруженный банковский чек после его сверки с бронированием.",
              "This PDF is generated from the saved iumrah booking snapshot. It is not a bank receipt. Proof of manual payment is the uploaded bank receipt after it is reconciled with the booking.",
              "Ushbu PDF saqlangan iumrah bron ma’lumotlaridan yaratilgan. U bank cheki emas. Qo‘lda to‘lov tasdig‘i — bron bilan tekshirilgan yuklangan bank cheki.",
              "Ушбу PDF сақланган iumrah брон маълумотларидан яратилган. У банк чеки эмас. Қўлда тўлов тасдиғи — брон билан текширилган юкланган банк чеки.")
    }

    private static func label(_ language: AppSettingsStore.Language, _ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        switch language {
        case .russian: return ru
        case .english: return en
        case .uzbek: return uz
        case .uzbekCyrillic: return uzCy
        }
    }
}
