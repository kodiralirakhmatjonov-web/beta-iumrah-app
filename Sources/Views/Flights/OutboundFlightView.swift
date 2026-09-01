import SwiftUI

struct OutboundFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var candidates: [LiveFlightCandidate] = []
    @State private var offers: [FlightOffer] = []
    @State private var isInitialLoading = true
    @State private var isSearching = false
    @State private var fatalErrorText: String?
    @State private var searchStatus: GeneratorSearchStage? = .starting
    @State private var searchGeneration = UUID()

    var body: some View {
        Group {
            if hasVerifiedResults {
                resultsView
                    .iumrahInternalNavigation(progress: .flight)
            } else if !isSearching && !isInitialLoading {
                searchGate
                    .iumrahInternalNavigation(progress: .flight)
            } else {
                FlightSearchImmersiveView(state: .searching, liveStatus: searchStatus)
            }
        }
        .background(shouldShowImmersive ? Color.black : Color.iumrahPageBackground)
        .task { await search(continueExisting: false) }
        .onAppear { updateImmersive() }
        .onChange(of: isInitialLoading) { _, _ in updateImmersive() }
        .onDisappear { chrome.setImmersive(false) }
    }

    private var searchGate: some View {
        FlightSearchGateView(
            direction: .outbound,
            anchorDate: journey.trip.departureDate,
            flexibility: journey.trip.flexibility,
            message: fatalErrorText ?? searchGateFallbackMessage,
            onRetry: { Task { await search(continueExisting: true) } }
        )
    }

    private var searchGateFallbackMessage: String {
        switch settings.language {
        case .russian: return "Поиск завершён без рейса, который прошёл все проверки iumrah."
        case .english: return "Search completed without a flight that passed all iumrah checks."
        case .uzbek: return "Qidiruv iumrah tekshiruvlaridan o‘tgan reyssiz yakunlandi."
        case .uzbekCyrillic: return "Қидирув iumrah текширувларидан ўтган рейссиз якунланди."
        }
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                IumrahFlowProgress(stage: .flight)
                SectionHeader(
                    L10n.text("flight_out_title", settings.language),
                    eyebrow: L10n.text("flight_out_eyebrow", settings.language),
                    subtitle: L10n.text("flight_out_body", settings.language)
                )


                flightGroups

                FlightSearchProgressCard(
                    isSearching: isSearching,
                    hasResults: !offers.isEmpty,
                    liveStatus: searchStatus,
                    onContinue: { Task { await search(continueExisting: true) } }
                )
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .background(Color.iumrahPageBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if journey.selectedOutbound != nil {
                floatingContinueBar
            }
        }
    }

    @ViewBuilder
    private var flightGroups: some View {
        let rows = FlightResultRowModel.merge(candidates: candidates, offers: offers)
        let groups = grouped(rows: rows, anchor: journey.trip.departureDate)

        ForEach(groups, id: \.offset) { group in
            VStack(alignment: .leading, spacing: 12) {
                if journey.trip.flexibility.isFlexibleDayRange || group.offset != 0 {
                    flexibleDateHeader(offset: group.offset, date: group.rows.first?.departureAt)
                }

                ForEach(group.rows) { row in
                    resultRow(row)
                }
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ row: FlightResultRowModel) -> some View {
        if let offer = row.offer {
            VStack(spacing: 10) {
                Button {
                    journey.chooseOutboundFlight(offer)
                    IumrahHaptics.selection()
                } label: {
                    FlightCard(
                        offer: offer,
                        isSelected: journey.selectedOutbound?.id == offer.id,
                        isRecommended: recommendedOfferID == offer.id
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    FlightDetailsView(offer: offer)
                } label: {
                    HStack(spacing: 6) {
                        Text(L10n.text("flight_details_cta", settings.language))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }
        } else if let candidate = row.candidate {
            FlightCandidatePreviewCard(candidate: candidate)
        }
    }

    private var recommendedOfferID: String? {
        let selectedDay = offers.filter { dayOffset($0.departureAt, from: journey.trip.departureDate) == 0 }
        return (selectedDay.isEmpty ? offers : selectedDay).min(by: { $0.totalPackagePrice < $1.totalPackagePrice })?.id
    }

    private var floatingContinueBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)
            NavigationLink {
                ReturnFlightView()
            } label: {
                HStack(spacing: 10) {
                    Text(L10n.text("flight_choose_return", settings.language))
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.horizontal, 20)
                .frame(height: 58)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func search(continueExisting: Bool) async {
        guard !isSearching else { return }
        guard let makkahHotel = journey.selectedHotel else {
            fatalErrorText = L10n.text("flight_select_hotel_first", settings.language)
            isInitialLoading = false
            return
        }
        let madinahHotel = journey.selectedMadinahHotel
        if journey.trip.scope == .makkahAndMadinah, madinahHotel == nil {
            fatalErrorText = FlowCopy.text(.madinahHotelRequired, settings.language)
            isInitialLoading = false
            return
        }

        if !continueExisting {
            candidates = []
            offers = []
            journey.selectedOutbound = nil
            journey.selectedInbound = nil
            journey.quote = nil
        }

        let generation = UUID()
        searchGeneration = generation
        isSearching = true
        fatalErrorText = nil
        journey.errorMessage = nil
        if candidates.isEmpty && offers.isEmpty { isInitialLoading = true }


        do {
            let final = try await journey.flightService.searchOutboundProgressive(
                trip: journey.trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                onUpdate: { progress in
                    guard searchGeneration == generation else { return }
                    candidates = mergeCandidates(candidates, progress.discoveredCandidates)
                    offers = mergeOffers(offers, progress.pricedOffers)
                    searchStatus = progress.status
                    isSearching = progress.isSearching
                    if !offers.isEmpty || !progress.isSearching {
                        withAnimation(.easeInOut(duration: 0.22)) { isInitialLoading = false }
                    }
                }
            )
            guard searchGeneration == generation else { return }
            offers = mergeOffers(offers, final)
        } catch {
            guard searchGeneration == generation else { return }
            // Provider exhaustion is handled inside the progressive service. Only
            // backend/configuration failures reach this branch.
            fatalErrorText = L10n.error(error, settings.language)
            journey.errorMessage = error.localizedDescription
        }

        guard searchGeneration == generation else { return }
        isSearching = false
        isInitialLoading = false
        if !offers.isEmpty { IumrahHaptics.success() }
    }

    private var hasVerifiedResults: Bool { !offers.isEmpty }

    private var shouldShowImmersive: Bool {
        !hasVerifiedResults && (isSearching || isInitialLoading)
    }

    private func updateImmersive() {
        chrome.setImmersive(shouldShowImmersive)
    }

    private func mergeCandidates(_ lhs: [LiveFlightCandidate], _ rhs: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var result = lhs.filter(\.isDisplayableCandidate)
        var indexByKey = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.deduplicationKey, $0.offset) })
        for candidate in rhs where candidate.isDisplayableCandidate {
            if let index = indexByKey[candidate.deduplicationKey] {
                if candidate.observedAt > result[index].observedAt { result[index] = candidate }
            } else {
                indexByKey[candidate.deduplicationKey] = result.count
                result.append(candidate)
            }
        }
        return result
    }

    private func mergeOffers(_ lhs: [FlightOffer], _ rhs: [FlightOffer]) -> [FlightOffer] {
        var result = lhs.filter { $0.isVerifiedForBooking && isValidOutboundDate($0.departureAt, airportCode: $0.origin) }
        var indexByKey = Dictionary(uniqueKeysWithValues: result.enumerated().map { ($0.element.deduplicationKey, $0.offset) })
        for offer in rhs where offer.isVerifiedForBooking && isValidOutboundDate(offer.departureAt, airportCode: offer.origin) {
            if let index = indexByKey[offer.deduplicationKey] {
                result[index] = offer
            } else {
                indexByKey[offer.deduplicationKey] = result.count
                result.append(offer)
            }
        }
        return result
    }

    private func isValidOutboundDate(_ date: Date, airportCode: String) -> Bool {
        travelDay(date, airportCode: airportCode) < Calendar.current.startOfDay(for: journey.trip.returnDate)
    }

    private func travelDay(_ date: Date, airportCode: String) -> Date {
        var source = Calendar(identifier: .gregorian)
        source.timeZone = FlightReferenceCatalog.timeZone(for: airportCode) ?? TimeZone(secondsFromGMT: 0)!
        let parts = source.dateComponents([.year, .month, .day], from: date)
        return Calendar.current.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day)) ?? Calendar.current.startOfDay(for: date)
    }

    private func flexibleDateHeader(offset: Int, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if journey.trip.flexibility.isWeeklyDiscovery, let date {
                Text(weeklyDateTitle(date))
                    .font(.title3.weight(.bold))
                Text(weeklyDateSubtitle(offset))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(flexibleDateTitle(offset))
                    .font(.title3.weight(.bold))
                if let date {
                    Text("\(localizedDate(date)) · \(flexibleDateSubtitle(offset))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, offset == 0 ? 0 : 8)
    }

    private func weeklyDateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: date).localizedCapitalized
    }

    private func weeklyDateSubtitle(_ offset: Int) -> String {
        let selected = offset == 0
        switch settings.language {
        case .russian: return selected ? "Ваша дата · есть подтверждённый рейс" : "На эту дату найден подтверждённый рейс"
        case .english: return selected ? "Your date · verified flight available" : "A verified flight is available on this date"
        case .uzbek: return selected ? "Siz tanlagan sana · tasdiqlangan reys bor" : "Bu sanada tasdiqlangan reys topildi"
        case .uzbekCyrillic: return selected ? "Сиз танлаган сана · тасдиқланган рейс бор" : "Бу санада тасдиқланган рейс топилди"
        }
    }

    private func flexibleDateTitle(_ offset: Int) -> String {
        switch settings.language {
        case .russian:
            if offset == 0 { return "Ваша выбранная дата" }
            return offset < 0 ? "На \(abs(offset)) дн. раньше" : "На \(offset) дн. позже"
        case .english:
            if offset == 0 { return "Your selected date" }
            return offset < 0 ? "\(abs(offset)) day(s) earlier" : "\(offset) day(s) later"
        case .uzbek:
            if offset == 0 { return "Siz tanlagan sana" }
            return offset < 0 ? "\(abs(offset)) kun oldin" : "\(offset) kun keyin"
        case .uzbekCyrillic:
            if offset == 0 { return "Сиз танлаган сана" }
            return offset < 0 ? "\(abs(offset)) кун олдин" : "\(offset) кун кейин"
        }
    }

    private func flexibleDateSubtitle(_ offset: Int) -> String {
        switch settings.language {
        case .russian:
            return offset == 0 ? "Сначала показываем варианты на выбранный день" : "Нашли дополнительные варианты и хорошие цены рядом с вашей датой"
        case .english:
            return offset == 0 ? "Options on the date you selected" : "More useful options and prices close to your date"
        case .uzbek:
            return offset == 0 ? "Avval tanlangan kundagi variantlar" : "Tanlangan sanaga yaqin qo‘shimcha qulay variantlar"
        case .uzbekCyrillic:
            return offset == 0 ? "Аввал танланган кундаги вариантлар" : "Танланган санага яқин қўшимча қулай вариантлар"
        }
    }

    private func localizedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}
