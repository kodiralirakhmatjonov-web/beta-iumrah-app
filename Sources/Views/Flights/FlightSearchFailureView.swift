import SwiftUI

/// Search-stage surface shown only before the first verified flight exists.
/// It intentionally does not use the "Choose flight" title: the pilgrim remains
/// in discovery until at least one concrete itinerary passes the strict boundary.
struct FlightSearchGateView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let direction: FlightDirection
    let anchorDate: Date
    let flexibility: DateFlexibility
    let message: String
    let providerEvents: [FlightProviderSearchEvent]
    let challenge: FlightBotChallenge?
    let onRetry: () -> Void
    let onOpenChallenge: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                IumrahFlowProgress(stage: .flight)

                SectionHeader(
                    searchTitle,
                    eyebrow: directionEyebrow,
                    subtitle: searchSubtitle
                )

                FlightSearchFailureView(
                    anchorDate: anchorDate,
                    flexibility: flexibility,
                    message: message,
                    providerEvents: providerEvents,
                    challenge: challenge,
                    onRetry: onRetry,
                    onOpenChallenge: onOpenChallenge
                )
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground)
    }

    private var directionEyebrow: String {
        switch (direction, settings.language) {
        case (.outbound, .russian): return "ТУДА"
        case (.outbound, .english): return "OUTBOUND"
        case (.outbound, .uzbek): return "BORISH"
        case (.outbound, .uzbekCyrillic): return "БОРИШ"
        case (.inbound, .russian): return "ОБРАТНО"
        case (.inbound, .english): return "RETURN"
        case (.inbound, .uzbek): return "QAYTISH"
        case (.inbound, .uzbekCyrillic): return "ҚАЙТИШ"
        }
    }

    private var searchTitle: String {
        switch settings.language {
        case .russian: return "Поиск перелёта"
        case .english: return "Flight search"
        case .uzbek: return "Parvoz qidiruvi"
        case .uzbekCyrillic: return "Парвоз қидируви"
        }
    }

    private var searchSubtitle: String {
        let isWeek = flexibility.isWeeklyDiscovery
        switch settings.language {
        case .russian:
            return isWeek
                ? "Проверяем всю неделю вокруг выбранной даты и показываем только подтверждённые рейсы."
                : "Проверяем выбранную дату и показываем только подтверждённые рейсы."
        case .english:
            return isWeek
                ? "Checking the full week around your selected date and showing only verified flights."
                : "Checking your selected date and showing only verified flights."
        case .uzbek:
            return isWeek
                ? "Tanlangan sana atrofidagi butun haftani tekshirib, faqat tasdiqlangan reyslarni ko‘rsatamiz."
                : "Tanlangan sanani tekshirib, faqat tasdiqlangan reyslarni ko‘rsatamiz."
        case .uzbekCyrillic:
            return isWeek
                ? "Танланган сана атрофидаги бутун ҳафтани текшириб, фақат тасдиқланган рейсларни кўрсатамиз."
                : "Танланган санани текшириб, фақат тасдиқланган рейсларни кўрсатамиз."
        }
    }
}

