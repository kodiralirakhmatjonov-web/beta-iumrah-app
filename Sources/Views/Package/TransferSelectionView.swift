import SwiftUI
import Foundation

private enum TransferDiscoveryPhase {
    case searching
    case matched
}

struct TransferSelectionView: View {
    @EnvironmentObject private var journey: JourneyStore
    @EnvironmentObject private var settings: AppSettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var discoveryPhase: TransferDiscoveryPhase = .searching
    @State private var searchStep = 0
    @State private var routeProgress: CGFloat = 0.04
    @State private var pulse = false
    @State private var selectedIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showTrainDetails = false
    @State private var showFinalPackage = false
    @State private var isConfirming = false
    @State private var confirmationError: String?

    private let vehicles = TransferVehicleKind.allCases

    private var selectedVehicle: TransferVehicleKind {
        vehicles[min(max(selectedIndex, 0), vehicles.count - 1)]
    }

    private var includesMadinah: Bool { journey.trip.scope == .makkahAndMadinah }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                IumrahFlowProgress(stage: .transfer)

                if discoveryPhase == .searching {
                    discoveryScene
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    matchedScene
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 44)
        }
        .background(Color.iumrahPageBackground)
        .iumrahInternalNavigation(progress: .transfer)
        .navigationDestination(isPresented: $showFinalPackage) {
            FinalPackageView()
        }
        .sheet(isPresented: $showTrainDetails) {
            HaramainTrainDetailSheet(
                isSelected: journey.haramainTrainSelected,
                routeTitle: trainSegmentTitle,
                addOnPrice: journey.haramainTrainAddOnUsd,
                language: settings.language,
                onChange: { selected in
                    journey.setHaramainTrainSelected(selected)
                    IumrahHaptics.selection()
                }
            )
        }
        .alert(errorTitle, isPresented: Binding(
            get: { confirmationError != nil },
            set: { if !$0 { confirmationError = nil } }
        )) {
            Button("OK", role: .cancel) { confirmationError = nil }
        } message: {
            Text(confirmationError ?? "")
        }
        .task { await startDiscoveryIfNeeded() }
    }

    private var discoveryScene: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.12 : 0.78)
                        .opacity(pulse ? 0.55 : 1)
                    Text(localized("iumrah Transfer", "iumrah Transfer", "iumrah Transfer", "iumrah Transfer"))
                        .font(.caption.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(.secondary)
                }

                Text(localized(
                    "Подбираем трансфер для вашей поездки",
                    "Matching a transfer to your trip",
                    "Safaringiz uchun transfer tanlanmoqda",
                    "Сафарингиз учун трансфер танланмоқда"
                ))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)

                Text("\(routeTitle) · \(dateRangeTitle)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            TransferDiscoveryMap(
                includeMadinah: includesMadinah,
                progress: routeProgress,
                pulse: pulse,
                arrivalCode: journey.trip.outboundDestinationCode,
                language: settings.language
            )
            .frame(height: 248)

            HStack(spacing: 13) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 3) {
                    Text(searchStatusTitle)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.opacity)
                    Text(localized(
                        "Сопоставляем маршрут, группу и багаж с доступным классом автомобиля.",
                        "Matching your route, group and luggage with an available vehicle class.",
                        "Yo‘nalish, guruh va bagajga mos mavjud avtomobil klassi tanlanmoqda.",
                        "Йўналиш, гуруҳ ва багажга мос мавжуд автомобиль класси танланмоқда."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.iumrahCardBackground.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.iumrahCardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.055), radius: 28, y: 14)
    }

    private var matchedScene: some View {
        VStack(spacing: 20) {
            matchedHeader
            vehicleStage
            vehicleInformation
            if includesMadinah { haramainCard }
            confirmationButton
        }
    }

    private var matchedHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                Text(localized(
                    "Трансфер найден",
                    "Transfer matched",
                    "Transfer topildi",
                    "Трансфер топилди"
                ))
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedIndex + 1) / \(vehicles.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Text(localized(
                "Нашли подходящий автомобиль",
                "We found a suitable vehicle",
                "Sizga mos avtomobil topildi",
                "Сизга мос автомобиль топилди"
            ))
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .tracking(-0.85)

            Text("\(routeTitle) · \(dateRangeTitle)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vehicleStage: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let pageWidth = max(width * 0.78, 1)

            ZStack {
                TransferStageBackground(
                    label: vehicleClassTitle(selectedVehicle).uppercased(),
                    number: String(format: "%02d", selectedIndex + 1),
                    parallax: dragOffset * 0.18
                )

                ForEach(Array(vehicles.enumerated()), id: \.element.id) { index, vehicle in
                    let relative = CGFloat(index - selectedIndex) + (dragOffset / pageWidth)
                    let distance = min(abs(relative), 1.25)
                    let scale = 1 - min(distance, 1) * 0.115
                    let opacity = 1 - min(distance, 1) * 0.48

                    TransferVehicleHero(vehicle: vehicle, active: distance < 0.16)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .offset(
                            x: relative * width * 0.82,
                            y: min(distance, 1) * 8
                        )
                        .zIndex(Double(10 - distance))
                        .accessibilityHidden(index != selectedIndex)
                }
            }
            .contentShape(Rectangle())
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isConfirming else { return }
                        dragOffset = resistedTranslation(value.translation.width)
                    }
                    .onEnded { value in
                        guard !isConfirming else { return }
                        finishDrag(value, pageWidth: pageWidth)
                    }
            )
        }
        .frame(height: 326)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.055), radius: 30, y: 16)
    }

    private var vehicleInformation: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(vehicleClassTitle(selectedVehicle))
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(selectedVehicle.modelName)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-0.45)
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Label(availabilityTitle, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    if isRecommended(selectedVehicle) {
                        Text(localized("Рекомендуем", "Recommended", "Tavsiya", "Тавсия"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 9)
                            .frame(height: 25)
                            .background(Color.iumrahCareLight.opacity(0.14), in: Capsule())
                    }
                }
            }

            Text(vehicleRecommendationBody(selectedVehicle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 9) {
                metricChip(systemName: "person.2.fill", text: passengerMetric)
                metricChip(systemName: "suitcase.fill", text: luggageMetric)
                if requiredVehicleCount(for: selectedVehicle) > 1 {
                    metricChip(
                        systemName: "car.2.fill",
                        text: "\(requiredVehicleCount(for: selectedVehicle)) ×"
                    )
                }
            }
        }
        .padding(19)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
    }

    private var haramainCard: some View {
        Button {
            showTrainDetails = true
            IumrahHaptics.soft()
        } label: {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    Image("HaramainMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localized(
                            "Быстрый участок маршрута",
                            "Faster intercity option",
                            "Tezroq shaharlararo yo‘l",
                            "Тезроқ шаҳарлараро йўл"
                        ))
                        .font(.subheadline.weight(.bold))

                        Text("Haramain · \(trainSegmentTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 6)

                    Image(systemName: journey.haramainTrainSelected ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(journey.haramainTrainSelected ? Color.green : Color.secondary)
                }

                Text(localized(
                    "Часть междугороднего переезда можно заменить скоростным поездом. Трансфер до станции и после прибытия остаётся частью маршрута iumrah.",
                    "Replace the intercity road segment with high-speed rail. Station transfers before and after the train stay connected inside your iumrah route.",
                    "Shaharlararo avtomobil qismini tezyurar poyezdga almashtiring. Vokzalgacha va undan keyingi transfer iumrah yo‘nalishida qoladi.",
                    "Шаҳарлараро автомобиль қисмини тезюрар поездга алмаштиринг. Вокзалгача ва ундан кейинги трансфер iumrah йўналишида қолади."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Label("≈ 2 h", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(journey.haramainTrainSelected ? selectedAddOnTitle : addOnPriceTitle)
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(.primary)
            .padding(18)
            .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        journey.haramainTrainSelected ? Color.iumrahCareLight.opacity(0.5) : Color.primary.opacity(0.06),
                        lineWidth: journey.haramainTrainSelected ? 1.2 : 0.7
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var confirmationButton: some View {
        Button {
            Task { await confirmTransfer() }
        } label: {
            HStack(spacing: 10) {
                if isConfirming { ProgressView().tint(.white) }
                Text(isConfirming ? confirmingTitle : confirmTitle)
                if !isConfirming {
                    Spacer(minLength: 10)
                    Image(systemName: "arrow.right")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(IumrahPrimaryButtonStyle())
        .disabled(isConfirming)
    }

    private func metricChip(systemName: String, text: String) -> some View {
        Label(text, systemImage: systemName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.iumrahRaisedBackground, in: Capsule())
    }

    @MainActor
    private func startDiscoveryIfNeeded() async {
        let recommended = journey.selectedTransferVehicle ?? journey.recommendedTransferVehicle()
        selectedIndex = vehicles.firstIndex(of: recommended) ?? 0
        if journey.selectedTransferVehicle == nil { journey.chooseTransferVehicle(recommended) }

        if journey.transferSelectionConfirmed {
            discoveryPhase = .matched
            routeProgress = 1
            pulse = false
            return
        }

        pulse = true
        if reduceMotion {
            routeProgress = 1
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            discoveryPhase = .matched
            pulse = false
            return
        }

        withAnimation(.easeInOut(duration: 1.35)) { routeProgress = 1 }
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) { pulse.toggle() }

        for step in 1...2 {
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) { searchStep = step }
        }

        try? await Task.sleep(for: .milliseconds(480))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.90)) {
            discoveryPhase = .matched
            pulse = false
        }
        IumrahHaptics.success()
    }

    private func resistedTranslation(_ raw: CGFloat) -> CGFloat {
        if selectedIndex == 0, raw > 0 { return raw * 0.32 }
        if selectedIndex == vehicles.count - 1, raw < 0 { return raw * 0.32 }
        return raw
    }

    private func finishDrag(_ value: DragGesture.Value, pageWidth: CGFloat) {
        let projected = value.predictedEndTranslation.width
        let threshold = pageWidth * 0.19
        var target = selectedIndex

        if projected < -threshold {
            target = min(vehicles.count - 1, selectedIndex + 1)
        } else if projected > threshold {
            target = max(0, selectedIndex - 1)
        }

        withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) {
            selectedIndex = target
            dragOffset = 0
        }

        let selected = vehicles[target]
        if journey.selectedTransferVehicle != selected {
            journey.chooseTransferVehicle(selected)
            IumrahHaptics.selection()
        }
    }

    @MainActor
    private func confirmTransfer() async {
        guard !isConfirming else { return }
        isConfirming = true
        confirmationError = nil
        journey.chooseTransferVehicle(selectedVehicle)
        journey.confirmTransferSelection()

        if !journey.hasFinalGeneratorQuote {
            await journey.buildQuote(forceHotelRefresh: false)
        }

        guard journey.hasFinalGeneratorQuote else {
            journey.transferSelectionConfirmed = false
            confirmationError = journey.errorMessage ?? localized(
                "Не удалось подтвердить итоговую конфигурацию поездки. Попробуйте ещё раз.",
                "The trip configuration could not be confirmed. Please try again.",
                "Safar konfiguratsiyasini tasdiqlab bo‘lmadi. Qayta urinib ko‘ring.",
                "Сафар конфигурациясини тасдиқлаб бўлмади. Қайта уриниб кўринг."
            )
            isConfirming = false
            IumrahHaptics.error()
            return
        }

        if !reduceMotion { try? await Task.sleep(for: .milliseconds(260)) }
        IumrahHaptics.success()
        isConfirming = false
        showFinalPackage = true
    }

    private func vehicleClassTitle(_ vehicle: TransferVehicleKind) -> String {
        switch vehicle {
        case .malibu: return localized("Sedan", "Sedan", "Sedan", "Sedan")
        case .carnival: return localized("Family", "Family", "Family", "Family")
        case .yukon: return "VIP"
        }
    }

    private func vehicleRecommendationBody(_ vehicle: TransferVehicleKind) -> String {
        switch vehicle {
        case .malibu:
            return localized(
                "Спокойный приватный трансфер для небольшой группы и компактного багажа.",
                "A calm private transfer for a small group with compact luggage.",
                "Kichik guruh va ixcham bagaj uchun qulay shaxsiy transfer.",
                "Кичик гуруҳ ва ихчам багаж учун қулай шахсий трансфер."
            )
        case .carnival:
            return localized(
                "Больше пространства для семьи и багажа — оптимальный вариант для большинства Umrah-поездок.",
                "More room for family and luggage — the balanced choice for most Umrah trips.",
                "Oila va bagaj uchun ko‘proq joy — aksariyat Umra safarlari uchun muvozanatli tanlov.",
                "Оила ва багаж учун кўпроқ жой — аксарият Умра сафарлари учун мувозанатли танлов."
            )
        case .yukon:
            return localized(
                "Повышенный уровень пространства и приватности для премиального трансфера.",
                "Extra space and privacy for a premium transfer experience.",
                "Premium transfer uchun ko‘proq joy va maxfiylik.",
                "Премиум трансфер учун кўпроқ жой ва махфийлик."
            )
        }
    }

    private func isRecommended(_ vehicle: TransferVehicleKind) -> Bool {
        vehicle == journey.recommendedTransferVehicle()
    }

    private func requiredVehicleCount(for vehicle: TransferVehicleKind) -> Int {
        max(1, Int(ceil(Double(max(1, journey.trip.travelerCount)) / Double(vehicle.passengerCapacity))))
    }

    private var passengerMetric: String {
        "\(min(journey.trip.travelerCount, selectedVehicle.passengerCapacity))/\(selectedVehicle.passengerCapacity)"
    }

    private var luggageMetric: String { "≤ \(selectedVehicle.luggageCapacity)" }

    private var availabilityTitle: String {
        localized("Подходит вашим датам", "Fits your dates", "Sanalaringizga mos", "Саналарингизга мос")
    }

    private var searchStatusTitle: String {
        switch searchStep {
        case 0:
            return localized("Проверяем маршрут", "Checking your route", "Yo‘nalish tekshirilmoqda", "Йўналиш текширилмоқда")
        case 1:
            return localized("Учитываем группу и багаж", "Matching group and luggage", "Guruh va bagaj hisoblanmoqda", "Гуруҳ ва багаж ҳисобланмоқда")
        default:
            return localized("Подбираем доступный класс", "Finding an available class", "Mavjud klass tanlanmoqda", "Мавжуд класс танланмоқда")
        }
    }

    private var routeTitle: String {
        if !includesMadinah { return "JED → Makkah" }
        return journey.trip.arrivalAirport == .madinah
            ? "MED → Madinah → Makkah → JED"
            : "JED → Makkah → Madinah → MED"
    }

    private var trainSegmentTitle: String {
        journey.trip.arrivalAirport == .madinah ? "Madinah → Makkah" : "Makkah → Madinah"
    }

    private var dateRangeTitle: String {
        "\(shortDate(journey.trip.departureDate)) – \(shortDate(journey.trip.returnDate))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter.string(from: date)
    }

    private var localeIdentifier: String {
        switch settings.language {
        case .russian: return "ru_RU"
        case .english: return "en_US"
        case .uzbek: return "uz_Latn_UZ"
        case .uzbekCyrillic: return "uz_Cyrl_UZ"
        }
    }

    private var addOnPriceTitle: String {
        "+\(usd(journey.haramainTrainAddOnUsd)) " + localized("к пакету", "to package", "paketga", "пакетга")
    }

    private var selectedAddOnTitle: String {
        localized("Добавлено", "Added", "Qo‘shildi", "Қўшилди")
    }

    private var confirmTitle: String {
        localized("Подтвердить трансфер", "Confirm transfer", "Transferni tasdiqlash", "Трансферни тасдиқлаш")
    }

    private var confirmingTitle: String {
        localized("Подтверждаем трансфер…", "Confirming transfer…", "Transfer tasdiqlanmoqda…", "Трансфер тасдиқланмоқда…")
    }

    private var errorTitle: String {
        localized("Не удалось продолжить", "Could not continue", "Davom ettirib bo‘lmadi", "Давом эттириб бўлмади")
    }

    private func usd(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "$%.0f", number)
    }

    private func localized(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        transferLocalized(settings.language, russian: ru, english: en, uzbek: uz, uzbekCyrillic: uzCy)
    }
}

private struct TransferStageBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    let number: String
    let parallax: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.105, green: 0.11, blue: 0.12), Color(red: 0.055, green: 0.06, blue: 0.07)]
                    : [Color(red: 0.985, green: 0.985, blue: 0.99), Color(red: 0.92, green: 0.93, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(colorScheme == .dark ? 0.13 : 0.72), .clear],
                center: UnitPoint(x: 0.58, y: 0.43),
                startRadius: 8,
                endRadius: 235
            )

            Text(number)
                .font(.system(size: 116, weight: .black, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.035))
                .offset(x: -110 + parallax * 0.22, y: -78)

            Text(label)
                .font(.system(size: 64, weight: .black, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(Color.primary.opacity(0.045))
                .offset(x: parallax, y: 80)
                .padding(.horizontal, 18)
        }
    }
}

