import SwiftUI

struct PackageGenerationView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var showFinalPackage = false
    @State private var selectionError: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                IumrahFlowProgress(stage: .hotel, labelKey: "step_package")
                header
                searchSummary
                packageStack
                searchFooter
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 48)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .hotel)
        .navigationDestination(isPresented: $showFinalPackage) {
            FinalPackageView()
        }
        .task {
            await runOrResumeSearch()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if journey.trip.isWeekendUmrah {
                Text("SUNDAY UMRAH CLUB")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Text(copy(.sundayTitle))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                Text(copy(.sundayBody))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(copy(.eyebrow))
                    .font(.caption.weight(.bold))
                    .tracking(1.25)
                    .foregroundStyle(.secondary)
                Text(copy(.title))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                Text(copy(.body))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchSummary: some View {
        HStack(spacing: 12) {
            summaryPill(icon: "airplane", text: "\(journey.trip.originCode) → \(journey.trip.outboundDestinationCode)")
            summaryPill(icon: "person.2.fill", text: "\(journey.trip.travelerCount)")
            if journey.trip.scope == .makkahAndMadinah {
                summaryPill(icon: "building.2.fill", text: copy(.twoCities))
            } else {
                summaryPill(icon: "building.fill", text: copy(.makkahOnly))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    @ViewBuilder
    private var packageStack: some View {
        if let snapshot = journey.serverSearchSnapshot {
            VStack(spacing: 14) {
                ForEach(snapshot.packages) { package in
                    packageCard(package, snapshot: snapshot)
                }
            }
        } else {
            VStack(spacing: 14) {
                ForEach(placeholderKeys, id: \.self) { key in
                    packagePlaceholder(key)
                }
            }
        }
    }

    private var placeholderKeys: [ServerPackageProductKey] {
        journey.trip.isWeekendUmrah ? [.comfort, .luxury] : [.essential, .comfort, .luxury]
    }

    @ViewBuilder
    private func packageCard(_ package: ServerGeneratedPackage, snapshot: ServerPackageSearchSnapshot) -> some View {
        Button {
            guard package.status == .ready else { return }
            do {
                try journey.applyGeneratedPackage(package)
                selectionError = nil
                IumrahHaptics.success()
                showFinalPackage = true
            } catch {
                selectionError = error.localizedDescription
                IumrahHaptics.error()
            }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(packageName(package.key))
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            if package.recommended {
                                Text(copy(.recommended))
                                    .font(.system(size: 9, weight: .bold))
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 8)
                                    .frame(height: 21)
                                    .foregroundStyle(Color(uiColor: .systemBackground))
                                    .background(Color.primary, in: Capsule())
                            }
                        }
                        Text("\(package.stars)★ · \(packageSubtitle(package.key))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 6)
                    statusBadge(package.status)
                }

                if let makkah = package.hotelMakkah {
                    compactHotel(icon: "building.2.fill", city: copy(.makkah), hotel: makkah)
                } else if package.status == .searching {
                    skeletonLine(width: 0.82)
                }

                if snapshot.itinerary.includeMadinah {
                    if let madinah = package.hotelMadinah {
                        compactHotel(icon: "building.2.fill", city: copy(.madinah), hotel: madinah)
                    } else if package.status == .searching {
                        skeletonLine(width: 0.68)
                    }
                }

                if package.status == .ready, let quote = package.quote {
                    Divider().opacity(0.5)
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(copy(.packagePrice))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(money(quote.totalPackagePrice, quote.currency))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .tracking(-0.6)
                                .foregroundStyle(.primary)
                            Text("\(money(quote.pricePerPerson, quote.currency)) · \(copy(.perPerson))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 31, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 8) {
                        Label(package.transport.type == .haramainTrain ? copy(.haramain) : copy(.roadTransfer), systemImage: package.transport.type == .haramainTrain ? "tram.fill" : "car.fill")
                        if package.selectedDateOffset != 0 {
                            Label(offsetText(package.selectedDateOffset), systemImage: "calendar.badge.checkmark")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                } else if package.status == .blocked {
                    Label(friendlyBlockReason(package.blockReason), systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text(copy(.verifying))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(package.key))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(package.recommended ? Color.primary.opacity(0.16) : Color.primary.opacity(0.05), lineWidth: package.recommended ? 1.1 : 0.6)
            }
            .shadow(color: .black.opacity(package.recommended ? 0.09 : 0.04), radius: package.recommended ? 22 : 12, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(package.status != .ready)
    }

    private func cardBackground(_ key: ServerPackageProductKey) -> some ShapeStyle {
        switch key {
        case .essential:
            return AnyShapeStyle(Color.iumrahCardBackground)
        case .comfort:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.iumrahCardBackground, Color.iumrahCareLight.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .luxury:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.iumrahCardBackground, Color.primary.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func packagePlaceholder(_ key: ServerPackageProductKey) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(packageName(key))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Spacer()
                ProgressView().controlSize(.small)
            }
            skeletonLine(width: 0.78)
            skeletonLine(width: 0.60)
            skeletonLine(width: 0.42)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func skeletonLine(width: CGFloat) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Color.primary.opacity(0.07))
                .frame(width: max(54, proxy.size.width * width), height: 13)
        }
        .frame(height: 13)
    }

    private func compactHotel(icon: String, city: String, hotel: ServerPackageHotel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(Color.iumrahRaisedBackground, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(city)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hotel.hotelName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let rating = hotel.rating, rating > 0 {
                Text(String(format: "%.1f", rating))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Color.iumrahRaisedBackground, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: ServerPackageCardStatus) -> some View {
        switch status {
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.iumrahCareDark)
        case .searching:
            ProgressView().controlSize(.small)
        case .blocked:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var searchFooter: some View {
        if let selectionError {
            Text(selectionError)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let snapshot = journey.serverSearchSnapshot {
            if snapshot.status == .searching || snapshot.status == .partial || snapshot.status == .queued {
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy(.continuingSearch))
                            .font(.subheadline.weight(.semibold))
                        Text(searchProgress(snapshot))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(17)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            } else if snapshot.status == .failed {
                retryCard(message: friendlySearchMessage(snapshot.message))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.iumrahCareDark)
                    Text(copy(.searchComplete))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(snapshot.outboundFlights.count + snapshot.inboundFlights.count) \(copy(.flights))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        } else if let error = journey.errorMessage {
            retryCard(message: error)
        }
    }

    private func retryCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(copy(.searchUnavailable), systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(copy(.retry)) {
                Task { await journey.beginServerPackageSearch(force: true) }
            }
            .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .padding(18)
        .background(Color.iumrahCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @MainActor
    private func runOrResumeSearch() async {
        if journey.serverSearchId == nil {
            await journey.beginServerPackageSearch()
        } else {
            await journey.refreshServerPackageSearch()
        }

        while !Task.isCancelled {
            guard let snapshot = journey.serverSearchSnapshot else { return }
            if snapshot.status.isTerminal { return }
            try? await Task.sleep(for: .milliseconds(900))
            if Task.isCancelled { return }
            await journey.refreshServerPackageSearch()
        }
    }

    private func searchProgress(_ snapshot: ServerPackageSearchSnapshot) -> String {
        if snapshot.pendingDateOffsets.isEmpty {
            return copy(.finalizing)
        }
        if snapshot.outboundFlights.isEmpty && snapshot.inboundFlights.isEmpty {
            return copy(.findingFlights)
        }
        return "\(snapshot.outboundFlights.count + snapshot.inboundFlights.count) \(copy(.verifiedOptions))"
    }

    private func offsetText(_ value: Int) -> String {
        switch settings.language {
        case .russian: return value > 0 ? "на \(value) дн. позже" : "на \(-value) дн. раньше"
        case .english: return value > 0 ? "\(value)d later" : "\(-value)d earlier"
        case .uzbek: return value > 0 ? "\(value) kun keyin" : "\(-value) kun oldin"
        case .uzbekCyrillic: return value > 0 ? "\(value) кун кейин" : "\(-value) кун олдин"
        }
    }

    private func packageName(_ key: ServerPackageProductKey) -> String {
        switch key {
        case .essential: return "Essential"
        case .comfort: return "Comfort"
        case .luxury: return "Luxury"
        }
    }

    private func packageSubtitle(_ key: ServerPackageProductKey) -> String {
        switch (settings.language, key) {
        case (.russian, .essential): return "разумная база"
        case (.russian, .comfort): return "баланс поездки"
        case (.russian, .luxury): return "премиальный уровень"
        case (.english, .essential): return "smart essentials"
        case (.english, .comfort): return "balanced journey"
        case (.english, .luxury): return "premium journey"
        case (.uzbek, .essential): return "asosiy qulayliklar"
        case (.uzbek, .comfort): return "muvozanatli safar"
        case (.uzbek, .luxury): return "premium safar"
        case (.uzbekCyrillic, .essential): return "асосий қулайликлар"
        case (.uzbekCyrillic, .comfort): return "мувозанатли сафар"
        case (.uzbekCyrillic, .luxury): return "премиум сафар"
        }
    }

    private func friendlyBlockReason(_ code: String?) -> String {
        guard let code else { return copy(.packageUnavailable) }
        if code.contains("PRIMARY_HOTEL_NOT_CONFIGURED") || code.contains("PACKAGE_RATE_NOT_CONFIGURED") || code.contains("HOTEL_RATE_NOT_CONFIGURED") || code.contains("ROOM_RATE_NOT_CONFIGURED") {
            return copy(.packageUnavailable)
        }
        return copy(.packageUnavailable)
    }

    private func friendlySearchMessage(_ code: String?) -> String {
        if code == "FLIGHT_PROVIDER_NOT_CONFIGURED" { return copy(.providerUnavailable) }
        return code?.isEmpty == false ? copy(.temporaryFailure) : copy(.temporaryFailure)
    }

    private func money(_ amount: Decimal, _ currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }

    private enum CopyKey {
        case eyebrow, title, body, sundayTitle, sundayBody, recommended, twoCities, makkahOnly
        case makkah, madinah, packagePrice, perPerson, haramain, roadTransfer, verifying
        case continuingSearch, finalizing, findingFlights, verifiedOptions, searchComplete, flights
        case searchUnavailable, retry, packageUnavailable, providerUnavailable, temporaryFailure
    }

    private func copy(_ key: CopyKey) -> String {
        switch (settings.language, key) {
        case (.russian, .eyebrow): return "IUMRAH PACKAGE ENGINE"
        case (.russian, .title): return "Три варианта вашей Умры"
        case (.russian, .body): return "Сервер проверяет перелёт, Primary Hotels и полную цену пакета. Готовые варианты появляются сразу — поиск остальных продолжается."
        case (.russian, .sundayTitle): return "Умра на выходные"
        case (.russian, .sundayBody): return "Пятница — понедельник. Только Мекка. Comfort и Luxury для короткой самостоятельной Умры."
        case (.russian, .recommended): return "Рекомендуем"
        case (.russian, .twoCities): return "2 города"
        case (.russian, .makkahOnly): return "Мекка"
        case (.russian, .makkah): return "Мекка"
        case (.russian, .madinah): return "Медина"
        case (.russian, .packagePrice): return "Цена пакета"
        case (.russian, .perPerson): return "за человека"
        case (.russian, .haramain): return "Haramain"
        case (.russian, .roadTransfer): return "Трансфер"
        case (.russian, .verifying): return "Проверяем актуальную цену…"
        case (.russian, .continuingSearch): return "Продолжаем поиск"
        case (.russian, .finalizing): return "Финализируем проверенные варианты"
        case (.russian, .findingFlights): return "Ищем подтверждённые рейсы"
        case (.russian, .verifiedOptions): return "найденных вариантов"
        case (.russian, .searchComplete): return "Поиск завершён"
        case (.russian, .flights): return "рейсов"
        case (.russian, .searchUnavailable): return "Поиск временно недоступен"
        case (.russian, .retry): return "Повторить поиск"
        case (.russian, .packageUnavailable): return "Для этого уровня пока не настроен точный тариф Primary Hotel. Мы не показываем приблизительную цену."
        case (.russian, .providerUnavailable): return "Источник реальных авиабилетов ещё не подключён на сервере."
        case (.russian, .temporaryFailure): return "Сервер сохранил сессию поиска. Попробуйте обновить — найденные результаты не потеряются."

        case (.english, .eyebrow): return "IUMRAH PACKAGE ENGINE"
        case (.english, .title): return "Three ways to make your Umrah"
        case (.english, .body): return "The server verifies flights, Primary Hotels and the full package price. Ready options appear immediately while the rest of the search continues."
        case (.english, .sundayTitle): return "Weekend Umrah"
        case (.english, .sundayBody): return "Friday to Monday. Makkah only. Comfort and Luxury for a short independent Umrah."
        case (.english, .recommended): return "Recommended"
        case (.english, .twoCities): return "2 cities"
        case (.english, .makkahOnly): return "Makkah"
        case (.english, .makkah): return "Makkah"
        case (.english, .madinah): return "Madinah"
        case (.english, .packagePrice): return "Package price"
        case (.english, .perPerson): return "per person"
        case (.english, .haramain): return "Haramain"
        case (.english, .roadTransfer): return "Transfer"
        case (.english, .verifying): return "Verifying current price…"
        case (.english, .continuingSearch): return "Continuing search"
        case (.english, .finalizing): return "Finalizing verified options"
        case (.english, .findingFlights): return "Finding verified flights"
        case (.english, .verifiedOptions): return "verified options"
        case (.english, .searchComplete): return "Search complete"
        case (.english, .flights): return "flights"
        case (.english, .searchUnavailable): return "Search temporarily unavailable"
        case (.english, .retry): return "Retry search"
        case (.english, .packageUnavailable): return "An exact Primary Hotel rate is not configured for this level yet. We do not show an estimated price."
        case (.english, .providerUnavailable): return "The real-flight provider has not been configured on the server yet."
        case (.english, .temporaryFailure): return "The server kept this search session. Refreshing will not discard already found results."

        case (.uzbek, .eyebrow): return "IUMRAH PACKAGE ENGINE"
        case (.uzbek, .title): return "Umrangiz uchun uchta variant"
        case (.uzbek, .body): return "Server parvozlar, Primary Hotels va paketning to‘liq narxini tekshiradi. Tayyor variantlar darhol ko‘rinadi, qolgan qidiruv davom etadi."
        case (.uzbek, .sundayTitle): return "Dam olish kunlari Umra"
        case (.uzbek, .sundayBody): return "Jumadan dushanbagacha. Faqat Makka. Qisqa mustaqil Umra uchun Comfort va Luxury."
        case (.uzbek, .recommended): return "Tavsiya"
        case (.uzbek, .twoCities): return "2 shahar"
        case (.uzbek, .makkahOnly): return "Makka"
        case (.uzbek, .makkah): return "Makka"
        case (.uzbek, .madinah): return "Madina"
        case (.uzbek, .packagePrice): return "Paket narxi"
        case (.uzbek, .perPerson): return "bir kishi uchun"
        case (.uzbek, .haramain): return "Haramain"
        case (.uzbek, .roadTransfer): return "Transfer"
        case (.uzbek, .verifying): return "Joriy narx tekshirilmoqda…"
        case (.uzbek, .continuingSearch): return "Qidiruv davom etmoqda"
        case (.uzbek, .finalizing): return "Tasdiqlangan variantlar yakunlanmoqda"
        case (.uzbek, .findingFlights): return "Tasdiqlangan parvozlar qidirilmoqda"
        case (.uzbek, .verifiedOptions): return "topilgan variant"
        case (.uzbek, .searchComplete): return "Qidiruv yakunlandi"
        case (.uzbek, .flights): return "parvoz"
        case (.uzbek, .searchUnavailable): return "Qidiruv vaqtincha ishlamayapti"
        case (.uzbek, .retry): return "Qayta qidirish"
        case (.uzbek, .packageUnavailable): return "Bu daraja uchun aniq Primary Hotel tarifi hali sozlanmagan. Taxminiy narx ko‘rsatilmaydi."
        case (.uzbek, .providerUnavailable): return "Haqiqiy aviachiptalar manbasi serverga hali ulanmagan."
        case (.uzbek, .temporaryFailure): return "Server qidiruv sessiyasini saqlab qoldi. Yangilash topilgan natijalarni o‘chirmaydi."

        case (.uzbekCyrillic, .eyebrow): return "IUMRAH PACKAGE ENGINE"
        case (.uzbekCyrillic, .title): return "Умрангиз учун учта вариант"
        case (.uzbekCyrillic, .body): return "Сервер парвозлар, Primary Hotels ва пакетнинг тўлиқ нархини текширади. Тайёр вариантлар дарҳол кўринади, қолган қидирув давом этади."
        case (.uzbekCyrillic, .sundayTitle): return "Дам олиш кунлари Умра"
        case (.uzbekCyrillic, .sundayBody): return "Жумадан душанбагача. Фақат Макка. Қисқа мустақил Умра учун Comfort ва Luxury."
        case (.uzbekCyrillic, .recommended): return "Тавсия"
        case (.uzbekCyrillic, .twoCities): return "2 шаҳар"
        case (.uzbekCyrillic, .makkahOnly): return "Макка"
        case (.uzbekCyrillic, .makkah): return "Макка"
        case (.uzbekCyrillic, .madinah): return "Мадина"
        case (.uzbekCyrillic, .packagePrice): return "Пакет нархи"
        case (.uzbekCyrillic, .perPerson): return "бир киши учун"
        case (.uzbekCyrillic, .haramain): return "Haramain"
        case (.uzbekCyrillic, .roadTransfer): return "Трансфер"
        case (.uzbekCyrillic, .verifying): return "Жорий нарх текширилмоқда…"
        case (.uzbekCyrillic, .continuingSearch): return "Қидирув давом этмоқда"
        case (.uzbekCyrillic, .finalizing): return "Тасдиқланган вариантлар якунланмоқда"
        case (.uzbekCyrillic, .findingFlights): return "Тасдиқланган парвозлар қидирилмоқда"
        case (.uzbekCyrillic, .verifiedOptions): return "топилган вариант"
        case (.uzbekCyrillic, .searchComplete): return "Қидирув якунланди"
        case (.uzbekCyrillic, .flights): return "парвоз"
        case (.uzbekCyrillic, .searchUnavailable): return "Қидирув вақтинча ишламаяпти"
        case (.uzbekCyrillic, .retry): return "Қайта қидириш"
        case (.uzbekCyrillic, .packageUnavailable): return "Бу даража учун аниқ Primary Hotel тарифи ҳали созланмаган. Тахминий нарх кўрсатилмайди."
        case (.uzbekCyrillic, .providerUnavailable): return "Ҳақиқий авиачипталар манбаси серверга ҳали уланмаган."
        case (.uzbekCyrillic, .temporaryFailure): return "Сервер қидирув сессиясини сақлаб қолди. Янгилаш топилган натижаларни ўчирмайди."
        }
    }
}
