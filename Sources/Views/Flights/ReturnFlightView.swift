import SwiftUI

struct ReturnFlightView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    @State private var candidates: [LiveFlightCandidate] = []
    @State private var offers: [FlightOffer] = []
    @State private var isInitialLoading = true
    @State private var isSearching = false
    @State private var fatalErrorText: String?
    @State private var searchGeneration = UUID()

    var body: some View {
        Group {
            if isInitialLoading && candidates.isEmpty && offers.isEmpty {
                FlightSearchImmersiveView(state: .searching)
            } else {
                resultsView
                    .iumrahInternalNavigation(progress: .flight)
            }
        }
        .background(isInitialLoading && candidates.isEmpty && offers.isEmpty ? Color.black : Color.iumrahPageBackground)
        .task { await search(continueExisting: false) }
        .onAppear { updateImmersive() }
        .onChange(of: isInitialLoading) { _, _ in updateImmersive() }
        .onDisappear { chrome.setImmersive(false) }
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                IumrahFlowProgress(stage: .flight)
                SectionHeader(
                    L10n.text("flight_return_title", settings.language),
                    eyebrow: L10n.text("flight_return_eyebrow", settings.language),
                    subtitle: L10n.text("flight_return_body", settings.language)
                )

                if let fatalErrorText, candidates.isEmpty && offers.isEmpty {
                    fatalBackendCard(fatalErrorText)
                } else {
                    flightGroups

                    FlightSearchProgressCard(
                        isSearching: isSearching,
                        hasResults: !candidates.isEmpty || !offers.isEmpty,
                        onContinue: { Task { await search(continueExisting: true) } }
                    )
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 112)
        }
        .background(Color.iumrahPageBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if journey.selectedInbound != nil {
                floatingContinueBar
            }
        }
    }

    @ViewBuilder
    private var flightGroups: some View {
        let rows = FlightResultRowModel.merge(candidates: candidates, offers: offers)
        let groups = grouped(rows: rows, anchor: journey.trip.returnDate)

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
                    journey.selectedInbound = offer
                    journey.quote = nil
                    IumrahHaptics.selection()
                } label: {
                    FlightCard(
                        offer: offer,
                        isSelected: journey.selectedInbound?.id == offer.id,
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
        let selectedDay = offers.filter { dayOffset($0.departureAt, from: journey.trip.returnDate) == 0 }
        return (selectedDay.isEmpty ? offers : selectedDay).min(by: { $0.totalPackagePrice < $1.totalPackagePrice })?.id
    }

    private var floatingContinueBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)
            NavigationLink {
                FinalPackageView()
            } label: {
                HStack(spacing: 10) {
                    Text(L10n.text("flight_view_package", settings.language))
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
        guard let makkahHotel = journey.selectedHotel,
              let outbound = journey.selectedOutbound else {
            fatalErrorText = L10n.text("flight_select_outbound_first", settings.language)
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
            journey.selectedInbound = nil
            journey.quote = nil
        }

        let generation = UUID()
        searchGeneration = generation
        isSearching = true
        fatalErrorText = nil
        journey.errorMessage = nil
        if candidates.isEmpty && offers.isEmpty { isInitialLoading = true }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(9))
            guard searchGeneration == generation else { return }
            withAnimation(.easeInOut(duration: 0.22)) { isInitialLoading = false }
        }

        do {
            let final = try await journey.flightService.searchReturnProgressive(
                trip: journey.trip,
                makkahHotel: makkahHotel,
                madinahHotel: madinahHotel,
                outbound: outbound,
                onUpdate: { progress in
                    guard searchGeneration == generation else { return }
                    candidates = mergeCandidates(candidates, progress.discoveredCandidates)
                    offers = mergeOffers(offers, progress.pricedOffers)
                    isSearching = progress.isSearching
                    if !candidates.isEmpty || !offers.isEmpty || !progress.isSearching {
                        withAnimation(.easeInOut(duration: 0.22)) { isInitialLoading = false }
                    }
                }
            )
            guard searchGeneration == generation else { return }
            offers = mergeOffers(offers, final)
        } catch {
            guard searchGeneration == generation else { return }
            fatalErrorText = L10n.error(error, settings.language)
            journey.errorMessage = error.localizedDescription
        }

        guard searchGeneration == generation else { return }
        isSearching = false
        isInitialLoading = false
        if !offers.isEmpty { IumrahHaptics.success() }
    }

    private func updateImmersive() {
        chrome.setImmersive(isInitialLoading && candidates.isEmpty && offers.isEmpty)
    }

    private func grouped(rows: [FlightResultRowModel], anchor: Date) -> [(offset: Int, rows: [FlightResultRowModel])] {
        let byOffset = Dictionary(grouping: rows) { dayOffset($0.departureAt, from: anchor) }
        let preferredOrder = [0, -1, 1, -2, 2]
        let keys = byOffset.keys.sorted { lhs, rhs in
            let li = preferredOrder.firstIndex(of: lhs) ?? (100 + abs(lhs))
            let ri = preferredOrder.firstIndex(of: rhs) ?? (100 + abs(rhs))
            if li != ri { return li < ri }
            return lhs < rhs
        }
        return keys.map { ($0, byOffset[$0, default: []]) }
    }

    private func dayOffset(_ date: Date, from anchor: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: anchor)
        let value = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: value).day ?? 0
    }

    private func mergeCandidates(_ lhs: [LiveFlightCandidate], _ rhs: [LiveFlightCandidate]) -> [LiveFlightCandidate] {
        var result = lhs
        var keys = Set(lhs.map(\.deduplicationKey))
        for candidate in rhs where candidate.isDisplayableCandidate {
            if keys.insert(candidate.deduplicationKey).inserted { result.append(candidate) }
        }
        return result
    }

    private func mergeOffers(_ lhs: [FlightOffer], _ rhs: [FlightOffer]) -> [FlightOffer] {
        var map: [String: FlightOffer] = [:]
        for offer in lhs where offer.isVerifiedForBooking { map[offer.sourceCandidateID ?? offer.id] = offer }
        for offer in rhs where offer.isVerifiedForBooking { map[offer.sourceCandidateID ?? offer.id] = offer }
        return Array(map.values)
    }

    private func flexibleDateHeader(offset: Int, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(flexibleDateTitle(offset))
                .font(.title3.weight(.bold))
            if let date {
                Text("\(localizedDate(date)) · \(flexibleDateSubtitle(offset))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, offset == 0 ? 0 : 8)
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
            return offset == 0 ? "Сначала показываем варианты на выбранный день" : "Дополнительные варианты рядом с вашей датой"
        case .english:
            return offset == 0 ? "Options on the date you selected" : "More options close to your selected date"
        case .uzbek:
            return offset == 0 ? "Avval tanlangan kundagi variantlar" : "Tanlangan sanaga yaqin qo‘shimcha variantlar"
        case .uzbekCyrillic:
            return offset == 0 ? "Аввал танланган кундаги вариантлар" : "Танланган санага яқин қўшимча вариантлар"
        }
    }

    private func localizedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.localeIdentifier)
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    private func fatalBackendCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(backendTitle, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(backendRetryTitle) { Task { await search(continueExisting: true) } }
                .buttonStyle(IumrahSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .iumrahCard()
    }

    private var backendTitle: String {
        switch settings.language {
        case .russian: return "Не удалось рассчитать пакет"
        case .english: return "Package pricing is unavailable"
        case .uzbek: return "Paket narxini hisoblab bo‘lmadi"
        case .uzbekCyrillic: return "Пакет нархини ҳисоблаб бўлмади"
        }
    }

    private var backendRetryTitle: String {
        switch settings.language {
        case .russian: return "Повторить расчёт"
        case .english: return "Try pricing again"
        case .uzbek: return "Qayta hisoblash"
        case .uzbekCyrillic: return "Қайта ҳисоблаш"
        }
    }
}