private struct TransferVehicleHero: View {
    let vehicle: TransferVehicleKind
    let active: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(active ? 0.18 : 0.10))
                .frame(width: active ? 250 : 220, height: active ? 34 : 25)
                .blur(radius: active ? 18 : 15)
                .offset(y: 92)

            Image(vehicle.assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 350, maxHeight: 260)
        }
        .padding(.horizontal, 4)
    }
}

private struct TransferDiscoveryMap: View {
    let includeMadinah: Bool
    let progress: CGFloat
    let pulse: Bool
    let arrivalCode: String
    let language: AppSettingsStore.Language

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.primary.opacity(0.026))

                TransferGrid()
                    .stroke(Color.primary.opacity(0.045), lineWidth: 0.6)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                TransferRouteShape(includeMadinah: includeMadinah)
                    .stroke(Color.primary.opacity(0.11), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .padding(24)

                TransferRouteShape(includeMadinah: includeMadinah)
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [Color.iumrahCareLight.opacity(0.65), Color.primary.opacity(0.85)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .padding(24)

                routeNode(title: arrivalCode, subtitle: airportSubtitle, point: CGPoint(x: 0.16, y: 0.72), size: proxy.size)
                routeNode(title: "Makkah", subtitle: hotelSubtitle, point: CGPoint(x: 0.52, y: 0.35), size: proxy.size)
                if includeMadinah {
                    routeNode(title: "Madinah", subtitle: citySubtitle, point: CGPoint(x: 0.84, y: 0.60), size: proxy.size)
                }

                ForEach(0..<3, id: \.self) { index in
                    let points: [CGPoint] = [
                        CGPoint(x: 0.31, y: 0.57),
                        CGPoint(x: 0.64, y: 0.43),
                        CGPoint(x: 0.75, y: includeMadinah ? 0.55 : 0.37)
                    ]
                    let pt = points[index]
                    ZStack {
                        Circle()
                            .stroke(Color.iumrahCareLight.opacity(0.35), lineWidth: 1)
                            .frame(width: pulse ? 34 : 18, height: pulse ? 34 : 18)
                            .opacity(pulse ? 0.15 : 0.65)
                        Image(systemName: "car.side.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.62))
                    }
                    .position(x: proxy.size.width * pt.x, y: proxy.size.height * pt.y)
                }
            }
        }
    }

    private func routeNode(title: String, subtitle: String, point: CGPoint, size: CGSize) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.iumrahCardBackground)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 2))
                .overlay(Circle().fill(Color.primary).frame(width: 6, height: 6))
            Text(title)
                .font(.caption.weight(.bold))
            Text(subtitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .position(x: size.width * point.x, y: size.height * point.y)
    }

    private var airportSubtitle: String {
        transferLocalized(language, russian: "Аэропорт", english: "Airport", uzbek: "Aeroport", uzbekCyrillic: "Аэропорт")
    }
    private var hotelSubtitle: String {
        transferLocalized(language, russian: "Отель", english: "Hotel", uzbek: "Mehmonxona", uzbekCyrillic: "Меҳмонхона")
    }
    private var citySubtitle: String {
        transferLocalized(language, russian: "Маршрут", english: "Route", uzbek: "Yo‘nalish", uzbekCyrillic: "Йўналиш")
    }
}

