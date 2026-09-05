import SwiftUI

struct FlightDateCalendarView: View {
    let trip: TripDraft
    let initialDeparture: Date
    let initialReturn: Date
    let onApply: (Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var departure: Date?
    @State private var returnDate: Date?
    @State private var outboundPrices: [String: FlightFareCalendarEntry] = [:]
    @State private var returnPrices: [String: FlightFareCalendarEntry] = [:]
    @State private var suggestions: [FlightFareCalendarEntry] = []
    @State private var isLoading = false
    @State private var loadError = false

    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.firstWeekday = 2
        return value
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                calendarBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        routeSummary
                        fareLegend
                        ForEach(monthStarts, id: \.self) { month in
                            monthSection(month)
                        }
                        if !suggestions.isEmpty { bestDatesSection }
                        cacheExplanation
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 136)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        IumrahHaptics.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .principal) {
                    Image("IumrahFlightsCalendarLogo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(.primary)
                        .frame(width: 138, height: 30)
                        .accessibilityLabel("iumrah Flights")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .task { await loadCalendar() }
        }
        .onAppear {
            departure = calendar.startOfDay(for: initialDeparture)
            returnDate = calendar.startOfDay(for: initialReturn)
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(36)
    }

    private var calendarBackground: some View {
        ZStack {
            Color.iumrahPageBackground
            LinearGradient(
                colors: [
                    Color.primary.opacity(colorScheme == .dark ? 0.025 : 0.018),
                    Color.clear,
                    Color.iumrahCareLight.opacity(colorScheme == .dark ? 0.055 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(copy(.title))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-0.5)
            Text(copy(.subtitle))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var routeSummary: some View {
        HStack(spacing: 10) {
            routeCode(trip.originCode)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            routeCode(trip.outboundDestinationCode)
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            routeCode(trip.returnOriginCode)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            routeCode(trip.originCode)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func routeCode(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .monospaced()
            .frame(maxWidth: .infinity)
    }

    private var fareLegend: some View {
        HStack(spacing: 10) {
            IumrahIconBadge(
                systemName: "chart.line.downtrend.xyaxis",
                role: .payment,
                size: 40,
                symbolSize: 16,
                shape: .circle
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(copy(.priceCalendar))
                    .font(.subheadline.weight(.bold))
                Text(isLoading ? copy(.loading) : copy(.priceHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if loadError {
                Button(copy(.retry)) { Task { await loadCalendar() } }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .iumrahGlass(in: Capsule(), interactive: true)
                    .buttonStyle(.plain)
            }
        }
        .padding(14)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func monthSection(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(monthTitle(month))
                .font(.system(size: 25, weight: .bold, design: .rounded))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthCells(month), id: \.id) { cell in
                    if let date = cell.date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 62)
                    }
                }
            }
        }
        .padding(16)
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func dayCell(_ date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let disabled = day < calendar.startOfDay(for: Date())
        let isDeparture = departure.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isReturn = returnDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let inRange = isInsideSelectedRange(day)
        let entry = priceEntry(for: day)

        return Button {
            guard !disabled else { return }
            select(day)
        } label: {
            VStack(spacing: 3) {
                Text(String(calendar.component(.day, from: day)))
                    .font(.system(size: 17, weight: isDeparture || isReturn ? .bold : .medium, design: .rounded))
                if entry != nil {
                    Circle()
                        .fill(isDeparture || isReturn ? Color.iumrahCardBackground.opacity(0.82) : Color.green)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                } else {
                    Color.clear.frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                if isDeparture || isReturn {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primary)
                } else if inRange {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.07))
                }
            }
            .foregroundStyle(disabled ? Color.secondary.opacity(0.45) : ((isDeparture || isReturn) ? Color.iumrahCardBackground : Color.primary))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var bestDatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy(.bestDates))
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(copy(.bestDatesHint))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestions.prefix(6)) { entry in
                        Button {
                            guard let out = FlightFareCalendarService.date(entry.outboundDate),
                                  let inboundText = entry.inboundDate,
                                  let inbound = FlightFareCalendarService.date(inboundText), inbound > out else { return }
                            departure = out
                            returnDate = inbound
                            Task { await loadReturnPrices(for: out) }
                            IumrahHaptics.selection()
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(suggestionDates(entry))
                                    .font(.subheadline.weight(.bold))
                                Text(copy(.fareAvailable))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.green)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 72)
                            .iumrahGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var cacheExplanation: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(copy(.cacheNote))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                departure = nil
                returnDate = nil
                returnPrices = [:]
                IumrahHaptics.selection()
            } label: {
                Text(copy(.reset))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 116, height: 60)
            }
            .buttonStyle(.plain)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)

            Button {
                guard let departure, let returnDate, returnDate > departure else { return }
                IumrahHaptics.success()
                onApply(departure, returnDate)
                dismiss()
            } label: {
                VStack(spacing: 2) {
                    Text(copy(.chooseDates))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.iumrahCardBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.primary.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!hasValidRange)
            .opacity(hasValidRange ? 1 : 0.42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.iumrahCardBackground)
        .overlay(alignment: .top) { Divider().opacity(0.14) }
    }

    private var hasValidRange: Bool {
        guard let departure, let returnDate else { return false }
        return returnDate > departure
    }


    private func select(_ date: Date) {
        if departure == nil || (departure != nil && returnDate != nil) {
            departure = date
            returnDate = nil
            returnPrices = [:]
            Task { await loadReturnPrices(for: date) }
        } else if let departure, date <= departure {
            self.departure = date
            returnDate = nil
            returnPrices = [:]
            Task { await loadReturnPrices(for: date) }
        } else {
            returnDate = date
        }
        IumrahHaptics.selection()
    }

    private func isInsideSelectedRange(_ date: Date) -> Bool {
        guard let departure, let returnDate else { return false }
        return date > departure && date < returnDate
    }

    private func priceEntry(for date: Date) -> FlightFareCalendarEntry? {
        let key = FlightFareCalendarService.day.string(from: date)
        if departure != nil, returnDate == nil, !returnPrices.isEmpty { return returnPrices[key] }
        return outboundPrices[key]
    }


    private func suggestionDates(_ entry: FlightFareCalendarEntry) -> String {
        guard let out = FlightFareCalendarService.date(entry.outboundDate) else { return entry.outboundDate }
        let outText = shortDate(out)
        guard let inboundText = entry.inboundDate, let inbound = FlightFareCalendarService.date(inboundText) else { return outText }
        return "\(outText) → \(shortDate(inbound))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: date).capitalized(with: locale)
    }

    private var weekdayTitles: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        var symbols = formatter.veryShortStandaloneWeekdaySymbols
            ?? formatter.veryShortWeekdaySymbols
            ?? ["S", "M", "T", "W", "T", "F", "S"]
        if calendar.firstWeekday == 2, !symbols.isEmpty {
            let first = symbols.removeFirst()
            symbols.append(first)
        }
        return symbols
    }

    private var monthStarts: [Date] {
        let today = calendar.startOfDay(for: Date())
        let current = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        return (0..<6).compactMap { calendar.date(byAdding: .month, value: $0, to: current) }
    }

    private struct MonthCell: Identifiable {
        let id: String
        let date: Date?
    }

    private func monthCells(_ month: Date) -> [MonthCell] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [MonthCell] = (0..<leading).map { MonthCell(id: "blank-\(month.timeIntervalSince1970)-\($0)", date: nil) }
        cells += range.compactMap { day -> MonthCell? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: first) else { return nil }
            return MonthCell(id: FlightFareCalendarService.day.string(from: date), date: date)
        }
        return cells
    }

    private func loadCalendar() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = false
        defer { isLoading = false }
        do {
            let months = monthStarts
            guard let first = months.first, let last = months.last,
                  let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: last) else { return }
            let result = try await FlightFareCalendarService.shared.load(trip: trip, from: first, to: end)
            outboundPrices = Dictionary(uniqueKeysWithValues: result.prices.map { ($0.outboundDate, $0) })
            suggestions = result.suggestions
            if let departure { await loadReturnPrices(for: departure) }
        } catch {
            loadError = true
        }
    }

    private func loadReturnPrices(for outbound: Date) async {
        do {
            let months = monthStarts
            guard let first = months.first, let last = months.last,
                  let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: last) else { return }
            let result = try await FlightFareCalendarService.shared.load(trip: trip, from: first, to: end, selectedOutbound: outbound)
            var mapped: [String: FlightFareCalendarEntry] = [:]
            for entry in result.observations {
                guard let inbound = entry.inboundDate else { continue }
                if let current = mapped[inbound], current.minPerTravelerFare <= entry.minPerTravelerFare { continue }
                mapped[inbound] = entry
            }
            returnPrices = mapped
            if !result.suggestions.isEmpty { suggestions = result.suggestions }
        } catch {
            // Calendar prices are advisory. Date selection itself stays fully usable.
            returnPrices = [:]
        }
    }

    private var locale: Locale {
        switch settings.language {
        case .english: return Locale(identifier: "en_US")
        case .russian: return Locale(identifier: "ru_RU")
        case .uzbek: return Locale(identifier: "uz_Latn_UZ")
        case .uzbekCyrillic: return Locale(identifier: "uz_Cyrl_UZ")
        }
    }

    private enum CopyKey { case title, subtitle, priceCalendar, loading, priceHint, retry, bestDates, bestDatesHint, cacheNote, reset, chooseDates, fareAvailable }
    private func copy(_ key: CopyKey) -> String {
        switch (settings.language, key) {
        case (.russian, .title): return "Когда лететь"
        case (.russian, .subtitle): return "Выберите даты по актуальным данным рейсов"
        case (.russian, .priceCalendar): return "Календарь актуальных дат"
        case (.russian, .loading): return "Загружаем накопленные результаты…"
        case (.russian, .priceHint): return "Зелёная отметка означает, что для даты есть актуальный тариф"
        case (.russian, .retry): return "Обновить"
        case (.russian, .bestDates): return "Рекомендуемые даты"
        case (.russian, .bestDatesHint): return "Подходящие пары дат из актуальных поисков"
        case (.russian, .cacheNote): return "Календарь пополняется реальными поисками паломников. Повторный одинаковый поиск сначала использует свежий серверный кэш, поэтому результаты открываются быстрее и не создают лишний запрос к авиасистеме. Прошедшие даты автоматически удаляются."
        case (.russian, .reset): return "Сбросить"
        case (.russian, .chooseDates): return "Выбрать даты"
        case (.russian, .fareAvailable): return "Актуальный тариф найден"

        case (.english, .title): return "When to fly"
        case (.english, .subtitle): return "Choose dates using current flight data"
        case (.english, .priceCalendar): return "Current-date calendar"
        case (.english, .loading): return "Loading accumulated results…"
        case (.english, .priceHint): return "A green mark means a current fare is available for that date"
        case (.english, .retry): return "Refresh"
        case (.english, .bestDates): return "Recommended dates"
        case (.english, .bestDatesHint): return "Suitable date combinations from current searches"
        case (.english, .cacheNote): return "The calendar grows from real pilgrim searches. An identical search uses fresh server cache first, so results open faster without spending another flight-system request. Past dates are removed automatically."
        case (.english, .reset): return "Reset"
        case (.english, .chooseDates): return "Choose dates"
        case (.english, .fareAvailable): return "Current fare available"

        case (.uzbek, .title): return "Qachon uchasiz"
        case (.uzbek, .subtitle): return "Dolzarb reys ma’lumotlari asosida sanalarni tanlang"
        case (.uzbek, .priceCalendar): return "Dolzarb sanalar kalendari"
        case (.uzbek, .loading): return "Yig‘ilgan natijalar yuklanmoqda…"
        case (.uzbek, .priceHint): return "Yashil belgi shu sana uchun dolzarb tarif borligini bildiradi"
        case (.uzbek, .retry): return "Yangilash"
        case (.uzbek, .bestDates): return "Tavsiya etilgan sanalar"
        case (.uzbek, .bestDatesHint): return "Dolzarb qidiruvlardan mos sana juftliklari"
        case (.uzbek, .cacheNote): return "Kalendar ziyoratchilarning haqiqiy qidiruvlari bilan to‘lib boradi. Bir xil qidiruv avval yangi server keshidan olinadi — natija tezroq ochiladi va aviatsiya tizimiga ortiqcha so‘rov yuborilmaydi. O‘tgan sanalar avtomatik o‘chiriladi."
        case (.uzbek, .reset): return "Tozalash"
        case (.uzbek, .chooseDates): return "Sanalarni tanlash"
        case (.uzbek, .fareAvailable): return "Dolzarb tarif topildi"

        case (.uzbekCyrillic, .title): return "Қачон учасиз"
        case (.uzbekCyrillic, .subtitle): return "Долзарб рейс маълумотлари асосида саналарни танланг"
        case (.uzbekCyrillic, .priceCalendar): return "Долзарб саналар календари"
        case (.uzbekCyrillic, .loading): return "Йиғилган натижалар юкланмоқда…"
        case (.uzbekCyrillic, .priceHint): return "Яшил белги шу сана учун долзарб тариф борлигини билдиради"
        case (.uzbekCyrillic, .retry): return "Янгилаш"
        case (.uzbekCyrillic, .bestDates): return "Тавсия этилган саналар"
        case (.uzbekCyrillic, .bestDatesHint): return "Долзарб қидирувлардан мос сана жуфтликлари"
        case (.uzbekCyrillic, .cacheNote): return "Календар зиёратчиларнинг ҳақиқий қидирувлари билан тўлиб боради. Бир хил қидирув аввал янги сервер кешидан олинади — натижа тезроқ очилади ва авиация тизимига ортиқча сўров юборилмайди. Ўтган саналар автоматик ўчирилади."
        case (.uzbekCyrillic, .reset): return "Тозалаш"
        case (.uzbekCyrillic, .chooseDates): return "Саналарни танлаш"
        case (.uzbekCyrillic, .fareAvailable): return "Долзарб тариф топилди"
        }
    }
}