struct FlightSearchFailureView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    let anchorDate: Date
    let flexibility: DateFlexibility
    let message: String
    let providerEvents: [FlightProviderSearchEvent]
    let challenge: FlightBotChallenge?
    let onRetry: () -> Void
    let onOpenChallenge: () -> Void

    private var reports: [FlightProviderSearchReport] {
        FlightSearchDiagnostics.reports(from: providerEvents)
    }

    private var expectedDates: Int {
        FlightDatePlanner.dates(anchor: anchorDate, flexibility: flexibility).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: challenge == nil ? "magnifyingglass.circle" : "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                metric(icon: "network", value: "\(reports.count)", label: sourcesLabel)
                metric(icon: "calendar", value: "\(expectedDates)", label: daysLabel)
                metric(icon: "checkmark.seal", value: "0", label: confirmedLabel)
            }

            if !reports.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(reports.enumerated()), id: \.element.id) { index, report in
                        providerRow(report)
                        if index < reports.count - 1 { Divider().opacity(0.45) }
                    }
                }
                .padding(.horizontal, 14)
                .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            Text(meaningText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let challenge {
                Button(action: onOpenChallenge) {
                    HStack(spacing: 9) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text(verificationButton)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(IumrahSecondaryButtonStyle())
            }

            Button(action: onRetry) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.clockwise")
                    Text(retryLabel)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            DisclosureGroup(detailsLabel) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }

    private func providerRow(_ report: FlightProviderSearchReport) -> some View {
        HStack(spacing: 11) {
            AirlineLogoView(
                airlineCode: FlightBotProviderRegistry.providers.first(where: { $0.id == report.providerID })?.airlineCodes.first,
                size: 34
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(report.providerName)
                    .font(.subheadline.weight(.semibold))
                Text("\(report.attemptedDates.count)/\(expectedDates) \(dateAttemptsLabel) · \(statusText(report))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: statusIcon(report))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 11)
    }

    private func metric(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon).font(.caption.weight(.semibold))
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusText(_ report: FlightProviderSearchReport) -> String {
        if report.hasVerificationRequired {
            switch settings.language {
            case .russian: return "нужно подтверждение"
            case .english: return "verification required"
            case .uzbek: return "tasdiqlash kerak"
            case .uzbekCyrillic: return "тасдиқлаш керак"
            }
        }
        if report.isSearching {
            switch settings.language {
            case .russian: return "проверяем"
            case .english: return "checking"
            case .uzbek: return "tekshirilmoqda"
            case .uzbekCyrillic: return "текширилмоқда"
            }
        }
        if report.hasNotConfirmed {
            switch settings.language {
            case .russian: return "не удалось подтвердить"
            case .english: return "could not verify"
            case .uzbek: return "tasdiqlanmadi"
            case .uzbekCyrillic: return "тасдиқланмади"
            }
        }
        switch settings.language {
        case .russian: return "источник не завершил проверку"
        case .english: return "source did not complete"
        case .uzbek: return "manba tekshiruvi tugamadi"
        case .uzbekCyrillic: return "манба текшируви тугамади"
        }
    }

    private func statusIcon(_ report: FlightProviderSearchReport) -> String {
        if report.hasVerificationRequired { return "person.badge.key.fill" }
        if report.isSearching { return "clock" }
        if report.hasNotConfirmed { return "questionmark.circle" }
        return "exclamationmark.circle"
    }

    private var title: String {
        switch settings.language {
        case .russian: return challenge == nil ? "Рейс пока не подтверждён" : "Один источник просит подтверждение"
        case .english: return challenge == nil ? "No flight verified yet" : "A source needs verification"
        case .uzbek: return challenge == nil ? "Reys hali tasdiqlanmadi" : "Bir manba tasdiqlashni so‘radi"
        case .uzbekCyrillic: return challenge == nil ? "Рейс ҳали тасдиқланмади" : "Бир манба тасдиқлашни сўради"
        }
    }

    private var subtitle: String {
        if challenge != nil {
            switch settings.language {
            case .russian: return "Поиск продолжается, но один из официальных источников просит подтверждение на сайте авиакомпании."
            case .english: return "Search can continue, but one official source requires verification on the airline website."
            case .uzbek: return "Qidiruv davom etishi mumkin, ammo rasmiy manbalardan biri aviakompaniya saytida tasdiqlashni so‘ramoqda."
            case .uzbekCyrillic: return "Қидирув давом этиши мумкин, аммо расмий манбалардан бири авиакомпания сайтида тасдиқлашни сўрамоқда."
            }
        }
        switch settings.language {
        case .russian: return flexibility.isWeeklyDiscovery ? "Проверка семидневного окна завершилась без рейса, который можно безопасно показать." : "Проверка выбранной даты завершилась без рейса, который можно безопасно показать."
        case .english: return flexibility.isWeeklyDiscovery ? "The seven-day window finished without a flight safe to show." : "The selected date finished without a flight safe to show."
        case .uzbek: return flexibility.isWeeklyDiscovery ? "Yetti kunlik tekshiruv ko‘rsatish mumkin bo‘lgan tasdiqlangan reyssiz yakunlandi." : "Tanlangan sana tekshiruvi tasdiqlangan reyssiz yakunlandi."
        case .uzbekCyrillic: return flexibility.isWeeklyDiscovery ? "Етти кунлик текширув кўрсатиш мумкин бўлган тасдиқланган рейссиз якунланди." : "Танланган сана текшируви тасдиқланган рейссиз якунланди."
        }
    }

    private var meaningText: String {
        switch settings.language {
        case .russian: return "Это НЕ означает, что у авиакомпаний точно нет рейсов. Это означает, что iumrah не смог подтвердить ни один рейс с номером, временем и актуальной ценой. В отчёте видно, какие источники реально были проверены."
        case .english: return "This does NOT prove that the airlines have no flights. It means iumrah could not verify a flight with its number, times and current fare. The report shows which sources were actually checked."
        case .uzbek: return "Bu aviakompaniyalarda reys yo‘q degani EMAS. iumrah reys raqami, vaqti va joriy narxini tasdiqlay olmaganini anglatadi. Haqiqatan tekshirilgan manbalar quyida ko‘rsatilgan."
        case .uzbekCyrillic: return "Бу авиакомпанияларда рейс йўқ дегани ЭМАС. iumrah рейс рақами, вақти ва жорий нархини тасдиқлай олмаганини англатади. Ҳақиқатан текширилган манбалар қуйида кўрсатилган."
        }
    }

    private var sourcesLabel: String {
        switch settings.language { case .russian: return "источников запущено"; case .english: return "sources started"; case .uzbek: return "manba ishga tushdi"; case .uzbekCyrillic: return "манба ишга тушди" }
    }
    private var daysLabel: String {
        switch settings.language { case .russian: return "дней"; case .english: return "days"; case .uzbek: return "kun"; case .uzbekCyrillic: return "кун" }
    }
    private var confirmedLabel: String {
        switch settings.language { case .russian: return "подтверждено"; case .english: return "verified"; case .uzbek: return "tasdiqlandi"; case .uzbekCyrillic: return "тасдиқланди" }
    }
    private var dateAttemptsLabel: String {
        switch settings.language { case .russian: return "дат"; case .english: return "dates"; case .uzbek: return "sana"; case .uzbekCyrillic: return "сана" }
    }
    private var retryLabel: String {
        switch settings.language { case .russian: return "Проверить ещё раз"; case .english: return "Check again"; case .uzbek: return "Yana tekshirish"; case .uzbekCyrillic: return "Яна текшириш" }
    }
    private var verificationButton: String {
        switch settings.language { case .russian: return "Подтвердить на сайте авиакомпании"; case .english: return "Verify on the airline site"; case .uzbek: return "Aviakompaniya saytida tasdiqlash"; case .uzbekCyrillic: return "Авиакомпания сайтида тасдиқлаш" }
    }
    private var detailsLabel: String {
        switch settings.language { case .russian: return "Подробнее о результате"; case .english: return "Result details"; case .uzbek: return "Natija tafsilotlari"; case .uzbekCyrillic: return "Натижа тафсилотлари" }
    }
}