private struct TransferRouteShape: Shape {
    let includeMadinah: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let a = CGPoint(x: rect.width * 0.16, y: rect.height * 0.72)
        let b = CGPoint(x: rect.width * 0.52, y: rect.height * 0.35)
        path.move(to: a)
        path.addCurve(
            to: b,
            control1: CGPoint(x: rect.width * 0.28, y: rect.height * 0.72),
            control2: CGPoint(x: rect.width * 0.38, y: rect.height * 0.35)
        )
        if includeMadinah {
            let c = CGPoint(x: rect.width * 0.84, y: rect.height * 0.60)
            path.addCurve(
                to: c,
                control1: CGPoint(x: rect.width * 0.66, y: rect.height * 0.30),
                control2: CGPoint(x: rect.width * 0.72, y: rect.height * 0.62)
            )
        }
        return path
    }
}

private struct TransferGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 34
        stride(from: 0, through: rect.width, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        stride(from: 0, through: rect.height, by: step).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}

private struct HaramainTrainDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let isSelected: Bool
    let routeTitle: String
    let addOnPrice: Decimal
    let language: AppSettingsStore.Language
    let onChange: (Bool) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    heading
                    hybridRoute
                    explanation
                    actionArea
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
            }
            .background(Color.iumrahPageBackground)
            .navigationTitle("Haramain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                            .iumrahGlass(in: Circle(), interactive: true, chrome: true)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("HaramainHero")
                .resizable()
                .scaledToFill()
                .frame(height: 255)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Image("HaramainLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 188, height: 48)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(routeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.top, 8)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text("Гибридный маршрут", "Hybrid route", "Gibrid yo‘nalish", "Гибрид йўналиш"))
                .font(.caption.weight(.bold))
                .tracking(0.9)
                .foregroundStyle(.secondary)
            Text(text(
                "Сделать межгородской участок быстрее?",
                "Make the intercity segment faster?",
                "Shaharlararo qismni tezlashtirasizmi?",
                "Шаҳарлараро қисмни тезлаштирасизми?"
            ))
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .tracking(-0.7)
            Text(text(
                "Автомобиль остаётся частью поездки. Поезд заменяет только участок между Меккой и Мединой.",
                "Your private transfer stays part of the trip. The train replaces only the Makkah–Madinah intercity segment.",
                "Shaxsiy transfer safarda qoladi. Poyezd faqat Makka–Madina orasidagi shaharlararo qismni almashtiradi.",
                "Шахсий трансфер сафарда қолади. Поезд фақат Макка–Мадина орасидаги шаҳарлараро қисмни алмаштиради."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var hybridRoute: some View {
        HStack(spacing: 8) {
            routeLeg(icon: "car.fill", title: text("До станции", "To station", "Vokzalgacha", "Вокзалгача"))
            routeConnector
            routeLeg(icon: "tram.fill", title: "Haramain")
            routeConnector
            routeLeg(icon: "car.fill", title: text("До отеля", "To hotel", "Mehmonxonaga", "Меҳмонхонага"))
        }
        .padding(16)
        .background(Color.iumrahCardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7) }
    }

    private func routeLeg(icon: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(Color.iumrahRaisedBackground, in: Circle())
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var routeConnector: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow(icon: "clock.fill", title: "≈ 2 h", body: text("между Меккой и Мединой", "between Makkah and Madinah", "Makka va Madina orasida", "Макка ва Мадина орасида"))
            detailRow(icon: "arrow.trianglehead.branch", title: text("Единый маршрут", "Connected route", "Yagona yo‘nalish", "Ягона йўналиш"), body: text("iumrah связывает автомобиль → поезд → автомобиль", "iumrah connects car → train → car", "iumrah avtomobil → poyezd → avtomobilni bog‘laydi", "iumrah автомобиль → поезд → автомобилни боғлайди"))
            detailRow(icon: "plus.circle.fill", title: moneyTitle, body: text("добавляется к итоговой цене пакета", "added to the package total", "paketning yakuniy narxiga qo‘shiladi", "пакетнинг якуний нархига қўшилади"))
        }
    }

    private func detailRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.iumrahRaisedBackground, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            Button {
                onChange(!isSelected)
                dismiss()
            } label: {
                Text(isSelected
                     ? text("Использовать автомобиль на всём маршруте", "Use road transfer for the full route", "Butun yo‘lda avtomobildan foydalanish", "Бутун йўлда автомобилдан фойдаланиш")
                     : text("Добавить поезд в маршрут", "Add train to route", "Poyezdni yo‘nalishga qo‘shish", "Поездни йўналишга қўшиш"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(IumrahPrimaryButtonStyle())

            if !isSelected {
                Text(moneyTitle + " · " + text("к пакету", "to package", "paketga", "пакетга"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var moneyTitle: String {
        String(format: "+$%.0f", NSDecimalNumber(decimal: addOnPrice).doubleValue)
    }

    private func text(_ ru: String, _ en: String, _ uz: String, _ uzCy: String) -> String {
        transferLocalized(language, russian: ru, english: en, uzbek: uz, uzbekCyrillic: uzCy)
    }
}

private func transferLocalized(
    _ language: AppSettingsStore.Language,
    russian: String,
    english: String,
    uzbek: String,
    uzbekCyrillic: String
) -> String {
    switch language {
    case .russian: return russian
    case .english: return english
    case .uzbek: return uzbek
    case .uzbekCyrillic: return uzbekCyrillic
    }
}
